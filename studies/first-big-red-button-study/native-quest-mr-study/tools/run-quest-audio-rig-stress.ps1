[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 75,
    [switch]$SkipInstall,
    [switch]$SkipRedness
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
$audioStressIntentArgs = @(
    '--ez', 'brb.audioRigStress', 'true',
    '--ez', 'brb.autoValidation', 'false',
    '--ez', 'brb.physicalPressValidation', 'false',
    '--ez', 'brb.panelSmoke', 'false',
    '--ez', 'brb.fastControllerFlow', 'false',
    '--ez', 'brb.keyeventValidation', 'false',
    '--ez', 'brb.demographicsKeyboardValidation', 'false'
)
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\quest-audio-rig-stress\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$comparisons = New-Object System.Collections.Generic.List[object]
$runLogs = New-Object System.Collections.Generic.List[object]
$capturedLogTexts = New-Object System.Collections.Generic.List[string]

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
    $script:capturedLogTexts.Add($LogText) | Out-Null
    $path = Join-Path $outDir "$Name-logcat-filtered.txt"
    $LogText -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath $path -Encoding UTF8
    $script:runLogs.Add([pscustomobject]@{ name = $Name; path = $path }) | Out-Null
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

function Clear-RunLog {
    Invoke-Adb logcat -c | Out-Null
    Start-Sleep -Milliseconds 250
}

function Start-AudioStressRun {
    param([string]$Name)
    Invoke-Adb logcat -c | Out-Null
    Invoke-Adb shell am force-stop $package | Out-Null
    Start-Sleep -Seconds 1
    $intentArgs = @('shell', 'am', 'start', '-n', $activity) + $audioStressIntentArgs
    Invoke-Adb @intentArgs | Out-Null
    Wait-LogPattern 'BRB_STUDY_CREATED .*audioRigStress=true' "$Name launch extra" 45 | Out-Null
    Wait-LogPattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=demographics .*isPlaying=true' "$Name demographics intro cue" 30 | Out-Null
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' "$Name stable demographics panel" 45 | Out-Null
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

function Get-FirstLogTime {
    param(
        [string]$LogText,
        [string]$Pattern
    )
    foreach ($line in ($LogText -split "`r?`n")) {
        if ($line -match $Pattern -and $line -match '^(?<month>\d{2})-(?<day>\d{2})\s+(?<time>\d{2}:\d{2}:\d{2}\.\d{3})') {
            $stamp = '{0}-{1}-{2} {3}' -f (Get-Date).Year, $matches.month, $matches.day, $matches.time
            return [datetime]::ParseExact($stamp, 'yyyy-MM-dd HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture)
        }
    }
    return $null
}

function Add-TimeWindowComparison {
    param(
        [string]$Name,
        [string]$LogText,
        [string]$StartPattern,
        [string]$EndPattern,
        [int]$MinimumMs,
        [int]$MaximumMs
    )
    $start = Get-FirstLogTime $LogText $StartPattern
    $end = Get-FirstLogTime $LogText $EndPattern
    $observed = if ($null -ne $start -and $null -ne $end) { [int][math]::Round(($end - $start).TotalMilliseconds) } else { -1 }
    $pass = $observed -ge $MinimumMs -and $observed -le $MaximumMs
    $script:comparisons.Add([pscustomobject]@{
        name = $Name
        expected = "$MinimumMs..$MaximumMs ms"
        observed = "$observed ms"
        pass = $pass
        evidence = 'logcat timestamp delta'
    }) | Out-Null
    if ($pass) {
        Write-Host "PASS $Name observed=${observed}ms expected=${MinimumMs}..${MaximumMs}ms"
    } else {
        Write-Host "FAIL $Name observed=${observed}ms expected=${MinimumMs}..${MaximumMs}ms"
    }
}

function Run-PriorYesStress {
    Clear-RunLog
    Invoke-AudioStressCommand 'show_prior_prompt'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_OUTRO_CUE trigger=before_condition_1 .*isPlaying=true' 'prior yes demographics outro cue' 20 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN .*optionsVisible=false' 'prior yes prompt shown with options hidden' 30 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=prior_button_experience_question .*isPlaying=true' 'prior yes question playback' 20 | Out-Null
    Invoke-AudioStressCommand 'prior_answer_yes'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=yes .*reason=question_audio_active' 'prior yes early answer blocked' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY .*validationShortcut=false .*optionsVisible=true' 'prior yes options after question audio' 35 | Out-Null
    Invoke-AudioStressCommand 'prior_answer_yes'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER answer=yes .*locked=true .*otherOptionsHidden=true' 'prior yes answer locked' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=prior_button_experience_yes .*isPlaying=true' 'prior yes feedback playback' 10 | Out-Null
    Invoke-AudioStressCommand 'prior_answer_no'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=no .*reason=answer_locked' 'prior yes switch blocked' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=yes .*startEnabled=false .*preStartDelayActive=true .*preStartDelayMs=4000' 'prior yes feedback ready before pre-start pause' 20 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=yes .*state=start .*delayMs=4000' 'prior yes 4s pre-start pause begins' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=yes .*state=end .*delayMs=4000' 'prior yes 4s pre-start pause ends' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=pre_start_instructions .*isPlaying=true' 'prior yes pre-start instructions playback' 10 | Out-Null
    $log = Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=yes .*startEnabled=true' 'prior yes pre-start instructions complete' 45
    $path = Save-FilteredLog 'prior-yes' $log
    Add-Comparison 'prior yes question audio starts' $true ($log -match 'BRB_SFX_PLAY cue=prior_button_experience_question .*isPlaying=true') $path
    Add-Comparison 'prior yes answer blocked during question audio' $true ($log -match 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=yes .*reason=question_audio_active') $path
    Add-Comparison 'prior yes locks and hides other option' $true ($log -match 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER answer=yes .*locked=true .*otherOptionsHidden=true') $path
    Add-Comparison 'prior yes switch attempt blocked' $true ($log -match 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=no .*reason=answer_locked') $path
    Add-Comparison 'prior yes pre-start instructions audio starts' $true ($log -match 'BRB_SFX_PLAY cue=pre_start_instructions .*isPlaying=true') $path
    Add-TimeWindowComparison 'prior options wait for question audio' $log 'BRB_SFX_PLAY cue=prior_button_experience_question' 'BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY' 10250 12500
    Add-TimeWindowComparison 'prior yes start waits for feedback audio' $log 'BRB_SFX_PLAY cue=prior_button_experience_yes' 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=yes' 5000 7600
    Add-TimeWindowComparison 'prior yes inserts 4s pause before pre-start instructions' $log 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=yes' 'BRB_SFX_PLAY cue=pre_start_instructions' 3800 5500
    Add-TimeWindowComparison 'prior yes start waits for pre-start instructions' $log 'BRB_SFX_PLAY cue=pre_start_instructions' 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=yes' 34000 37000
}

function Run-PriorNoStress {
    Clear-RunLog
    Invoke-AudioStressCommand 'show_prior_prompt'
    Wait-LogPattern 'BRB_SFX_PLAY cue=prior_button_experience_question .*isPlaying=true' 'prior no question playback' 30 | Out-Null
    Invoke-AudioStressCommand 'prior_answer_no'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=no .*reason=question_audio_active' 'prior no early answer blocked' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_OPTIONS_READY .*validationShortcut=false .*optionsVisible=true' 'prior no options after question audio' 35 | Out-Null
    Invoke-AudioStressCommand 'prior_answer_no'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER answer=no .*locked=true .*otherOptionsHidden=true' 'prior no answer locked' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=prior_button_experience_no .*isPlaying=true' 'prior no feedback playback' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=no .*startEnabled=false .*preStartDelayActive=true .*preStartDelayMs=4000' 'prior no feedback ready before pre-start pause' 20 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=no .*state=start .*delayMs=4000' 'prior no 4s pre-start pause begins' 10 | Out-Null
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_PAUSE answer=no .*state=end .*delayMs=4000' 'prior no 4s pre-start pause ends' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=pre_start_instructions .*isPlaying=true' 'prior no pre-start instructions playback' 10 | Out-Null
    $log = Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=no .*startEnabled=true' 'prior no pre-start instructions complete' 45
    $path = Save-FilteredLog 'prior-no' $log
    Add-Comparison 'prior no feedback audio starts' $true ($log -match 'BRB_SFX_PLAY cue=prior_button_experience_no .*isPlaying=true') $path
    Add-Comparison 'prior no pre-start instructions audio starts' $true ($log -match 'BRB_SFX_PLAY cue=pre_start_instructions .*isPlaying=true') $path
    Add-Comparison 'prior no answer blocked during question audio' $true ($log -match 'BRB_PRIOR_BUTTON_EXPERIENCE_ANSWER_BLOCKED answer=no .*reason=question_audio_active') $path
    Add-TimeWindowComparison 'prior no start waits for feedback audio' $log 'BRB_SFX_PLAY cue=prior_button_experience_no' 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=no' 4050 6600
    Add-TimeWindowComparison 'prior no inserts 4s pause before pre-start instructions' $log 'BRB_PRIOR_BUTTON_EXPERIENCE_FEEDBACK_READY answer=no' 'BRB_SFX_PLAY cue=pre_start_instructions' 3800 5500
    Add-TimeWindowComparison 'prior no start waits for pre-start instructions' $log 'BRB_SFX_PLAY cue=pre_start_instructions' 'BRB_PRIOR_BUTTON_EXPERIENCE_PRE_START_READY answer=no' 34000 37000
}

function Run-FinalTenStress {
    Clear-RunLog
    Invoke-AudioStressCommand 'show_final_end'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SHOWN .*optionsVisible=false' 'final 10 prompt shown with options hidden' 20 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=final_end_confirmation_question_prompt .*isPlaying=true' 'final 10 question playback' 20 | Out-Null
    Invoke-AudioStressCommand 'final_answer_10'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SELECTION_BLOCKED rating=10 .*reason=question_audio_active' 'final 10 early rating blocked' 10 | Out-Null
    Wait-LogPattern 'BRB_AUDIO_RIG_STRESS_FINAL_ANSWER_RESULT rating=10 submitted=false' 'final 10 early submit blocked' 10 | Out-Null
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_OPTIONS_READY .*validationShortcut=false .*optionsVisible=true' 'final 10 options after question audio' 20 | Out-Null
    Invoke-AudioStressCommand 'final_answer_10'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SAVED rating=10 immediateEnd=true' 'final 10 answer saved' 10 | Out-Null
    $log = Wait-LogPattern 'BRB_SFX_PLAY cue=final_end_confirmation_10_feedback .*isPlaying=true' 'final 10 feedback playback' 15
    $path = Save-FilteredLog 'final-10' $log
    Add-Comparison 'final question prompt audio starts' $true ($log -match 'BRB_SFX_PLAY cue=final_end_confirmation_question_prompt .*isPlaying=true') $path
    Add-Comparison 'final rating blocked during prompt audio' $true ($log -match 'BRB_FINAL_END_CONFIRMATION_SELECTION_BLOCKED rating=10 .*reason=question_audio_active') $path
    Add-Comparison 'final 10 feedback audio starts' $true ($log -match 'BRB_SFX_PLAY cue=final_end_confirmation_10_feedback .*isPlaying=true') $path
    Add-TimeWindowComparison 'final options wait for question audio' $log 'BRB_SFX_PLAY cue=final_end_confirmation_question_prompt' 'BRB_FINAL_END_CONFIRMATION_OPTIONS_READY' 4900 7400
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_FINISH_SUPPRESSED reason=audio_rig_stress' 'final 10 finish suppressed for stress route' 10 | Out-Null
    Write-Host 'Waiting 17s for final 10 feedback audio before next phase...'
    Start-Sleep -Seconds 17
}

function Run-FinalExtraStress {
    Clear-RunLog
    Invoke-AudioStressCommand 'show_final_end'
    Wait-LogPattern 'BRB_SFX_PLAY cue=final_end_confirmation_question_prompt .*isPlaying=true' 'final extra question playback' 20 | Out-Null
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_OPTIONS_READY .*optionsVisible=true' 'final extra options after question audio' 20 | Out-Null
    Invoke-AudioStressCommand 'final_answer_7'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SAVED rating=7 immediateEnd=false' 'final extra non-10 saved' 10 | Out-Null
    Wait-LogPattern 'BRB_QUESTIONNAIRE_OUTRO_CUE trigger=final_extra_button_presses .*isPlaying=true' 'final extra outro cue' 20 | Out-Null
    Wait-LogPattern 'BRB_FINAL_EXTRA_BUTTON_CHALLENGE_START .*promptVisible=true .*buttonModelVisible=false' 'final extra prompt visible button hidden' 20 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=final_extra_presses_prompt .*isPlaying=true' 'final extra prompt playback' 10 | Out-Null
    Invoke-AudioStressCommand 'final_extra_press_attempt'
    Wait-LogPattern 'BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=prompt_audio_active source=audio_rig_stress' 'final extra press blocked during prompt audio' 10 | Out-Null
    Wait-LogPattern 'BRB_FINAL_EXTRA_PROMPT_HIDDEN reason=audio_complete .*buttonModelVisible=true .*counterOnly=true' 'final extra prompt hidden after audio' 70 | Out-Null
    Start-Sleep -Seconds 1
    Invoke-AudioStressCommand 'final_extra_press_attempt'
    Wait-LogPattern 'BRB_FINAL_EXTRA_BUTTON_PRESS index=1 .*source=audio_rig_stress' 'final extra button accepts after prompt audio' 10 | Out-Null
    $log = Wait-LogPattern 'BRB_SFX_PLAY cue=button_press .*asset=.*durationMs=' 'final extra button press sound' 10
    $path = Save-FilteredLog 'final-extra' $log
    Add-Comparison 'final extra prompt audio starts' $true ($log -match 'BRB_SFX_PLAY cue=final_extra_presses_prompt .*isPlaying=true') $path
    Add-Comparison 'final extra press blocked while prompt audio active' $true ($log -match 'BRB_FINAL_EXTRA_BUTTON_PRESS_SUPPRESSED reason=prompt_audio_active source=audio_rig_stress') $path
    Add-Comparison 'final extra button appears after prompt audio' $true ($log -match 'BRB_FINAL_EXTRA_PROMPT_HIDDEN reason=audio_complete .*buttonModelVisible=true .*counterOnly=true') $path
    Add-Comparison 'button press sound cue starts after prompt' $true ($log -match 'BRB_SFX_PLAY cue=button_press .*asset=.*durationMs=') $path
    Add-TimeWindowComparison 'final extra button waits for prompt audio' $log 'BRB_SFX_PLAY cue=final_extra_presses_prompt' 'BRB_FINAL_EXTRA_PROMPT_HIDDEN reason=audio_complete' 45200 49000
}

function Run-CueSuiteStress {
    Clear-RunLog
    Invoke-AudioStressCommand 'play_short_cues'
    Wait-LogPattern 'BRB_SFX_PLAY cue=questionnaire_choice .*isPlaying=true' 'questionnaire choice cue playback' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=questionnaire_navigation .*isPlaying=true' 'questionnaire navigation cue playback' 10 | Out-Null
    Wait-LogPattern 'BRB_SFX_PLAY cue=button_press asset=.*durationMs=' 'button press asset cue playback' 10 | Out-Null

    if (-not $SkipRedness) {
        Invoke-AudioStressCommand 'redness_vas_then_likert'
        Wait-LogPattern 'BRB_REDNESS_SCALE_CONVERSION_CUE order=vas_then_likert .*durationMs=22988' 'first redness cue metadata' 10 | Out-Null
        Wait-LogPattern 'BRB_SFX_PLAY cue=first_questionnaire_change .*isPlaying=true' 'first redness cue playback' 10 | Out-Null
        Start-Sleep -Milliseconds 23500
        Invoke-AudioStressCommand 'redness_likert_then_vas'
        Wait-LogPattern 'BRB_REDNESS_SCALE_CONVERSION_CUE order=likert_then_vas .*durationMs=16771' 'second redness cue metadata' 10 | Out-Null
        Wait-LogPattern 'BRB_SFX_PLAY cue=second_questionnaire_change_excuse .*isPlaying=true' 'second redness cue playback' 10 | Out-Null
    }

    $cueLog = Get-LogText
    $cuePath = Save-FilteredLog 'cue-suite' $cueLog
    Add-Comparison 'questionnaire choice cue starts' $true ($cueLog -match 'BRB_SFX_PLAY cue=questionnaire_choice .*isPlaying=true') $cuePath
    Add-Comparison 'questionnaire navigation cue starts' $true ($cueLog -match 'BRB_SFX_PLAY cue=questionnaire_navigation .*isPlaying=true') $cuePath
    Add-Comparison 'button press asset cue starts' $true ($cueLog -match 'BRB_SFX_PLAY cue=button_press asset=.*durationMs=') $cuePath
    if (-not $SkipRedness) {
        Add-Comparison 'first redness conversion audio starts' $true ($cueLog -match 'BRB_SFX_PLAY cue=first_questionnaire_change .*isPlaying=true') $cuePath
        Add-Comparison 'second redness conversion audio starts' $true ($cueLog -match 'BRB_SFX_PLAY cue=second_questionnaire_change_excuse .*isPlaying=true') $cuePath
    }

    foreach ($condition in 1, 2) {
        Clear-RunLog
        Invoke-AudioStressCommand "condition_${condition}_audio_probe"
        Wait-LogPattern "BRB_AUDIO_RIG_STRESS_CONDITION_AUDIO_PROBE condition=$condition" "condition $condition probe command" 10 | Out-Null
        Wait-LogPattern "BRB_CONDITION_AUDIO_START_ANCHOR condition=$condition .*durationMs=" "condition $condition audio anchor" 10 | Out-Null
        Wait-LogPattern "BRB_CONDITION_START condition=$condition .*isPlaying=true" "condition $condition audio started" 10 | Out-Null
        $conditionLog = Get-LogText
        $conditionPath = Save-FilteredLog "condition-$condition-probe" $conditionLog
        Add-Comparison "condition $condition instruction audio starts" $true ($conditionLog -match "BRB_CONDITION_START condition=$condition .*isPlaying=true") $conditionPath
    }
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest audio rig stress target: serial=$Serial model=$model android=$android"
Write-Host "APK SHA-256: $apkSha256"

try {
    if (-not $SkipInstall) {
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
        Start-Sleep -Seconds 3
    }

    Start-AudioStressRun 'audio-stress'
    Run-PriorYesStress
    Start-AudioStressRun 'audio-stress-prior-no'
    Run-PriorNoStress
    Run-FinalTenStress
    Run-FinalExtraStress
    Run-CueSuiteStress

    $allLog = Get-LogText
    $allLogPath = Save-FilteredLog 'final-device-log' $allLog
    $aggregatedLog = (($capturedLogTexts.ToArray()) -join "`n")
    Add-Comparison 'no raw cue failure markers' $false ($aggregatedLog -match 'BRB_SFX_FAILED|BRB_QUESTIONNAIRE_.*_CUE_FAILED') $allLogPath

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
        skipInstall = [bool]$SkipInstall
        skipRedness = [bool]$SkipRedness
        comparisons = $comparisons
        logs = $runLogs
        note = 'Headset stress for audio-linked prompt gates. It proves prior question options and final confirmation ratings stay hidden/blocked until their prompt MP3s finish, selected prior feedback is followed by the pre-start instructions clip before Start experiment appears, final extra presses remain blocked until the long prompt MP3 finishes, raw prompt/cue MP3s start with isPlaying=true, transition cues use explicit resource playback, and condition audio probes reach the real MediaPlayer start path without waiting through full tracks.'
    }
    $summaryPath = Join-Path $outDir 'quest-audio-rig-stress-summary.json'
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    if ($failed.Count -gt 0) {
        throw "Quest audio rig stress failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }
    Write-Host "Quest audio rig stress passed. Summary: $summaryPath"
} catch {
    $failureSummary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = 'error'
        error = $_.Exception.Message
        serial = $Serial
        package = $package
        apk = $ApkPath
        apkSha256 = $apkSha256
        evidenceDir = $outDir
        comparisons = $comparisons
        logs = $runLogs
    }
    $failurePath = Join-Path $outDir 'quest-audio-rig-stress-summary.json'
    $failureSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $failurePath -Encoding UTF8
    throw
}
