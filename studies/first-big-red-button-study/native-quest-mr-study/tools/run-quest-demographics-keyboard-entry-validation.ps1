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
$outDir = Join-Path $projectRoot "artifacts\quest-demographics-keyboard\$runId"
$remoteScreenshot = '/sdcard/Download/brb_demographics_keyboard_validation.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$comparisons = New-Object System.Collections.Generic.List[object]
$observedLogLines = New-Object System.Collections.Generic.List[string]

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function ConvertTo-AdbShellTextArg {
    param([string]$Value)
    return "'" + ($Value -replace "'", "") + "'"
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
    })
    if ($pass) {
        Write-Host "PASS $Name expected=$Expected observed=$Observed"
    } else {
        Write-Host "FAIL $Name expected=$Expected observed=$Observed"
    }
}

function Add-ObservedLogEvidence {
    param([string]$LogText)
    $LogText -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_' |
        ForEach-Object { $script:observedLogLines.Add($_.Line) }
}

function Wait-LogPattern {
    param(
        [string]$Pattern,
        [string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 300
        $log = Get-LogText
        if ($log -match 'FATAL EXCEPTION|E/AndroidRuntime') {
            $log | Set-Content -LiteralPath (Join-Path $outDir 'failure-logcat.txt') -Encoding UTF8
            throw "Fatal runtime marker while waiting for $Description."
        }
        if ($log -match $Pattern) {
            Add-ObservedLogEvidence $log
            return
        }
    }
    $timeoutLog = Get-LogText
    Add-ObservedLogEvidence $timeoutLog
    ($timeoutLog + "`n" + ($script:observedLogLines -join "`n")) |
        Set-Content -LiteralPath (Join-Path $outDir 'timeout-logcat.txt') -Encoding UTF8
    throw "Timed out waiting for $Description ($Pattern)."
}

function Invoke-DemographicsValidationCommand {
    param(
        [string]$Command,
        [string]$Text = ''
    )
    $commandArgs = @(
        'shell', 'am', 'start',
        '-n', $activity,
        '--ez', 'brb.demographicsKeyboardValidation', 'true',
        '--es', 'brb.demographicsKeyboardValidationSession', $runId,
        '--es', 'brb.demographicsKeyboardValidationCommand', $Command
    )
    if (-not [string]::IsNullOrEmpty($Text)) {
        $commandArgs += @('--es', 'brb.demographicsKeyboardValidationText', (ConvertTo-AdbShellTextArg $Text))
    }
    Invoke-Adb @commandArgs |
        Tee-Object -FilePath (Join-Path $outDir "command-$Command.txt") |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "demographics validation command '$Command' failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 300
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

function Save-Screenshot {
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir 'demographics-keyboard-after-entry.png') |
        Tee-Object -FilePath (Join-Path $outDir 'screenshot.pull.txt') |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest demographics keyboard validation target: serial=$Serial model=$model android=$android"
Write-Host "This mode proves the app-owned pop-out Name keyboard and the Age 0-100 slider, waits for the stable demographics panel, then validates multi-character Name -> Next -> Age slider 34 -> Done through the app-side validation command route."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Write-Host "APK SHA-256: $apkSha256"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb logcat -c
    Invoke-Adb shell am force-stop $package | Out-Null
    Start-DemographicsValidationActivity
    Ensure-TargetForeground

    Wait-LogPattern 'BRB_STUDY_CREATED .*demographicsKeyboardValidation=true' 'validation launch extra'
    Wait-LogPattern "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=$logRunId accepted=true state=start" 'validation session marker'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*implementation=app_owned .*platformControl=AppOwnedKeyboard .*inputOwner=appOwnedNameKeyboard .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*directAdbKeyeventValidation=true' 'name app-owned pop-out keyboard contract'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_CONTRACT field=age .*min=0 .*max=100 .*platformControl=ComposeSlider .*inputOwner=composeSlider .*sameExportField=demographics.age' 'age slider contract'
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' 'stable demographics panel after intro'
    Invoke-DemographicsValidationCommand 'focus_name'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=focus_name accepted=true' 'focus_name validation command'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_FOCUS field=name accepted=true .*source=validation_intent .*platformControl=AppOwnedKeyboard' 'name app-owned keyboard focus marker'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true' 'name left-side pop-out keyboard panel layout'

    Invoke-DemographicsValidationCommand 'set_name' 'George Fejer'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_name accepted=true' 'set_name validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george_fejer .*length=12 .*validation=true' 'George Fejer accepted in name field'

    Invoke-DemographicsValidationCommand 'name_next'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=name_next accepted=true' 'name_next validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next' 'Enter advances from name to age slider'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_HIDE reason=field_name_to_age_slider_validation_intent_name_next' 'name keyboard hides before age slider'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true .*source=validation_intent_name_next .*platformControl=ComposeSlider' 'age slider focus after name next'

    Invoke-DemographicsValidationCommand 'set_age' '1234'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_age accepted=true' 'set_age clamp validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_SANITIZE source=validation_intent rawLength=4 digitCount=4 cleanedValue=100 .*clamped=true' 'age slider clamps values above 100'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=validation_intent value=100 .*platformControl=ComposeSlider' 'age slider clamp value marker'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=slider value=100 .*digitsOnly=true .*platformControl=ComposeSlider .*validation=true' 'age slider clamp value logged as 100'

    Invoke-DemographicsValidationCommand 'clear_age'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=clear_age accepted=true' 'clear_age validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=slider value=unspecified .*length=0 .*validation=true' 'age cleared before slider value'

    Invoke-DemographicsValidationCommand 'set_age' '34'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=validation_intent value=34 .*platformControl=ComposeSlider' 'age slider final value marker'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=slider value=34 .*digitsOnly=true .*platformControl=ComposeSlider .*validation=true' '34 accepted through age slider'

    Invoke-DemographicsValidationCommand 'age_done'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=age_done accepted=true' 'age_done validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=validation_intent value=34 .*platformControl=ComposeSlider' 'Age slider Done marker'

    Start-Sleep -Seconds 1
    Save-Screenshot

    $latestLogText = Get-LogText
    Add-ObservedLogEvidence $latestLogText
    $logText = $latestLogText + "`n" + ($observedLogLines -join "`n")
    $logPath = Join-Path $outDir 'logcat-filtered.txt'
    $logText -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath $logPath -Encoding UTF8

    Add-Comparison 'name app-owned pop-out keyboard contract logged' $true ($logText -match 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*platformControl=AppOwnedKeyboard .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*noSystemImeDependency=true') 'logcat'
    Add-Comparison 'name left-side pop-out keyboard panel appeared on focus' $true ($logText -match 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true') 'logcat'
    Add-Comparison 'age slider contract logged' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_CONTRACT field=age .*min=0 .*max=100 .*platformControl=ComposeSlider') 'logcat'
    Add-Comparison 'demographics intro settled before focus' $true ($logText -match 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics') 'logcat'
    Add-Comparison 'validation requested app-owned name focus after panel settled' $true ($logText -match 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=focus_name accepted=true' -and $logText -match 'BRB_NAME_APP_KEYBOARD_FOCUS field=name accepted=true .*source=validation_intent .*platformControl=AppOwnedKeyboard') 'logcat'
    Add-Comparison 'name app-owned keyboard focus marker observed' $true ($logText -match 'BRB_NAME_APP_KEYBOARD_FOCUS field=name accepted=true .*source=validation_intent .*platformControl=AppOwnedKeyboard') 'logcat'
    Add-Comparison 'app-side validation command set name' $true ($logText -match 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_name accepted=true') 'logcat'
    Add-Comparison 'George Fejer accepted by shared text path' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george_fejer .*length=12 .*source=validation_intent .*validation=true') 'logcat'
    Add-Comparison 'validation next moved name to age slider' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next .*source=validation_intent' -and $logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true .*source=validation_intent_name_next') 'logcat'
    Add-Comparison 'age keyboard not requested' $true (-not ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_age')) 'logcat'
    Add-Comparison 'age slider clamps values above 100' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_SANITIZE source=validation_intent rawLength=4 digitCount=4 cleanedValue=100 .*clamped=true') 'logcat'
    Add-Comparison 'age slider emits value marker' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=validation_intent value=34 .*platformControl=ComposeSlider') 'logcat'
    Add-Comparison 'age clear command observed' $true ($logText -match 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=clear_age accepted=true') 'logcat'
    Add-Comparison 'age accepts 34 through slider' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=slider value=34 .*digitsOnly=true .*source=validation_intent .*validation=true') 'logcat'
    Add-Comparison 'validation done completed age slider' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=validation_intent value=34') 'logcat'

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
        screenshot = Join-Path $outDir 'demographics-keyboard-after-entry.png'
        logcat = $logPath
        comparisons = $comparisons
        note = 'Focused headset smoke for the first demographics panel. It proves the app-owned pop-out Name keyboard contract and the 0-100 Age slider contract, waits for the stable demographics panel, then validates multi-character Name text/Next, keyboard hide before the slider, Age clamp behavior, and final George Fejer/34 values through the app-side validation command route. Direct raw keyevent entry is covered by run-quest-demographics-direct-keyboard-validation.ps1. This complements qkv, which validates the remaining questionnaire stages through bounded D-pad/enter replay.'
    }
    $summaryPath = Join-Path $outDir 'quest-demographics-keyboard-validation-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

    if ($failed.Count -gt 0) {
        throw "Quest demographics keyboard validation failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }

    Write-Host "PASS Quest demographics keyboard validation"
    Write-Host "Summary: $summaryPath"
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
