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
if ([string]::IsNullOrWhiteSpace($AdbPath) -or $AdbPath -eq 'adb') {
    $localAdb = Join-Path $projectRoot 'artifacts\toolchain\android-platform-tools\platform-tools\adb.exe'
    $sideQuestAdb = Join-Path $env:LOCALAPPDATA 'Programs\SideQuest\resources\app.asar.unpacked\build\platform-tools\adb.exe'
    if (Test-Path -LiteralPath $localAdb) {
        $AdbPath = (Resolve-Path $localAdb).Path
    } elseif (Test-Path -LiteralPath $sideQuestAdb) {
        $AdbPath = (Resolve-Path $sideQuestAdb).Path
    } else {
        $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
        if ($null -ne $adbCommand) {
            $AdbPath = $adbCommand.Source
        }
    }
}
if (-not (Test-Path -LiteralPath $AdbPath) -and $null -eq (Get-Command $AdbPath -ErrorAction SilentlyContinue)) {
    throw "adb not found. Pass -AdbPath or install platform-tools. Tried '$AdbPath'."
}
if ([string]::IsNullOrWhiteSpace($ApkPath)) {
    $ApkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
}
$ApkPath = (Resolve-Path $ApkPath).Path
$apkItem = Get-Item -LiteralPath $ApkPath
$apkSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $ApkPath).Hash
$package = 'org.bigredbutton.firststudy'
$activity = 'org.bigredbutton.firststudy/.BigRedButtonStudyActivity'
$remoteScreenshot = '/sdcard/Download/brb_button_press_animation_stress.png'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\quest-button-press-animation-stress\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$audioStressIntentArgs = @(
    '--ez', 'brb.audioRigStress', 'true',
    '--ez', 'brb.autoValidation', 'false',
    '--ez', 'brb.physicalPressValidation', 'false',
    '--ez', 'brb.panelSmoke', 'false',
    '--ez', 'brb.fastControllerFlow', 'false',
    '--ez', 'brb.keyeventValidation', 'false',
    '--ez', 'brb.demographicsKeyboardValidation', 'false'
)
$comparisons = New-Object System.Collections.Generic.List[object]

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Get-LogText {
    return (Invoke-Adb logcat -d -v time | Out-String)
}

function Save-FilteredLog {
    param(
        [string]$Name,
        [string]$LogText
    )
    $path = Join-Path $outDir "$Name-logcat-filtered.txt"
    $LogText -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Wait-LogPattern {
    param(
        [string]$Pattern,
        [string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
        $log = Get-LogText
        if ($log -match 'FATAL EXCEPTION|E/AndroidRuntime') {
            $path = Save-FilteredLog "failure-$($Description -replace '[^A-Za-z0-9_-]', '_')" $log
            throw "Fatal runtime marker while waiting for $Description. See $path"
        }
        if ($log -match $Pattern) {
            return $log
        }
    }
    $timeoutLog = Get-LogText
    $path = Save-FilteredLog "timeout-$($Description -replace '[^A-Za-z0-9_-]', '_')" $timeoutLog
    throw "Timed out waiting for $Description ($Pattern). See $path"
}

function Invoke-AudioStressCommand {
    param([string]$Command)
    $intentArgs = @('shell', 'am', 'start', '-n', $activity) + $audioStressIntentArgs + @('--es', 'brb.audioRigStressCommand', $Command)
    Invoke-Adb @intentArgs | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "audio stress command '$Command' failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 250
}

function Add-Comparison {
    param(
        [string]$Name,
        $Expected,
        $Observed,
        [string]$Evidence
    )
    $pass = $Expected -eq $Observed
    $script:comparisons.Add([pscustomobject]@{
        name = $Name
        expected = $Expected
        observed = $Observed
        pass = $pass
        evidence = $Evidence
    }) | Out-Null
    if ($pass) {
        Write-Host "PASS $Name expected=$Expected observed=$Observed"
    } else {
        Write-Host "FAIL $Name expected=$Expected observed=$Observed"
    }
}

function Save-Screenshot {
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'button-press-animation-stress.png') |
        Tee-Object -FilePath (Join-Path $outDir 'screenshot.pull.txt') |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest button press animation stress target: serial=$Serial model=$model android=$android"
Write-Host "This hidden-mode stress schedules three accepted validation presses 200 ms apart and verifies the visual GLB replay guard defers instead of restarting mid-motion."
Write-Host "APK SHA-256: $apkSha256"

try {
    if (-not $SkipInstall) {
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
        Start-Sleep -Seconds 2
    }

    Invoke-Adb logcat -c | Out-Null
    Invoke-Adb shell am force-stop $package | Out-Null
    Start-Sleep -Seconds 1
    $launchArgs = @('shell', 'am', 'start', '-n', $activity) + $audioStressIntentArgs
    Invoke-Adb @launchArgs | Tee-Object -FilePath (Join-Path $outDir 'launch.txt') | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    Wait-LogPattern 'BRB_STUDY_CREATED .*audioRigStress=true' 'audio rig stress launch'
    Invoke-AudioStressCommand 'condition_1_audio_probe'
    Wait-LogPattern 'BRB_CONDITION_START condition=1 .*isPlaying=true' 'condition 1 audio started'
    Invoke-AudioStressCommand 'button_press_animation_stress'
    $completeLog = Wait-LogPattern 'BRB_BUTTON_PRESS_ANIMATION_STRESS state=complete condition=1 .*accepted=3 .*expected=3' 'button press animation stress complete' 15
    Save-Screenshot

    $logText = Get-LogText
    $fullLogPath = Join-Path $outDir 'logcat-full.txt'
    $logText | Set-Content -LiteralPath $fullLogPath -Encoding UTF8
    $filteredLogPath = Save-FilteredLog 'final' $logText

    $acceptedPressCount = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=1 .*source=audio_rig_stress .*validationAutomation=true')).Count
    $immediateStarts = ([regex]::Matches($logText, 'BRB_BUTTON_MODEL_ANIMATION name=pressed state=started .*deferred=false')).Count
    $deferredSchedules = ([regex]::Matches($logText, 'BRB_BUTTON_MODEL_ANIMATION_SCHEDULE state=deferred')).Count
    $deferredStarts = ([regex]::Matches($logText, 'BRB_BUTTON_MODEL_ANIMATION name=pressed state=started .*deferred=true')).Count
    $buttonSoundCount = ([regex]::Matches($logText, 'BRB_SFX_PLAY cue=button_press .*asset=.*durationMs=')).Count

    Add-Comparison 'animation stress command scheduled three presses' $true ($completeLog -match 'BRB_BUTTON_PRESS_ANIMATION_STRESS state=scheduled condition=1 .*expectedAccepted=3') $filteredLogPath
    Add-Comparison 'three accepted synthetic presses are provenance-marked' 3 $acceptedPressCount $filteredLogPath
    Add-Comparison 'first visual press starts immediately' $true ($immediateStarts -ge 1) $filteredLogPath
    Add-Comparison 'rapid accepted presses defer visual replay' $true ($deferredSchedules -ge 2 -and $deferredStarts -ge 2) $filteredLogPath
    Add-Comparison 'press sounds remain immediate per accepted press' $true ($buttonSoundCount -ge 3) $filteredLogPath
    Add-Comparison 'visual replay stays on stable idle model' $true ($logText -match 'target=stable_idle_model .*glowGeometrySwap=false' -and $logText -match 'BRB_BUTTON_GLOW_STABLE_SURFACE_READY') $filteredLogPath
    Add-Comparison 'no skipped visual animation during stress' $false ($logText -match 'BRB_BUTTON_MODEL_ANIMATION name=pressed state=skipped') $filteredLogPath
    Add-Comparison 'no fatal runtime marker' $false ($logText -match 'FATAL EXCEPTION|E/AndroidRuntime') $filteredLogPath

    $failed = @($comparisons | Where-Object { -not $_.pass })
    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        apkSizeBytes = $apkItem.Length
        evidenceDir = $outDir
        logcat = $filteredLogPath
        fullLogcat = $fullLogPath
        screenshot = Join-Path $outDir 'button-press-animation-stress.png'
        acceptedPressCount = $acceptedPressCount
        immediateAnimationStarts = $immediateStarts
        deferredAnimationSchedules = $deferredSchedules
        deferredAnimationStarts = $deferredStarts
        buttonSoundCount = $buttonSoundCount
        comparisons = @($comparisons.ToArray())
        note = 'Validation-only hidden stress. It does not prove human controller contact, but it exercises accepted rapid presses on-device and verifies the visual pressed animation is deferred by the restart guard instead of repeatedly snapping the GLB clip.'
    }
    $summaryPath = Join-Path $outDir 'quest-button-press-animation-stress-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($failed.Count -gt 0) {
        throw "Quest button press animation stress failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }

    Write-Host "PASS Quest button press animation stress"
    Write-Host "Summary: $summaryPath"
} catch {
    $errorSummary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'fail'
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        apkSizeBytes = $apkItem.Length
        evidenceDir = $outDir
        error = $_.Exception.Message
        comparisons = @($comparisons.ToArray())
    }
    $errorPath = Join-Path $outDir 'quest-button-press-animation-stress-summary.json'
    $errorSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $errorPath -Encoding UTF8
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
