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
        [string]$InputSource = 'controller_contact',
        [bool]$Automation = $false,
        [string]$FeedbackSource
    )
    $elapsedNs = 46153846L
    $startNs = [int64]$Condition * 1000000000000L
    return [ordered]@{
        conditionNumber = $Condition
        pressIndex = $Index
        elapsedMs = 46
        elapsedNs = $elapsedNs
        eventElapsedRealtimeNs = $startNs + $elapsedNs
        conditionStartElapsedRealtimeNs = $startNs
        unixTimeMs = 1781006400046 + (($Condition - 1) * 100000)
        isoTimestamp = if ($Condition -eq 1) { '2026-06-09T12:00:00.046Z' } else { '2026-06-09T12:05:00.046Z' }
        inputSource = $InputSource
        validationAutomation = $Automation
        feedbackSource = $FeedbackSource
        physiologySource = 'real_polar_h10'
        nearestEcgSampleIndex = 7
        nearestEcgElapsedNs = 46153846L
        nearestEcgDeltaNs = 0L
    }
}

function New-EcgBlinkEvent {
    param(
        [int]$Condition,
        [string]$Source
    )
    $unixTimeMs = 1781006400080 + (($Condition - 1) * 100000)
    return [ordered]@{
        conditionNumber = $Condition
        blinkIndex = 1
        source = $Source
        elapsedMs = 80
        unixTimeMs = $unixTimeMs
        isoTimestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($unixTimeMs).UtcDateTime.ToString('o')
        rrMs = 830.0
        heartRateBpm = 72
        pulseIntensity01 = 1.0
        pulseSourceTimestampUnixNs = [int64]$unixTimeMs * 1000000L
        detector = if ($Source -eq 'real_polar_h10') { 'polar_h10_rr_interval' } else { 'simulated_rr_interval' }
    }
}

function New-PolarRrEvent {
    param(
        [int]$Condition,
        [string]$FeedbackSource
    )
    $unixTimeMs = 1781006400080 + (($Condition - 1) * 100000)
    return [ordered]@{
        conditionNumber = $Condition
        rrIndex = 1
        elapsedMs = 80
        elapsedNs = 80000000L
        unixTimeMs = $unixTimeMs
        isoTimestamp = [DateTimeOffset]::FromUnixTimeMilliseconds($unixTimeMs).UtcDateTime.ToString('o')
        rrMs = 830.0
        heartRateBpm = 72
        feedbackSource = $FeedbackSource
        usedForFeedback = ($FeedbackSource -eq 'real_polar_h10')
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
    $unixTimeMs = 1781006400000 + (($Condition - 1) * 100000) + [int][math]::Round($ElapsedMs)
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
    param($Sample, [double]$ElapsedMs)
    $elapsedNs = [int64][math]::Round($ElapsedMs * 1000000.0)
    $Sample['elapsedMs'] = $ElapsedMs
    $Sample['elapsedNs'] = $elapsedNs
    $Sample['sensorTimestampNs'] = $elapsedNs
}

function New-EcgSampleSeries {
    param(
        [int]$Condition,
        [string]$Source = 'real_polar_h10',
        [int]$Count = 13,
        [int]$AudioDurationMs = 100
    )
    $samples = @()
    for ($index = 1; $index -le $Count; $index += 1) {
        $elapsedMs = (($index - 1) * 1000.0) / 130.0
        $samples += New-EcgSample -Condition $Condition -Index $index -Source $Source -ElapsedMs $elapsedMs -AudioDurationMs $AudioDurationMs
    }
    return @($samples)
}

function Get-EcgSeriesMinElapsedMs {
    param($Series)
    if (@($Series).Count -eq 0) { return $null }
    return (@($Series | ForEach-Object { [double]$_['elapsedMs'] } | Measure-Object -Minimum).Minimum)
}

function Get-EcgSeriesMaxElapsedMs {
    param($Series)
    if (@($Series).Count -eq 0) { return $null }
    return (@($Series | ForEach-Object { [double]$_['elapsedMs'] } | Measure-Object -Maximum).Maximum)
}

function New-ConditionJson {
    param(
        [int]$Condition,
        [string]$FeedbackSource,
        [string]$PhysiologySource,
        [array]$PressEvents,
        [array]$BlinkEvents,
        [array]$PolarRrEvents,
        [array]$Samples,
        [int]$AudioDurationMs = 100
    )
    return [ordered]@{
        conditionNumber = $Condition
        audioDurationMs = $AudioDurationMs
        ecgSource = $PhysiologySource
        feedbackSource = $FeedbackSource
        physiologySource = $PhysiologySource
        ecgBlinkCount = @($BlinkEvents).Count
        ecgBlinkEvents = @($BlinkEvents)
        polarRrEventCount = @($PolarRrEvents).Count
        polarRrEvents = @($PolarRrEvents)
        ecgCaptureStartedElapsedMs = 0
        ecgCaptureEndedElapsedMs = $AudioDurationMs
        ecgCaptureStartedElapsedNs = 0
        ecgCaptureEndedElapsedNs = [int64]$AudioDurationMs * 1000000L
        ecgCaptureDurationMs = $AudioDurationMs
        ecgCaptureDurationNs = [int64]$AudioDurationMs * 1000000L
        ecgAudioWindowStartMs = 0
        ecgAudioWindowEndMs = $AudioDurationMs
        ecgAudioWindowDurationMs = $AudioDurationMs
        ecgFirstSampleElapsedMs = Get-EcgSeriesMinElapsedMs $Samples
        ecgLastSampleElapsedMs = Get-EcgSeriesMaxElapsedMs $Samples
        ecgStartBoundaryGapMs = Get-EcgSeriesMinElapsedMs $Samples
        ecgEndBoundaryGapMs = if (@($Samples).Count -gt 0) { $AudioDurationMs - (Get-EcgSeriesMaxElapsedMs $Samples) } else { $null }
        ecgSampleRateHz = 130
        ecgExpectedSampleCount = 13
        ecgTimeSeriesSampleCount = @($Samples).Count
        realEcgTimeSeriesSampleCount = @($Samples | Where-Object { $_.source -eq 'real_polar_h10' }).Count
        ecgRequestedMtu = 70
        ecgNegotiatedMtu = 70
        ecgTimeSeries = @($Samples)
        pressEvents = @($PressEvents)
    }
}

function New-Case {
    param(
        [string]$Name,
        [string]$Mode
    )
    $nameToken = ($Name -replace '[^A-Za-z0-9]+', '').ToLowerInvariant()
    $caseRoot = Join-Path $OutDir ('c_' + $nameToken.Substring(0, [Math]::Min(12, $nameToken.Length)))
    $exportRoot = Join-Path $caseRoot 'BigRedButtonFirstStudyExports'
    $sessionFolder = '20260609-120000Z_p_s'
    $sessionDir = Join-Path $exportRoot $sessionFolder
    New-Item -ItemType Directory -Force -Path $sessionDir | Out-Null
    $sessionId = "s-$Name"
    $participantId = 'p'
    $jsonPath = Join-Path $sessionDir 'brb_first_study_p_case.json'
    $pressPath = Join-Path $sessionDir 'brb_first_study_p_case_press_events.csv'
    $ecgBlinkPath = Join-Path $sessionDir 'brb_first_study_p_case_ecg_blink_events.csv'
    $ecgTimeSeriesPath = Join-Path $sessionDir 'brb_first_study_p_case_ecg_timeseries.csv'
    $polarRrPath = Join-Path $sessionDir 'brb_first_study_p_case_polar_rr_events.csv'
    $manifestPath = Join-Path $sessionDir 'session-manifest.json'
    $indexPath = Join-Path $exportRoot 'session-index.jsonl'
    $logPath = Join-Path $caseRoot 'logcat-filtered.txt'
    $summaryPath = Join-Path $caseRoot 'physical-evidence-summary.json'

    $condition1Feedback = 'real_polar_h10'
    $condition2Feedback = 'simulated_neurokit2'
    $condition1Physiology = 'real_polar_h10'
    $condition2Physiology = if ($Mode -eq 'only-one-real-polar-condition') { 'simulated_neurokit2' } else { 'real_polar_h10' }
    $condition1PressEvents = @((New-PressEvent -Condition 1 -Index 1 -FeedbackSource $condition1Feedback))
    $condition2PressEvents = @((New-PressEvent -Condition 2 -Index 1 -FeedbackSource $condition2Feedback))
    if ($Mode -eq 'auto-source') {
        $condition2PressEvents += New-PressEvent -Condition 2 -Index 2 -InputSource 'auto_validation' -Automation $true -FeedbackSource $condition2Feedback
    }
    if ($Mode -eq 'controller-marked-automation') {
        $condition1PressEvents = @((New-PressEvent -Condition 1 -Index 1 -Automation $true -FeedbackSource $condition1Feedback))
    }
    if ($Mode -eq 'missing-press-elapsed-ns') {
        $condition1PressEvents[0]['elapsedNs'] = ''
    }
    if ($Mode -eq 'missing-nearest-ecg-linkage') {
        $condition1PressEvents[0]['nearestEcgSampleIndex'] = ''
        $condition1PressEvents[0]['nearestEcgElapsedNs'] = ''
        $condition1PressEvents[0]['nearestEcgDeltaNs'] = ''
    }
    if ($Mode -eq 'oversized-press-ecg-gap') {
        $condition1PressEvents[0]['nearestEcgDeltaNs'] = 30000000L
    }

    $condition1BlinkEvents = @((New-EcgBlinkEvent -Condition 1 -Source $condition1Feedback))
    $condition2BlinkEvents = @((New-EcgBlinkEvent -Condition 2 -Source $condition2Feedback))
    $condition1PolarRrEvents = @((New-PolarRrEvent -Condition 1 -FeedbackSource $condition1Feedback))
    $condition2PolarRrEvents = @((New-PolarRrEvent -Condition 2 -FeedbackSource $condition2Feedback))
    $condition1Samples = New-EcgSampleSeries -Condition 1
    $condition2SampleSource = if ($Mode -eq 'sham-filled-with-simulated-ecg') { 'simulated_neurokit2' } else { 'real_polar_h10' }
    $condition2Samples = New-EcgSampleSeries -Condition 2 -Source $condition2SampleSource
    if ($Mode -eq 'missing-real-ecg-samples') {
        $condition1Samples = @()
    }
    if ($Mode -eq 'nonmonotonic-ecg-timing' -and @($condition2Samples).Count -ge 5) {
        Set-EcgSampleElapsed -Sample $condition2Samples[4] -ElapsedMs ([double]$condition2Samples[3]['elapsedMs'])
    }
    if ($Mode -eq 'missing-polar-rr') {
        $condition2PolarRrEvents = @()
    }

    $json = [ordered]@{
        schema = 'bigredbutton.first_study.v1'
        sessionId = $sessionId
        demographics = [ordered]@{ participantId = $participantId }
        ecgProtocol = [ordered]@{
            schema = 'bigredbutton.ecg_counterbalanced.v1'
            assignmentOrder = 'real_then_simulated'
            assignmentBasis = 'feedback_source'
            condition1Source = $condition1Feedback
            condition2Source = $condition2Feedback
            condition1FeedbackSource = $condition1Feedback
            condition2FeedbackSource = $condition2Feedback
            condition1PhysiologySource = $condition1Physiology
            condition2PhysiologySource = $condition2Physiology
        }
        conditions = @(
            New-ConditionJson -Condition 1 -FeedbackSource $condition1Feedback -PhysiologySource $condition1Physiology -PressEvents $condition1PressEvents -BlinkEvents $condition1BlinkEvents -PolarRrEvents $condition1PolarRrEvents -Samples $condition1Samples
            New-ConditionJson -Condition 2 -FeedbackSource $condition2Feedback -PhysiologySource $condition2Physiology -PressEvents $condition2PressEvents -BlinkEvents $condition2BlinkEvents -PolarRrEvents $condition2PolarRrEvents -Samples $condition2Samples
        )
    }
    $json | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $pressRows = New-Object System.Collections.Generic.List[string]
    $pressRows.Add('session_id,participant_id,condition_number,press_index,elapsed_ms,elapsed_ns,event_elapsed_realtime_ns,condition_start_elapsed_realtime_ns,unix_time_ms,iso_timestamp,input_source,validation_automation,feedback_source,physiology_source,nearest_ecg_sample_index,nearest_ecg_elapsed_ns,nearest_ecg_delta_ns')
    foreach ($event in @($condition1PressEvents + $condition2PressEvents)) {
        $pressRows.Add("$sessionId,$participantId,$($event.conditionNumber),$($event.pressIndex),$($event.elapsedMs),$($event.elapsedNs),$($event.eventElapsedRealtimeNs),$($event.conditionStartElapsedRealtimeNs),$($event.unixTimeMs),$($event.isoTimestamp),$($event.inputSource),$($event.validationAutomation.ToString().ToLowerInvariant()),$($event.feedbackSource),$($event.physiologySource),$($event.nearestEcgSampleIndex),$($event.nearestEcgElapsedNs),$($event.nearestEcgDeltaNs)")
    }
    $pressRows | Set-Content -LiteralPath $pressPath -Encoding UTF8

    $ecgBlinkRows = New-Object System.Collections.Generic.List[string]
    $ecgBlinkRows.Add('session_id,participant_id,condition_number,blink_index,source,elapsed_ms,unix_time_ms,iso_timestamp,rr_ms,heart_rate_bpm,pulse_intensity_0_1,pulse_source_timestamp_unix_ns,detector')
    foreach ($event in @($condition1BlinkEvents + $condition2BlinkEvents)) {
        $ecgBlinkRows.Add("$sessionId,$participantId,$($event.conditionNumber),$($event.blinkIndex),$($event.source),$($event.elapsedMs),$($event.unixTimeMs),$($event.isoTimestamp),$($event.rrMs),$($event.heartRateBpm),$($event.pulseIntensity01),$($event.pulseSourceTimestampUnixNs),$($event.detector)")
    }
    $ecgBlinkRows | Set-Content -LiteralPath $ecgBlinkPath -Encoding UTF8

    $polarRrRows = New-Object System.Collections.Generic.List[string]
    $polarRrRows.Add('session_id,participant_id,condition_number,rr_index,elapsed_ms,elapsed_ns,unix_time_ms,iso_timestamp,rr_ms,heart_rate_bpm,feedback_source,used_for_feedback')
    foreach ($event in @($condition1PolarRrEvents + $condition2PolarRrEvents)) {
        $polarRrRows.Add("$sessionId,$participantId,$($event.conditionNumber),$($event.rrIndex),$($event.elapsedMs),$($event.elapsedNs),$($event.unixTimeMs),$($event.isoTimestamp),$($event.rrMs),$($event.heartRateBpm),$($event.feedbackSource),$($event.usedForFeedback.ToString().ToLowerInvariant())")
    }
    $polarRrRows | Set-Content -LiteralPath $polarRrPath -Encoding UTF8

    $ecgTimeSeriesRows = New-Object System.Collections.Generic.List[string]
    $ecgTimeSeriesRows.Add('session_id,participant_id,condition_number,sample_index,source,elapsed_ms,elapsed_ns,audio_window_start_ms,audio_window_end_ms,audio_window_duration_ms,unix_time_ms,iso_timestamp,sensor_timestamp_ns,microvolts,sample_rate_hz,frame_index,frame_type,package_size_bytes,requested_mtu,negotiated_mtu')
    foreach ($sample in @($condition1Samples + $condition2Samples)) {
        $ecgTimeSeriesRows.Add("$sessionId,$participantId,$($sample.conditionNumber),$($sample.sampleIndex),$($sample.source),$($sample.elapsedMs),$($sample.elapsedNs),$($sample.audioWindowStartMs),$($sample.audioWindowEndMs),$($sample.audioWindowDurationMs),$($sample.unixTimeMs),$($sample.isoTimestamp),$($sample.sensorTimestampNs),$($sample.microVolts),$($sample.sampleRateHz),$($sample.frameIndex),$($sample.frameType),$($sample.packageSizeBytes),$($sample.requestedMtu),$($sample.negotiatedMtu)")
    }
    $ecgTimeSeriesRows | Set-Content -LiteralPath $ecgTimeSeriesPath -Encoding UTF8

    [ordered]@{
        schema = 'bigredbutton.session_manifest.v1'
        sessionId = $sessionId
        participantId = $participantId
        safeParticipantId = $participantId
        sessionFolder = $sessionFolder
        sessionStartIso = '2026-06-09T12:00:00Z'
        exportedIso = '2026-06-09T12:10:27Z'
        primaryRootName = 'BigRedButtonFirstStudyExports'
        mirrorRootName = 'ExperimentResults'
        manifestFilename = 'session-manifest.json'
        files = @(
            [IO.Path]::GetFileName($jsonPath),
            [IO.Path]::GetFileName($pressPath),
            [IO.Path]::GetFileName($ecgBlinkPath),
            [IO.Path]::GetFileName($ecgTimeSeriesPath),
            [IO.Path]::GetFileName($polarRrPath),
            'session-manifest.json'
        )
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    [ordered]@{
        schema = 'bigredbutton.session_index.v1'
        sessionId = $sessionId
        participantId = $participantId
        safeParticipantId = $participantId
        sessionStartIso = '2026-06-09T12:00:00Z'
        exportedIso = '2026-06-09T12:10:27Z'
        timestampIso = '2026-06-09T12:10:27Z'
        sessionFolder = $sessionFolder
        manifest = "$sessionFolder/session-manifest.json"
        json = "$sessionFolder/$([IO.Path]::GetFileName($jsonPath))"
        pressEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($pressPath))"
        ecgBlinkEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($ecgBlinkPath))"
        ecgTimeSeriesCsv = "$sessionFolder/$([IO.Path]::GetFileName($ecgTimeSeriesPath))"
        polarRrEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($polarRrPath))"
    } | ConvertTo-Json -Compress | Set-Content -LiteralPath $indexPath -Encoding UTF8

    $logLines = New-Object System.Collections.Generic.List[string]
    foreach ($event in @($condition1PressEvents + $condition2PressEvents)) {
        if ($Mode -ne 'missing-accepted-select') {
            $logLines.Add('06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true')
        }
        $logLines.Add("06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_BUTTON_PRESS condition=$($event.conditionNumber) index=$($event.pressIndex) source=$($event.inputSource) validationAutomation=$($event.validationAutomation.ToString().ToLowerInvariant()) elapsedMs=$($event.elapsedMs) elapsedNs=$($event.elapsedNs)")
    }
    if ($Mode -ne 'missing-source-summary') {
        $condition1ControllerCount = @($condition1PressEvents | Where-Object { $_.inputSource -eq 'controller_contact' }).Count
        $condition2ControllerCount = @($condition2PressEvents | Where-Object { $_.inputSource -eq 'controller_contact' }).Count
        if ($Mode -eq 'source-summary-mismatch') {
            $condition2ControllerCount += 1
        }
        $logLines.Add("06-09 12:05:01.000 I/BigRedButtonStudy(123): BRB_CONDITION_PRESS_SOURCES condition=1 total=$($condition1PressEvents.Count) controllerContact=$condition1ControllerCount interimPanel=0 sceneObjectFallback=0 autoValidation=0")
        $logLines.Add("06-09 12:10:27.000 I/BigRedButtonStudy(123): BRB_CONDITION_PRESS_SOURCES condition=2 total=$($condition2PressEvents.Count) controllerContact=$condition2ControllerCount interimPanel=0 sceneObjectFallback=0 autoValidation=0")
    }
    if ($Mode -ne 'missing-low-latency-config') {
        $logLines.Add('06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_POLAR_H10_LOW_LATENCY_CONFIG connectionPriorityHighRequested=true requestedMtu=70 mtuIssued=true strategy=minimum_mtu_low_latency_ecg')
    }
    foreach ($condition in 1..2) {
        $sampleCount = if ($condition -eq 1) { @($condition1Samples).Count } else { @($condition2Samples).Count }
        $logLines.Add("06-09 12:00:00.000 I/BigRedButtonStudy(123): BRB_ECG_CAPTURE_START condition=$condition source=real_polar_h10 audioDurationMs=100 sampleRateHz=130 expectedSamples=13 requestedMtu=70 negotiatedMtu=70")
        $logLines.Add("06-09 12:00:00.100 I/BigRedButtonStudy(123): BRB_ECG_CAPTURE_END condition=$condition source=real_polar_h10 audioDurationMs=100 sampleRateHz=130 expectedSamples=13 actualSamples=$sampleCount captureWindowMs=100")
    }
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
    [pscustomobject]@{ case = New-Case -Name 'only-one-real-polar-condition' -Mode 'only-one-real-polar-condition'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'sham-filled-with-simulated-ecg' -Mode 'sham-filled-with-simulated-ecg'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-press-elapsed-ns' -Mode 'missing-press-elapsed-ns'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-nearest-ecg-linkage' -Mode 'missing-nearest-ecg-linkage'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'nonmonotonic-ecg-timing' -Mode 'nonmonotonic-ecg-timing'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'oversized-press-ecg-gap' -Mode 'oversized-press-ecg-gap'; shouldPass = $false },
    [pscustomobject]@{ case = New-Case -Name 'missing-polar-rr' -Mode 'missing-polar-rr'; shouldPass = $false },
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
