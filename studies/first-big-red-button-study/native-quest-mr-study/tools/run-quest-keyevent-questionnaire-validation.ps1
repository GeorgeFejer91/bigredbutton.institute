[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 120,
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
$outDir = Join-Path $projectRoot "artifacts\qkv\$runId"
$deviceExportDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"
$deviceResultsDir = "/sdcard/Android/data/$package/files/ExperimentResults"
$pullDir = Join-Path $outDir 'pulled'
$legacyPullDir = Join-Path $pullDir 'BigRedButtonFirstStudyExports'
$resultsPullDir = Join-Path $pullDir 'ExperimentResults'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $legacyPullDir | Out-Null
New-Item -ItemType Directory -Force -Path $resultsPullDir | Out-Null
$script:LogSnapshots = New-Object System.Collections.Generic.List[string]

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

function Start-KeyeventValidationActivity {
    Invoke-Adb shell am start -n $activity --ez brb.keyeventValidation true |
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

    Start-KeyeventValidationActivity
    Start-Sleep -Seconds 3
    $retryDump = Get-ForegroundDump
    $retryDump | Set-Content -LiteralPath (Join-Path $outDir 'foreground-after-relaunch.txt') -Encoding UTF8
    if (-not (Test-TargetForeground $retryDump)) {
        $retryPackage = Get-ForegroundPackage $retryDump
        throw "Target package $package was not foreground after relaunch. Current foreground package: $retryPackage"
    }
}

function Wait-LogPattern {
    param(
        [string]$Pattern,
        [string]$Description,
        [int]$Seconds = $TimeoutSeconds
    )
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 350
        $log = Get-LogText
        if ($log -match 'FATAL EXCEPTION|E/AndroidRuntime') {
            $script:LogSnapshots.Add($log)
            $log | Set-Content -LiteralPath (Join-Path $outDir 'failure-logcat.txt') -Encoding UTF8
            throw "Fatal runtime marker while waiting for $Description."
        }
        if ($log -match $Pattern) {
            $script:LogSnapshots.Add($log)
            return
        }
    }
    $log = Get-LogText
    $script:LogSnapshots.Add($log)
    $log | Set-Content -LiteralPath (Join-Path $outDir 'timeout-logcat.txt') -Encoding UTF8
    throw "Timed out waiting for $Description ($Pattern)."
}

function Send-KeyCode {
    param([int]$KeyCode, [string]$Name)
    Invoke-Adb shell input keyevent $KeyCode | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "adb keyevent $Name failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 170
}

function Send-Direction {
    param([string]$Direction)
    switch ($Direction) {
        'up' { Send-KeyCode 19 'DPAD_UP' }
        'down' { Send-KeyCode 20 'DPAD_DOWN' }
        'left' { Send-KeyCode 21 'DPAD_LEFT' }
        'right' { Send-KeyCode 22 'DPAD_RIGHT' }
        'enter' { Send-KeyCode 66 'ENTER' }
        default { throw "Unknown direction '$Direction'" }
    }
}

function Send-Sequence {
    param([string[]]$Directions)
    foreach ($direction in $Directions) {
        Send-Direction $direction
    }
}

function Pull-DeviceFolder {
    param([string]$DeviceDir, [string]$LocalDir)
    New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
    $filesRaw = Invoke-Adb shell ls -1 $DeviceDir
    if ($LASTEXITCODE -ne 0) {
        throw "Could not list $DeviceDir"
    }
    $files = @(
        $filesRaw |
            ForEach-Object { "$_".Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^total\s+' }
    )
    if ($files.Count -eq 0) {
        throw "No files found at $DeviceDir"
    }
    $shortPullRoot = Join-Path $env:TEMP ('brb-keyevent-pull-' + [IO.Path]::GetRandomFileName())
    New-Item -ItemType Directory -Force -Path $shortPullRoot | Out-Null
    try {
        $index = 0
        foreach ($file in $files) {
            $index += 1
            $tmp = Join-Path $shortPullRoot "file-$index.tmp"
            Invoke-Adb pull "$DeviceDir/$file" $tmp | Tee-Object -Append -FilePath (Join-Path $outDir 'pull.txt') | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull $DeviceDir/$file"
            }
            $safeFile =
                if ($file -eq 'session-index.jsonl') {
                    'session-index.jsonl'
                } elseif ($file -like '*_press_events.csv') {
                    'brb_first_study_keyevent_press_events.csv'
                } elseif ($file -like '*_ecg_blink_events.csv') {
                    'brb_first_study_keyevent_ecg_blink_events.csv'
                } elseif ($file -like '*_ecg_timeseries.csv') {
                    'brb_first_study_keyevent_ecg_timeseries.csv'
                } elseif ($file -like '*_ecg_detector_events.csv') {
                    'brb_first_study_keyevent_ecg_detector_events.csv'
                } elseif ($file -like '*_external_signal_samples.csv') {
                    'brb_first_study_keyevent_external_signal_samples.csv'
                } elseif ($file -like '*_summary.csv') {
                    'brb_first_study_keyevent_summary.csv'
                } elseif ($file -like 'brb_first_study_*.json') {
                    'brb_first_study_keyevent.json'
                } else {
                    "export-$index.dat"
                }
            Move-Item -LiteralPath $tmp -Destination (Join-Path $LocalDir $safeFile) -Force
        }
    } finally {
        if (Test-Path $shortPullRoot) {
            Remove-Item -Recurse -Force -LiteralPath $shortPullRoot
        }
    }
}

function Compare-ExportMirror {
    param(
        [string]$PrimaryDir,
        [string]$MirrorDir,
        [string]$OutPath
    )

    $primaryFiles = @(Get-ChildItem -LiteralPath $PrimaryDir -File | Sort-Object Name)
    $mirrorFiles = @(Get-ChildItem -LiteralPath $MirrorDir -File | Sort-Object Name)
    $mirrorByName = @{}
    foreach ($file in $mirrorFiles) {
        $mirrorByName[$file.Name] = $file
    }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($primary in $primaryFiles) {
        $mirror = $mirrorByName[$primary.Name]
        $primaryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $primary.FullName).Hash
        $mirrorHash = if ($null -ne $mirror) { (Get-FileHash -Algorithm SHA256 -LiteralPath $mirror.FullName).Hash } else { '' }
        $rows.Add([pscustomobject]@{
            fileName = $primary.Name
            primaryPath = $primary.FullName
            mirrorPath = if ($null -ne $mirror) { $mirror.FullName } else { '' }
            primarySizeBytes = $primary.Length
            mirrorSizeBytes = if ($null -ne $mirror) { $mirror.Length } else { $null }
            primarySha256 = $primaryHash
            mirrorSha256 = $mirrorHash
            matched = ($null -ne $mirror -and $primary.Length -eq $mirror.Length -and $primaryHash -eq $mirrorHash)
        })
    }
    $primaryNames = @($primaryFiles | ForEach-Object { $_.Name })
    foreach ($mirror in $mirrorFiles) {
        if ($primaryNames -notcontains $mirror.Name) {
            $rows.Add([pscustomobject]@{
                fileName = $mirror.Name
                primaryPath = ''
                mirrorPath = $mirror.FullName
                primarySizeBytes = $null
                mirrorSizeBytes = $mirror.Length
                primarySha256 = ''
                mirrorSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $mirror.FullName).Hash
                matched = $false
            })
        }
    }

    $mismatches = @($rows | Where-Object { -not $_.matched })
    $result = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = if ($mismatches.Count -eq 0 -and $primaryFiles.Count -eq $mirrorFiles.Count) { 'pass' } else { 'fail' }
        primaryDir = $PrimaryDir
        mirrorDir = $MirrorDir
        primaryFileCount = $primaryFiles.Count
        mirrorFileCount = $mirrorFiles.Count
        mismatchCount = $mismatches.Count
        files = $rows
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8
    if ($result.status -ne 'pass') {
        throw "Export mirror mismatch: $PrimaryDir and $MirrorDir differ. See $OutPath"
    }
    return $result
}

function Add-Comparison {
    param(
        [System.Collections.Generic.List[object]]$List,
        [string]$Name,
        $Expected,
        $Observed,
        [string]$Evidence = ''
    )
    $pass = "$Expected" -eq "$Observed"
    $List.Add([pscustomobject]@{
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

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest keyevent questionnaire validation target: serial=$Serial model=$model android=$android"

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Write-Host "APK SHA-256: $apkSha256"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Write-Host "Clearing prior exports/logcat"
    Invoke-Adb shell rm -rf $deviceExportDir $deviceResultsDir | Out-Null
    Invoke-Adb logcat -c

    Write-Host "Launching keyevent validation mode"
    Start-KeyeventValidationActivity
    Ensure-TargetForeground

    Wait-LogPattern 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name keyboardMode=text' 'startup native text keyboard request'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN' 'prior big-red-button experience prompt'
    Wait-LogPattern 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=right' 'prior big-red-button experience right-select replay'
    Wait-LogPattern 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pre_button_experience submitted=true' 'prior big-red-button experience enter-submit replay'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SAVED answer=yes' 'prior big-red-button experience save'
    Wait-LogPattern 'BRB_CONDITION_START condition=1' 'condition 1 start after prior-experience prompt'
    Wait-LogPattern 'BRB_CONDITION_END condition=1' 'condition 1 shortcut end'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=post_condition_1' 'condition 1 questionnaire intro'

    Wait-LogPattern 'BRB_PICTOGRAPHIC_SAVED condition=1' 'condition 1 pictographic save'
    Wait-LogPattern 'BRB_IPQ_SAVED condition=1' 'condition 1 ratings save'
    Wait-LogPattern 'BRB_LOST_OPPORTUNITY_SAVED condition=1' 'condition 1 additional-time save'
    Wait-LogPattern 'BRB_CONDITION_START condition=2' 'condition 2 start after outro'
    Wait-LogPattern 'BRB_CONDITION_END condition=2' 'condition 2 shortcut end'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=post_condition_2' 'condition 2 questionnaire intro'
    Wait-LogPattern 'BRB_PICTOGRAPHIC_SAVED condition=2' 'condition 2 pictographic save'
    Wait-LogPattern 'BRB_IPQ_SAVED condition=2' 'condition 2 ratings save'
    Wait-LogPattern 'BRB_EXPORT_COMPLETE' 'export complete'
    Wait-LogPattern 'BRB_EXPERIMENT_RESULTS_FOLDER' 'ExperimentResults folder marker'

    $script:LogSnapshots.Add((Get-LogText))
    $logText = ($script:LogSnapshots -join "`n")
    $logPath = Join-Path $outDir 'logcat-filtered.txt'
    $logText -split "`r?`n" |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|FATAL EXCEPTION|E/AndroidRuntime' |
        ForEach-Object { $_.Line } |
        Set-Content -LiteralPath $logPath -Encoding UTF8

    Pull-DeviceFolder -DeviceDir $deviceExportDir -LocalDir $legacyPullDir
    Pull-DeviceFolder -DeviceDir $deviceResultsDir -LocalDir $resultsPullDir
    $mirrorComparisonPath = Join-Path $outDir 'export-mirror-comparison.json'
    $mirrorComparison = Compare-ExportMirror -PrimaryDir $legacyPullDir -MirrorDir $resultsPullDir -OutPath $mirrorComparisonPath

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -ExportDir $legacyPullDir |
        Tee-Object -FilePath (Join-Path $outDir 'legacy-export-schema-validation.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "legacy export schema validation failed with exit code $LASTEXITCODE"
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -ExportDir $resultsPullDir |
        Tee-Object -FilePath (Join-Path $outDir 'experiment-results-schema-validation.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "ExperimentResults export schema validation failed with exit code $LASTEXITCODE"
    }

    $jsonFile = Get-ChildItem -LiteralPath $resultsPullDir -Filter 'brb_first_study_*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $summaryFile = Get-ChildItem -LiteralPath $resultsPullDir -Filter '*_summary.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $pressFile = Get-ChildItem -LiteralPath $resultsPullDir -Filter '*_press_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $ecgBlinkFile = Get-ChildItem -LiteralPath $resultsPullDir -Filter '*_ecg_blink_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $ecgTimeSeriesFile = Get-ChildItem -LiteralPath $resultsPullDir -Filter '*_ecg_timeseries.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
    $summaryCsv = Import-Csv -LiteralPath $summaryFile.FullName
    $pressCsv = Import-Csv -LiteralPath $pressFile.FullName
    $ecgBlinkCsv = Import-Csv -LiteralPath $ecgBlinkFile.FullName
    $ecgTimeSeriesCsv = Import-Csv -LiteralPath $ecgTimeSeriesFile.FullName
    $c1 = @($exportJson.conditions | Where-Object { $_.conditionNumber -eq 1 })[0]
    $c2 = @($exportJson.conditions | Where-Object { $_.conditionNumber -eq 2 })[0]
    $conditions = @($c1, $c2)
    $simulatedCondition = @($conditions | Where-Object { $_.ecgSource -eq 'simulated_neurokit2' })[0]
    $realCondition = @($conditions | Where-Object { $_.ecgSource -eq 'real_polar_h10' })[0]
    $simulatedConditionNumber = if ($null -ne $simulatedCondition) { [int]$simulatedCondition.conditionNumber } else { 0 }
    $realConditionNumber = if ($null -ne $realCondition) { [int]$realCondition.conditionNumber } else { 0 }
    $simulatedBlinkRows = @($ecgBlinkCsv | Where-Object { [int]$_.condition_number -eq $simulatedConditionNumber -and $_.source -eq 'simulated_neurokit2' })
    $simulatedTimeSeriesRows = @($ecgTimeSeriesCsv | Where-Object { [int]$_.condition_number -eq $simulatedConditionNumber -and $_.source -eq 'simulated_neurokit2' })
    $assignmentMatchesSources =
        ($exportJson.ecgProtocol.assignmentOrder -eq 'real_then_simulated' -and $c1.ecgSource -eq 'real_polar_h10' -and $c2.ecgSource -eq 'simulated_neurokit2') -or
        ($exportJson.ecgProtocol.assignmentOrder -eq 'simulated_then_real' -and $c1.ecgSource -eq 'simulated_neurokit2' -and $c2.ecgSource -eq 'real_polar_h10')
    $row = @($summaryCsv)[0]
    $uniquePriorExperiencePromptLines = @(
        $logText -split "`r?`n" |
            Where-Object { $_ -match 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN' } |
            Sort-Object -Unique
    )
    $comparisons = New-Object System.Collections.Generic.List[object]

    Add-Comparison $comparisons 'participant id generated under hood' 'KEYEVENT_VALIDATION_' ($exportJson.demographics.participantId.Substring(0, [Math]::Min(20, $exportJson.demographics.participantId.Length))) 'JSON demographics.participantId'
    Add-Comparison $comparisons 'name text exported' 'Keyevent Validation' $exportJson.demographics.name 'JSON demographics.name'
    Add-Comparison $comparisons 'age numeric text exported' '33' $exportJson.demographics.age 'JSON demographics.age'
    Add-Comparison $comparisons 'gender four-choice exported' 'prefer_not_to_say' $exportJson.demographics.gender 'JSON demographics.gender'
    Add-Comparison $comparisons 'handedness tri-choice exported' 'right' $exportJson.demographics.handedness 'JSON demographics.handedness'
    Add-Comparison $comparisons 'signature stroke format exported' $true ($exportJson.demographics.signature -match 'brb_signature_strokes_v1') 'JSON demographics.signature'
    Add-Comparison $comparisons 'prior big-red-button experience JSON answer' 'yes' $exportJson.priorBigRedButtonExperience.answer 'JSON priorBigRedButtonExperience.answer'
    Add-Comparison $comparisons 'prior big-red-button experience JSON boolean' $true $exportJson.priorBigRedButtonExperience.hasExperience 'JSON priorBigRedButtonExperience.hasExperience'
    Add-Comparison $comparisons 'prior big-red-button experience JSON location' 'button_counter_panel' $exportJson.priorBigRedButtonExperience.displayLocation 'JSON priorBigRedButtonExperience.displayLocation'
    Add-Comparison $comparisons 'prior big-red-button experience shown before condition' 1 $exportJson.priorBigRedButtonExperience.shownBeforeCondition 'JSON priorBigRedButtonExperience.shownBeforeCondition'
    Add-Comparison $comparisons 'prior big-red-button experience summary answer' 'yes' $row.prior_big_red_button_experience 'summary CSV'
    Add-Comparison $comparisons 'prior big-red-button experience summary boolean' 'true' $row.prior_big_red_button_experience_bool 'summary CSV'
    Add-Comparison $comparisons 'prior big-red-button experience summary timestamp present' $true (-not [string]::IsNullOrWhiteSpace($row.prior_big_red_button_experience_timestamp_iso)) 'summary CSV'
    Add-Comparison $comparisons 'prior big-red-button experience prompt shown once' 1 $uniquePriorExperiencePromptLines.Count 'unique logcat lines'
    Add-Comparison $comparisons 'prior big-red-button experience not repeated in condition 2' $false ($logText -match 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN .*condition=2') 'logcat'
    Add-Comparison $comparisons 'prior big-red-button experience controller replay observed' $true ($logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=right' -and $logText -match 'BRB_CONTROLLER_DIRECTION stage=pre_button_experience direction=right answer=yes' -and $logText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pre_button_experience submitted=true') 'logcat'

    Add-Comparison $comparisons 'condition 1 emulated button count' 2 $c1.buttonPressCount 'JSON condition 1 buttonPressCount'
    Add-Comparison $comparisons 'condition 2 emulated button count' 2 $c2.buttonPressCount 'JSON condition 2 buttonPressCount'
    Add-Comparison $comparisons 'ECG assignment exported' $true ($exportJson.ecgProtocol.assignmentOrder -in @('real_then_simulated', 'simulated_then_real')) 'JSON ecgProtocol.assignmentOrder'
    Add-Comparison $comparisons 'condition 1 ECG source exported' $true ($c1.ecgSource -in @('real_polar_h10', 'simulated_neurokit2')) 'JSON condition 1 ecgSource'
    Add-Comparison $comparisons 'condition 2 ECG source exported' $true ($c2.ecgSource -in @('real_polar_h10', 'simulated_neurokit2')) 'JSON condition 2 ecgSource'
    Add-Comparison $comparisons 'ECG sources counterbalanced complement' $true (($null -ne $simulatedCondition) -and ($null -ne $realCondition) -and ($simulatedConditionNumber -ne $realConditionNumber)) 'JSON condition ecgSource values'
    Add-Comparison $comparisons 'ECG assignment order matches condition sources' $true $assignmentMatchesSources 'JSON ecgProtocol.assignmentOrder and condition ecgSource values'
    Add-Comparison $comparisons 'ECG blink event CSV readable' $true ($null -ne $ecgBlinkCsv) 'ExperimentResults ECG blink-events CSV'
    Add-Comparison $comparisons 'ECG time-series CSV readable' $true ($null -ne $ecgTimeSeriesCsv) 'ExperimentResults ECG time-series CSV'
    Add-Comparison $comparisons 'simulated ECG blink count exported' $true (($null -ne $simulatedCondition) -and ([int]$simulatedCondition.ecgBlinkCount -gt 0)) 'JSON simulated condition ecgBlinkCount'
    Add-Comparison $comparisons 'simulated ECG blink rows match JSON count' ([int]$simulatedCondition.ecgBlinkCount) @($simulatedBlinkRows).Count 'ExperimentResults ECG blink-events CSV'
    Add-Comparison $comparisons 'simulated ECG blink runtime marker observed' $true ($logText -match "BRB_ECG_BLINK condition=$simulatedConditionNumber .*source=simulated_neurokit2") 'logcat'
    Add-Comparison $comparisons 'simulated heartbeat visual flash observed' $true ($logText -match "BRB_HEARTBEAT_FLASH condition=$simulatedConditionNumber source=simulated_neurokit2") 'logcat'
    Add-Comparison $comparisons 'simulated ECG time-series sample count equals expected' ([int]$simulatedCondition.ecgExpectedSampleCount) ([int]$simulatedCondition.ecgTimeSeriesSampleCount) 'JSON simulated condition raw ECG count'
    Add-Comparison $comparisons 'simulated ECG time-series CSV rows match JSON count' ([int]$simulatedCondition.ecgTimeSeriesSampleCount) @($simulatedTimeSeriesRows).Count 'ExperimentResults ECG time-series CSV'
    Add-Comparison $comparisons 'condition 1 ECG capture duration equals audio' $c1.audioDurationMs $c1.ecgCaptureDurationMs 'JSON condition 1 ECG capture window'
    Add-Comparison $comparisons 'condition 2 ECG capture duration equals audio' $c2.audioDurationMs $c2.ecgCaptureDurationMs 'JSON condition 2 ECG capture window'
    Add-Comparison $comparisons 'condition 1 ECG sample rate' 130 $c1.ecgSampleRateHz 'JSON condition 1 ECG sample rate'
    Add-Comparison $comparisons 'condition 2 ECG sample rate' 130 $c2.ecgSampleRateHz 'JSON condition 2 ECG sample rate'
    Add-Comparison $comparisons 'condition 1 ECG audio window start' 0 $c1.ecgAudioWindowStartMs 'JSON condition 1 ECG audio-window start'
    Add-Comparison $comparisons 'condition 2 ECG audio window start' 0 $c2.ecgAudioWindowStartMs 'JSON condition 2 ECG audio-window start'
    Add-Comparison $comparisons 'condition 1 ECG audio window end equals audio' $c1.audioDurationMs $c1.ecgAudioWindowEndMs 'JSON condition 1 ECG audio-window end'
    Add-Comparison $comparisons 'condition 2 ECG audio window end equals audio' $c2.audioDurationMs $c2.ecgAudioWindowEndMs 'JSON condition 2 ECG audio-window end'
    Add-Comparison $comparisons 'condition 1 ECG audio window duration equals audio' $c1.audioDurationMs $c1.ecgAudioWindowDurationMs 'JSON condition 1 ECG audio-window duration'
    Add-Comparison $comparisons 'condition 2 ECG audio window duration equals audio' $c2.audioDurationMs $c2.ecgAudioWindowDurationMs 'JSON condition 2 ECG audio-window duration'
    Add-Comparison $comparisons 'condition 1 ECG capture ns duration equals audio' ([int64]$c1.audioDurationMs * 1000000L) ([int64]$c1.ecgCaptureEndedElapsedNs - [int64]$c1.ecgCaptureStartedElapsedNs) 'JSON condition 1 ECG nanosecond capture window'
    Add-Comparison $comparisons 'condition 2 ECG capture ns duration equals audio' ([int64]$c2.audioDurationMs * 1000000L) ([int64]$c2.ecgCaptureEndedElapsedNs - [int64]$c2.ecgCaptureStartedElapsedNs) 'JSON condition 2 ECG nanosecond capture window'
    Add-Comparison $comparisons 'condition 1 closeness' 50 $c1.pictographic.feltCloseness0To100 'D-pad left/up/right/down'
    Add-Comparison $comparisons 'condition 1 presence' 50 $c1.pictographic.feltPresence0To100 'D-pad left/up/right/down'
    Add-Comparison $comparisons 'condition 2 closeness' 40 $c2.pictographic.feltCloseness0To100 'D-pad right/right/up/up'
    Add-Comparison $comparisons 'condition 2 presence' 60 $c2.pictographic.feltPresence0To100 'D-pad right/right/up/up'
    Add-Comparison $comparisons 'condition 1 redness VAS' 60 $c1.pictographic.rednessVas0To100 'fast replay VAS-to-Likert conversion'
    Add-Comparison $comparisons 'condition 1 redness Likert' 5 $c1.pictographic.rednessLikert1To7 'fast replay VAS-to-Likert conversion'
    Add-Comparison $comparisons 'condition 1 redness order' 'vas_then_likert' $c1.pictographic.rednessScaleOrder 'JSON pictographic.rednessScaleOrder'
    Add-Comparison $comparisons 'condition 2 redness VAS' 66 $c2.pictographic.rednessVas0To100 'fast replay Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness Likert' 5 $c2.pictographic.rednessLikert1To7 'fast replay Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness order' 'likert_then_vas' $c2.pictographic.rednessScaleOrder 'JSON pictographic.rednessScaleOrder'
    Add-Comparison $comparisons 'condition 1 lost opportunity' 59 $c1.lostOpportunity.score0To100 'D-pad right/right/down'
    Add-Comparison $comparisons 'condition 2 lost opportunity' 51 $c2.lostOpportunity.score0To100 'D-pad left/up/right'
    Add-Comparison $comparisons 'summary condition 1 lost opportunity' 59 $row.condition_1_lost_opportunity_for_better_results_quotient 'summary CSV'
    Add-Comparison $comparisons 'summary condition 2 lost opportunity' 51 $row.condition_2_lost_opportunity_for_better_results_quotient 'summary CSV'

    foreach ($item in @($exportJson.presenceQuestionnaire.items)) {
        $id = [string]$item.id
        Add-Comparison $comparisons "condition 1 $id raw" 4 $c1.presenceQuestionnaire.rawAnswers0To6.$id 'D-pad right on each item'
        Add-Comparison $comparisons "condition 2 $id raw" 2 $c2.presenceQuestionnaire.rawAnswers0To6.$id 'D-pad left on each item'
    }

    $pressSources = @($pressCsv | Select-Object -ExpandProperty input_source -Unique)
    Add-Comparison $comparisons 'press event source' 'controller_emulated_validation' ($pressSources -join '|') 'press-events CSV'
    $automationFlags = @($pressCsv | Select-Object -ExpandProperty validation_automation -Unique)
    Add-Comparison $comparisons 'press validation automation flag' 'true' ($automationFlags -join '|') 'press-events CSV'
    Add-Comparison $comparisons 'press event rows' 4 @($pressCsv).Count 'press-events CSV'
    Add-Comparison $comparisons 'native keyboard request observed' $true ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name .*implementation=system') 'logcat'
    Add-Comparison $comparisons 'native keyboard name text mode observed' $true ($logText -match 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=name .*keyboardMode=text .*keyboardType=Text .*implementation=system_native') 'logcat'
    Add-Comparison $comparisons 'native keyboard age numeric mode observed' $true ($logText -match 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=age .*keyboardMode=number .*keyboardType=Number .*digitsOnly=true .*maxDigits=3') 'logcat'
    Add-Comparison $comparisons 'native keyboard movable panel contract observed' $true ($logText -match 'BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT field=name .*movablePanel=true .*closeToParticipant=system_managed' -and $logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name .*movablePanel=true .*closeToParticipant=system_managed') 'logcat'
    Add-Comparison $comparisons 'native keyboard text-to-number retarget observed' $true ($logText -match 'BRB_SOFT_KEYBOARD_SWITCH from=field_name to=field_age .*fromMode=text .*toMode=number .*failSafeRetarget=true') 'logcat'
    Add-Comparison $comparisons 'startup native keyboard request uses text mode' $true ($logText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_name .*keyboardMode=text') 'logcat'
    Add-Comparison $comparisons 'redness conversion cue observed' $true (
        $logText -match 'BRB_REDNESS_SCALE_CONVERSION condition=1 .*from=vas to=likert' -and
        $logText -match 'BRB_REDNESS_SCALE_CONVERSION condition=2 .*from=likert to=vas' -and
        $logText -match 'BRB_REDNESS_SCALE_CONVERSION_CUE order=vas_then_likert .*cue=first_questionnaire_change .*placeholder=false .*validationShortcut=true' -and
        $logText -match 'BRB_REDNESS_SCALE_CONVERSION_CUE order=likert_then_vas .*cue=second_questionnaire_change_excuse .*placeholder=false .*validationShortcut=true'
    ) 'logcat'
    Add-Comparison $comparisons 'panel-exit keyboard hide before condition 1 observed' $true ($logText -match 'BRB_SOFT_KEYBOARD_HIDE reason=before_condition_1') 'logcat'
    Add-Comparison $comparisons 'panel-exit keyboard hide before condition 2 observed' $true ($logText -match 'BRB_SOFT_KEYBOARD_HIDE reason=before_condition_2') 'logcat'
    Add-Comparison $comparisons 'directional replay observed' $true ($logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pictographic direction=left') 'logcat'
    Add-Comparison $comparisons 'enter submit replay observed' $true ($logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pictographic direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=presence_questionnaire direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=lost_opportunity direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=pictographic direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=presence_questionnaire direction=enter' -and $logText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=lost_opportunity direction=enter') 'logcat'
    Add-Comparison $comparisons 'controller submit replay observed' $true ($logText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pictographic submitted=true' -and $logText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=2 stage=lost_opportunity submitted=true') 'logcat'
    Add-Comparison $comparisons 'intro glitch observed' $true ($logText -match 'BRB_PANEL_GLITCH state=start mode=intro') 'logcat'
    Add-Comparison $comparisons 'outro glitch observed' $true ($logText -match 'BRB_PANEL_GLITCH state=start mode=outro') 'logcat'
    Add-Comparison $comparisons 'SideQuest results folder marker observed' $true ($logText -match 'BRB_EXPERIMENT_RESULTS_FOLDER') 'logcat'

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
        apkInfo = [pscustomobject]@{
            path = $ApkPath
            sha256 = $apkSha256
            sizeBytes = $apkItem.Length
            lastWriteTime = $apkItem.LastWriteTime.ToString('o')
        }
        evidenceDir = $outDir
        deviceExportDir = $deviceExportDir
        deviceExperimentResultsDir = $deviceResultsDir
        json = $jsonFile.FullName
        summaryCsv = $summaryFile.FullName
        pressEventsCsv = $pressFile.FullName
        ecgBlinkEventsCsv = $ecgBlinkFile.FullName
        ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
        exportMirrorComparison = $mirrorComparisonPath
        exportMirrorMatched = ($mirrorComparison.status -eq 'pass')
        exportMirrorFileCount = $mirrorComparison.primaryFileCount
        comparisons = $comparisons
        note = 'Fast directional questionnaire validation. It shortcuts instruction-audio waiting, replays bounded up/down/left/right/enter-equivalent commands through the app controller-direction/submit handlers, validates field-specific native system keyboard request modes and text-to-number retarget markers, redness VAS/Likert conversion markers, panel-exit hide markers and glitch markers, pulls both export folders, and compares exported values against expected outcomes. ADB input keyevent is not treated as the reliable transport for Spatial SDK panels. This is not physical controller-contact evidence.'
    }
    $summaryPath = Join-Path $outDir 'quest-keyevent-questionnaire-validation-summary.json'
    $summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    $comparisons | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outDir 'expected-vs-observed.csv')

    if ($failed.Count -gt 0) {
        throw "Keyevent questionnaire validation failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }

    Write-Host "PASS Quest keyevent questionnaire validation"
    Write-Host "Summary: $summaryPath"
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
