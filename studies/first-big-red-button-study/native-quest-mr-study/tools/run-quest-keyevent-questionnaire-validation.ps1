[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 120,
    [string]$StudyLanguage = '',
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'export-session-layout.ps1')
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
$pullDir = Join-Path $outDir 'p'
$legacyPullDir = Join-Path $pullDir 'b'
$resultsPullDir = Join-Path $pullDir 'e'

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

function Get-ExpectedStudyLanguageRoute {
    param([string]$Language)
    if ($Language -match '^(ja|ja-JP|jp|japanese)$') {
        return [pscustomobject]@{ LocaleSegment = 'ja_jp'; LanguageCode = 'ja-JP' }
    }
    if ($Language -match '^(de|de-DE|german|deutsch)$') {
        return [pscustomobject]@{ LocaleSegment = 'de_de'; LanguageCode = 'de-DE' }
    }
    return [pscustomobject]@{ LocaleSegment = 'en_us'; LanguageCode = 'en-US' }
}

function Start-KeyeventValidationActivity {
    $launchArgs = @('shell', 'am', 'start', '-n', $activity, '--ez', 'brb.keyeventValidation', 'true')
    if (-not [string]::IsNullOrWhiteSpace($StudyLanguage)) {
        $launchArgs += @('--es', 'brb.studyLanguage', $StudyLanguage)
    }
    Invoke-Adb @launchArgs |
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
        ($foregroundPackage -eq 'com.oculus.systemux' -or
            ($foregroundPackage -notlike 'com.oculus.*' -and $foregroundPackage -notlike 'android.*'))) {
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
    $filesRaw = Invoke-Adb shell find $DeviceDir -type f
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
    $pathMap = @{}
    try {
        $index = 0
        foreach ($remoteFile in $files) {
            $index += 1
            $tmp = Join-Path $shortPullRoot "file-$index.tmp"
            $relative = "$remoteFile"
            if ($relative.StartsWith($DeviceDir, [StringComparison]::Ordinal)) {
                $relative = $relative.Substring($DeviceDir.Length).TrimStart('/')
            } else {
                $relative = Split-Path -Leaf $relative
            }
            $relativeParts = @($relative -split '/')
            $localRelative =
                if ($relativeParts.Count -gt 1) {
                    (($relativeParts[0..($relativeParts.Count - 2)] + (Get-BrbShortExportFileName -FileName $relativeParts[-1] -Prefix 'brb_first_study_keyevent')) -join '/')
                } else {
                    Get-BrbShortExportFileName -FileName $relativeParts[-1] -Prefix 'brb_first_study_keyevent'
                }
            $pathMap[$relative] = $localRelative
            $localPath = Join-Path $LocalDir ($localRelative -replace '/', '\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localPath) | Out-Null
            Invoke-Adb pull "$remoteFile" $tmp | Tee-Object -Append -FilePath (Join-Path $outDir 'pull.txt') | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull $remoteFile"
            }
            Move-Item -LiteralPath $tmp -Destination $localPath -Force
        }
        Update-BrbPulledExportMetadata -LocalDir $LocalDir -PathMap $pathMap
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

    $primaryFiles = @(Get-BrbRecursiveFileRows -RootDir $PrimaryDir)
    $mirrorFiles = @(Get-BrbRecursiveFileRows -RootDir $MirrorDir)
    $mirrorByName = @{}
    foreach ($row in $mirrorFiles) {
        $mirrorByName[$row.RelativePath] = $row.File
    }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($primaryRow in $primaryFiles) {
        $primary = $primaryRow.File
        $mirror = $mirrorByName[$primaryRow.RelativePath]
        $primaryHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $primary.FullName).Hash
        $mirrorHash = if ($null -ne $mirror) { (Get-FileHash -Algorithm SHA256 -LiteralPath $mirror.FullName).Hash } else { '' }
        $rows.Add([pscustomobject]@{
            fileName = $primaryRow.RelativePath
            primaryPath = $primary.FullName
            mirrorPath = if ($null -ne $mirror) { $mirror.FullName } else { '' }
            primarySizeBytes = $primary.Length
            mirrorSizeBytes = if ($null -ne $mirror) { $mirror.Length } else { $null }
            primarySha256 = $primaryHash
            mirrorSha256 = $mirrorHash
            matched = ($null -ne $mirror -and $primary.Length -eq $mirror.Length -and $primaryHash -eq $mirrorHash)
        })
    }
    $primaryNames = @($primaryFiles | ForEach-Object { $_.RelativePath })
    foreach ($mirrorRow in $mirrorFiles) {
        $mirror = $mirrorRow.File
        if ($primaryNames -notcontains $mirrorRow.RelativePath) {
            $rows.Add([pscustomobject]@{
                fileName = $mirrorRow.RelativePath
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
    Invoke-Adb shell am force-stop $package | Out-Null
    Start-Sleep -Milliseconds 500
    Invoke-Adb logcat -c

    Write-Host "Launching keyevent validation mode"
    Start-KeyeventValidationActivity
    Ensure-TargetForeground

    Wait-LogPattern 'BRB_QUESTIONNAIRE_CONTRACT schema=bigredbutton.questionnaire_flow.v1 .*transport=in_process_spatial_panel .*productCommunication=app_internal' 'questionnaire protocol contract marker'
    Wait-LogPattern 'BRB_LSL status=disabled .*role=diagnostic_only .*streamName=HRV_Biofeedback .*streamType=HRV .*contaminatesPressCounts=false' 'disabled diagnostic external signal contract marker'
    Wait-LogPattern 'BRB_AGENT_INTEGRATION_CONTRACT schema=bigredbutton.agent_integration.v1 .*adaptation=native_meta_spatial_sdk_in_process .*rustyXrBrokerRequired=false .*directPolarPmdActive=true .*directLslEnabled=false .*finalPressProof=controller_contact' 'native agent integration contract marker'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_FOCUS field=name .*platformControl=AppOwnedKeyboard' 'startup app-owned name keyboard focus'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN' 'prior big-red-button experience prompt'
    Wait-LogPattern 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=right' 'prior big-red-button experience right-select replay'
    Wait-LogPattern 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pre_button_experience submitted=true' 'prior big-red-button experience enter-submit replay'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SAVED answer=yes' 'prior big-red-button experience save'
    Wait-LogPattern 'BRB_CONDITION_START condition=1' 'condition 1 start after prior-experience prompt'
    Wait-LogPattern 'BRB_CONDITION_END condition=1' 'condition 1 shortcut end'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=post_condition_1' 'condition 1 questionnaire intro'
    Wait-LogPattern 'BRB_SPONTANEOUS_REMARK_CUE kind=vas .*scale=pictographic_.*audioId=aud_07.*noOverlap=true .*randomOrder=true' 'condition 1 VAS spontaneous remark cue'
    Wait-LogPattern 'BRB_SPONTANEOUS_REMARK_COOLDOWN kind=vas .*audioId=aud_07.*minMs=5000 .*maxMs=10000 .*reason=' 'condition 1 VAS spontaneous remark cooldown'

    Wait-LogPattern 'BRB_PICTOGRAPHIC_SAVED condition=1' 'condition 1 pictographic save'
    Wait-LogPattern 'BRB_IPQ_HISTORY_NARRATION_CUE condition=1 .*cue=ipq_history_part1 .*audioId=aud_0320 .*blocking=false' 'condition 1 IPQ history narration cue'
    Wait-LogPattern 'BRB_SFX_PLAY cue=ipq_history_part1 audioId=aud_0320 asset=.*aud_0320_ipq_history_part1__.*\.mp3 .*durationMs=' 'condition 1 IPQ history narration playback'
    Wait-LogPattern 'BRB_IPQ_SAVED condition=1' 'condition 1 ratings save'
    Wait-LogPattern 'BRB_LOST_OPPORTUNITY_SAVED condition=1' 'condition 1 additional-time save'
    Wait-LogPattern 'BRB_CONDITION_START condition=2' 'condition 2 start after outro'
    Wait-LogPattern 'BRB_CONDITION_END condition=2' 'condition 2 shortcut end'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_pictographic condition=2' 'condition 2 post-condition pictographic stage opens'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_INTRO_CUE trigger=post_condition_2' 'condition 2 questionnaire intro'
    Wait-LogPattern 'BRB_PICTOGRAPHIC_SAVED condition=2' 'condition 2 pictographic save'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_presence_questionnaire condition=2' 'condition 2 post-condition presence stage opens'
    Wait-LogPattern 'BRB_IPQ_HISTORY_NARRATION_CUE condition=2 .*cue=ipq_history_part2 .*audioId=aud_0330 .*blocking=false' 'condition 2 IPQ history narration cue'
    Wait-LogPattern 'BRB_SFX_PLAY cue=ipq_history_part2 audioId=aud_0330 asset=.*aud_0330_ipq_history_part2__.*\.mp3 .*durationMs=' 'condition 2 IPQ history narration playback'
    Wait-LogPattern 'BRB_IPQ_SAVED condition=2' 'condition 2 ratings save'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_lost_opportunity condition=2' 'condition 2 post-condition lost-opportunity stage opens'
    Wait-LogPattern 'BRB_LOST_OPPORTUNITY_SAVED condition=2' 'condition 2 additional-time save'
    Wait-LogPattern 'BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=post_condition_2_lost_opportunity condition=2 nextStageId=final_end_confirmation' 'condition 2 post-condition block completes before final confirmation'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SHOWN' 'final end-confirmation questionnaire shown'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_OPTIONS_READY .*optionsVisible=true' 'final end-confirmation options ready before replay'
    Wait-LogPattern 'BRB_KEYEVENT_REPLAY_STEP condition=0 stage=final_end_confirmation direction=right' 'final end-confirmation right-select replay'
    Wait-LogPattern 'BRB_CONTROLLER_SUBMIT_REPLAY condition=0 stage=final_end_confirmation submitted=true' 'final end-confirmation enter-submit replay'
    Wait-LogPattern 'BRB_FINAL_END_CONFIRMATION_SAVED rating=10 immediateEnd=true' 'final end-confirmation option 10 save'
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

    $resultsSession = Resolve-BrbExportSession -ExportDir $resultsPullDir
    $resultsSessionDir = $resultsSession.SessionDir
    $jsonFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter 'brb_first_study_*.json'
    $summaryFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_summary.csv'
    $pressFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_press_events.csv'
    $finalExtraPressFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_final_extra_button_presses.csv'
    $ecgBlinkFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_ecg_blink_events.csv'
    $ecgTimeSeriesFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_ecg_timeseries.csv'
    $polarRrFile = Get-BrbExportSessionFile -SessionDir $resultsSessionDir -Filter '*_polar_rr_events.csv'

    $exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
    $runLogText = $logText
    $exportSessionId = "$($exportJson.sessionId)"
    if (-not [string]::IsNullOrWhiteSpace($exportSessionId)) {
        $exportSessionPattern =
            "BigRedButtonStudy\((?<pid>\d+)\): BRB_EXPORT_COMPLETE .*sessionId=$([regex]::Escape($exportSessionId))"
        $exportSessionMatches = [regex]::Matches($logText, $exportSessionPattern)
        if ($exportSessionMatches.Count -gt 0) {
            $exportPid = $exportSessionMatches.Item(($exportSessionMatches.Count - 1)).Groups['pid'].Value
            $runLogText =
                (($logText -split "`r?`n") |
                    Where-Object { $_ -match "BigRedButtonStudy\($([regex]::Escape($exportPid))\):" }) -join "`n"
        }
    }
    $summaryCsv = Import-Csv -LiteralPath $summaryFile.FullName
    $pressCsv = Import-Csv -LiteralPath $pressFile.FullName
    $finalExtraPressCsv = if ($null -ne $finalExtraPressFile) { Import-Csv -LiteralPath $finalExtraPressFile.FullName } else { @() }
    $ecgBlinkCsv = Import-Csv -LiteralPath $ecgBlinkFile.FullName
    $ecgTimeSeriesHeader =
        if ($null -ne $ecgTimeSeriesFile) {
            Get-Content -LiteralPath $ecgTimeSeriesFile.FullName -TotalCount 1
        } else {
            ''
        }
    $ecgTimeSeriesCsv =
        if ($null -ne $ecgTimeSeriesFile) {
            @(Import-Csv -LiteralPath $ecgTimeSeriesFile.FullName)
        } else {
            @()
        }
    $polarRrCsv = if ($null -ne $polarRrFile) { Import-Csv -LiteralPath $polarRrFile.FullName } else { @() }
    $c1 = @($exportJson.conditions | Where-Object { $_.conditionNumber -eq 1 })[0]
    $c2 = @($exportJson.conditions | Where-Object { $_.conditionNumber -eq 2 })[0]
    $conditions = @($c1, $c2)
    $simulatedCondition = @($conditions | Where-Object { $_.feedbackSource -eq 'simulated_neurokit2' })[0]
    $realCondition = @($conditions | Where-Object { $_.feedbackSource -eq 'real_polar_h10' })[0]
    $simulatedConditionNumber = if ($null -ne $simulatedCondition) { [int]$simulatedCondition.conditionNumber } else { 0 }
    $realConditionNumber = if ($null -ne $realCondition) { [int]$realCondition.conditionNumber } else { 0 }
    $simulatedBlinkRows = @($ecgBlinkCsv | Where-Object { [int]$_.condition_number -eq $simulatedConditionNumber -and $_.source -eq 'simulated_neurokit2' })
    $simulatedTimeSeriesRows = @($ecgTimeSeriesCsv | Where-Object { $_.source -eq 'simulated_neurokit2' })
    $pressRowsWithElapsedNs = @($pressCsv | Where-Object { -not [string]::IsNullOrWhiteSpace($_.elapsed_ns) })
    $pressColumns = if (@($pressCsv).Count -gt 0) { @($pressCsv[0].PSObject.Properties.Name) } else { @() }
    $pressAlignmentColumnsPresent =
        $pressColumns -contains 'elapsed_ns' -and
        $pressColumns -contains 'event_elapsed_realtime_ns' -and
        $pressColumns -contains 'condition_start_elapsed_realtime_ns' -and
        $pressColumns -contains 'nearest_ecg_sample_index' -and
        $pressColumns -contains 'nearest_ecg_elapsed_ns' -and
        $pressColumns -contains 'nearest_ecg_delta_ns'
    $assignmentMatchesSources =
        ($exportJson.ecgProtocol.assignmentOrder -eq 'real_then_simulated' -and $c1.feedbackSource -eq 'real_polar_h10' -and $c2.feedbackSource -eq 'simulated_neurokit2') -or
        ($exportJson.ecgProtocol.assignmentOrder -eq 'simulated_then_real' -and $c1.feedbackSource -eq 'simulated_neurokit2' -and $c2.feedbackSource -eq 'real_polar_h10')
    $row = @($summaryCsv)[0]
    $expectedStudyLanguageRoute = Get-ExpectedStudyLanguageRoute $StudyLanguage
    $expectedIpqLocaleSegment = $expectedStudyLanguageRoute.LocaleSegment
    $expectedIpqLanguageCode = $expectedStudyLanguageRoute.LanguageCode
    $uniquePriorExperiencePromptLines = @(
        $runLogText -split "`r?`n" |
            Where-Object { $_ -match 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN' } |
            Sort-Object -Unique
    )
    $comparisons = New-Object System.Collections.Generic.List[object]

    Add-Comparison $comparisons 'participant id generated under hood' 'QKV_' ($exportJson.demographics.participantId.Substring(0, [Math]::Min(4, $exportJson.demographics.participantId.Length))) 'JSON demographics.participantId'
    Add-Comparison $comparisons 'name text exported' 'Keyevent Validation' $exportJson.demographics.name 'JSON demographics.name'
    Add-Comparison $comparisons 'age selector value exported' '33' $exportJson.demographics.age 'JSON demographics.age'
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
    Add-Comparison $comparisons 'prior big-red-button experience not repeated in condition 2' $false ($runLogText -match 'BRB_PRIOR_BUTTON_EXPERIENCE_SHOWN .*condition=2') 'logcat'
    Add-Comparison $comparisons 'prior big-red-button experience controller replay observed' $true ($runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=right' -and $runLogText -match 'BRB_CONTROLLER_DIRECTION stage=pre_button_experience direction=right answer=yes' -and $runLogText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pre_button_experience submitted=true') 'logcat'
    Add-Comparison $comparisons 'condition 1 IPQ history narration cue observed' $true (
        $runLogText -match 'BRB_IPQ_HISTORY_NARRATION_CUE condition=1 .*cue=ipq_history_part1 .*audioId=aud_0320 .*blocking=false' -and
        $runLogText -match "BRB_SFX_PLAY cue=ipq_history_part1 audioId=aud_0320 asset=localized/$expectedIpqLocaleSegment/aud_0320_ipq_history_part1__.*\.mp3 language=$expectedIpqLanguageCode durationMs="
    ) 'logcat'
    Add-Comparison $comparisons 'condition 2 IPQ history narration cue observed' $true (
        $runLogText -match 'BRB_IPQ_HISTORY_NARRATION_CUE condition=2 .*cue=ipq_history_part2 .*audioId=aud_0330 .*blocking=false' -and
        $runLogText -match "BRB_SFX_PLAY cue=ipq_history_part2 audioId=aud_0330 asset=localized/$expectedIpqLocaleSegment/aud_0330_ipq_history_part2__.*\.mp3 language=$expectedIpqLanguageCode durationMs="
    ) 'logcat'
    Add-Comparison $comparisons 'final end confirmation JSON rating' 10 $exportJson.finalEndConfirmation.rating1To10 'JSON finalEndConfirmation.rating1To10'
    Add-Comparison $comparisons 'final end confirmation JSON immediate end' $true $exportJson.finalEndConfirmation.immediateEnd 'JSON finalEndConfirmation.immediateEnd'
    Add-Comparison $comparisons 'final end confirmation JSON extra press count' 0 $exportJson.finalEndConfirmation.extraPressCount 'JSON finalEndConfirmation.extraPressCount'
    Add-Comparison $comparisons 'final end confirmation summary rating' 10 $row.final_end_confirmation_rating_1_10 'summary CSV'
    Add-Comparison $comparisons 'final end confirmation summary immediate end' 'true' $row.final_end_confirmation_immediate_end 'summary CSV'
    Add-Comparison $comparisons 'final extra button press summary count' 0 $row.final_extra_button_press_count 'summary CSV'
    Add-Comparison $comparisons 'final extra button press CSV exists' $true ($null -ne $finalExtraPressFile) 'ExperimentResults final extra button presses CSV'
    Add-Comparison $comparisons 'final extra button press CSV rows' 0 @($finalExtraPressCsv).Count 'ExperimentResults final extra button presses CSV'
    Add-Comparison $comparisons 'final end confirmation options ready before replay' $true ($runLogText -match 'BRB_FINAL_END_CONFIRMATION_OPTIONS_READY .*optionsVisible=true' -and $runLogText -match 'BRB_FINAL_END_CONFIRMATION_VALIDATION_WAIT .*reason=question_audio_active') 'logcat'
    Add-Comparison $comparisons 'final end confirmation controller replay observed' $true ($runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=0 stage=final_end_confirmation direction=right' -and $runLogText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=0 stage=final_end_confirmation submitted=true' -and $runLogText -match 'BRB_FINAL_END_CONFIRMATION_SAVED rating=10 immediateEnd=true') 'logcat'

    Add-Comparison $comparisons 'condition 1 emulated button count' 2 $c1.buttonPressCount 'JSON condition 1 buttonPressCount'
    Add-Comparison $comparisons 'condition 2 emulated button count' 2 $c2.buttonPressCount 'JSON condition 2 buttonPressCount'
    Add-Comparison $comparisons 'feedback assignment exported' $true ($exportJson.ecgProtocol.assignmentOrder -in @('real_then_simulated', 'simulated_then_real')) 'JSON ecgProtocol.assignmentOrder'
    Add-Comparison $comparisons 'condition 1 feedback source exported' $true ($c1.feedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) 'JSON condition 1 feedbackSource'
    Add-Comparison $comparisons 'condition 2 feedback source exported' $true ($c2.feedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) 'JSON condition 2 feedbackSource'
    Add-Comparison $comparisons 'condition 1 physiology source exported' 'real_polar_h10' $c1.physiologySource 'JSON condition 1 physiologySource'
    Add-Comparison $comparisons 'condition 2 physiology source exported' 'real_polar_h10' $c2.physiologySource 'JSON condition 2 physiologySource'
    Add-Comparison $comparisons 'feedback sources counterbalanced complement' $true (($null -ne $simulatedCondition) -and ($null -ne $realCondition) -and ($simulatedConditionNumber -ne $realConditionNumber)) 'JSON condition feedbackSource values'
    Add-Comparison $comparisons 'feedback assignment order matches condition feedback sources' $true $assignmentMatchesSources 'JSON ecgProtocol.assignmentOrder and condition feedbackSource values'
    Add-Comparison $comparisons 'ECG blink event CSV readable' $true ($null -ne $ecgBlinkCsv) 'ExperimentResults ECG blink-events CSV'
    Add-Comparison $comparisons 'ECG time-series CSV readable' $true (($null -ne $ecgTimeSeriesFile) -and $ecgTimeSeriesHeader.Contains('session_id,participant_id,condition_number')) 'ExperimentResults ECG time-series CSV'
    Add-Comparison $comparisons 'Polar RR event CSV readable' $true ($null -ne $polarRrFile) 'ExperimentResults Polar RR events CSV'
    Add-Comparison $comparisons 'simulated ECG blink count exported' $true (($null -ne $simulatedCondition) -and ([int]$simulatedCondition.ecgBlinkCount -gt 0)) 'JSON simulated condition ecgBlinkCount'
    Add-Comparison $comparisons 'simulated ECG blink rows match JSON count' ([int]$simulatedCondition.ecgBlinkCount) @($simulatedBlinkRows).Count 'ExperimentResults ECG blink-events CSV'
    Add-Comparison $comparisons 'simulated ECG blink runtime marker observed' $true ($runLogText -match "BRB_ECG_BLINK condition=$simulatedConditionNumber .*source=simulated_neurokit2") 'logcat'
    Add-Comparison $comparisons 'simulated heartbeat visual flash observed' $true ($runLogText -match "BRB_HEARTBEAT_FLASH condition=$simulatedConditionNumber source=simulated_neurokit2") 'logcat'
    Add-Comparison $comparisons 'simulated feedback excluded from real ECG time-series' 0 @($simulatedTimeSeriesRows).Count 'ExperimentResults ECG time-series CSV'
    Add-Comparison $comparisons 'press elapsed_ns exported' @($pressCsv).Count $pressRowsWithElapsedNs.Count 'ExperimentResults press-events CSV'
    Add-Comparison $comparisons 'press alignment columns exported' $true $pressAlignmentColumnsPresent 'ExperimentResults press-events CSV'
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
    Add-Comparison $comparisons 'condition 1 redness carried VAS' 60 $c1.pictographic.rednessCarriedForwardVas0To100 'closest analogue carried through VAS-to-Likert conversion'
    Add-Comparison $comparisons 'condition 1 redness carried Likert' 5 $c1.pictographic.rednessCarriedForwardLikert1To7 'closest analogue carried through VAS-to-Likert conversion'
    Add-Comparison $comparisons 'condition 1 redness post-conversion edited' $false $c1.pictographic.rednessPostConversionEdited 'no post-conversion edit in fast replay'
    Add-Comparison $comparisons 'condition 1 redness post-conversion edit scale' 'none' $c1.pictographic.rednessPostConversionEditScale 'no post-conversion edit in fast replay'
    Add-Comparison $comparisons 'condition 1 redness changed after conversion' $false $c1.pictographic.rednessChangedAfterConversion 'final answer stays with closest analogue'
    Add-Comparison $comparisons 'condition 1 redness final matches carried' $true $c1.pictographic.rednessFinalMatchesCarriedForward 'final answer stays with closest analogue'
    Add-Comparison $comparisons 'condition 2 redness VAS' 66 $c2.pictographic.rednessVas0To100 'fast replay Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness Likert' 5 $c2.pictographic.rednessLikert1To7 'fast replay Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness order' 'likert_then_vas' $c2.pictographic.rednessScaleOrder 'JSON pictographic.rednessScaleOrder'
    Add-Comparison $comparisons 'condition 2 redness carried VAS' 66 $c2.pictographic.rednessCarriedForwardVas0To100 'closest analogue carried through Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness carried Likert' 5 $c2.pictographic.rednessCarriedForwardLikert1To7 'closest analogue carried through Likert-to-VAS conversion'
    Add-Comparison $comparisons 'condition 2 redness post-conversion edited' $false $c2.pictographic.rednessPostConversionEdited 'no post-conversion edit in fast replay'
    Add-Comparison $comparisons 'condition 2 redness post-conversion edit scale' 'none' $c2.pictographic.rednessPostConversionEditScale 'no post-conversion edit in fast replay'
    Add-Comparison $comparisons 'condition 2 redness changed after conversion' $false $c2.pictographic.rednessChangedAfterConversion 'final answer stays with closest analogue'
    Add-Comparison $comparisons 'condition 2 redness final matches carried' $true $c2.pictographic.rednessFinalMatchesCarriedForward 'final answer stays with closest analogue'
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
    Add-Comparison $comparisons 'agent integration protocol native adaptation' $true (
        $exportJson.agentIntegrationProtocol.schema -eq 'bigredbutton.agent_integration.v1' -and
        $exportJson.agentIntegrationProtocol.sourceBrief -eq 'New-Agent-Integration-Brief.md' -and
        $exportJson.agentIntegrationProtocol.adaptation -eq 'native_meta_spatial_sdk_in_process' -and
        $exportJson.agentIntegrationProtocol.unityDependency -eq $false -and
        $exportJson.agentIntegrationProtocol.rustyXrBrokerRequired -eq $false -and
        $exportJson.agentIntegrationProtocol.localHeadsetExportsOnly -eq $true -and
        $exportJson.agentIntegrationProtocol.exportMirror -eq 'ExperimentResults'
    ) 'JSON agentIntegrationProtocol'
    Add-Comparison $comparisons 'agent integration questionnaire route' $true (
        $exportJson.agentIntegrationProtocol.questionnaire.transport -eq 'in_process_spatial_panel' -and
        $exportJson.agentIntegrationProtocol.questionnaire.productCommunication -eq 'app_internal' -and
        $exportJson.agentIntegrationProtocol.questionnaire.standalonePanelPackage -eq 'io.github.mesmerprism.questquestionnaire.panel' -and
        $exportJson.agentIntegrationProtocol.questionnaire.standalonePanelAdopted -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractCompatibleIfAdopted -eq $true -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.schema -eq 'quest.questionnaire.v1' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.launchIntent -eq 'explicit' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.requestJsonExtra -eq 'request_json' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.resultUriScheme -eq 'content' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.resultUriOwner -eq 'caller' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.writeUriGrant -eq $true -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.completionCallback -eq 'one_shot_immutable_broadcast_pending_intent' -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.answersOnlyWrittenToCallerUri -eq $true -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.callerReadsOwnResultUri -eq $true -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.adbProductCommunication -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.publicSharedStorageExchange -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.mediaStoreExchange -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.fileUriExchange -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.packageKillReturnFlow -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.overlayReturnFlow -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.queryAllPackages -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.systemAlertWindow -eq $false -and
        $exportJson.agentIntegrationProtocol.questionnaire.answersInLogs -eq $false
    ) 'JSON agentIntegrationProtocol.questionnaire'
    Add-Comparison $comparisons 'agent integration direct routes' $true (
        $exportJson.agentIntegrationProtocol.directPolar.enabled -eq $true -and
        $exportJson.agentIntegrationProtocol.directPolar.transport -eq 'native_ble_pmd_ecg_rr' -and
        $exportJson.agentIntegrationProtocol.directPolar.recordsBothConditions -eq $true -and
        $exportJson.agentIntegrationProtocol.directPolar.brokerRequired -eq $false -and
        $exportJson.agentIntegrationProtocol.directPolar.heartbeatBlinkRoute -eq 'HeartbeatPulseDriver' -and
        $exportJson.agentIntegrationProtocol.directLsl.enabled -eq $false -and
        $exportJson.agentIntegrationProtocol.directLsl.role -eq 'diagnostic_only' -and
        $exportJson.agentIntegrationProtocol.directLsl.streamName -eq 'HRV_Biofeedback' -and
        $exportJson.agentIntegrationProtocol.directLsl.streamType -eq 'HRV' -and
        $exportJson.agentIntegrationProtocol.directLsl.channelIndex -eq 0 -and
        [math]::Abs(([double]$exportJson.agentIntegrationProtocol.directLsl.triggerThreshold01) - 0.5) -lt 0.0001 -and
        $exportJson.agentIntegrationProtocol.directLsl.minimumTriggerIntervalMs -eq 250 -and
        $exportJson.agentIntegrationProtocol.directLsl.nativeLibraryPackaged -eq $false -and
        $exportJson.agentIntegrationProtocol.directLsl.jniEnabled -eq $false -and
        $exportJson.agentIntegrationProtocol.directLsl.drivesButtonPresses -eq $false -and
        $exportJson.agentIntegrationProtocol.directLsl.finalPressProofAllowed -eq $false
    ) 'JSON agentIntegrationProtocol direct routes'
    Add-Comparison $comparisons 'agent integration button/final gate route' $true (
        $exportJson.agentIntegrationProtocol.buttonRoutes.finalParticipantPressProof -eq 'controller_contact' -and
        $exportJson.agentIntegrationProtocol.buttonRoutes.handContactSupplemental -eq $true -and
        $exportJson.agentIntegrationProtocol.buttonRoutes.heartbeatBlinkRoute -eq 'HeartbeatPulseDriver' -and
        $exportJson.agentIntegrationProtocol.buttonRoutes.stableButtonModelDuringBlink -eq $true -and
        $exportJson.agentIntegrationProtocol.buttonRoutes.externalSignalPressesSatisfyFinalGate -eq $false -and
        @($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'adb_relaunch' -and
        @($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'public_shared_storage_exchange' -and
        @($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'file_uri' -and
        @($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'query_all_packages' -and
        @($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'system_alert_window'
    ) 'JSON agentIntegrationProtocol button routes'
    Add-Comparison $comparisons 'questionnaire protocol schema' 'bigredbutton.questionnaire_flow.v1' $exportJson.questionnaireProtocol.schema 'JSON questionnaireProtocol.schema'
    Add-Comparison $comparisons 'questionnaire protocol transport' 'in_process_spatial_panel' $exportJson.questionnaireProtocol.transport 'JSON questionnaireProtocol.transport'
    Add-Comparison $comparisons 'questionnaire protocol product communication' 'app_internal' $exportJson.questionnaireProtocol.productCommunication 'JSON questionnaireProtocol.productCommunication'
    Add-Comparison $comparisons 'questionnaire protocol stage sequence' $true (
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'consent_demographics' -and
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'prior_big_red_button_experience' -and
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'post_condition_1_pictographic' -and
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'post_condition_2_lost_opportunity' -and
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'final_end_confirmation' -and
        @($exportJson.questionnaireProtocol.stageSequence) -contains 'complete_export_summary'
    ) 'JSON questionnaireProtocol.stageSequence'
    Add-Comparison $comparisons 'questionnaire protocol shortcut modes' $true (
        @($exportJson.questionnaireProtocol.validationShortcutModes) -contains 'keyevent_validation' -and
        @($exportJson.questionnaireProtocol.validationShortcutModes) -contains 'physical_press_validation'
    ) 'JSON questionnaireProtocol.validationShortcutModes'
    Add-Comparison $comparisons 'questionnaire product path exclusions' $true (
        $exportJson.questionnaireProtocol.adbProductCommunication -eq $false -and
        $exportJson.questionnaireProtocol.publicSharedStorageExchange -eq $false -and
        $exportJson.questionnaireProtocol.overlayReturnFlow -eq $false -and
        $exportJson.questionnaireProtocol.packageKillReturnFlow -eq $false
    ) 'JSON questionnaireProtocol product path exclusions'
    Add-Comparison $comparisons 'external signal protocol disabled diagnostic' $true (
        $exportJson.externalSignalProtocol.schema -eq 'bigredbutton.external_signal.v1' -and
        $exportJson.externalSignalProtocol.enabled -eq $false -and
        $exportJson.externalSignalProtocol.role -eq 'diagnostic_only' -and
        $exportJson.externalSignalProtocol.contaminatesPressCounts -eq $false -and
        $exportJson.externalSignalProtocol.streamName -eq 'HRV_Biofeedback' -and
        $exportJson.externalSignalProtocol.streamType -eq 'HRV' -and
        $exportJson.externalSignalProtocol.channelIndex -eq 0 -and
        [math]::Abs(([double]$exportJson.externalSignalProtocol.triggerThreshold01) - 0.5) -lt 0.0001 -and
        $exportJson.externalSignalProtocol.triggerOnRisingEdgeOnly -eq $true -and
        $exportJson.externalSignalProtocol.minimumTriggerIntervalMs -eq 250 -and
        $exportJson.externalSignalProtocol.nativeLibraryPackaged -eq $false -and
        $exportJson.externalSignalProtocol.jniEnabled -eq $false -and
        $exportJson.externalSignalProtocol.drivesHeartbeatBlink -eq $false -and
        $exportJson.externalSignalProtocol.drivesButtonPresses -eq $false
    ) 'JSON externalSignalProtocol'
    Add-Comparison $comparisons 'questionnaire lifecycle markers observed' $true (
        $runLogText -match 'BRB_QUESTIONNAIRE_CONTRACT schema=bigredbutton.questionnaire_flow.v1 .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=consent_demographics .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=consent_demographics .*nextStageId=prior_big_red_button_experience .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_1_pictographic .*condition=1 .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=post_condition_2_lost_opportunity .*nextStageId=final_end_confirmation .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=complete_export_summary .*answersLogged=false'
    ) 'logcat'
    Add-Comparison $comparisons 'condition 2 post-condition questionnaire chain observed' $true (
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=condition_2 .*nextStageId=post_condition_2_pictographic .*answersLogged=false' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_pictographic .*condition=2 .*answersLogged=false' -and
        $runLogText -match 'BRB_PICTOGRAPHIC_SAVED condition=2' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_presence_questionnaire .*condition=2 .*answersLogged=false' -and
        $runLogText -match 'BRB_IPQ_SAVED condition=2' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_OPEN stageId=post_condition_2_lost_opportunity .*condition=2 .*answersLogged=false' -and
        $runLogText -match 'BRB_LOST_OPPORTUNITY_SAVED condition=2' -and
        $runLogText -match 'BRB_QUESTIONNAIRE_STAGE_COMPLETE stageId=post_condition_2_lost_opportunity .*nextStageId=final_end_confirmation .*answersLogged=false'
    ) 'logcat'
    Add-Comparison $comparisons 'external signal diagnostic marker observed' $true (
        $runLogText -match 'BRB_LSL status=disabled .*role=diagnostic_only .*streamName=HRV_Biofeedback .*streamType=HRV .*drivesButtonPresses=false'
    ) 'logcat'
    Add-Comparison $comparisons 'agent integration marker observed' $true (
        $runLogText -match 'BRB_AGENT_INTEGRATION_CONTRACT schema=bigredbutton.agent_integration.v1 .*sourceBrief=New-Agent-Integration-Brief.md .*unityDependency=false .*rustyXrBrokerRequired=false .*directPolarPmdActive=true .*directLslEnabled=false .*finalPressProof=controller_contact .*answersLogged=false'
    ) 'logcat'
    Add-Comparison $comparisons 'app-owned name keyboard observed' $true ($runLogText -match 'BRB_NAME_APP_KEYBOARD_FOCUS field=name .*platformControl=AppOwnedKeyboard') 'logcat'
    Add-Comparison $comparisons 'app-owned name text mode observed' $true ($runLogText -match 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*keyboardMode=text .*keyboardType=Text .*platformControl=AppOwnedKeyboard') 'logcat'
    Add-Comparison $comparisons 'age slider contract observed' $true ($runLogText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_CONTRACT field=age .*min=0 .*max=100 .*platformControl=ComposeSlider') 'logcat'
    Add-Comparison $comparisons 'app-owned name pop-out keyboard panel contract observed' $true (
        $runLogText -match 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*closeToParticipant=left_of_questionnaire_near_user' -and
        $runLogText -match 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false'
    ) 'logcat'
    Add-Comparison $comparisons 'age is not an IME target' $true (-not ($runLogText -match 'BRB_SOFT_KEYBOARD_REQUEST reason=field_age')) 'logcat'
    Add-Comparison $comparisons 'startup app-owned name keyboard uses text mode' $true ($runLogText -match 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*keyboardMode=text') 'logcat'
    Add-Comparison $comparisons 'VAS spontaneous remark cue observed' $true (
        $runLogText -match 'BRB_SPONTANEOUS_REMARK_CUE kind=vas .*scale=pictographic_.*audioId=aud_07.*noOverlap=true .*randomOrder=true'
    ) 'logcat'
    Add-Comparison $comparisons 'VAS spontaneous remark cooldown observed' $true (
        $runLogText -match 'BRB_SPONTANEOUS_REMARK_COOLDOWN kind=vas .*audioId=aud_07.*cooldownMs=\d+ .*minMs=5000 .*maxMs=10000 .*reason='
    ) 'logcat'
    Add-Comparison $comparisons 'redness conversion cue observed' $true (
        $runLogText -match 'BRB_REDNESS_SCALE_CONVERSION condition=1 .*from=vas to=likert' -and
        $runLogText -match 'BRB_REDNESS_SCALE_CONVERSION condition=2 .*from=likert to=vas' -and
        $runLogText -match 'BRB_REDNESS_SCALE_CONVERSION_CUE order=vas_then_likert .*cue=first_questionnaire_change .*placeholder=false .*microTimeline=.*supervisor_ping.*seven_boxes_assemble.*validationShortcut=true' -and
        $runLogText -match 'BRB_REDNESS_SCALE_CONVERSION_CUE order=likert_then_vas .*cue=second_questionnaire_change_excuse .*placeholder=false .*microTimeline=.*professional_warning.*boxes_erased.*validationShortcut=true'
    ) 'logcat'
    Add-Comparison $comparisons 'panel-exit keyboard hide before condition 1 observed' $true ($runLogText -match 'BRB_SOFT_KEYBOARD_HIDE reason=before_condition_1') 'logcat'
    Add-Comparison $comparisons 'panel-exit keyboard hide before condition 2 observed' $true ($runLogText -match 'BRB_SOFT_KEYBOARD_HIDE reason=before_condition_2') 'logcat'
    Add-Comparison $comparisons 'directional replay observed' $true ($runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pictographic direction=left') 'logcat'
    Add-Comparison $comparisons 'enter submit replay observed' $true ($runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pre_button_experience direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=pictographic direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=presence_questionnaire direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=1 stage=lost_opportunity direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=pictographic direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=presence_questionnaire direction=enter' -and $runLogText -match 'BRB_KEYEVENT_REPLAY_STEP condition=2 stage=lost_opportunity direction=enter') 'logcat'
    Add-Comparison $comparisons 'controller submit replay observed' $true ($runLogText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=1 stage=pictographic submitted=true' -and $runLogText -match 'BRB_CONTROLLER_SUBMIT_REPLAY condition=2 stage=lost_opportunity submitted=true') 'logcat'
    Add-Comparison $comparisons 'intro glitch observed' $true ($runLogText -match 'BRB_PANEL_GLITCH state=start mode=intro') 'logcat'
    Add-Comparison $comparisons 'outro glitch observed' $true ($runLogText -match 'BRB_PANEL_GLITCH state=start mode=outro') 'logcat'
    Add-Comparison $comparisons 'SideQuest results folder marker observed' $true ($runLogText -match 'BRB_EXPERIMENT_RESULTS_FOLDER') 'logcat'

    $failed = @($comparisons | Where-Object { -not $_.pass })
    $summary = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
        serial = $Serial
        model = $model
        android = $android
        package = $package
        studyLanguageOverride = $StudyLanguage
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
        finalExtraButtonPressesCsv = if ($null -ne $finalExtraPressFile) { $finalExtraPressFile.FullName } else { $null }
        ecgBlinkEventsCsv = $ecgBlinkFile.FullName
        ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
        exportMirrorComparison = $mirrorComparisonPath
        exportMirrorMatched = ($mirrorComparison.status -eq 'pass')
        exportMirrorFileCount = $mirrorComparison.primaryFileCount
        comparisons = $comparisons
        note = 'Fast directional questionnaire validation. It shortcuts instruction-audio waiting, replays bounded up/down/left/right/enter-equivalent commands through the app controller-direction/submit handlers, validates app-owned Name keyboard evidence, Age slider evidence, randomized VAS spontaneous remark cue/cooldown evidence, redness VAS/Likert conversion markers, panel-exit hide markers, glitch markers, questionnaire protocol metadata, and disabled diagnostic-only external signal protocol metadata, pulls both export folders, and compares exported values against expected outcomes. Raw ADB Name keyevent transport is validated separately by run-quest-demographics-direct-keyboard-validation.ps1. This is not physical controller-contact evidence.'
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
