[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 120,
    [int]$ExportTimeoutSeconds = 0,
    [switch]$RequireExportEvidence,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ($RequireExportEvidence -and $ExportTimeoutSeconds -le 0) {
    $ExportTimeoutSeconds = 760
}
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$apkItem = Get-Item -LiteralPath $ApkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\qhps\$runId"
$remoteScreenshot = '/sdcard/Download/brb_hand_contact_physics_smoke.png'
$summaryPath = Join-Path $outDir 'quest-hand-contact-physics-smoke-summary.json'
$deviceExportDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"
$pulledRoot = Join-Path $outDir 'pulled'
$pulledExportDir = Join-Path $pulledRoot 'BigRedButtonFirstStudyExports'

$script:predictivePreloadEvents = 0
$script:acceptedHandSelects = 0
$script:handContactPresses = 0
$script:pressMechanicsEvents = 0
$script:handContactExportPresses = 0
$script:exportSchemaStatus = 'not_requested'
$script:exportEvidencePath = ''
$script:evidenceValidationPath = ''
$script:pressMechanicsAnalysisPath = ''
$script:pressMechanicsAnalysisStatus = 'not_requested'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Save-Evidence {
    Invoke-Adb logcat -d -v time |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|GLTF|FATAL EXCEPTION|E/AndroidRuntime' |
        Set-Content -LiteralPath (Join-Path $outDir 'logcat-filtered.txt') -Encoding UTF8
    Invoke-Adb shell dumpsys activity activities |
        Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
        Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'screenshot.png') |
        Tee-Object -FilePath (Join-Path $outDir 'screenshot-pull.txt') |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

function Update-LogCounters {
    $logPath = Join-Path $outDir 'logcat-filtered.txt'
    if (-not (Test-Path -LiteralPath $logPath)) {
        return
    }
    $logText = Get-Content -Raw -LiteralPath $logPath
    $script:predictivePreloadEvents = ([regex]::Matches($logText, 'BRB_BUTTON_HAND_IMPACT_PREDICTED')).Count
    $script:acceptedHandSelects = ([regex]::Matches($logText, 'BRB_BUTTON_HAND_CONTACT_SELECT accepted=true')).Count
    $script:handContactPresses = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=hand_contact')).Count
    $script:pressMechanicsEvents = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS_MECHANICS .*source=hand_contact')).Count
}

function Wait-ForExportEvidence {
    if ($ExportTimeoutSeconds -le 0) {
        return
    }
    $deadline = (Get-Date).AddSeconds($ExportTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $files = @(Invoke-Adb shell find $deviceExportDir -type f 2>$null | ForEach-Object { "$_".Trim() } | Where-Object { $_ -match 'press_events\.csv$|\.json$' })
        if ($files.Count -gt 0) {
            New-Item -ItemType Directory -Force -Path $pulledRoot | Out-Null
            Invoke-Adb pull $deviceExportDir $pulledRoot |
                Tee-Object -FilePath (Join-Path $outDir 'export-pull.txt') |
                Out-Host
            $script:exportEvidencePath = $pulledExportDir
            try {
                & (Join-Path $projectRoot 'tools\validate-export-schema.ps1') -ExportDir $pulledExportDir |
                    Tee-Object -FilePath (Join-Path $outDir 'export-schema-validation.txt') |
                    Out-Host
                $script:exportSchemaStatus = 'pass'
            } catch {
                $script:exportSchemaStatus = "fail: $($_.Exception.Message)"
                throw
            }
            $pressCsv = Get-ChildItem -Path $pulledExportDir -Recurse -File -Filter '*press_events.csv' | Select-Object -First 1
            if ($null -ne $pressCsv) {
                $rows = @(Import-Csv -LiteralPath $pressCsv.FullName)
                $script:handContactExportPresses = @($rows | Where-Object { $_.input_source -eq 'hand_contact' -and $_.press_mechanics_trigger_evidence }).Count
            }
            return
        }
        Start-Sleep -Seconds 5
    }
    if ($RequireExportEvidence) {
        throw "No export evidence appeared within $ExportTimeoutSeconds seconds."
    }
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()

function Write-HandContactSummary {
    param(
        [string]$Status,
        [string]$ErrorMessage = ''
    )
    [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = $Status
        error = $ErrorMessage
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        apkSizeBytes = $apkItem.Length
        evidenceDir = $outDir
        predictivePreloadEvents = $script:predictivePreloadEvents
        acceptedHandSelects = $script:acceptedHandSelects
        handContactPresses = $script:handContactPresses
        pressMechanicsEvents = $script:pressMechanicsEvents
        exportEvidenceRequired = [bool]$RequireExportEvidence
        exportSchemaStatus = $script:exportSchemaStatus
        exportEvidencePath = $script:exportEvidencePath
        handContactExportPresses = $script:handContactExportPresses
        evidenceValidationPath = $script:evidenceValidationPath
        pressMechanicsAnalysisPath = $script:pressMechanicsAnalysisPath
        pressMechanicsAnalysisStatus = $script:pressMechanicsAnalysisStatus
        note = 'Fast human-operated hand-contact physics smoke. This is supplemental paper-relevant evidence for hand_contact feel and mechanics; it does not replace controller_contact final proof.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

Write-Host "Quest hand-contact physics smoke target: serial=$Serial model=$model android=$android"
Write-Host "Operator requirement: enable hand tracking, keep controllers quiet, and press the modeled Big Red Button with your hand."
Write-Host "Expected markers: BRB_BUTTON_HAND_IMPACT_PREDICTED, BRB_BUTTON_HAND_CONTACT_SELECT accepted=true, BRB_BUTTON_PRESS source=hand_contact, and BRB_BUTTON_PRESS_MECHANICS source=hand_contact."
Write-Host "This supplemental smoke does not satisfy the final controller_contact proof gate."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb logcat -c
    Invoke-Adb shell am start -n $activity --ez brb.physicalPressValidation true |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $pressDetected = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        $markers = Invoke-Adb logcat -d -v time |
            Select-String -Pattern 'BRB_BUTTON_HAND_IMPACT_PREDICTED|BRB_BUTTON_HAND_CONTACT_SELECT accepted=true|BRB_BUTTON_PRESS .*source=hand_contact|BRB_BUTTON_PRESS_MECHANICS .*source=hand_contact|FATAL EXCEPTION|E/AndroidRuntime'
        if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during hand-contact physics smoke."
        }
        if (($markers | Select-String -Pattern 'BRB_BUTTON_HAND_IMPACT_PREDICTED') -and
            ($markers | Select-String -Pattern 'BRB_BUTTON_HAND_CONTACT_SELECT accepted=true') -and
            ($markers | Select-String -Pattern 'BRB_BUTTON_PRESS .*source=hand_contact') -and
            ($markers | Select-String -Pattern 'BRB_BUTTON_PRESS_MECHANICS .*source=hand_contact')) {
            $pressDetected = $true
            break
        }
        $elapsed = [int]($TimeoutSeconds - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds))
        Write-Host "Waiting for hand_contact predictive preload + accepted press... elapsed ${elapsed}s"
    }

    Save-Evidence
    Update-LogCounters

    if (-not $pressDetected) {
        throw "No complete hand_contact predictive preload + accepted mechanics sequence detected within $TimeoutSeconds seconds. See $outDir"
    }
    if ($script:predictivePreloadEvents -lt 1) {
        throw "hand_contact press detected but predictive preload marker was missing."
    }
    if ($script:acceptedHandSelects -lt 1) {
        throw "hand_contact press detected but accepted hand select marker was missing."
    }
    if ($script:handContactPresses -lt 1 -or $script:pressMechanicsEvents -lt 1) {
        throw "hand_contact mechanics markers were incomplete in saved logcat."
    }

    Wait-ForExportEvidence
    if ($RequireExportEvidence -and $script:handContactExportPresses -lt 1) {
        throw "Required export evidence did not contain a hand_contact press with mechanics trigger evidence."
    }

    $script:evidenceValidationPath = Join-Path $outDir 'hand-contact-physics-evidence-validation.json'
    $validatorArgs = @(
        '-EvidenceDir', $outDir,
        '-OutPath', $script:evidenceValidationPath
    )
    if ($RequireExportEvidence) {
        $validatorArgs += '-RequireExportEvidence'
    }
    & (Join-Path $projectRoot 'tools\validate-hand-contact-physics-evidence.ps1') @validatorArgs |
        Tee-Object -FilePath (Join-Path $outDir 'hand-contact-physics-evidence-validation.txt') |
        Out-Host

    if (-not [string]::IsNullOrWhiteSpace($script:exportEvidencePath)) {
        $analysisDir = Join-Path $outDir 'press-mechanics-analysis'
        try {
            & (Join-Path $projectRoot 'tools\analyze-hand-contact-press-mechanics.ps1') -EvidenceDir $outDir -OutDir $analysisDir -RequireHandContact |
                Tee-Object -FilePath (Join-Path $outDir 'press-mechanics-analysis.txt') |
                Out-Host
            $script:pressMechanicsAnalysisPath = Join-Path $analysisDir 'press-mechanics-analysis.json'
            $script:pressMechanicsAnalysisStatus = 'pass'
        } catch {
            $script:pressMechanicsAnalysisPath = Join-Path $analysisDir 'press-mechanics-analysis.json'
            $script:pressMechanicsAnalysisStatus = "fail: $($_.Exception.Message)"
            throw
        }
    }

    Write-HandContactSummary -Status 'pass'
    Write-Host "PASS Quest hand-contact physics smoke"
    Write-Host "Summary: $summaryPath"
} catch {
    $failureMessage = $_.Exception.Message
    try {
        Save-Evidence
        Update-LogCounters
    } catch {
        Write-Warning "Could not save full hand-contact failure evidence: $($_.Exception.Message)"
    }
    Write-HandContactSummary -Status 'fail' -ErrorMessage $failureMessage
    Write-Host "FAIL Quest hand-contact physics smoke"
    Write-Host "Summary: $summaryPath"
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
