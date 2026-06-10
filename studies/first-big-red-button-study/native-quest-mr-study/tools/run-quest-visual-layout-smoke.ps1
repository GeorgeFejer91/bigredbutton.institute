[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 45,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\quest-visual-layout-smoke\$runId"
$remoteScreenshot = '/sdcard/Download/brb_visual_layout_smoke.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Save-Evidence {
    $fullLogPath = Join-Path $outDir 'logcat-full.txt'
    $filteredLogPath = Join-Path $outDir 'logcat-filtered.txt'
    $fullLog = @(Invoke-Adb logcat -d -v time)
    $fullLog | Set-Content -LiteralPath $fullLogPath -Encoding UTF8
    $filteredLog =
        @($fullLog | Select-String -Pattern 'BigRedButtonStudy|BRB_|GLTF|FATAL EXCEPTION|E/AndroidRuntime' |
            ForEach-Object { $_.Line })
    $filteredLog | Set-Content -LiteralPath $filteredLogPath -Encoding UTF8
    Invoke-Adb shell dumpsys activity activities |
        Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
        Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'button-condition-screenshot.png') |
        Tee-Object -FilePath (Join-Path $outDir 'screenshot-pull.txt') |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

function Get-ForegroundDump {
    return (Invoke-Adb shell dumpsys activity activities) -join "`n"
}

function Get-ForegroundPackage {
    param([string]$Dump)
    $foregroundLines =
        ($Dump -split "`n") |
        Where-Object { $_ -match 'mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' }
    $foregroundText = $foregroundLines -join "`n"
    $matches = [regex]::Matches($foregroundText, '([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)/')
    foreach ($match in $matches) {
        $candidate = $match.Groups[1].Value
        if ($candidate -notlike 'com.oculus.*' -and $candidate -notlike 'android.*') {
            return $candidate
        }
    }
    if ($matches.Count -gt 0) {
        return $matches[0].Groups[1].Value
    }
    return ''
}

function Test-TargetForeground {
    param([string]$Dump)
    $foregroundLines =
        ($Dump -split "`n") |
        Where-Object { $_ -match 'mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' }
    return (($foregroundLines -join "`n") -match [regex]::Escape($package))
}

function Start-VisualSmokeActivity {
    Invoke-Adb shell am start -n $activity --ez brb.physicalPressValidation true |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }
}

function Ensure-TargetForeground {
    Start-Sleep -Seconds 3
    $foregroundDump = Get-ForegroundDump
    $foregroundDump | Set-Content -LiteralPath (Join-Path $outDir 'foreground-after-launch.txt') -Encoding UTF8
    if (Test-TargetForeground $foregroundDump) {
        return
    }

    $foregroundPackage = Get-ForegroundPackage $foregroundDump
    if (-not [string]::IsNullOrWhiteSpace($foregroundPackage) -and
        $foregroundPackage -ne $package -and
        $foregroundPackage -notlike 'com.oculus.*' -and
        $foregroundPackage -notlike 'android.*') {
        Write-Host "Foreground is $foregroundPackage, force-stopping it once before relaunching $package."
        Invoke-Adb shell am force-stop $foregroundPackage | Out-Null
        Start-Sleep -Seconds 1
    } else {
        Write-Host "Target package not foreground after launch; retrying $package once."
    }

    Start-VisualSmokeActivity
    Start-Sleep -Seconds 3
    $retryDump = Get-ForegroundDump
    $retryDump | Set-Content -LiteralPath (Join-Path $outDir 'foreground-after-relaunch.txt') -Encoding UTF8
    if (-not (Test-TargetForeground $retryDump)) {
        $retryPackage = Get-ForegroundPackage $retryDump
        throw "Target package $package was not foreground after relaunch. Current foreground package: $retryPackage"
    }
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest visual-layout smoke target: serial=$Serial model=$model android=$android"
Write-Host "This hidden-mode smoke captures the in-condition 3D button layout and runtime angle marker, then stops before full audio completion."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb logcat -c
    Start-VisualSmokeActivity
    Ensure-TargetForeground

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $conditionStarted = $false
    $spatialMarker = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 1
        $markers = Invoke-Adb logcat -d -v time |
            Select-String -Pattern 'BRB_BUTTON_SPATIAL_LAYOUT|BRB_CONDITION_START condition=1|GLTF: Loading GLTF|BRB_BUTTON_MODEL_ASSET|FATAL EXCEPTION|E/AndroidRuntime'
        if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during visual-layout smoke."
        }
        $spatialMarker = [bool]($markers | Select-String -Pattern 'BRB_BUTTON_SPATIAL_LAYOUT')
        $conditionStarted = [bool]($markers | Select-String -Pattern 'BRB_CONDITION_START condition=1')
        if ($spatialMarker -and $conditionStarted) {
            break
        }
    }

    if (-not $spatialMarker) {
        Save-Evidence
        throw "BRB_BUTTON_SPATIAL_LAYOUT marker was not observed within $TimeoutSeconds seconds."
    }
    if (-not $conditionStarted) {
        Save-Evidence
        throw "Condition 1 did not start within $TimeoutSeconds seconds."
    }

    Start-Sleep -Seconds 3
    Save-Evidence

    $logPath = Join-Path $outDir 'logcat-filtered.txt'
    $logText = Get-Content -Raw -LiteralPath $logPath
    if ([string]::IsNullOrWhiteSpace($logText)) {
        $fullLogPath = Join-Path $outDir 'logcat-full.txt'
        if (Test-Path -LiteralPath $fullLogPath) {
            $logText = Get-Content -Raw -LiteralPath $fullLogPath
        }
    }
    $spatialMatch = [regex]::Match($logText, 'BRB_BUTTON_SPATIAL_LAYOUT.*facingParticipant=(true|false).*downwardAngleDeg=([0-9.]+).*angularDiameterDeg=([0-9.]+)')
    if (-not $spatialMatch.Success) {
        throw "Saved logcat is missing a parseable BRB_BUTTON_SPATIAL_LAYOUT marker."
    }
    $facingParticipant = $spatialMatch.Groups[1].Value -eq 'true'
    $downwardAngleDeg = [double]::Parse($spatialMatch.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture)
    $angularDiameterDeg = [double]::Parse($spatialMatch.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture)
    $gltfLoaded = $logText -match "GLTF: Loading GLTF: 'apk:///models/BigRedButton\.glb'" -or $logText -match 'BRB_BUTTON_MODEL_ASSET uri=apk:///models/BigRedButton\.glb'
    $noFatal = -not ($logText -match 'FATAL EXCEPTION|E/AndroidRuntime')

    if (-not $facingParticipant) {
        throw "Runtime spatial marker reported facingParticipant=false."
    }
    if ($downwardAngleDeg -lt 10.0 -or $downwardAngleDeg -gt 35.0) {
        throw "Runtime downward angle out of expected seated-interaction range: $downwardAngleDeg"
    }
    if ($angularDiameterDeg -lt 20.0 -or $angularDiameterDeg -gt 45.0) {
        throw "Runtime angular diameter out of expected visible-button range: $angularDiameterDeg"
    }
    if (-not $gltfLoaded) {
        throw "Saved logcat did not confirm the BigRedButton.glb model path."
    }
    if (-not $noFatal) {
        throw "Fatal runtime marker detected in saved logcat."
    }

    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'pass'
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        evidenceDir = $outDir
        condition1Started = $conditionStarted
        glbModelConfirmed = $gltfLoaded
        facingParticipant = $facingParticipant
        downwardAngleDeg = $downwardAngleDeg
        angularDiameterDeg = $angularDiameterDeg
        screenshot = Join-Path $outDir 'button-condition-screenshot.png'
        note = 'Short visual-layout smoke only. It validates the in-condition 3D button view and spatial marker, then force-stops before full audio completion.'
    }
    $summaryPath = Join-Path $outDir 'quest-visual-layout-smoke-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    Write-Host "PASS Quest visual-layout smoke"
    Write-Host "Summary: $summaryPath"
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
