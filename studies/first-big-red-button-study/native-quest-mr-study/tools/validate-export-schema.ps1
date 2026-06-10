[CmdletBinding()]
param(
    [string]$ExportDir = '',
    [switch]$Synthetic
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$requiredSummaryColumns = @(
    'session_id',
    'participant_id',
    'name',
    'age',
    'gender',
    'handedness',
    'signature',
    'consent',
    'consent_timestamp_iso',
    'ecg_assignment_order',
    'polar_h10_state',
    'polar_h10_detected',
    'polar_h10_connected',
    'polar_h10_streaming',
    'polar_h10_pmd_ready',
    'polar_h10_ecg_streaming',
    'polar_h10_heart_rate_bpm',
    'polar_h10_rr_interval_count',
    'polar_h10_ecg_sample_count',
    'polar_h10_pmd_frame_count',
    'polar_h10_requested_mtu',
    'polar_h10_negotiated_mtu',
    'polar_h10_ecg_sample_rate_hz',
    'polar_h10_ecg_resolution_bits',
    'polar_h10_missing_permissions'
)
$conditionColumns = @(
    'button_press_count',
    'controller_contact_press_count',
    'hand_contact_press_count',
    'interim_panel_press_count',
    'scene_object_fallback_press_count',
    'validation_automation_press_count',
    'ecg_source',
    'ecg_blink_count',
    'ecg_timeseries_sample_count',
    'ecg_expected_sample_count',
    'ecg_capture_start_elapsed_ms',
    'ecg_capture_end_elapsed_ms',
    'ecg_capture_start_elapsed_ns',
    'ecg_capture_end_elapsed_ns',
    'ecg_capture_duration_ms',
    'ecg_capture_duration_ns',
    'ecg_audio_window_start_ms',
    'ecg_audio_window_end_ms',
    'ecg_audio_window_duration_ms',
    'ecg_first_sample_elapsed_ms',
    'ecg_last_sample_elapsed_ms',
    'ecg_start_boundary_gap_ms',
    'ecg_end_boundary_gap_ms',
    'ecg_sample_rate_hz',
    'ecg_requested_mtu',
    'ecg_negotiated_mtu',
    'audio_duration_ms',
    'elapsed_ms',
    'felt_closeness_0_100',
    'self_button_distance_units',
    'felt_presence_0_100',
    'button_presence_radius_units',
    'redness_vas_0_100',
    'redness_likert_1_7',
    'redness_likert_descriptor',
    'redness_scale_order',
    'lost_opportunity_for_better_results_quotient',
    'ipq_total_mean_0_6',
    'ipq_general_mean_0_6',
    'ipq_spatial_presence_mean_0_6',
    'ipq_involvement_mean_0_6',
    'ipq_experienced_realism_mean_0_6'
)
$ipqItemIds = @(
    'ipq_g1',
    'ipq_sp1',
    'ipq_sp2',
    'ipq_sp3',
    'ipq_sp4',
    'ipq_sp5',
    'ipq_inv1',
    'ipq_inv2',
    'ipq_inv3',
    'ipq_inv4',
    'ipq_real1',
    'ipq_real2',
    'ipq_real3',
    'ipq_real4'
)
$requiredPressColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'press_index',
    'elapsed_ms',
    'unix_time_ms',
    'iso_timestamp',
    'input_source',
    'validation_automation'
)
$requiredEcgBlinkColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'blink_index',
    'source',
    'elapsed_ms',
    'unix_time_ms',
    'iso_timestamp',
    'rr_ms',
    'heart_rate_bpm'
)
$requiredEcgTimeSeriesColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'sample_index',
    'source',
    'elapsed_ms',
    'elapsed_ns',
    'audio_window_start_ms',
    'audio_window_end_ms',
    'audio_window_duration_ms',
    'unix_time_ms',
    'iso_timestamp',
    'sensor_timestamp_ns',
    'microvolts',
    'sample_rate_hz',
    'frame_index',
    'frame_type',
    'package_size_bytes',
    'requested_mtu',
    'negotiated_mtu'
)

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-CsvHeader {
    param([string]$Path)
    $firstLine = Get-Content -LiteralPath $Path -TotalCount 1
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($firstLine)) "CSV has no header: $Path"
    return $firstLine.Split(',')
}

function New-SyntheticExport {
    $outDir = Join-Path $projectRoot ('artifacts\export-schema-validation\synthetic-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $sessionId = 'brb-synthetic-session'
    $participantId = 'synthetic_participant'
    $jsonPath = Join-Path $outDir 'brb_first_study_synthetic_participant_brb-synthetic-session.json'
    $summaryPath = Join-Path $outDir 'brb_first_study_synthetic_participant_brb-synthetic-session_summary.csv'
    $pressPath = Join-Path $outDir 'brb_first_study_synthetic_participant_brb-synthetic-session_press_events.csv'
    $ecgBlinkPath = Join-Path $outDir 'brb_first_study_synthetic_participant_brb-synthetic-session_ecg_blink_events.csv'
    $ecgTimeSeriesPath = Join-Path $outDir 'brb_first_study_synthetic_participant_brb-synthetic-session_ecg_timeseries.csv'
    $indexPath = Join-Path $outDir 'session-index.jsonl'

    $conditions = @()
    foreach ($condition in 1..2) {
        $rawAnswers = [ordered]@{}
        $scoredAnswers = [ordered]@{}
        foreach ($item in $ipqItemIds) {
            $rawAnswers[$item] = 3
            $scoredAnswers[$item] = 3
        }
        $conditions += [ordered]@{
            conditionNumber = $condition
            label = "Condition $condition"
            audioAssetPath = if ($condition -eq 1) { 'first-big-red-button-vr-study-instructions-final.mp3' } else { 'first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3' }
            startedIso = '2026-06-09T12:00:00Z'
            endedIso = '2026-06-09T12:05:00Z'
            elapsedMs = if ($condition -eq 1) { 300774 } else { 325590 }
            audioDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
            buttonPressCount = $condition
            ecgSource = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
            ecgBlinkCount = 1
            ecgCaptureStartedElapsedMs = 0
            ecgCaptureEndedElapsedMs = if ($condition -eq 1) { 300774 } else { 325590 }
            ecgCaptureStartedElapsedNs = 0
            ecgCaptureEndedElapsedNs = if ($condition -eq 1) { 300774000000 } else { 325590000000 }
            ecgCaptureDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
            ecgCaptureDurationNs = if ($condition -eq 1) { 300774000000 } else { 325590000000 }
            ecgAudioWindowStartMs = 0
            ecgAudioWindowEndMs = if ($condition -eq 1) { 300774 } else { 325590 }
            ecgAudioWindowDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
            ecgFirstSampleElapsedMs = 0
            ecgLastSampleElapsedMs = 15.385
            ecgStartBoundaryGapMs = 0
            ecgEndBoundaryGapMs = if ($condition -eq 1) { 300758.615 } else { 325574.615 }
            ecgSampleRateHz = 130
            ecgExpectedSampleCount = 3
            ecgTimeSeriesSampleCount = 3
            ecgRequestedMtu = 70
            ecgNegotiatedMtu = 70
            ecgBlinkEvents = @(
                [ordered]@{
                    conditionNumber = $condition
                    blinkIndex = 1
                    source = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
                    elapsedMs = 830
                    unixTimeMs = 1781006400830
                    isoTimestamp = '2026-06-09T12:00:00.830Z'
                    rrMs = 830.1
                    heartRateBpm = 72
                }
            )
            ecgTimeSeries = @(
                [ordered]@{
                    conditionNumber = $condition
                    sampleIndex = 1
                    source = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
                    elapsedMs = 0
                    elapsedNs = 0
                    audioWindowStartMs = 0
                    audioWindowEndMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    audioWindowDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    unixTimeMs = 1781006400000
                    isoTimestamp = '2026-06-09T12:00:00Z'
                    sensorTimestampNs = 0
                    microVolts = 0
                    sampleRateHz = 130
                    frameIndex = 1
                    frameType = 0
                    packageSizeBytes = 16
                    requestedMtu = 70
                    negotiatedMtu = 70
                },
                [ordered]@{
                    conditionNumber = $condition
                    sampleIndex = 2
                    source = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
                    elapsedMs = 7.692
                    elapsedNs = 7692308
                    audioWindowStartMs = 0
                    audioWindowEndMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    audioWindowDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    unixTimeMs = 1781006400008
                    isoTimestamp = '2026-06-09T12:00:00.008Z'
                    sensorTimestampNs = 7692308
                    microVolts = 512
                    sampleRateHz = 130
                    frameIndex = 1
                    frameType = 0
                    packageSizeBytes = 16
                    requestedMtu = 70
                    negotiatedMtu = 70
                },
                [ordered]@{
                    conditionNumber = $condition
                    sampleIndex = 3
                    source = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
                    elapsedMs = 15.385
                    elapsedNs = 15384615
                    audioWindowStartMs = 0
                    audioWindowEndMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    audioWindowDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
                    unixTimeMs = 1781006400015
                    isoTimestamp = '2026-06-09T12:00:00.015Z'
                    sensorTimestampNs = 15384615
                    microVolts = 1200
                    sampleRateHz = 130
                    frameIndex = 1
                    frameType = 0
                    packageSizeBytes = 16
                    requestedMtu = 70
                    negotiatedMtu = 70
                }
            )
            pressEvents = @(
                [ordered]@{
                    conditionNumber = $condition
                    pressIndex = 1
                    elapsedMs = 1000
                    unixTimeMs = 1781006400000
                    isoTimestamp = '2026-06-09T12:00:01Z'
                    inputSource = 'auto_validation'
                    validationAutomation = $true
                }
            )
            pictographic = [ordered]@{
                conditionNumber = $condition
                feltCloseness0To100 = 50
                selfButtonDistanceUnits = 220.0
                feltPresence0To100 = 50
                buttonPresenceRadiusUnits = 81.5
                rednessVas0To100 = if ($condition -eq 1) { 63 } else { 38 }
                rednessLikert1To7 = if ($condition -eq 1) { 5 } else { 3 }
                rednessLikertDescriptor = if ($condition -eq 1) { 'very red' } else { 'moderately red' }
                rednessScaleOrder = if ($condition -eq 1) { 'vas_then_likert' } else { 'likert_then_vas' }
                timestampIso = '2026-06-09T12:06:00Z'
            }
            presenceQuestionnaire = [ordered]@{
                conditionNumber = $condition
                rawAnswers0To6 = $rawAnswers
                scoredAnswers0To6 = $scoredAnswers
                subscaleMeans0To6 = [ordered]@{
                    general = 3
                    spatial_presence = 3
                    involvement = 3
                    experienced_realism = 3
                }
                totalMean0To6 = 3
                timestampIso = '2026-06-09T12:07:00Z'
            }
            lostOpportunity = [ordered]@{
                conditionNumber = $condition
                score0To100 = 50
                variableName = 'Lost Opportunity for better results quotient'
                timestampIso = '2026-06-09T12:08:00Z'
            }
        }
    }

    $json = [ordered]@{
        schema = 'bigredbutton.first_study.v1'
        appPackage = 'org.bigredbutton.firststudy'
        appVersion = '0.1.0'
        sessionId = $sessionId
        exportedAtIso = '2026-06-09T12:09:00Z'
        demographics = [ordered]@{
            participantId = $participantId
            name = 'Synthetic'
            age = '33'
            gender = 'synthetic'
            handedness = 'right'
            signature = '{"format":"brb_signature_strokes_v1","widthPx":1200,"heightPx":360,"strokeCount":1,"pointCount":3,"validationSample":true,"strokes":[{"index":0,"points":[{"index":0,"xNorm":0.18,"yNorm":0.62,"tMs":0}]}]}'
            consent = $true
            consentTimestampIso = '2026-06-09T11:59:00Z'
        }
        ecgProtocol = [ordered]@{
            schema = 'bigredbutton.ecg_counterbalanced.v1'
            assignmentOrder = 'simulated_then_real'
            condition1Source = 'simulated_neurokit2'
            condition2Source = 'real_polar_h10'
            simulatedRrAsset = 'ecg/neurokit2_simulated_rr_intervals_ms.csv'
            simulatedRrCount = 865
            polarH10Status = [ordered]@{
                state = 'streaming'
                detected = $true
                connected = $true
                streaming = $true
                pmdReady = $true
                ecgStreaming = $true
                deviceName = 'Synthetic Polar H10'
                deviceAddress = '00:00:00:00:00:00'
                heartRateBpm = 72
                rrIntervalCount = 2
                ecgSampleCount = 6
                pmdFrameCount = 2
                lastEventElapsedMs = 123456
                lastEcgEventElapsedMs = 123789
                requestedMtu = 70
                negotiatedMtu = 70
                connectionPriorityHighRequested = $true
                ecgSampleRateHz = 130
                ecgResolutionBits = 14
                missingPermissions = ''
                error = ''
            }
        }
        conditionOrder = @(1, 2)
        conditions = $conditions
        presenceQuestionnaire = [ordered]@{
            sourceInstrument = 'Igroup Presence Questionnaire'
            adaptation = 'Items are reworded to refer to the Big Red Button in the previous session.'
            scale = '0-6'
            items = @($ipqItemIds | ForEach-Object { [ordered]@{ id = $_; subscale = 'synthetic'; text = $_; reverse = $false } })
        }
    }
    $json | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

    $summaryColumns = New-Object System.Collections.Generic.List[string]
    $requiredSummaryColumns | ForEach-Object { $summaryColumns.Add($_) }
    foreach ($condition in 1..2) {
        $conditionColumns | ForEach-Object { $summaryColumns.Add("condition_${condition}_$_") }
        $ipqItemIds | ForEach-Object { $summaryColumns.Add("condition_${condition}_${_}_raw_0_6") }
        $ipqItemIds | ForEach-Object { $summaryColumns.Add("condition_${condition}_${_}_scored_0_6") }
    }
    $summaryValues = @($summaryColumns | ForEach-Object { '1' })
    Set-Content -LiteralPath $summaryPath -Encoding UTF8 -Value @(
        ($summaryColumns -join ','),
        ($summaryValues -join ',')
    )

    Set-Content -LiteralPath $pressPath -Encoding UTF8 -Value @(
        ($requiredPressColumns -join ','),
        "$sessionId,$participantId,1,1,1000,1781006400000,2026-06-09T12:00:01Z,auto_validation,true",
        "$sessionId,$participantId,2,1,1000,1781006400000,2026-06-09T12:05:01Z,auto_validation,true"
    )
    Set-Content -LiteralPath $ecgBlinkPath -Encoding UTF8 -Value @(
        ($requiredEcgBlinkColumns -join ','),
        "$sessionId,$participantId,1,1,simulated_neurokit2,830,1781006400830,2026-06-09T12:00:00.830Z,830.1,72",
        "$sessionId,$participantId,2,1,real_polar_h10,830,1781006700830,2026-06-09T12:05:00.830Z,830.1,72"
    )
    Set-Content -LiteralPath $ecgTimeSeriesPath -Encoding UTF8 -Value @(
        ($requiredEcgTimeSeriesColumns -join ','),
        "$sessionId,$participantId,1,1,simulated_neurokit2,0,0,0,300774,300774,1781006400000,2026-06-09T12:00:00Z,0,0,130,1,0,16,70,70",
        "$sessionId,$participantId,1,2,simulated_neurokit2,7.692,7692308,0,300774,300774,1781006400008,2026-06-09T12:00:00.008Z,7692308,512,130,1,0,16,70,70",
        "$sessionId,$participantId,2,1,real_polar_h10,0,0,0,325590,325590,1781006700000,2026-06-09T12:05:00Z,0,0,130,1,0,16,70,70",
        "$sessionId,$participantId,2,2,real_polar_h10,7.692,7692308,0,325590,325590,1781006700008,2026-06-09T12:05:00.008Z,7692308,512,130,1,0,16,70,70"
    )
    Add-Content -LiteralPath $indexPath -Encoding UTF8 -Value (@{
        sessionId = $sessionId
        participantId = $participantId
        timestampIso = '2026-06-09T12:09:00Z'
        json = [IO.Path]::GetFileName($jsonPath)
        summaryCsv = [IO.Path]::GetFileName($summaryPath)
        pressEventsCsv = [IO.Path]::GetFileName($pressPath)
        ecgBlinkEventsCsv = [IO.Path]::GetFileName($ecgBlinkPath)
        ecgTimeSeriesCsv = [IO.Path]::GetFileName($ecgTimeSeriesPath)
    } | ConvertTo-Json -Compress)
    return $outDir
}

if ($Synthetic -or [string]::IsNullOrWhiteSpace($ExportDir)) {
    $ExportDir = New-SyntheticExport
}
$ExportDir = (Resolve-Path $ExportDir).Path

$jsonFile = Get-ChildItem -LiteralPath $ExportDir -Filter 'brb_first_study_*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$summaryFile = Get-ChildItem -LiteralPath $ExportDir -Filter '*_summary.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$pressFile = Get-ChildItem -LiteralPath $ExportDir -Filter '*_press_events.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$ecgBlinkFile = Get-ChildItem -LiteralPath $ExportDir -Filter '*_ecg_blink_events.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$ecgTimeSeriesFile = Get-ChildItem -LiteralPath $ExportDir -Filter '*_ecg_timeseries.csv' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$indexFile = Join-Path $ExportDir 'session-index.jsonl'

Assert-Condition ($null -ne $jsonFile) "Missing JSON export in $ExportDir"
Assert-Condition ($null -ne $summaryFile) "Missing summary CSV export in $ExportDir"
Assert-Condition ($null -ne $pressFile) "Missing press-events CSV export in $ExportDir"
Assert-Condition ($null -ne $ecgBlinkFile) "Missing ECG blink-events CSV export in $ExportDir"
Assert-Condition ($null -ne $ecgTimeSeriesFile) "Missing ECG time-series CSV export in $ExportDir"
Assert-Condition (Test-Path $indexFile) "Missing session-index.jsonl in $ExportDir"

$exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
Assert-Condition ($exportJson.schema -eq 'bigredbutton.first_study.v1') 'JSON schema mismatch'
Assert-Condition ($exportJson.appPackage -eq 'org.bigredbutton.firststudy') 'JSON package mismatch'
Assert-Condition ($exportJson.demographics.participantId.Length -gt 0) 'Missing demographics.participantId'
Assert-Condition ($exportJson.demographics.signature -match 'brb_signature_strokes_v1') 'Signature must use stroke JSON format'
Assert-Condition ($null -ne $exportJson.ecgProtocol) 'Missing ecgProtocol'
Assert-Condition ($exportJson.ecgProtocol.schema -eq 'bigredbutton.ecg_counterbalanced.v1') 'ECG protocol schema mismatch'
Assert-Condition ($exportJson.ecgProtocol.assignmentOrder -in @('real_then_simulated', 'simulated_then_real')) 'Invalid ECG assignment order'
Assert-Condition ($exportJson.ecgProtocol.condition1Source -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 1 ECG source'
Assert-Condition ($exportJson.ecgProtocol.condition2Source -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 2 ECG source'
Assert-Condition ($null -ne $exportJson.ecgProtocol.polarH10Status) 'Missing Polar H10 status snapshot'
Assert-Condition (@($exportJson.conditions).Count -eq 2) 'JSON must contain exactly two conditions'
Assert-Condition (@($exportJson.presenceQuestionnaire.items).Count -eq 14) 'Presence questionnaire metadata must contain 14 items'

foreach ($condition in @($exportJson.conditions)) {
    Assert-Condition ($condition.conditionNumber -in @(1, 2)) "Invalid condition number $($condition.conditionNumber)"
    Assert-Condition ($condition.audioDurationMs -gt 0) "Condition $($condition.conditionNumber) missing audioDurationMs"
    Assert-Condition ($condition.buttonPressCount -ge 0) "Condition $($condition.conditionNumber) invalid buttonPressCount"
    Assert-Condition ($condition.ecgSource -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $($condition.conditionNumber) invalid ecgSource"
    Assert-Condition ($condition.ecgBlinkCount -ge 0) "Condition $($condition.conditionNumber) invalid ecgBlinkCount"
    Assert-Condition ($null -ne $condition.ecgBlinkEvents) "Condition $($condition.conditionNumber) missing ecgBlinkEvents"
    Assert-Condition ($condition.ecgCaptureDurationMs -eq $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG capture duration must match audio duration"
    Assert-Condition ($condition.ecgCaptureDurationNs -eq ($condition.audioDurationMs * 1000000)) "Condition $($condition.conditionNumber) ECG capture duration ns must match audio duration"
    Assert-Condition (($condition.ecgCaptureEndedElapsedNs - $condition.ecgCaptureStartedElapsedNs) -eq ($condition.audioDurationMs * 1000000)) "Condition $($condition.conditionNumber) ECG capture ns window must match audio duration"
    Assert-Condition ($condition.ecgAudioWindowStartMs -eq 0) "Condition $($condition.conditionNumber) ECG audio window must start at 0 ms"
    Assert-Condition ($condition.ecgAudioWindowEndMs -eq $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG audio window end must equal audio duration"
    Assert-Condition ($condition.ecgAudioWindowDurationMs -eq $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG audio window duration must equal audio duration"
    Assert-Condition ($condition.ecgSampleRateHz -eq 130) "Condition $($condition.conditionNumber) ECG sample rate should be 130 Hz"
    Assert-Condition ($condition.ecgExpectedSampleCount -ge 1) "Condition $($condition.conditionNumber) missing ECG expected sample count"
    Assert-Condition ($condition.ecgTimeSeriesSampleCount -ge 0) "Condition $($condition.conditionNumber) invalid ECG time-series sample count"
    Assert-Condition ($null -ne $condition.ecgTimeSeries) "Condition $($condition.conditionNumber) missing ecgTimeSeries"
    if ($condition.ecgSource -eq 'simulated_neurokit2') {
        Assert-Condition ($condition.ecgTimeSeriesSampleCount -eq $condition.ecgExpectedSampleCount) "Condition $($condition.conditionNumber) simulated ECG must contain expected sample count"
    }
    foreach ($event in @($condition.ecgBlinkEvents)) {
        Assert-Condition ($event.source -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $($condition.conditionNumber) ECG blink event has invalid source"
        Assert-Condition ($event.blinkIndex -gt 0) "Condition $($condition.conditionNumber) ECG blink event missing blinkIndex"
        Assert-Condition ($event.rrMs -gt 0) "Condition $($condition.conditionNumber) ECG blink event missing rrMs"
    }
    foreach ($sample in @($condition.ecgTimeSeries)) {
        Assert-Condition ($sample.source -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $($condition.conditionNumber) ECG time-series sample has invalid source"
        Assert-Condition ($sample.sampleIndex -gt 0) "Condition $($condition.conditionNumber) ECG time-series sample missing sampleIndex"
        Assert-Condition ($sample.elapsedMs -ge 0) "Condition $($condition.conditionNumber) ECG time-series sample has negative elapsedMs"
        Assert-Condition ($sample.elapsedNs -ge 0) "Condition $($condition.conditionNumber) ECG time-series sample has negative elapsedNs"
        Assert-Condition ($sample.elapsedMs -le $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG time-series sample exceeds audio duration"
        Assert-Condition ($sample.elapsedNs -le ($condition.audioDurationMs * 1000000)) "Condition $($condition.conditionNumber) ECG time-series sample elapsedNs exceeds audio duration"
        Assert-Condition ($sample.audioWindowStartMs -eq 0) "Condition $($condition.conditionNumber) ECG sample audio window start mismatch"
        Assert-Condition ($sample.audioWindowEndMs -eq $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG sample audio window end mismatch"
        Assert-Condition ($sample.audioWindowDurationMs -eq $condition.audioDurationMs) "Condition $($condition.conditionNumber) ECG sample audio window duration mismatch"
        Assert-Condition ($sample.sampleRateHz -eq 130) "Condition $($condition.conditionNumber) ECG time-series sample should be 130 Hz"
    }
    foreach ($event in @($condition.pressEvents)) {
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.inputSource)) "Condition $($condition.conditionNumber) press event missing inputSource"
        Assert-Condition ($null -ne $event.validationAutomation) "Condition $($condition.conditionNumber) press event missing validationAutomation"
    }
    Assert-Condition ($null -ne $condition.pictographic) "Condition $($condition.conditionNumber) missing pictographic"
    Assert-Condition ($condition.pictographic.rednessVas0To100 -ge 0 -and $condition.pictographic.rednessVas0To100 -le 100) "Condition $($condition.conditionNumber) redness VAS out of range"
    Assert-Condition ($condition.pictographic.rednessLikert1To7 -ge 1 -and $condition.pictographic.rednessLikert1To7 -le 7) "Condition $($condition.conditionNumber) redness Likert out of range"
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($condition.pictographic.rednessLikertDescriptor)) "Condition $($condition.conditionNumber) missing redness descriptor"
    Assert-Condition ($condition.pictographic.rednessScaleOrder -in @('vas_then_likert', 'likert_then_vas')) "Condition $($condition.conditionNumber) invalid redness scale order"
    Assert-Condition ($null -ne $condition.presenceQuestionnaire) "Condition $($condition.conditionNumber) missing presenceQuestionnaire"
    Assert-Condition ($null -ne $condition.lostOpportunity) "Condition $($condition.conditionNumber) missing lostOpportunity"
    Assert-Condition ($condition.lostOpportunity.variableName -eq 'Lost Opportunity for better results quotient') "Condition $($condition.conditionNumber) lostOpportunity variable mismatch"
}

$summaryHeader = Get-CsvHeader -Path $summaryFile.FullName
foreach ($column in $requiredSummaryColumns) {
    Assert-Condition ($summaryHeader -contains $column) "Missing summary column $column"
}
foreach ($condition in 1..2) {
    foreach ($suffix in $conditionColumns) {
        $column = "condition_${condition}_$suffix"
        Assert-Condition ($summaryHeader -contains $column) "Missing summary column $column"
    }
    foreach ($item in $ipqItemIds) {
        Assert-Condition ($summaryHeader -contains "condition_${condition}_${item}_raw_0_6") "Missing raw IPQ summary column condition_${condition}_${item}_raw_0_6"
        Assert-Condition ($summaryHeader -contains "condition_${condition}_${item}_scored_0_6") "Missing scored IPQ summary column condition_${condition}_${item}_scored_0_6"
    }
}

$pressHeader = Get-CsvHeader -Path $pressFile.FullName
foreach ($column in $requiredPressColumns) {
    Assert-Condition ($pressHeader -contains $column) "Missing press-events column $column"
}

$ecgBlinkHeader = Get-CsvHeader -Path $ecgBlinkFile.FullName
foreach ($column in $requiredEcgBlinkColumns) {
    Assert-Condition ($ecgBlinkHeader -contains $column) "Missing ECG blink-events column $column"
}

$ecgTimeSeriesHeader = Get-CsvHeader -Path $ecgTimeSeriesFile.FullName
foreach ($column in $requiredEcgTimeSeriesColumns) {
    Assert-Condition ($ecgTimeSeriesHeader -contains $column) "Missing ECG time-series column $column"
}

$outRoot = Join-Path $projectRoot 'artifacts\export-schema-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("export-schema-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
[pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    exportDir = $ExportDir
    json = $jsonFile.FullName
    summaryCsv = $summaryFile.FullName
    pressEventsCsv = $pressFile.FullName
    ecgBlinkEventsCsv = $ecgBlinkFile.FullName
    ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "PASS export schema validation"
Write-Host "Export dir: $ExportDir"
Write-Host "Validation summary: $summaryPath"
