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
    if (Test-Path -LiteralPath $localAdb) {
        $AdbPath = (Resolve-Path $localAdb).Path
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
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$logRunId = $runId -replace '[^A-Za-z0-9_]', '_'
$outDir = Join-Path $projectRoot "artifacts\quest-demographics-direct-keyboard\$runId"
$remoteScreenshot = '/sdcard/Download/brb_demographics_direct_keyboard.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$comparisons = New-Object System.Collections.Generic.List[object]
$observedLogSnapshots = New-Object System.Collections.Generic.List[string]

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Get-LogText {
    return (Invoke-Adb logcat -d -v time | Out-String)
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

function Save-FilteredLog {
    param([string]$Name)
    $path = Join-Path $outDir "$Name-logcat-filtered.txt"
    $latestLog = Get-LogText
    $combinedLog = (($script:observedLogSnapshots | ForEach-Object { $_ }) -join "`n") + "`n" + $latestLog
    $combinedLog -split "`r?`n" |
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
            $path = Save-FilteredLog "failure-$($Description -replace '[^A-Za-z0-9_-]', '_')"
            throw "Fatal runtime marker while waiting for $Description. See $path"
        }
        if ($log -match $Pattern) {
            $script:observedLogSnapshots.Add($log) | Out-Null
            return
        }
    }
    $path = Save-FilteredLog "timeout-$($Description -replace '[^A-Za-z0-9_-]', '_')"
    throw "Timed out waiting for $Description ($Pattern). See $path"
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

function Invoke-DemographicsValidationCommand {
    param([string]$Command)
    Invoke-Adb shell am start -n $activity --ez brb.demographicsKeyboardValidation true --es brb.demographicsKeyboardValidationSession $runId --es brb.demographicsKeyboardValidationCommand $Command |
        Tee-Object -FilePath (Join-Path $outDir "command-$Command.txt") |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "demographics validation command '$Command' failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 350
}

function Start-DemographicsValidationActivity {
    Invoke-Adb shell am start -n $activity --ez brb.demographicsKeyboardValidation true --es brb.demographicsKeyboardValidationSession $runId |
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

    Start-DemographicsValidationActivity
    Start-Sleep -Seconds 3
    $retryDump = Get-ForegroundDump
    $retryDump | Set-Content -LiteralPath (Join-Path $outDir 'foreground-after-relaunch.txt') -Encoding UTF8
    if (-not (Test-TargetForeground $retryDump)) {
        $retryPackage = Get-ForegroundPackage $retryDump
        throw "Target package $package was not foreground after relaunch. Current foreground package: $retryPackage"
    }
}

function Send-KeyCode {
    param([int]$KeyCode, [string]$Name)
    Invoke-Adb shell input keyevent $KeyCode | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "adb keyevent $Name failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 300
}

function Save-Screenshot {
    param(
        [string]$LocalName = 'demographics-direct-keyboard-after-entry.png'
    )
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir $LocalName) |
        Tee-Object -FilePath (Join-Path $outDir "screenshot-$LocalName.pull.txt") |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest demographics direct-keyboard validation target: serial=$Serial model=$model android=$android"
Write-Host "This test installs/launches the APK, focuses Name, types Georgex Backspace Space Fejer using raw adb keyevents, submits with Enter, then sets Age 34 with D-pad keyevents."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Write-Host "APK SHA-256: $apkSha256"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb shell am force-stop $package | Out-Null
    Invoke-Adb logcat -c | Out-Null
    Start-DemographicsValidationActivity
    Ensure-TargetForeground

    Wait-LogPattern 'BRB_STUDY_CREATED .*demographicsKeyboardValidation=true' 'validation launch extra'
    Wait-LogPattern "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=$logRunId accepted=true state=start" 'validation session marker'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*implementation=app_owned .*platformControl=AppOwnedKeyboard .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*directAdbKeyeventValidation=true' 'app-owned pop-out name keyboard contract'
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' 'stable demographics panel after intro'

    Invoke-DemographicsValidationCommand 'focus_name'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_FOCUS field=name accepted=true .*source=validation_intent .*platformControl=AppOwnedKeyboard' 'name app keyboard focus'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true' 'name left-side pop-out keyboard panel layout'

    $nameKeys = @(
        @{ code = 35; name = 'G' },
        @{ code = 33; name = 'E' },
        @{ code = 43; name = 'O' },
        @{ code = 46; name = 'R' },
        @{ code = 35; name = 'G' },
        @{ code = 33; name = 'E' },
        @{ code = 52; name = 'X' },
        @{ code = 67; name = 'BACKSPACE' },
        @{ code = 62; name = 'SPACE' },
        @{ code = 34; name = 'F' },
        @{ code = 33; name = 'E' },
        @{ code = 38; name = 'J' },
        @{ code = 33; name = 'E' },
        @{ code = 46; name = 'R' }
    )
    foreach ($key in $nameKeys) {
        Send-KeyCode $key.code $key.name
    }

    Wait-LogPattern 'BRB_DEMOGRAPHICS_NAME_BACKSPACE accepted=true source=hardware_key_event length=6 .*platformControl=AppOwnedKeyboard' 'raw keyevent backspace'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name keyboardMode=text value=george_fejer length=12 .*source=hardware_key_event .*validation=true' 'raw keyevents typed George Fejer'
    Save-Screenshot 'demographics-direct-keyboard-name-entry.png'

    Send-KeyCode 66 'ENTER_NAME_NEXT'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next source=hardware_key_event .*platformControl=AppOwnedKeyboard' 'raw enter submits name'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true .*source=hardware_key_event_name_next' 'age slider focused after raw enter'

    Send-KeyCode 19 'AGE_PLUS_10'
    Send-KeyCode 19 'AGE_PLUS_10'
    Send-KeyCode 19 'AGE_PLUS_10'
    Send-KeyCode 22 'AGE_PLUS_1'
    Send-KeyCode 22 'AGE_PLUS_1'
    Send-KeyCode 22 'AGE_PLUS_1'
    Send-KeyCode 22 'AGE_PLUS_1'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=activity_key_event value=34 .*platformControl=ComposeSlider' 'age set to 34 through D-pad slider controls'
    Send-KeyCode 66 'ENTER_AGE_DONE'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=activity_key_event value=34' 'age slider done'

    Start-Sleep -Seconds 1
    Save-Screenshot 'demographics-direct-keyboard-after-entry.png'
    $logPath = Save-FilteredLog 'final'
    $logText = Get-Content -Raw -LiteralPath $logPath

    Add-Comparison 'app-owned pop-out Name keyboard contract observed' $true ($logText -match 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*platformControl=AppOwnedKeyboard .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*noSystemImeDependency=true') $logPath
    Add-Comparison 'left-side pop-out Name keyboard panel appeared on focus' $true ($logText -match 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true') $logPath
    Add-Comparison 'raw keyevents produced final Name' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name keyboardMode=text value=george_fejer length=12 .*source=hardware_key_event') $logPath
    Add-Comparison 'raw keyevent backspace worked' $true ($logText -match 'BRB_DEMOGRAPHICS_NAME_BACKSPACE accepted=true source=hardware_key_event length=6') $logPath
    Add-Comparison 'raw enter moved to Age slider' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next source=hardware_key_event' -and $logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true .*source=hardware_key_event_name_next') $logPath
    Add-Comparison 'age accepted 34 through D-pad route' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=activity_key_event value=34') $logPath
    Add-Comparison 'age completed through Enter' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=activity_key_event value=34') $logPath
    Add-Comparison 'system IME not required for Name' $true (-not ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name')) $logPath

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
        nameEntryScreenshot = Join-Path $outDir 'demographics-direct-keyboard-name-entry.png'
        finalScreenshot = Join-Path $outDir 'demographics-direct-keyboard-after-entry.png'
        screenshot = Join-Path $outDir 'demographics-direct-keyboard-after-entry.png'
        logcat = $logPath
        typedName = 'George Fejer'
        typedAge = '34'
        comparisons = $comparisons
        note = 'Headset validation for direct keyboard/keyevent input against the installed APK. It does not use the app-side set_name route for Name text; raw KEYCODE letters, space, backspace, and enter update the app-owned Name keyboard path.'
    }
    $summaryPath = Join-Path $outDir 'quest-demographics-direct-keyboard-validation-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($failed.Count -gt 0) {
        throw "Quest demographics direct-keyboard validation failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }

    Write-Host "PASS Quest demographics direct-keyboard validation"
    Write-Host "Summary: $summaryPath"
} catch {
    $logPath = Save-FilteredLog 'failure'
    $summaryPath = Join-Path $outDir 'quest-demographics-direct-keyboard-validation-summary.json'
    [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'fail'
        serial = $Serial
        model = $model
        android = $android
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        evidenceDir = $outDir
        logcat = $logPath
        error = $_.Exception.Message
        comparisons = $comparisons
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
