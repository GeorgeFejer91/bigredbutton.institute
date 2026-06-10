[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\ppe-tests\t-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function New-PressEvent {
    param(
        [int]$Condition,
        [int]$Index,
        [string]$Source,
        [bool]$Automation
    )
    return [ordered]@{
        conditionNumber = $Condition
        pressIndex = $Index
        elapsedMs = 1000 * $Index
        unixTimeMs = 1781006400000 + (1000 * $Index)
        isoTimestamp = "2026-06-09T12:00:0${Index}Z"
        inputSource = $Source
        validationAutomation = $Automation
    }
}

function New-EcgBlinkEvent {
    param(
        [int]$Condition,
        [int]$Index,
        [string]$Source,
        [double]$ElapsedMs
    )
    $unixTimeMs = 1781006400000 + [int][math]::Round($ElapsedMs)
    return [ordered]@{
        conditionNumber = $Condition
        blinkIndex = $Index
        source = $Source
        elapsedMs = $ElapsedMs
        unixTimeMs = $unixTimeMs
        isoTimestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($unixTimeMs).UtcDateTime.ToString('o')
        rrMs = 830.0
        heartRateBpm = 72
    }
}

function New-EcgSample {
    param(
        [int]$Condition,
        [int]$Index,
        [string]$Source,
        [double]$ElapsedMs,
        [int]$SampleRateHz = 130,
        [int]$PackageSizeBytes = 16,
        [int]$RequestedMtu = 70,
        [int]$NegotiatedMtu = 70,
        [int]$AudioDurationMs = 100
    )
    $unixTimeMs = 1781006400000 + [int][math]::Round($ElapsedMs)
    $elapsedNs = [int64][math]::Round($ElapsedMs * 1000000.0)
    return [ordered]@{
        conditionNumber = $Condition
        sampleIndex = $Index
        source = $Source
        elapsedMs = $ElapsedMs
        elapsedNs = $elapsedNs
        audioWindowStartMs = 0
        audioWindowEndMs = $AudioDurationMs
        audioWindowDurationMs = $AudioDurationMs
        unixTimeMs = $unixTimeMs
        isoTimestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($unixTimeMs).UtcDateTime.ToString('o')
        sensorTimestampNs = $elapsedNs
        microVolts = 120 + $Index
        sampleRateHz = $SampleRateHz
        frameIndex = [int][math]::Ceiling($Index / 2.0)
        frameType = 0
        packageSizeBytes = $PackageSizeBytes
        requestedMtu = $RequestedMtu
        negotiatedMtu = $NegotiatedMtu
    }
}

function Set-EcgSampleElapsed {
    param(
        $Sample,
        [double]$ElapsedMs
    )
    $unixTimeMs = 1781006400000 + [int][math]::Round($ElapsedMs)
    $elapsedNs = [int64][math]::Round($ElapsedMs * 1000000.0)
    $Sample['elapsedMs'] = $ElapsedMs
    $Sample['elapsedNs'] = $elapsedNs
    $Sample['unixTimeMs'] = $unixTimeMs
    $Sample['isoTimestamp'] = [DateTimeOffset]::FromUnixTimeMilliseconds($unixTimeMs).UtcDateTime.ToString('o')
    $Sample['sensorTimestampNs'] = $elapsedNs
}

function New-EcgSampleSeries {
    param(
        [int]$Condition,
        [string]$Source,
        [int]$Count,
        [int]$SampleRateHz = 130,
        [int]$PackageSizeBytes = 16,
        [int]$RequestedMtu = 70,
        [int]$NegotiatedMtu = 70,
        [int]$AudioDurationMs = 100
    )
    $samples = @()
    for ($index = 1; $index -le $Count; $index += 1) {
        $elapsedMs = (($index - 1) * 1000.0) / 130.0
        $samples += New-EcgSample `
            -Condition $Condition `
            -Index $index `
            -Source $Source `
            -ElapsedMs $elapsedMs `
            -SampleRateHz $SampleRateHz `
            -PackageSizeBytes $PackageSizeBytes `
            -RequestedMtu $RequestedMtu `
            -NegotiatedMtu $NegotiatedMtu `
            -AudioDurationMs $AudioDurationMs
    }
    return @($samples)
}

function Get-EcgSeriesMinElapsedMs {
    param($Series)
    if (@($Series).Count -eq 0) {
        return $null
    }
    return (@($Series | ForEach-Object { [double]$_['elapsedMs'] } | Measure-Object -Minimum).Minimum)
}

function Get-EcgSeriesMaxElapsedMs {
    param($Series)
    if (@($Series).Count -eq 0) {
        return $null
    }
    return (@($Series | ForEach-Object { [double]$_['elapsedMs'] } | Measure-Object -Maximum).Maximum)
}

function New-Case {
    param(
        [string]$Name,
        [string]$Mode
    )
    $caseRoot = Join-Path $OutDir $Name
    $exportRoot = Join-Path $caseRoot 'BigRedButtonFirstStudyExports'
    New-Item -ItemType Directory -Force -Path $exportRoot | Out-Null
    $sessionId = "s-$Name"
    $participantId = 'p'
    $jsonPath = Join-Path $exportRoot "brb_first_study_p_${Name}.json"
    $pressPath = Join-Path $exportRoot "brb_first_study_p_${Name}_press_events.csv"
    $ecgBlinkPath = Join-Path $exportRoot "brb_first_study_p_${Name}_ecg_blink_events.csv"
    $ecgTimeSeriesPath = Join-Path $exportRoot "brb_first_study_p_${Name}_ecg_timeseries.csv"
    $logPath = Join-Path $caseRoot 'logcat-filtered.txt'
    $summaryPath = Join-Path $caseRoot 'physical-evidence-summary.json'

    $condition1Events = @((New-PressEvent -Condition 1 -Index 1 -Source 'controller_contact' -Automation $false))
    $condition2Events = @((New-PressEvent -Condition 2 -Index 1 -Source 'controller_contact' -Automation $false))
    if ($Mode -eq 'auto-source') {
        $condition2Events += New-PressEvent -Condition 2 -Index 2 -Source 'auto_validation' -Automation $true
    }
    if ($Mode -eq 'controller-marked-automation') {
        $condition1Events = @((New-PressEvent -Condition 1 -Index 1 -Source 'controller_contact' -Automation $true))
    }

    $audioDurationMs = 100
    $expectedSamples = 13
    $realSampleRateHz = if ($Mode -eq 'wrong-real-ecg-rate') { 129 } else { 130 }
    $realRequestedMtu = if ($Mode -eq 'invalid-real-ecg-mtu') { 185 } else { 70 }
    $realBlinkEvents = @((New-EcgBlinkEvent -Condition 1 -Index 1 -Source 'real_polar_h10' -ElapsedMs 80.0))
    $simBlinkEvents = @((New-EcgBlinkEvent -Condition 2 -Index 1 -Source 'simulated_neurokit2' -ElapsedMs 70.0))
    $realTimeSeries =
        New-EcgSampleSeries -Condition 1 -Source 'real_polar_h10' -Count $expectedSamples -SampleRateHz $realSampleRateHz -RequestedMtu $realRequestedMtu -AudioDurationMs $audioDurationMs
    $simTimeSeries =
        New-EcgSampleSeries -Condition 2 -Source 'simulated_neurokit2' -Count $expectedSamples -PackageSizeBytes 0 -RequestedMtu 0 -NegotiatedMtu 0 -AudioDurationMs $audioDurationMs
    if ($Mode -eq 'missing-real-ecg-samples') {
        $realTimeSeries = @()
    }
    if ($Mode -eq 'missing-real-blink') {
        $realBlinkEvents = @()
    }
    if ($Mode -eq 'short-real-ecg-coverage') {
        $realTimeSeries = @($realTimeSeries | Select-Object -First 2)
    }
    if ($Mode -eq 'invalid-real-ecg-package') {
        $realTimeSeries = @(
            $realTimeSeries | ForEach-Object {
                if ($_.sampleIndex -eq 1) {
                    $_.packageSizeBytes = 0
                }
                $_
            }
        )
    }
    if ($Mode -eq 'nonmonotonic-real-ecg-timing' -and $realTimeSeries.Count -ge 5) {
        Set-EcgSampleElapsed -Sample $realTimeSeries[4] -ElapsedMs ([double]$realTimeSeries[3]['elapsedMs'])
    }
    if ($Mode -eq 'coarse-real-ecg-timing' -and $realTimeSeries.Count -ge 13) {
        $coarseElapsedMs = @(0.0, 12.5, 13.5, 26.0, 27.0, 39.5, 40.5, 53.0, 54.0, 66.5, 67.5, 80.0, 92.3)
        for ($i = 0; $i -lt $coarseElapsedMs.Count; $i += 1) {
            Set-EcgSampleElapsed -Sample $realTimeSeries[$i] -ElapsedMs $coarseElapsedMs[$i]
        }
    }

    $json = [ordered]@{
        schema = 'bigredbutton.first_study.v1'
        sessionId = $sessionId
        demographics = [ordered]@{ participantId = $participantId }
        conditions = @(
            [ordered]@{
                conditionNumber = 1
                audioDurationMs = $audioDurationMs
                ecgSource = 'real_polar_h10'
                ecgBlinkCount = $realBlinkEvents.Count
                ecgBlinkEvents = $realBlinkEvents
                ecgCaptureStartedElapsedMs = 0
                ecgCaptureEndedElapsedMs = $audioDurationMs
                ecgCaptureStartedElapsedNs = 0
                ecgCaptureEndedElapsedNs = $audioDurationMs * 1000000
                ecgCaptureDurationMs = $audioDurationMs
                ecgCaptureDurationNs = $audioDurationMs * 1000000
                ecgAudioWindowStartMs = 0
                ecgAudioWindowEndMs = $audioDurationMs
                ecgAudioWindowDurationMs = $audioDurationMs
                ecgFirstSampleElapsedMs = Get-EcgSeriesMinElapsedMs $realTimeSeries
                ecgLastSampleElapsedMs = Get-EcgSeriesMaxElapsedMs $realTimeSeries
                ecgStartBoundaryGapMs = Get-EcgSeriesMinElapsedMs $realTimeSeries
                ecgEndBoundaryGapMs = if ($realTimeSeries.Count -gt 0) { $audioDurationMs - (Get-EcgSeriesMaxElapsedMs $realTimeSeries) } else { $null }
                ecgSampleRateHz = $realSampleRateHz
                ecgExpectedSampleCount = $expectedSamples
                ecgTimeSeriesSampleCount = $realTimeSeries.Count
                ecgRequestedMtu = $realRequestedMtu
                ecgNegotiatedMtu = 70
                ecgTimeSeries = $realTimeSeries
                pressEvents = $condition1Events
            },
            [ordered]@{
                conditionNumber = 2
                audioDurationMs = $audioDurationMs
                ecgSource = 'simulated_neurokit2'
                ecgBlinkCount = $simBlinkEvents.Count
                ecgBlinkEvents = $simBlinkEvents
                ecgCaptureStartedElapsedMs = 0
                ecgCaptureEndedElapsedMs = $audioDurationMs
                ecgCaptureStartedElapsedNs = 0
                ecgCaptureEndedElapsedNs = $audioDurationMs * 1000000
                ecgCaptureDurationMs = $audioDurationMs
                ecgCaptureDurationNs = $audioDurationMs * 1000000
                ecgAudioWindowStartMs = 0
                ecgAudioWindowEndMs = $audioDurationMs
                ecgAudioWindowDurationMs = $audioDurationMs
                ecgFirstSampleElapsedMs = Get-EcgSeriesMinElapsedMs $simTimeSeries
                ecgLastSampleElapsedMs = Get-EcgSeriesMaxElapsedMs $simTimeSeries
                ecgStartBoundaryGapMs = Get-EcgSeriesMinElapsedMs $simTimeSeries
                ecgEndBoundaryGapMs = if ($simTimeSeries.Count -gt 0) { $audioDurationMs - (Get-EcgSeriesMaxElapsedMs $simTimeSeries) } else { $null }
                ecgSampleRateHz = 130
                ecgExpectedSampleCount = $expectedSamples
                ecgTimeSeriesSampleCount = $simTimeSeries.Count
                ecgRequestedMtu = 0
                ecgNegotiatedMtu = 0
                ecgTimeSeries = $simTimeSeries
                pressEvents = $condition2Events
            }
        )
    }
    $json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $pressRows = New-Object System.Collections.Generic.List[string]
    $pressRows.Add('session_id,participant_id,condition_number,press_index,elapsed_ms,unix_time_ms,iso_timestamp,input_source,validation_automation')
    foreach ($event in @($condition1Events + $condition2Events)) {
        $pressRows.Add(
            "$sessionId,$participantId,$($event.conditionNumber),$($event.pressIndex),$($event.elapsedMs),$($event.unixTimeMs),$($event.isoTimestamp),$($event.inputSource),$($event.validationAutomation.ToString().ToLowerInvariant())"
        )
    }
    $pressRows | Set-Content -LiteralPath $pressPath -Encoding UTF8

    $ecgBlinkRows = New-Object System.Collections.Generic.List[string]
    $ecgBlinkRows.Add('session_id,participant_id,condition_number,blink_index,source,elapsed_ms,unix_time_ms,iso_timestamp,rr_ms,heart_rate_bpm')
    foreach ($event in @($realBlinkEvents + $simBlinkEvents)) {
        $ecgBlinkRows.Add(
            "$sessionId,$participantId,$($event.conditionNumber),$($event.blinkIndex),$($event.source),$($event.elapsedMs),$($event.unixTimeMs),$($event.isoTimestamp),$($event.rrMs),$($event.heartRateBpm)"
        )
    }
    $ecgBlinkRows | Set-Content -LiteralPath $ecgBlinkPath -Encoding UTF8

    $ecgTimeSeriesRows = New-Object System.Collections.Generic.List[string]
    $ecgTimeSeriesRows.Add('session_id,participant_id,condition_number,sample_index,source,elapsed_ms,elapsed_ns,audio_window_start_ms,audio_window_end_ms,audio_window_duration_ms,unix_time_ms,iso_timestamp,sensor_timestamp_ns,microvolts,sample_rate_hz,frame_index,frame_type,package_size_bytes,requested_mtu,negotiated_mtu')
    foreach ($sample in @($realTimeSeries + $simTimeSeries)) {
        $ecgTimeSeriesRows.Add(
            "$sessionId,$participantId,$($sample.conditionNumber),$($sample.sampleIndex),$($sample.source),$($sample.elapsedMs),$($sample.elapsedNs),$($sample.audioWindowStartMs),$($sample.audioWindowEndMs),$($sample.audioWindowDurationMs),$($sample.unixTimeMs),$($sample.isoTimestamp),$($sample.sensorTimestampNs),$($sample.microVolts),$($sample.sampleRateHz),$($sample.frameIndex),$($sample.frameType),$($sample.packageSizeBytes),$($sample.requestedMtu),$($sample.negotiatedMtu)"
        )
    }
    $ecgTimeSeriesRows | Set-Content -LiteralPath $ecgTimeSeriesPath -Encoding UTF8

    $logLines = New-Object System.Collections.Generic.List[string]
    foreach ($event in @($condition1Events + $condition2Events)) {
        if ($Mode -ne 'missing-accepted-select') {
            $logLines.Add(
                "06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true"
            )
        }
        $logLines.Add(
            "06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_BUTTON_PRESS condition=$($event.conditionNumber) index=$($event.pressIndex) source=$($event.inputSource) validationAutomation=$($event.validationAutomation.ToString().ToLowerInvariant()) elapsedMs=$($event.elapsedMs)"
        )
    }
    if ($Mode -ne 'missing-source-summary') {
        $condition1ControllerCount = @($condition1Events | Where-Object { $_.inputSource -eq 'controller_contact' }).Count
        $condition2ControllerCount = @($condition2Events | Where-Object { $_.inputSource -eq 'controller_contact' }).Count
        if ($Mode -eq 'source-summary-mismatch') {
            $condition2ControllerCount += 1
        }
        $logLines.Add("06-09 12:05:01.000 I/BigRedButtonStudy(123): BRB_CONDITION_PRESS_SOURCES condition=1 total=$($condition1Events.Count) controllerContact=$condition1ControllerCount interimPanel=0 sceneObjectFallback=0 autoValidation=0")
        $logLines.Add("06-09 12:10:27.000 I/BigRedButtonStudy(123): BRB_CONDITION_PRESS_SOURCES condition=2 total=$($condition2Events.Count) controllerContact=$condition2ControllerCount interimPanel=0 sceneObjectFallback=0 autoValidation=0")
    }
    if ($Mode -ne 'missing-low-latency-config') {
        $logLines.Add('06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_POLAR_H10_LOW_LATENCY_CONFIG connectionPriorityHighRequested=true requestedMtu=70 mtuIssued=true strategy=minimum_mtu_low_latency_ecg')
    }
    $logLines.Add("06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_ECG_CAPTURE_START condition=1 source=real_polar_h10 audioDurationMs=$audioDurationMs sampleRateHz=$realSampleRateHz expectedSamples=$expectedSamples requestedMtu=70 negotiatedMtu=70")
    $logLines.Add("06-09 12:00:00.100 I/BigRedButtonStudy(123): BRB_ECG_CAPTURE_END condition=1 source=real_polar_h10 audioDurationMs=$audioDurationMs sampleRateHz=$realSampleRateHz expectedSamples=$expectedSamples actualSamples=$($realTimeSeries.Count) captureWindowMs=$audioDurationMs")
    $logLines | Set-Content -LiteralPath $logPath -Encoding UTF8

    return [pscustomobject]@{
        name = $Name
        mode = $Mode
        exportRoot = $exportRoot
        logPath = $logPath
        summaryPath = $summaryPath
    }
}

function Invoke-ValidatorCase {
    param(
        $Case,
        [bool]$ShouldPass
    )
    $passed = $false
    $message = ''
    try {
        $validatorOutput = powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'validate-physical-press-evidence.ps1') `
            -ExportDir $Case.exportRoot `
            -LogcatPath $Case.logPath `
            -OutPath $Case.summaryPath *>&1
        $validatorOutput | Set-Content -LiteralPath (Join-Path (Split-Path -Parent $Case.summaryPath) 'validator-output.txt') -Encoding UTF8
        if ($LASTEXITCODE -ne 0) {
            throw "validator exited with $LASTEXITCODE"
        }
        $validatorOutput | Out-Host
        $passed = $true
    } catch {
        $message = $_.Exception.Message
        $passed = $false
    }
    if ($passed -ne $ShouldPass) {
        throw "Case $($Case.name) expected pass=$ShouldPass but got pass=$passed. $message"
    }
    return [pscustomobject]@{
        name = $Case.name
        mode = $Case.mode
        expectedPass = $ShouldPass
        actualPass = $passed
        message = $message
        exportRoot = $Case.exportRoot
        logPath = $Case.logPath
        summaryPath = $Case.summaryPath
    }
}

$cases = @(
    [pscustomobject]@{ case = New-Case -Name 'clean' -Mode 'clean'; shouldPass = $true },
    [pscustomobject]@{ case = New-Case -Name 'auto' -Mode 'auto-source'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'flag' -Mode 'controller-marked-automation'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-accepted' -Mode 'missing-accepted-select'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-summary' -Mode 'missing-source-summary'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'summary-mismatch' -Mode 'source-summary-mismatch'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-real-ecg' -Mode 'missing-real-ecg-samples'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-real-blink' -Mode 'missing-real-blink'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'wrong-real-rate' -Mode 'wrong-real-ecg-rate'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'short-real-ecg' -Mode 'short-real-ecg-coverage'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'invalid-real-ecg-package' -Mode 'invalid-real-ecg-package'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'invalid-real-ecg-mtu' -Mode 'invalid-real-ecg-mtu'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'nonmonotonic-real-ecg-timing' -Mode 'nonmonotonic-real-ecg-timing'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'coarse-real-ecg-timing' -Mode 'coarse-real-ecg-timing'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-low-latency' -Mode 'missing-low-latency-config'; shouldPass = $false }
)

$results = New-Object System.Collections.Generic.List[object]
foreach ($item in $cases) {
    $results.Add((Invoke-ValidatorCase -Case $item.case -ShouldPass $item.shouldPass))
}

$summaryPath = Join-Path $OutDir 'physical-evidence-validator-test-summary.json'
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    outDir = $OutDir
    results = $results
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "PASS physical press evidence validator tests"
Write-Host "Summary: $summaryPath"
