[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 90,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$apkItem = Get-Item -LiteralPath $ApkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\qcs\$runId"
$remoteScreenshot = '/sdcard/Download/brb_controller_contact_smoke.png'
$summaryPath = Join-Path $outDir 'quest-controller-contact-smoke-summary.json'
$script:pressDetected = $false
$script:contactEvents = 0
$script:acceptedSelects = 0
$script:controllerPresses = 0

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

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()

function Write-ControllerContactSummary {
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
        apkInfo = [pscustomobject]@{
            path = $ApkPath
            sha256 = $apkSha256
            sizeBytes = $apkItem.Length
            lastWriteTime = $apkItem.LastWriteTime.ToString('o')
        }
        evidenceDir = $outDir
        pressDetected = $script:pressDetected
        contactEvents = $script:contactEvents
        acceptedContactSelects = $script:acceptedSelects
        controllerContactPresses = $script:controllerPresses
        note = 'Fast human-operated smoke only. It proves the controller-contact input path reaches recordButtonPress, but it does not validate full audio completion or JSON/CSV exports.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

Write-Host "Quest controller-contact smoke target: serial=$Serial model=$model android=$android"
Write-Host "Operator requirement: after launch, physically press the modeled Big Red Button with a Quest controller."
Write-Host "This is a fast smoke gate. It does not wait for full audio completion and does not replace export validation."

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
            Select-String -Pattern 'BRB_BUTTON_PRESS .*source=controller_contact|BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true|BRB_BUTTON_CONTACT_EVENT|FATAL EXCEPTION|E/AndroidRuntime'
        if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during controller-contact smoke."
        }
        if ($markers | Select-String -Pattern 'BRB_BUTTON_PRESS .*source=controller_contact') {
            $pressDetected = $true
            $script:pressDetected = $true
            break
        }
        $elapsed = [int]($TimeoutSeconds - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds))
        Write-Host "Waiting for controller_contact press... elapsed ${elapsed}s"
    }

    Save-Evidence

    if (-not $pressDetected) {
        throw "No controller_contact press detected within $TimeoutSeconds seconds. See $outDir"
    }

    $logText = Get-Content -Raw -LiteralPath (Join-Path $outDir 'logcat-filtered.txt')
    $contactEvents = ([regex]::Matches($logText, 'BRB_BUTTON_CONTACT_EVENT')).Count
    $acceptedSelects = ([regex]::Matches($logText, 'BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true')).Count
    $controllerPresses = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=controller_contact')).Count
    $script:contactEvents = $contactEvents
    $script:acceptedSelects = $acceptedSelects
    $script:controllerPresses = $controllerPresses
    if ($acceptedSelects -lt 1) {
        throw "controller_contact press was logged but accepted contact select marker was missing."
    }
    if ($controllerPresses -lt 1) {
        throw "controller_contact press marker missing from saved logcat."
    }

    Write-ControllerContactSummary -Status 'pass'
    Write-Host "PASS Quest controller-contact smoke"
    Write-Host "Summary: $summaryPath"
} catch {
    $failureMessage = $_.Exception.Message
    try {
        Save-Evidence
        if (Test-Path (Join-Path $outDir 'logcat-filtered.txt')) {
            $logText = Get-Content -Raw -LiteralPath (Join-Path $outDir 'logcat-filtered.txt')
            $script:contactEvents = ([regex]::Matches($logText, 'BRB_BUTTON_CONTACT_EVENT')).Count
            $script:acceptedSelects = ([regex]::Matches($logText, 'BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true')).Count
            $script:controllerPresses = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=controller_contact')).Count
        }
    } catch {
        Write-Warning "Could not save full controller-contact failure evidence: $($_.Exception.Message)"
    }
    Write-ControllerContactSummary -Status 'fail' -ErrorMessage $failureMessage
    Write-Host "FAIL Quest controller-contact smoke"
    Write-Host "Summary: $summaryPath"
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
