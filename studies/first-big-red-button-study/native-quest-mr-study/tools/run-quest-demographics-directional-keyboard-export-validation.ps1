[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$TimeoutSeconds = 140,
    [switch]$SkipInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'export-session-layout.ps1')
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
$outDir = Join-Path $projectRoot "artifacts\qdk\$runId"
$deviceExportDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"
$deviceResultsDir = "/sdcard/Android/data/$package/files/ExperimentResults"
$pullDir = Join-Path $outDir 'p'
$primaryPullDir = Join-Path $pullDir 'b'
$resultsPullDir = Join-Path $pullDir 'e'
$remoteScreenshot = '/sdcard/Download/brb_demographics_directional_keyboard.png'

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
New-Item -ItemType Directory -Force -Path $primaryPullDir | Out-Null
New-Item -ItemType Directory -Force -Path $resultsPullDir | Out-Null
$comparisons = New-Object System.Collections.Generic.List[object]

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Get-LogText {
    return (Invoke-Adb logcat -d -v time | Out-String)
}

function Save-FilteredLog {
    param([string]$Name)
    $path = Join-Path $outDir "$Name-logcat-filtered.txt"
    (Get-LogText) -split "`r?`n" |
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
        Start-Sleep -Milliseconds 300
        $log = Get-LogText
        if ($log -match 'FATAL EXCEPTION|E/AndroidRuntime') {
            $path = Save-FilteredLog "failure-$($Description -replace '[^A-Za-z0-9_-]', '_')"
            throw "Fatal runtime marker while waiting for $Description. See $path"
        }
        if ($log -match $Pattern) {
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
    $pass = "$Expected" -eq "$Observed"
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

function Send-KeyCode {
    param([int]$KeyCode, [string]$Name)
    Invoke-Adb shell input keyevent $KeyCode | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "adb keyevent $Name failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Milliseconds 220
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

$keyboardRows = @(
    @('Q','W','E','R','T','Y','U','I','O','P'),
    @('A','S','D','F','G','H','J','K','L'),
    @('Z','X','C','V','B','N','M'),
    @('Clear','Space','Back','Next')
)

function Map-Column {
    param([int]$Column, [int]$FromSize, [int]$ToSize)
    if ($ToSize -le 1 -or $FromSize -le 1) {
        return 0
    }
    $ratio = [double]$Column / [double]($FromSize - 1)
    return [Math]::Min($ToSize - 1, [Math]::Max(0, [int][Math]::Floor($ratio * [double]($ToSize - 1))))
}

function Get-Neighbors {
    param([int]$Row, [int]$Column)
    $rowSize = $keyboardRows[$Row].Count
    $neighbors = @()
    if ($Column -gt 0) {
        $neighbors += [pscustomobject]@{ row = $Row; column = $Column - 1; direction = 'left' }
    }
    if ($Column -lt ($rowSize - 1)) {
        $neighbors += [pscustomobject]@{ row = $Row; column = $Column + 1; direction = 'right' }
    }
    if ($Row -gt 0) {
        $newRow = $Row - 1
        $neighbors += [pscustomobject]@{
            row = $newRow
            column = Map-Column $Column $rowSize $keyboardRows[$newRow].Count
            direction = 'up'
        }
    }
    if ($Row -lt ($keyboardRows.Count - 1)) {
        $newRow = $Row + 1
        $neighbors += [pscustomobject]@{
            row = $newRow
            column = Map-Column $Column $rowSize $keyboardRows[$newRow].Count
            direction = 'down'
        }
    }
    return $neighbors
}

function Find-KeyPosition {
    param([string]$Label)
    for ($row = 0; $row -lt $keyboardRows.Count; $row += 1) {
        for ($column = 0; $column -lt $keyboardRows[$row].Count; $column += 1) {
            if ($keyboardRows[$row][$column] -eq $Label) {
                return [pscustomobject]@{ row = $row; column = $column }
            }
        }
    }
    throw "Keyboard label '$Label' not found"
}

function Find-Path {
    param(
        [int]$StartRow,
        [int]$StartColumn,
        [int]$TargetRow,
        [int]$TargetColumn
    )
    $startKey = "$StartRow,$StartColumn"
    $targetKey = "$TargetRow,$TargetColumn"
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue([pscustomobject]@{ row = $StartRow; column = $StartColumn; path = @() })
    $visited = @{ $startKey = $true }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if ("$($current.row),$($current.column)" -eq $targetKey) {
            return @($current.path)
        }
        foreach ($neighbor in Get-Neighbors $current.row $current.column) {
            $key = "$($neighbor.row),$($neighbor.column)"
            if ($visited.ContainsKey($key)) {
                continue
            }
            $visited[$key] = $true
            $queue.Enqueue([pscustomobject]@{
                row = $neighbor.row
                column = $neighbor.column
                path = @($current.path) + @($neighbor.direction)
            })
        }
    }
    throw "No path from $startKey to $targetKey"
}

function Press-KeyboardLabel {
    param(
        [string]$Label,
        [ref]$CursorRow,
        [ref]$CursorColumn
    )
    $target = Find-KeyPosition $Label
    $path = Find-Path $CursorRow.Value $CursorColumn.Value $target.row $target.column
    foreach ($direction in $path) {
        Send-Direction $direction
    }
    Send-Direction 'enter'
    $CursorRow.Value = $target.row
    $CursorColumn.Value = $target.column
    Add-Content -LiteralPath (Join-Path $outDir 'directional-keyboard-protocol.txt') -Value (($path + @('enter')) -join ',')
}

function Save-Screenshot {
    param([string]$LocalName)
    Invoke-Adb shell screencap -p $remoteScreenshot | Out-Null
    Invoke-Adb pull $remoteScreenshot (Join-Path $outDir $LocalName) |
        Tee-Object -FilePath (Join-Path $outDir "screenshot-$LocalName.pull.txt") |
        Out-Host
    Invoke-Adb shell rm $remoteScreenshot | Out-Null
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

function Get-ShortExportFileName {
    param([string]$FileName)
    if ($FileName -eq 'session-index.jsonl') {
        return $FileName
    }
    $knownSuffixes = @(
        '_summary.csv',
        '_press_events.csv',
        '_ecg_blink_events.csv',
        '_ecg_detector_events.csv',
        '_ecg_timeseries.csv',
        '_external_signal_samples.csv',
        '_final_extra_button_presses.csv',
        '_polar_rr_events.csv'
    )
    foreach ($suffix in $knownSuffixes) {
        if ($FileName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) {
            return "brb_first_study_qdk$suffix"
        }
    }
    if ($FileName -match '^brb_first_study_.*\.json$') {
        return 'brb_first_study_qdk.json'
    }
    return $FileName
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
    $manifestRows = New-Object System.Collections.Generic.List[object]
    $pathMap = @{}
    foreach ($remoteFile in $files) {
        $relative = "$remoteFile"
        if ($relative.StartsWith($DeviceDir, [StringComparison]::Ordinal)) {
            $relative = $relative.Substring($DeviceDir.Length).TrimStart('/')
        } else {
            $relative = Split-Path -Leaf $relative
        }
        $relativeParts = @($relative -split '/')
        $localRelative =
            if ($relativeParts.Count -gt 1) {
                (($relativeParts[0..($relativeParts.Count - 2)] + (Get-BrbShortExportFileName -FileName $relativeParts[-1] -Prefix 'brb_first_study_qdk')) -join '/')
            } else {
                Get-BrbShortExportFileName -FileName $relativeParts[-1] -Prefix 'brb_first_study_qdk'
            }
        $pathMap[$relative] = $localRelative
        $localPath = Join-Path $LocalDir ($localRelative -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $localPath) | Out-Null
        $tempPath = Join-Path ([IO.Path]::GetTempPath()) ("brb-qdk-" + [IO.Path]::GetRandomFileName())
        try {
            Invoke-Adb pull "$remoteFile" $tempPath |
                Tee-Object -Append -FilePath (Join-Path $outDir 'pull.txt') |
                Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to pull $remoteFile"
            }
            Move-Item -LiteralPath $tempPath -Destination $localPath -Force
            $manifestRows.Add([pscustomobject]@{
                deviceDir = $DeviceDir
                deviceName = $remoteFile
                localName = $localRelative
            }) | Out-Null
        } finally {
            if (Test-Path -LiteralPath $tempPath) {
                Remove-Item -LiteralPath $tempPath -Force
            }
        }
    }
    Update-BrbPulledExportMetadata -LocalDir $LocalDir -PathMap $pathMap
    $manifestName = 'pull-manifest-' + (Split-Path -Leaf $LocalDir) + '.csv'
    $manifestRows | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outDir $manifestName)
}

function Compare-ExportMirror {
    param([string]$PrimaryDir, [string]$MirrorDir, [string]$OutPath)
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
            primarySizeBytes = $primary.Length
            mirrorSizeBytes = if ($null -ne $mirror) { $mirror.Length } else { $null }
            primarySha256 = $primaryHash
            mirrorSha256 = $mirrorHash
            matched = ($null -ne $mirror -and $primary.Length -eq $mirror.Length -and $primaryHash -eq $mirrorHash)
        }) | Out-Null
    }
    $result = [pscustomobject]@{
        generatedAt = (Get-Date).ToString('o')
        status = if (@($rows | Where-Object { -not $_.matched }).Count -eq 0 -and $primaryFiles.Count -eq $mirrorFiles.Count) { 'pass' } else { 'fail' }
        primaryDir = $PrimaryDir
        mirrorDir = $MirrorDir
        primaryFileCount = $primaryFiles.Count
        mirrorFileCount = $mirrorFiles.Count
        files = $rows
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8
    if ($result.status -ne 'pass') {
        throw "Export mirror mismatch. See $OutPath"
    }
    return $result
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()
Write-Host "Quest demographics directional-keyboard export validation target: serial=$Serial model=$model android=$android"
Write-Host "This test uses only D-pad Up/Down/Left/Right plus Enter to press the visible app-owned pop-out Name keyboard, then validates the pulled local headset export."

try {
    if (-not $SkipInstall) {
        Write-Host "Installing $ApkPath"
        Write-Host "APK SHA-256: $apkSha256"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    }

    Invoke-Adb shell rm -rf $deviceExportDir $deviceResultsDir | Out-Null
    Invoke-Adb shell am force-stop $package | Out-Null
    Invoke-Adb logcat -c | Out-Null
    Invoke-Adb shell am start -n $activity --ez brb.keyeventValidation true --ez brb.demographicsKeyboardValidation true --es brb.demographicsKeyboardValidationSession $runId |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    Wait-LogPattern 'BRB_STUDY_CREATED .*keyeventValidation=true .*demographicsKeyboardValidation=true' 'combined keyevent/demographics validation launch'
    Wait-LogPattern "BRB_DEMOGRAPHICS_VALIDATION_SESSION session=$logRunId accepted=true state=start" 'validation session marker'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_CONTRACT field=name .*platformControl=AppOwnedKeyboard .*keyboardPanel=keyboard_panel .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*noSystemImeDependency=true' 'app-owned pop-out Name keyboard contract'
    Wait-LogPattern 'BRB_PANEL_GLITCH state=end mode=intro trigger=demographics' 'stable demographics panel'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_FOCUS field=name accepted=true .*platformControl=AppOwnedKeyboard' 'Name keyboard focus'
    Wait-LogPattern 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true' 'Name left-side pop-out keyboard panel layout'
    $nameFocusLogPath = Save-FilteredLog 'name-focus'
    $nameFocusLogText = Get-Content -Raw -LiteralPath $nameFocusLogPath

    $cursorRow = [ref]3
    $cursorColumn = [ref]3
    $targetKeys = @('G','E','O','R','G','E','X','Back','Space','F','E','J','E','R')
    foreach ($label in $targetKeys) {
        Press-KeyboardLabel $label $cursorRow $cursorColumn
    }
    Wait-LogPattern 'BRB_DEMOGRAPHICS_NAME_BACKSPACE accepted=true source=hardware_key_event length=6 .*platformControl=AppOwnedKeyboard' 'Back key pressed through directional keyboard'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name keyboardMode=text value=george_fejer length=12 .*source=hardware_key_event .*validation=true' 'directional keyboard produced George Fejer'
    Save-Screenshot 'demographics-directional-keyboard-name-entry.png'
    Press-KeyboardLabel 'Next' $cursorRow $cursorColumn
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_FOCUS field=age accepted=true .*source=hardware_key_event_name_next' 'Next moved to Age slider'

    1..3 | ForEach-Object { Send-Direction 'up' }
    1..4 | ForEach-Object { Send-Direction 'right' }
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=activity_key_event value=34 .*platformControl=ComposeSlider' 'Age set to 34 with D-pad'
    Send-Direction 'enter'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_AGE_SLIDER_DONE source=activity_key_event value=34' 'Age confirmed with Enter'
    Wait-LogPattern 'BRB_SPONTANEOUS_REMARK_CUE kind=age scale=demographics_age value=34 bucket=age .*audioId=aud_0700 .*noOverlap=true' 'soft age privacy spontaneous remark cue'
    Save-Screenshot 'demographics-directional-keyboard-after-age.png'
    $nameEntryLogPath = Save-FilteredLog 'name-entry'
    $nameEntryLogText = Get-Content -Raw -LiteralPath $nameEntryLogPath

    Invoke-DemographicsValidationCommand 'select_handedness_right'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_HANDEDNESS_SELECTED accepted=true value=right .*blocking=true' 'handedness selection accepted through runtime path'
    Wait-LogPattern 'BRB_HANDEDNESS_NARRATION_CUE cue=handedness_controller_selection audioId=aud_0190 asset=localized/(en_us|ja_jp)/aud_0190_handedness_controller_selection__.*\.mp3 .*blocking=true' 'handedness narration cue started'
    Wait-LogPattern 'BRB_SFX_PLAY cue=handedness_controller_selection audioId=aud_0190 .*durationMs=[0-9]+' 'handedness narration MediaPlayer started'
    Wait-LogPattern 'BRB_HANDEDNESS_NARRATION_GATE state=clear .*reason=complete' 'handedness narration gate cleared after playback' 110
    $handednessLogPath = Save-FilteredLog 'handedness-narration'
    $handednessLogText = Get-Content -Raw -LiteralPath $handednessLogPath

    Invoke-DemographicsValidationCommand 'submit_current_demographics'
    Wait-LogPattern 'BRB_DEMOGRAPHICS_VALIDATION_SUBMIT_CURRENT accepted=true .*preservesKeyboardDraft=true' 'current keyboard drafts submitted'
    Wait-LogPattern 'BRB_PRIOR_BUTTON_EXPERIENCE_SAVED answer=yes' 'qkv prior-experience continuation'
    Wait-LogPattern 'BRB_EXPORT_COMPLETE' 'export complete'
    Wait-LogPattern 'BRB_EXPERIMENT_RESULTS_FOLDER' 'ExperimentResults mirror marker'

    $logPath = Save-FilteredLog 'final'
    $logText = Get-Content -Raw -LiteralPath $logPath
    Pull-DeviceFolder -DeviceDir $deviceExportDir -LocalDir $primaryPullDir
    Pull-DeviceFolder -DeviceDir $deviceResultsDir -LocalDir $resultsPullDir
    $mirrorComparisonPath = Join-Path $outDir 'export-mirror-comparison.json'
    $mirrorComparison = Compare-ExportMirror -PrimaryDir $primaryPullDir -MirrorDir $resultsPullDir -OutPath $mirrorComparisonPath

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
    $exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
    $summaryRow = @(Import-Csv -LiteralPath $summaryFile.FullName)[0]

    Add-Comparison 'directional keyboard nav markers observed' $true ($nameEntryLogText -match 'BRB_NAME_APP_KEYBOARD_NAV direction=' -and $nameEntryLogText -match 'BRB_NAME_APP_KEYBOARD_PRESS key=G .*source=hardware_key_event' -and $nameEntryLogText -match 'BRB_NAME_APP_KEYBOARD_PRESS key=Next .*action=next') $nameEntryLogPath
    Add-Comparison 'left-side pop-out keyboard panel appeared before directional entry' $true ($nameFocusLogText -match 'BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT .*placement=left_of_questionnaire_near_user .*radialReference=headset_center .*orientation=faces_headset .*keyboardPanel=keyboard_panel .*nonObstructing=true .*fovVisible=true .*presentation=pop_out_spatial_panel .*integratedInQuestionnaire=false .*appearsOnTextFieldFocus=true') $nameFocusLogPath
    Add-Comparison 'directional keyboard produced final Name before export' $true ($nameEntryLogText -match 'BRB_DEMOGRAPHICS_TEXT_VALUE field=name keyboardMode=text value=george_fejer length=12 .*source=hardware_key_event') $nameEntryLogPath
    Add-Comparison 'Age 34 produced before export' $true ($nameEntryLogText -match 'BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE source=activity_key_event value=34') $nameEntryLogPath
    Add-Comparison 'soft age privacy remark cue observed' $true ($nameEntryLogText -match 'BRB_SPONTANEOUS_REMARK_CUE kind=age scale=demographics_age value=34 bucket=age .*audioId=aud_0700 .*noOverlap=true') $nameEntryLogPath
    Add-Comparison 'handedness narration cue started and blocked input' $true ($handednessLogText -match 'BRB_HANDEDNESS_NARRATION_CUE .*audioId=aud_0190 .*blocking=true' -and $handednessLogText -match 'BRB_SFX_PLAY cue=handedness_controller_selection audioId=aud_0190 .*durationMs=[0-9]+') $handednessLogPath
    Add-Comparison 'handedness narration gate cleared before export' $true ($handednessLogText -match 'BRB_HANDEDNESS_NARRATION_GATE state=clear .*reason=complete') $handednessLogPath
    Add-Comparison 'JSON saved directional Name' 'George Fejer' $exportJson.demographics.name $jsonFile.FullName
    Add-Comparison 'JSON saved directional Age' '34' $exportJson.demographics.age $jsonFile.FullName
    Add-Comparison 'JSON participant ID marks directional validation' 'QDK_' ($exportJson.demographics.participantId.Substring(0, [Math]::Min(4, $exportJson.demographics.participantId.Length))) $jsonFile.FullName
    Add-Comparison 'summary CSV saved directional Name' 'George Fejer' $summaryRow.name $summaryFile.FullName
    Add-Comparison 'summary CSV saved directional Age' '34' $summaryRow.age $summaryFile.FullName
    Add-Comparison 'export mirror matched' 'pass' $mirrorComparison.status $mirrorComparisonPath
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
        directionProtocol = Join-Path $outDir 'directional-keyboard-protocol.txt'
        nameEntryScreenshot = Join-Path $outDir 'demographics-directional-keyboard-name-entry.png'
        ageScreenshot = Join-Path $outDir 'demographics-directional-keyboard-after-age.png'
        nameFocusLogcat = $nameFocusLogPath
        nameEntryLogcat = $nameEntryLogPath
        logcat = $logPath
        json = $jsonFile.FullName
        summaryCsv = $summaryFile.FullName
        exportMirrorComparison = $mirrorComparisonPath
        exportMirrorMatched = ($mirrorComparison.status -eq 'pass')
        typedName = 'George Fejer'
        typedAge = '34'
        inputTransport = 'dpad_up_down_left_right_enter_only_for_name_keyboard_and_age_slider'
        comparisons = $comparisons
        note = 'Full-loop headset validation: uses only D-pad Up/Down/Left/Right plus Enter to navigate the visible app-owned pop-out Name keyboard and Age slider, observes the one-shot soft age privacy remark, submits those current draft values, lets the APK write local headset exports, pulls ExperimentResults, and verifies JSON/CSV values.'
    }
    $summaryPath = Join-Path $outDir 'quest-demographics-directional-keyboard-export-validation-summary.json'
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
    $comparisons | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outDir 'expected-vs-observed.csv')

    if ($failed.Count -gt 0) {
        throw "Quest demographics directional-keyboard export validation failed: $($failed.Count) comparison(s) failed. Summary: $summaryPath"
    }
    Write-Host "PASS Quest demographics directional-keyboard export validation"
    Write-Host "Summary: $summaryPath"
} catch {
    $logPath = Save-FilteredLog 'failure'
    $summaryPath = Join-Path $outDir 'quest-demographics-directional-keyboard-export-validation-summary.json'
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
