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

function Get-LogText {
    return (Invoke-Adb logcat -d -v time | Out-String)
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
            return $log
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
        $commandArgs += @('--es', 'brb.demographicsKeyboardValidationText', $Text)
    }
    Invoke-Adb @commandArgs |
        Tee-Object -FilePath (Join-Path $outDir "command-$Command.txt") |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "demographics validation command '$Command' failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 300
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
Write-Host "This mode proves visible AndroidView(EditText) Name and Age controls, waits for the stable demographics panel, then validates George -> Next -> Age 34 -> Done through the app-side validation command route."

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
    Invoke-Adb shell am start -n $activity --ez brb.demographicsKeyboardValidation true --es brb.demographicsKeyboardValidationSession $runId |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    Wait-LogPattern 'BRB_STUDY_CREATED .*demographicsKeyboardValidation=true' 'validation launch extra'
    Wait-LogPattern "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=$logRunId accepted=true state=start" 'validation session marker'
    Wait-LogPattern 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=name .*platformControl=EditText .*inputOwner=androidViewEditText .*imeAction=next' 'name EditText contract'
    Wait-LogPattern 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=age .*keyboardMode=number .*platformControl=EditText .*inputOwner=androidViewEditText .*imeAction=done' 'age EditText contract'
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' 'stable demographics panel after intro'
    Invoke-DemographicsValidationCommand 'focus_name'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=focus_name accepted=true' 'focus_name validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS_REQUEST field=name accepted=true' 'name EditText focus request'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS field=name .*keyboardMode=text .*source=focus_request_initial_validation_intent' 'actual name EditText focus marker'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name keyboardMode=text .*source=focus_request_initial_validation_intent .*focusedView=EditText .*restartInput=true' 'name text keyboard request after focus'

    Invoke-DemographicsValidationCommand 'set_name' 'George'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_name accepted=true' 'set_name validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george .*validation=true' 'George accepted in name field'

    Invoke-DemographicsValidationCommand 'name_next'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=name_next accepted=true' 'name_next validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next' 'Enter advances from name to age field'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS_REQUEST field=age accepted=true .*source=validation_intent_name_next .*keyboardMode=number' 'age EditText focus request'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_RETARGET from=field_name to=field_age .*restartInput=true .*platformControl=EditText' 'keyboard retargets from name to age'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS field=age .*keyboardMode=number .*source=focus_request_initial_validation_intent_name_next' 'actual age EditText focus marker'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_REQUEST reason=field_age keyboardMode=number .*source=focus_request_initial_validation_intent_name_next .*focusedView=EditText .*restartInput=true' 'age number keyboard request after retarget'

    Invoke-DemographicsValidationCommand 'set_age' 'a1234'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_age accepted=true' 'set_age mixed-input validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_FILTER source=validation_intent rawLength=5 digitCount=4 cleanedLength=3 stripped=true truncated=true' 'age strips letters and truncates to 3 digits'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=123 .*digitsOnly=true .*validation=true' 'mixed age input cleaned to 123'

    Invoke-DemographicsValidationCommand 'clear_age'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=clear_age accepted=true' 'clear_age validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=unspecified .*length=0 .*validation=true' 'age cleared before digit entry'

    Invoke-DemographicsValidationCommand 'set_age' '34'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=34 .*digitsOnly=true .*platformControl=EditText .*validation=true' '34 accepted in age field'

    Invoke-DemographicsValidationCommand 'age_done'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=age_done accepted=true' 'age_done validation command'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=age action=done .*platformControl=EditText' 'Age Done editor action marker'
    Wait-LogPattern 'BRB_SOFT_KEYBOARD_HIDE reason=field_age_done_validation_intent' 'age keyboard hide after Done'

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

    Add-Comparison 'name EditText contract logged' $true ($logText -match 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=name .*platformControl=EditText .*imeAction=next') 'logcat'
    Add-Comparison 'age EditText contract logged' $true ($logText -match 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=age .*keyboardMode=number .*platformControl=EditText .*imeAction=done') 'logcat'
    Add-Comparison 'demographics intro settled before focus' $true ($logText -match 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics') 'logcat'
    Add-Comparison 'validation requested name focus after panel settled' $true ($logText -match 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS_REQUEST field=name accepted=true') 'logcat'
    Add-Comparison 'actual name EditText focus marker observed' $true ($logText -match 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS field=name .*keyboardMode=text .*source=focus_request_initial_validation_intent') 'logcat'
    Add-Comparison 'name text keyboard request observed after focus' $true ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name keyboardMode=text .*source=focus_request_initial_validation_intent .*focusedView=EditText .*restartInput=true') 'logcat'
    Add-Comparison 'app-side validation command set name' $true ($logText -match 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=set_name accepted=true') 'logcat'
    Add-Comparison 'George accepted by shared text path' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name .*value=george .*source=validation_intent .*validation=true') 'logcat'
    Add-Comparison 'validation next moved name to age EditText' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=name action=next .*source=validation_intent') 'logcat'
    Add-Comparison 'age focus request observed' $true ($logText -match 'BRB_DEMOGRAPHICS_EDITTEXT_FOCUS_REQUEST field=age accepted=true .*source=validation_intent_name_next') 'logcat'
    Add-Comparison 'age number keyboard request observed' $true ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_age keyboardMode=number .*focusedView=EditText .*restartInput=true') 'logcat'
    Add-Comparison 'mixed age input strips letters and truncates' $true ($logText -match 'BRB_DEMOGRAPHICS_AGE_FILTER source=validation_intent rawLength=5 digitCount=4 cleanedLength=3 stripped=true truncated=true') 'logcat'
    Add-Comparison 'mixed age input cleaned to 123' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=123 .*digitsOnly=true .*source=validation_intent .*validation=true') 'logcat'
    Add-Comparison 'age clear command observed' $true ($logText -match 'BRB_DEMOGRAPHICS_VALIDATION_COMMAND command=clear_age accepted=true') 'logcat'
    Add-Comparison 'age accepts 34 through number field' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=age keyboardMode=number value=34 .*digitsOnly=true .*source=validation_intent .*validation=true') 'logcat'
    Add-Comparison 'validation done completed age EditText' $true ($logText -match 'BRB_DEMOGRAPHICS_TEXT_EDITOR_ACTION field=age action=done .*source=validation_intent') 'logcat'

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
        note = 'Focused headset smoke for the first demographics panel. It proves visible AndroidView(EditText) contracts for Name and Age, waits for the stable demographics panel, then validates Name text/Next, Age number/Done, mixed age cleanup, and final George/34 values through the app-side validation command route. Physical headset overlay-keyboard typing remains a manual smoke item. This complements qkv, which validates the remaining questionnaire stages through bounded D-pad/enter replay.'
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
