[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$AdbPath = 'adb',
    [string]$ApkPath = '',
    [int]$WaitSeconds = 760,
    [int]$MinCondition1ControllerPresses = 1,
    [int]$MinCondition2ControllerPresses = 1,
    [int]$PolarPrecheckTimeoutSeconds = 120,
    [switch]$SkipPolarPrecheck,
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
$outDir = Join-Path $projectRoot "artifacts\qpv\$runId"
$exportPullDir = Join-Path $outDir 'pulled-exports'
$pulledExportRoot = Join-Path $exportPullDir 'BigRedButtonFirstStudyExports'
$pulledExperimentResultsRoot = Join-Path $exportPullDir 'ExperimentResults'
$deviceExportDir = "/sdcard/Android/data/$package/files/BigRedButtonFirstStudyExports"
$deviceExperimentResultsDir = "/sdcard/Android/data/$package/files/ExperimentResults"
$operatorChecklistPath = Join-Path $outDir 'operator-checklist.txt'
$polarPrecheckSummaryPath = $null
$script:polarPrecheckSummaryPath = $null
$summaryPath = Join-Path $outDir 'quest-physical-press-validation-summary.json'
$physicalEvidenceSummaryPath = Join-Path $outDir 'physical-press-evidence-validation.json'
$physicalEvidenceSummaryExperimentResultsPath = Join-Path $outDir 'physical-press-evidence-validation-experiment-results.json'
$mirrorComparisonPath = Join-Path $outDir 'export-mirror-comparison.json'
$script:condition1ControllerPresses = 0
$script:condition2ControllerPresses = 0
$script:logControllerPressMarkers = 0
$script:jsonAutomatedPresses = 0
$script:csvAutomatedPresses = 0
$script:logAutomatedPressMarkers = 0
$script:jsonControllerPressesMarkedAutomated = 0
$script:csvControllerPressesMarkedAutomated = 0
$script:jsonFilePath = $null
$script:pressEventsCsvPath = $null
$script:experimentResultsJsonFilePath = $null
$script:experimentResultsPressEventsCsvPath = $null
$script:exportMirrorMatched = $false
$script:exportMirrorFileCount = 0
$script:realPolarConditionNumber = $null
$script:realPolarSampleCount = $null
$script:realPolarRequiredSamples = $null
$script:realPolarBlinkCount = $null
$script:realPolarAudioDurationMs = $null
$script:realPolarCaptureDurationMs = $null
$script:realPolarFirstSampleElapsedMs = $null
$script:realPolarLastSampleElapsedMs = $null
$script:lowLatencyConfigMarkers = $null

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Invoke-Adb {
    & $AdbPath -s $Serial @args
}

function Save-FilteredLogcat {
    Invoke-Adb logcat -d -v time |
        Select-String -Pattern 'BigRedButtonStudy|BRB_|GLTF|FATAL EXCEPTION|E/AndroidRuntime' |
        Set-Content -LiteralPath (Join-Path $outDir 'logcat-filtered.txt') -Encoding UTF8
}

function Remove-SafeTempTree {
    param([string]$Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $target = [IO.Path]::GetFullPath($Path)
    if (-not $target.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove temp pull directory outside system temp root: $target"
    }
    if (Test-Path $target) {
        Remove-Item -Recurse -Force -LiteralPath $target
    }
}

function Pull-DeviceExportFolder {
    param(
        [string]$DeviceDir,
        [string]$DestinationDir,
        [string]$PullLogPath,
        [string]$TempTag
    )

    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null
    $deviceFilesRaw = Invoke-Adb shell ls -1 $DeviceDir
    if ($LASTEXITCODE -ne 0) {
        throw "adb export listing failed for $DeviceDir with exit code $LASTEXITCODE"
    }
    $deviceFiles = @(
        $deviceFilesRaw |
            ForEach-Object { "$_".Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -notmatch '^total\s+' }
    )
    if ($deviceFiles.Count -eq 0) {
        throw "No export files found at $DeviceDir"
    }

    $shortPullRoot = Join-Path ([IO.Path]::GetTempPath()) ("brb-physical-pull-$runId-$TempTag")
    Remove-SafeTempTree -Path $shortPullRoot
    New-Item -ItemType Directory -Force -Path $shortPullRoot | Out-Null
    try {
        $fileIndex = 0
        foreach ($deviceFile in $deviceFiles) {
            $fileIndex += 1
            $remoteFile = "$DeviceDir/$deviceFile"
            $shortLocalFile = Join-Path $shortPullRoot ("export-$fileIndex.tmp")
            $localFile = Join-Path $DestinationDir $deviceFile
            Invoke-Adb pull $remoteFile $shortLocalFile | Tee-Object -Append -FilePath $PullLogPath | Out-Host
            if ($LASTEXITCODE -ne 0) {
                throw "adb export pull failed for $remoteFile with exit code $LASTEXITCODE"
            }
            Move-Item -LiteralPath $shortLocalFile -Destination $localFile -Force
        }
    } finally {
        Remove-SafeTempTree -Path $shortPullRoot
    }

    return [pscustomobject]@{
        deviceDir = $DeviceDir
        destinationDir = $DestinationDir
        fileCount = $deviceFiles.Count
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

function Write-OperatorChecklist {
    @(
        'Big Red Button physical press validation operator checklist',
        '',
        'Before launch:',
        '- Quest is worn by a human operator.',
        '- At least one Quest controller is tracked and held in reach of the virtual button.',
        '- A Polar H10 is worn, awake, wetted, and close enough for the Quest to stream PMD ECG.',
        '- Operator is ready for both full audio tracks: about 5:01, then about 5:26.',
        '',
        'During each condition:',
        "- Physically move the Quest controller into the modeled 3D Big Red Button and press at least $MinCondition1ControllerPresses time(s) in condition 1.",
        "- Physically move the Quest controller into the modeled 3D Big Red Button and press at least $MinCondition2ControllerPresses time(s) in condition 2.",
        '- Do not use ADB taps, Android keyevents, keyboard input, gaze, or flat UI elements as proof of button pressing.',
        '- After each audio track, wait for hidden validation mode to auto-submit non-press questionnaire fields.',
        '',
        'Pass criteria enforced by this script:',
        '- logcat contains controller_contact button press markers.',
        '- pulled JSON and press-events CSV contain controller_contact presses for both conditions.',
        '- controller_contact rows are not marked validationAutomation=true.',
        '- no auto_validation button press source appears in logcat, JSON, or press-events CSV.',
        '- exactly one condition is real_polar_h10 and one is simulated_neurokit2.',
        '- the real_polar_h10 condition exports raw 130 Hz PMD ECG rows covering the full instruction-audio window.',
        '- the real_polar_h10 condition exports Polar RR blink rows.',
        '- logcat includes the minimum-MTU low-latency PMD ECG setup marker with requestedMtu=70.'
    ) | Set-Content -LiteralPath $operatorChecklistPath -Encoding UTF8
    Write-Host "Operator checklist: $operatorChecklistPath"
}

function Update-LatestPolarPrecheckSummary {
    $qpolarRoot = Join-Path $projectRoot 'artifacts\qpolar'
    if (-not (Test-Path $qpolarRoot)) {
        return
    }
    $latestPolarDir =
        Get-ChildItem -LiteralPath $qpolarRoot -Directory |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($null -eq $latestPolarDir) {
        return
    }
    $candidateSummary = Join-Path $latestPolarDir.FullName 'quest-polar-h10-live-smoke-summary.json'
    if (Test-Path $candidateSummary) {
        $script:polarPrecheckSummaryPath = $candidateSummary
    }
}

$model = (Invoke-Adb shell getprop ro.product.model).Trim()
$android = (Invoke-Adb shell getprop ro.build.version.release).Trim()

function Write-PhysicalValidationSummary {
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
        pulledExportRoot = $pulledExportRoot
        pulledExperimentResultsRoot = $pulledExperimentResultsRoot
        condition1ControllerPresses = $script:condition1ControllerPresses
        condition2ControllerPresses = $script:condition2ControllerPresses
        logControllerPressMarkers = $script:logControllerPressMarkers
        jsonAutomatedPresses = $script:jsonAutomatedPresses
        csvAutomatedPresses = $script:csvAutomatedPresses
        logAutomatedPressMarkers = $script:logAutomatedPressMarkers
        jsonControllerPressesMarkedAutomated = $script:jsonControllerPressesMarkedAutomated
        csvControllerPressesMarkedAutomated = $script:csvControllerPressesMarkedAutomated
        json = $script:jsonFilePath
        pressEventsCsv = $script:pressEventsCsvPath
        experimentResultsJson = $script:experimentResultsJsonFilePath
        experimentResultsPressEventsCsv = $script:experimentResultsPressEventsCsvPath
        experimentResultsSchemaValidation = Join-Path $outDir 'experiment-results-schema-validation.txt'
        exportMirrorComparison = $mirrorComparisonPath
        exportMirrorMatched = $script:exportMirrorMatched
        exportMirrorFileCount = $script:exportMirrorFileCount
        physicalEvidenceValidation = $physicalEvidenceSummaryPath
        physicalEvidenceValidationExperimentResults = $physicalEvidenceSummaryExperimentResultsPath
        polarPrecheckSummary = $script:polarPrecheckSummaryPath
        polarPrecheckSkipped = [bool]$SkipPolarPrecheck
        realPolarConditionNumber = $script:realPolarConditionNumber
        realPolarSampleCount = $script:realPolarSampleCount
        realPolarRequiredSamples = $script:realPolarRequiredSamples
        realPolarBlinkCount = $script:realPolarBlinkCount
        realPolarAudioDurationMs = $script:realPolarAudioDurationMs
        realPolarCaptureDurationMs = $script:realPolarCaptureDurationMs
        realPolarFirstSampleElapsedMs = $script:realPolarFirstSampleElapsedMs
        realPolarLastSampleElapsedMs = $script:realPolarLastSampleElapsedMs
        lowLatencyConfigMarkers = $script:lowLatencyConfigMarkers
        operatorChecklist = $operatorChecklistPath
        note = 'This gate requires a human operator to physically press the modeled Big Red Button with a Quest controller while a live Polar H10 streams real 130 Hz PMD ECG. The app auto-submits non-press questionnaire fields only after real MediaPlayer completion events.'
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
}

Write-Host "Quest physical press validation target: serial=$Serial model=$model android=$android"
Write-Host "Operator requirement: press the modeled Big Red Button with a Quest controller at least $MinCondition1ControllerPresses time(s) in condition 1 and $MinCondition2ControllerPresses time(s) in condition 2."
Write-Host "Physiology requirement: wear an awake Polar H10 so the app exports real 130 Hz PMD ECG/RR rows throughout both audio conditions; only the glow feedback source is counterbalanced."
if (-not $SkipPolarPrecheck) {
    Write-Host "Live Polar precheck: enabled. The script will verify PMD ECG streaming before starting the full audio run."
} else {
    Write-Host "Live Polar precheck: skipped by operator flag. The final export validator will still require real Polar ECG evidence."
}
Write-Host "This mode waits for the real MP3 durations. It auto-submits non-press questionnaire fields only after each condition audio completes."
Write-OperatorChecklist

try {
    $polarPrecheckInstalledApk = $false
    if (-not $SkipPolarPrecheck) {
        Write-Host "Running live Polar H10 PMD ECG precheck before full physical validation."
        $polarPrecheckArgs = @(
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            (Join-Path $PSScriptRoot 'run-quest-polar-h10-live-smoke.ps1'),
            '-Serial',
            $Serial,
            '-AdbPath',
            $AdbPath,
            '-ApkPath',
            $ApkPath,
            '-TimeoutSeconds',
            $PolarPrecheckTimeoutSeconds
        )
        if ($SkipInstall) {
            $polarPrecheckArgs += '-SkipInstall'
        }
        powershell @polarPrecheckArgs |
            Tee-Object -FilePath (Join-Path $outDir 'polar-precheck.txt') |
            Out-Host
        if ($LASTEXITCODE -ne 0) {
            Update-LatestPolarPrecheckSummary
            throw "Live Polar H10 precheck failed with exit code $LASTEXITCODE. Full physical validation was not started. See $outDir"
        }
        $polarPrecheckInstalledApk = -not $SkipInstall
        Update-LatestPolarPrecheckSummary
        Write-Host "Live Polar precheck passed: $script:polarPrecheckSummaryPath"
    }

    if (-not $SkipInstall -and -not $polarPrecheckInstalledApk) {
        Write-Host "Installing $ApkPath"
        Invoke-Adb install -r -d -g $ApkPath | Tee-Object -FilePath (Join-Path $outDir 'install.txt') | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "adb install failed with exit code $LASTEXITCODE"
        }
    } elseif ($polarPrecheckInstalledApk) {
        Write-Host "Skipping second APK install because the live Polar precheck already installed the same APK."
    }

    Write-Host "Clearing previous app exports and logcat"
    Invoke-Adb shell rm -rf $deviceExportDir | Out-Null
    Invoke-Adb shell rm -rf $deviceExperimentResultsDir | Out-Null
    Invoke-Adb logcat -c

    Write-Host "Launching physical press validation mode."
    Invoke-Adb shell am start -n $activity --ez brb.physicalPressValidation true |
        Tee-Object -FilePath (Join-Path $outDir 'launch.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "adb launch failed with exit code $LASTEXITCODE"
    }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    $completed = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 10
        $logcat = Invoke-Adb logcat -d -v time
        $logText = ($logcat -join "`n")
        $markers = $logcat | Select-String -Pattern 'BRB_PHYSICAL_VALIDATION_COMPLETE|BRB_EXPORT_COMPLETE|BRB_BUTTON_PRESS .*source=controller_contact|FATAL EXCEPTION|E/AndroidRuntime'
        if ($markers | Select-String -Pattern 'FATAL EXCEPTION|E/AndroidRuntime') {
            $markers | Set-Content -LiteralPath (Join-Path $outDir 'failure-markers.txt') -Encoding UTF8
            throw "Fatal runtime marker detected during physical press validation."
        }
        $condition1ControllerLogMarkers =
            ([regex]::Matches(
                $logText,
                'BRB_BUTTON_PRESS condition=1 index=\d+ source=controller_contact validationAutomation=false'
            )).Count
        $condition2ControllerLogMarkers =
            ([regex]::Matches(
                $logText,
                'BRB_BUTTON_PRESS condition=2 index=\d+ source=controller_contact validationAutomation=false'
            )).Count
        $sourceSummaryMarkers =
            @($logcat | Select-String -Pattern 'BRB_CONDITION_PRESS_SOURCES')
        if ($markers | Select-String -Pattern 'BRB_PHYSICAL_VALIDATION_COMPLETE') {
            $completed = $true
            break
        }
        $elapsed = [int]($WaitSeconds - [math]::Max(0, ($deadline - (Get-Date)).TotalSeconds))
        Write-Host "Waiting for physical validation export... elapsed ${elapsed}s c1Controller=$condition1ControllerLogMarkers/$MinCondition1ControllerPresses c2Controller=$condition2ControllerLogMarkers/$MinCondition2ControllerPresses conditionSourceSummaries=$($sourceSummaryMarkers.Count)"
    }

    Save-FilteredLogcat
    Invoke-Adb shell dumpsys activity activities |
        Select-String -Pattern 'bigredbutton|mCurrentFocus|mFocusedApp|ResumedActivity|topResumedActivity' |
        Set-Content -LiteralPath (Join-Path $outDir 'foreground.txt') -Encoding UTF8

    if (-not $completed) {
        throw "Physical press validation timed out after $WaitSeconds seconds. See $outDir"
    }

    $exportPullLog = Join-Path $outDir 'export-pull.txt'
    $primaryPull = Pull-DeviceExportFolder -DeviceDir $deviceExportDir -DestinationDir $pulledExportRoot -PullLogPath $exportPullLog -TempTag 'primary'
    $experimentResultsPull = Pull-DeviceExportFolder -DeviceDir $deviceExperimentResultsDir -DestinationDir $pulledExperimentResultsRoot -PullLogPath $exportPullLog -TempTag 'experiment-results'
    Write-Host "Pulled exports: primary=$($primaryPull.fileCount) experimentResults=$($experimentResultsPull.fileCount)"
    $mirrorComparison = Compare-ExportMirror -PrimaryDir $pulledExportRoot -MirrorDir $pulledExperimentResultsRoot -OutPath $mirrorComparisonPath
    $script:exportMirrorMatched = ($mirrorComparison.status -eq 'pass')
    $script:exportMirrorFileCount = $mirrorComparison.primaryFileCount

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -ExportDir $pulledExportRoot |
        Tee-Object -FilePath (Join-Path $outDir 'export-schema-validation.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "primary export schema validation failed with exit code $LASTEXITCODE"
    }

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-export-schema.ps1') -ExportDir $pulledExperimentResultsRoot |
        Tee-Object -FilePath (Join-Path $outDir 'experiment-results-schema-validation.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "ExperimentResults schema validation failed with exit code $LASTEXITCODE"
    }

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-physical-press-evidence.ps1') `
        -ExportDir $pulledExportRoot `
        -LogcatPath (Join-Path $outDir 'logcat-filtered.txt') `
        -MinCondition1ControllerPresses $MinCondition1ControllerPresses `
        -MinCondition2ControllerPresses $MinCondition2ControllerPresses `
        -OutPath $physicalEvidenceSummaryPath |
        Tee-Object -FilePath (Join-Path $outDir 'physical-press-evidence-validation.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "primary physical press evidence validation failed with exit code $LASTEXITCODE"
    }
    $physicalEvidenceSummary = Get-Content -Raw -LiteralPath $physicalEvidenceSummaryPath | ConvertFrom-Json

    powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-physical-press-evidence.ps1') `
        -ExportDir $pulledExperimentResultsRoot `
        -LogcatPath (Join-Path $outDir 'logcat-filtered.txt') `
        -MinCondition1ControllerPresses $MinCondition1ControllerPresses `
        -MinCondition2ControllerPresses $MinCondition2ControllerPresses `
        -OutPath $physicalEvidenceSummaryExperimentResultsPath |
        Tee-Object -FilePath (Join-Path $outDir 'physical-press-evidence-validation-experiment-results.txt') |
        Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "ExperimentResults physical press evidence validation failed with exit code $LASTEXITCODE"
    }

    $jsonFile = Get-ChildItem -LiteralPath $pulledExportRoot -Filter 'brb_first_study_*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $pressFile = Get-ChildItem -LiteralPath $pulledExportRoot -Filter '*_press_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $script:jsonFilePath = $jsonFile.FullName
    $script:pressEventsCsvPath = $pressFile.FullName
    $experimentResultsJsonFile = Get-ChildItem -LiteralPath $pulledExperimentResultsRoot -Filter 'brb_first_study_*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $experimentResultsPressFile = Get-ChildItem -LiteralPath $pulledExperimentResultsRoot -Filter '*_press_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    $script:experimentResultsJsonFilePath = $experimentResultsJsonFile.FullName
    $script:experimentResultsPressEventsCsvPath = $experimentResultsPressFile.FullName
    $exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
    $conditions = @($exportJson.conditions)
    $condition1 = $conditions | Where-Object { $_.conditionNumber -eq 1 } | Select-Object -First 1
    $condition2 = $conditions | Where-Object { $_.conditionNumber -eq 2 } | Select-Object -First 1
    $allJsonPressEvents = @($conditions | ForEach-Object { @($_.pressEvents) })
    $condition1ControllerPressEvents = @($condition1.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
    $condition2ControllerPressEvents = @($condition2.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
    $condition1ControllerPresses = $condition1ControllerPressEvents.Count
    $condition2ControllerPresses = $condition2ControllerPressEvents.Count
    $script:condition1ControllerPresses = $condition1ControllerPresses
    $script:condition2ControllerPresses = $condition2ControllerPresses
    $pressRows = @(Import-Csv -LiteralPath $pressFile.FullName)
    $csvCondition1ControllerPressRows = @($pressRows | Where-Object { $_.condition_number -eq '1' -and $_.input_source -eq 'controller_contact' })
    $csvCondition2ControllerPressRows = @($pressRows | Where-Object { $_.condition_number -eq '2' -and $_.input_source -eq 'controller_contact' })
    $csvCondition1ControllerPresses = $csvCondition1ControllerPressRows.Count
    $csvCondition2ControllerPresses = $csvCondition2ControllerPressRows.Count
    $logText = Get-Content -Raw -LiteralPath (Join-Path $outDir 'logcat-filtered.txt')
    $logControllerPressMarkers = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=controller_contact')).Count
    $script:logControllerPressMarkers = $logControllerPressMarkers
    $jsonAutomatedPresses = @(
        $allJsonPressEvents |
            Where-Object { $_.inputSource -eq 'auto_validation' -or $_.validationAutomation -eq $true }
    ).Count
    $script:jsonAutomatedPresses = $jsonAutomatedPresses
    $csvAutomatedPresses = @(
        $pressRows |
            Where-Object { $_.input_source -eq 'auto_validation' -or $_.validation_automation -eq 'true' }
    ).Count
    $script:csvAutomatedPresses = $csvAutomatedPresses
    $logAutomatedPressMarkers = (
        [regex]::Matches($logText, 'BRB_BUTTON_PRESS .*source=auto_validation|BRB_BUTTON_PRESS .*validationAutomation=true')
    ).Count
    $script:logAutomatedPressMarkers = $logAutomatedPressMarkers
    $jsonControllerPressesMarkedAutomated = @(
        $allJsonPressEvents |
            Where-Object { $_.inputSource -eq 'controller_contact' -and $_.validationAutomation -eq $true }
    ).Count
    $script:jsonControllerPressesMarkedAutomated = $jsonControllerPressesMarkedAutomated
    $csvControllerPressesMarkedAutomated = @(
        $pressRows |
            Where-Object { $_.input_source -eq 'controller_contact' -and $_.validation_automation -eq 'true' }
    ).Count
    $script:csvControllerPressesMarkedAutomated = $csvControllerPressesMarkedAutomated

    if ($condition1ControllerPresses -lt $MinCondition1ControllerPresses) {
        throw "Condition 1 controller_contact presses too low: expected at least $MinCondition1ControllerPresses, found $condition1ControllerPresses"
    }
    if ($condition2ControllerPresses -lt $MinCondition2ControllerPresses) {
        throw "Condition 2 controller_contact presses too low: expected at least $MinCondition2ControllerPresses, found $condition2ControllerPresses"
    }
    if ($condition1ControllerPresses -ne $csvCondition1ControllerPresses) {
        throw "Condition 1 JSON/CSV controller_contact mismatch: json=$condition1ControllerPresses csv=$csvCondition1ControllerPresses"
    }
    if ($condition2ControllerPresses -ne $csvCondition2ControllerPresses) {
        throw "Condition 2 JSON/CSV controller_contact mismatch: json=$condition2ControllerPresses csv=$csvCondition2ControllerPresses"
    }
    if ($logControllerPressMarkers -lt ($condition1ControllerPresses + $condition2ControllerPresses)) {
        throw "Logcat controller_contact markers fewer than exported controller_contact events: log=$logControllerPressMarkers export=$($condition1ControllerPresses + $condition2ControllerPresses)"
    }
    if ($jsonAutomatedPresses -gt 0) {
        throw "Physical press validation export contains automated button presses in JSON: $jsonAutomatedPresses"
    }
    if ($csvAutomatedPresses -gt 0) {
        throw "Physical press validation export contains automated button presses in CSV: $csvAutomatedPresses"
    }
    if ($logAutomatedPressMarkers -gt 0) {
        throw "Physical press validation logcat contains automated button press markers: $logAutomatedPressMarkers"
    }
    if ($jsonControllerPressesMarkedAutomated -gt 0) {
        throw "JSON controller_contact press events are marked validationAutomation=true: $jsonControllerPressesMarkedAutomated"
    }
    if ($csvControllerPressesMarkedAutomated -gt 0) {
        throw "CSV controller_contact press rows are marked validation_automation=true: $csvControllerPressesMarkedAutomated"
    }

    $script:realPolarConditionNumber = $physicalEvidenceSummary.realPolarConditionNumber
    $script:realPolarSampleCount = $physicalEvidenceSummary.realPolarSampleCount
    $script:realPolarRequiredSamples = $physicalEvidenceSummary.realPolarRequiredSamples
    $script:realPolarBlinkCount = $physicalEvidenceSummary.realPolarBlinkCount
    $script:realPolarAudioDurationMs = $physicalEvidenceSummary.realPolarAudioDurationMs
    $script:realPolarCaptureDurationMs = $physicalEvidenceSummary.realPolarCaptureDurationMs
    $script:realPolarFirstSampleElapsedMs = $physicalEvidenceSummary.realPolarFirstSampleElapsedMs
    $script:realPolarLastSampleElapsedMs = $physicalEvidenceSummary.realPolarLastSampleElapsedMs
    $script:lowLatencyConfigMarkers = $physicalEvidenceSummary.lowLatencyConfigMarkers
    Write-PhysicalValidationSummary -Status 'pass'
    Write-Host "PASS Quest physical press validation"
    Write-Host "Summary: $summaryPath"
} catch {
    $failureMessage = $_.Exception.Message
    try {
        if ([string]::IsNullOrWhiteSpace($script:polarPrecheckSummaryPath)) {
            Update-LatestPolarPrecheckSummary
        }
        Save-FilteredLogcat
        if (Test-Path (Join-Path $outDir 'logcat-filtered.txt')) {
            $logText = Get-Content -Raw -LiteralPath (Join-Path $outDir 'logcat-filtered.txt')
            $script:logControllerPressMarkers = ([regex]::Matches($logText, 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=controller_contact')).Count
            $script:logAutomatedPressMarkers = (
                [regex]::Matches($logText, 'BRB_BUTTON_PRESS .*source=auto_validation|BRB_BUTTON_PRESS .*validationAutomation=true')
            ).Count
        }
    } catch {
        Write-Warning "Could not save full physical-validation failure evidence: $($_.Exception.Message)"
    }
    Write-PhysicalValidationSummary -Status 'fail' -ErrorMessage $failureMessage
    Write-Host "FAIL Quest physical press validation"
    Write-Host "Summary: $summaryPath"
    throw
} finally {
    Invoke-Adb shell am force-stop $package | Out-Null
}
