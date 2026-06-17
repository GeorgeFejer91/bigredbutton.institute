[CmdletBinding()]
param(
    [string]$ExportDir = '',
    [switch]$Synthetic
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'export-session-layout.ps1')
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
    'prior_big_red_button_experience',
    'prior_big_red_button_experience_bool',
    'prior_big_red_button_experience_timestamp_iso',
    'final_end_confirmation_rating_1_10',
    'final_end_confirmation_immediate_end',
    'final_end_confirmation_timestamp_iso',
    'final_end_confirmation_feedback_text',
    'final_extra_button_press_requirement',
    'final_extra_button_press_count',
    'final_extra_button_press_completed',
    'final_extra_button_press_started_iso',
    'final_extra_button_press_completed_iso',
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
    'hand_predictive_preload_press_count',
    'hand_contact_mean_impact_velocity_mps',
    'interim_panel_press_count',
    'scene_object_fallback_press_count',
    'validation_automation_press_count',
    'ecg_source',
    'feedback_source',
    'physiology_source',
    'ecg_blink_count',
    'ecg_timeseries_sample_count',
    'real_ecg_timeseries_sample_count',
    'polar_rr_event_count',
    'ecg_detector_event_count',
    'external_signal_sample_count',
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
    'redness_carried_forward_vas_0_100',
    'redness_carried_forward_likert_1_7',
    'redness_carried_forward_likert_descriptor',
    'redness_post_conversion_edited',
    'redness_post_conversion_edit_scale',
    'redness_changed_after_conversion',
    'redness_final_matches_carried_forward',
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
    'elapsed_ns',
    'event_elapsed_realtime_ns',
    'condition_start_elapsed_realtime_ns',
    'unix_time_ms',
    'iso_timestamp',
    'input_source',
    'validation_automation',
    'feedback_source',
    'physiology_source',
    'press_mechanics_prediction_mode',
    'press_mechanics_phase',
    'press_mechanics_impact_velocity_mps',
    'press_mechanics_predicted_time_to_impact_ms',
    'press_mechanics_preload_lead_ms',
    'press_mechanics_confidence_0_1',
    'press_mechanics_lateral_velocity_mps',
    'press_mechanics_predicted_lateral_at_impact_m',
    'press_mechanics_trajectory_fit_0_1',
    'press_mechanics_approach_angle_deg',
    'press_mechanics_approach_alignment_0_1',
    'press_mechanics_impact_energy_j',
    'press_mechanics_spring_compression_m',
    'press_mechanics_damping_ratio',
    'press_mechanics_normal_impulse_n_s',
    'press_mechanics_estimated_peak_force_n',
    'press_mechanics_estimated_contact_pressure_kpa',
    'press_mechanics_estimated_contact_patch_area_m2',
    'press_mechanics_compression_peak_0_1',
    'press_mechanics_actuation_travel_0_1',
    'press_mechanics_actuation_delay_ms',
    'press_mechanics_snap_travel_0_1',
    'press_mechanics_snap_duration_ms',
    'press_mechanics_bottom_out_delay_ms',
    'press_mechanics_release_duration_ms',
    'press_mechanics_visual_start_offset_ms',
    'press_mechanics_trigger_evidence',
    'nearest_ecg_sample_index',
    'nearest_ecg_elapsed_ns',
    'nearest_ecg_delta_ns'
)
$requiredFinalExtraPressColumns = @(
    'session_id',
    'participant_id',
    'press_index',
    'elapsed_ms',
    'unix_time_ms',
    'iso_timestamp',
    'input_source',
    'validation_automation',
    'requirement'
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
    'heart_rate_bpm',
    'pulse_intensity_0_1',
    'pulse_source_timestamp_unix_ns',
    'detector'
)
$requiredEcgDetectorColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'detector_index',
    'detector',
    'source',
    'elapsed_ms',
    'elapsed_ns',
    'unix_time_ms',
    'iso_timestamp',
    'sensor_timestamp_ns',
    'microvolts',
    'threshold_microvolts',
    'sample_index'
)
$requiredPolarRrColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'rr_index',
    'elapsed_ms',
    'elapsed_ns',
    'unix_time_ms',
    'iso_timestamp',
    'rr_ms',
    'heart_rate_bpm',
    'feedback_source',
    'used_for_feedback'
)
$requiredExternalSignalColumns = @(
    'session_id',
    'participant_id',
    'condition_number',
    'sample_index',
    'source',
    'stream_name',
    'stream_type',
    'channel_index',
    'value_0_1',
    'elapsed_ms',
    'unix_time_ms',
    'iso_timestamp'
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
    $rootDir = Join-Path $projectRoot ('artifacts\xv\s-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $sessionFolder = '20260609-115900Z_synthetic_participant_syntheti'
    $outDir = Join-Path $rootDir $sessionFolder
    $baseName = 'brb_first_study_p_s'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    $sessionId = 'brb-synthetic-session'
    $participantId = 'synthetic_participant'
    $jsonPath = Join-Path $outDir "$baseName.json"
    $summaryPath = Join-Path $outDir "${baseName}_summary.csv"
    $pressPath = Join-Path $outDir "${baseName}_press_events.csv"
    $finalExtraPressPath = Join-Path $outDir "${baseName}_final_extra_button_presses.csv"
    $ecgBlinkPath = Join-Path $outDir "${baseName}_ecg_blink_events.csv"
    $ecgTimeSeriesPath = Join-Path $outDir "${baseName}_ecg_timeseries.csv"
    $ecgDetectorPath = Join-Path $outDir "${baseName}_ecg_detector_events.csv"
    $polarRrPath = Join-Path $outDir "${baseName}_polar_rr_events.csv"
    $externalSignalPath = Join-Path $outDir "${baseName}_external_signal_samples.csv"
    $manifestPath = Join-Path $outDir 'session-manifest.json'
    $indexPath = Join-Path $rootDir 'session-index.jsonl'

    $conditions = @()
    foreach ($condition in 1..2) {
        $rawAnswers = [ordered]@{}
        $scoredAnswers = [ordered]@{}
        foreach ($item in $ipqItemIds) {
            $rawAnswers[$item] = 3
            $scoredAnswers[$item] = 3
        }
        $feedbackSource = if ($condition -eq 1) { 'simulated_neurokit2' } else { 'real_polar_h10' }
        $audioDurationMs = if ($condition -eq 1) { 300774 } else { 325590 }
        $audioDurationNs = [int64]$audioDurationMs * 1000000L
        $conditionUnixBaseMs = if ($condition -eq 1) { 1781006400000 } else { 1781006700000 }
        $conditionIsoBase = if ($condition -eq 1) { '2026-06-09T12:00:00Z' } else { '2026-06-09T12:05:00Z' }
        $conditions += [ordered]@{
            conditionNumber = $condition
            label = "Condition $condition"
            audioAssetPath = if ($condition -eq 1) { 'localized/en_us/aud_0100_condition_1_instructions__en_us.mp3' } else { 'localized/en_us/aud_0110_condition_2_instructions__en_us.mp3' }
            startedIso = '2026-06-09T12:00:00Z'
            endedIso = '2026-06-09T12:05:00Z'
            elapsedMs = $audioDurationMs
            audioDurationMs = $audioDurationMs
            buttonPressCount = $condition
            ecgSource = 'real_polar_h10'
            feedbackSource = $feedbackSource
            physiologySource = 'real_polar_h10'
            ecgBlinkCount = 1
            ecgCaptureStartedElapsedMs = 0
            ecgCaptureEndedElapsedMs = $audioDurationMs
            ecgCaptureStartedElapsedNs = 0
            ecgCaptureEndedElapsedNs = $audioDurationNs
            ecgCaptureDurationMs = $audioDurationMs
            ecgCaptureDurationNs = $audioDurationNs
            ecgAudioWindowStartMs = 0
            ecgAudioWindowEndMs = $audioDurationMs
            ecgAudioWindowDurationMs = $audioDurationMs
            ecgFirstSampleElapsedMs = 0
            ecgLastSampleElapsedMs = 15.385
            ecgStartBoundaryGapMs = 0
            ecgEndBoundaryGapMs = [math]::Round($audioDurationMs - 15.385, 3)
            ecgSampleRateHz = 130
            ecgExpectedSampleCount = 3
            ecgTimeSeriesSampleCount = 3
            realEcgTimeSeriesSampleCount = 3
            polarRrEventCount = 1
            ecgDetectorEventCount = 1
            externalSignalSampleCount = 0
            ecgRequestedMtu = 70
            ecgNegotiatedMtu = 70
            ecgBlinkEvents = @(
                [ordered]@{
                    conditionNumber = $condition
                    blinkIndex = 1
                    source = $feedbackSource
                    elapsedMs = 830
                    unixTimeMs = $conditionUnixBaseMs + 830
                    isoTimestamp = '2026-06-09T12:00:00.830Z'
                    rrMs = 830.1
                    heartRateBpm = 72
                    pulseIntensity01 = 1.0
                    pulseSourceTimestampUnixNs = ($conditionUnixBaseMs + 830) * 1000000L
                    detector = if ($condition -eq 1) { 'simulated_rr_interval' } else { 'polar_h10_rr_interval' }
                }
            )
            polarRrEvents = @(
                [ordered]@{
                    conditionNumber = $condition
                    rrIndex = 1
                    elapsedMs = 830
                    elapsedNs = 830000000
                    unixTimeMs = $conditionUnixBaseMs + 830
                    isoTimestamp = '2026-06-09T12:00:00.830Z'
                    rrMs = 830.1
                    heartRateBpm = 72
                    feedbackSource = $feedbackSource
                    usedForFeedback = ($feedbackSource -eq 'real_polar_h10')
                }
            )
            ecgDetectorEvents = @(
                [ordered]@{
                    conditionNumber = $condition
                    detectorIndex = 1
                    detector = 'native_threshold_uv800'
                    source = 'real_polar_h10'
                    elapsedMs = 15.385
                    elapsedNs = 15384615
                    unixTimeMs = $conditionUnixBaseMs + 15
                    isoTimestamp = '2026-06-09T12:00:00.015Z'
                    sensorTimestampNs = 15384615
                    microVolts = 1200
                    thresholdMicroVolts = 800
                    sampleIndex = 3
                }
            )
            externalSignalSamples = @()
            ecgTimeSeries = @(
                [ordered]@{
                    conditionNumber = $condition
                    sampleIndex = 1
                    source = 'real_polar_h10'
                    elapsedMs = 0
                    elapsedNs = 0
                    audioWindowStartMs = 0
                    audioWindowEndMs = $audioDurationMs
                    audioWindowDurationMs = $audioDurationMs
                    unixTimeMs = $conditionUnixBaseMs
                    isoTimestamp = $conditionIsoBase
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
                    source = 'real_polar_h10'
                    elapsedMs = 7.692
                    elapsedNs = 7692308
                    audioWindowStartMs = 0
                    audioWindowEndMs = $audioDurationMs
                    audioWindowDurationMs = $audioDurationMs
                    unixTimeMs = $conditionUnixBaseMs + 8
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
                    source = 'real_polar_h10'
                    elapsedMs = 15.385
                    elapsedNs = 15384615
                    audioWindowStartMs = 0
                    audioWindowEndMs = $audioDurationMs
                    audioWindowDurationMs = $audioDurationMs
                    unixTimeMs = $conditionUnixBaseMs + 15
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
                    elapsedMs = 7
                    elapsedNs = 7692308
                    eventElapsedRealtimeNs = 7692308
                    conditionStartElapsedRealtimeNs = 0
                    unixTimeMs = $conditionUnixBaseMs + 8
                    isoTimestamp = '2026-06-09T12:00:01Z'
                    inputSource = 'auto_validation'
                    validationAutomation = $true
                    feedbackSource = $feedbackSource
                    physiologySource = 'real_polar_h10'
                    pressMechanics = [ordered]@{
                        predictionMode = 'none'
                        phase = 'impact'
                        impactVelocityMetersPerSecond = 0.0
                        predictedTimeToImpactMs = -1
                        preloadLeadMs = 0
                        confidence01 = 1.0
                        lateralVelocityMetersPerSecond = 0.0
                        predictedLateralAtImpactMeters = 0.0
                        trajectoryFit01 = 0.0
                        approachAngleDegrees = 0.0
                        approachAlignment01 = 1.0
                        impactEnergyJoules = 0.0
                        springCompressionMeters = 0.0
                        dampingRatio = 0.55
                        normalImpulseNewtonSeconds = 0.0
                        estimatedPeakForceNewtons = 1.35
                        estimatedContactPressureKilopascals = 2.08
                        estimatedContactPatchAreaSquareMeters = 0.00065
                        compressionPeak01 = 1.0
                        actuationTravel01 = 0.469
                        actuationDelayMs = 30
                        snapTravel01 = 0.450
                        snapDurationMs = 16
                        bottomOutDelayMs = 64
                        releaseDurationMs = 132
                        visualStartOffsetMs = 0
                        triggerEvidence = 'auto_validation'
                    }
                    nearestEcgSampleIndex = 2
                    nearestEcgElapsedNs = 7692308
                    nearestEcgDeltaNs = 0
                }
            )
            pictographic = [ordered]@{
                conditionNumber = $condition
                feltCloseness0To100 = 50
                selfButtonDistanceUnits = 300.0
                feltPresence0To100 = 50
                buttonPresenceRadiusUnits = 81.5
                rednessVas0To100 = if ($condition -eq 1) { 63 } else { 38 }
                rednessLikert1To7 = if ($condition -eq 1) { 5 } else { 3 }
                rednessLikertDescriptor = if ($condition -eq 1) { 'very red' } else { 'moderately red' }
                rednessScaleOrder = if ($condition -eq 1) { 'vas_then_likert' } else { 'likert_then_vas' }
                rednessCarriedForwardVas0To100 = if ($condition -eq 1) { 63 } else { 33 }
                rednessCarriedForwardLikert1To7 = if ($condition -eq 1) { 5 } else { 3 }
                rednessCarriedForwardLikertDescriptor = if ($condition -eq 1) { 'very red' } else { 'moderately red' }
                rednessPostConversionEdited = if ($condition -eq 1) { $false } else { $true }
                rednessPostConversionEditScale = if ($condition -eq 1) { 'none' } else { 'vas' }
                rednessChangedAfterConversion = if ($condition -eq 1) { $false } else { $true }
                rednessFinalMatchesCarriedForward = if ($condition -eq 1) { $true } else { $false }
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
        exportLayout = [ordered]@{
            schema = 'bigredbutton.session_folder_export.v1'
            sessionFolderName = $sessionFolder
            primaryRootName = 'BigRedButtonFirstStudyExports'
            mirrorRootName = 'ExperimentResults'
            sessionStartIso = '2026-06-09T11:59:00Z'
            exportedIso = '2026-06-09T12:09:00Z'
            manifestFilename = 'session-manifest.json'
            jsonFilename = [IO.Path]::GetFileName($jsonPath)
            summaryCsvFilename = [IO.Path]::GetFileName($summaryPath)
        }
        validationMode = 'participant'
        participantPhysiologyEvidenceRequired = $true
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
        priorBigRedButtonExperience = [ordered]@{
            question = 'Oh wait, we have just one more question: Do you have any experience with pressing big red buttons?'
            sourceQuestionEnglish = 'Oh wait, we have just one more question: Do you have any experience with pressing big red buttons?'
            languageCode = 'en-US'
            answer = 'yes'
            hasExperience = $true
            timestampIso = '2026-06-09T11:59:30Z'
            shownBeforeCondition = 1
            displayLocation = 'button_counter_panel'
        }
        finalEndConfirmation = [ordered]@{
            question = 'How sure are you that you want to end the experiment, on a scale of 1 to 10?'
            sourceQuestionEnglish = 'How sure are you that you want to end the experiment, on a scale of 1 to 10?'
            languageCode = 'en-US'
            scale = '1-10'
            rating1To10 = 10
            immediateEnd = $true
            selectedTimestampIso = '2026-06-09T12:09:30Z'
            feedbackText = "All right then, I guess you can give the VR headset back then if you don't feel like doing any more button presses."
            extraPressRequirement = 0
            extraPressPrompt = 'That is fantastic! I will take your non-decimal response as a big red YES! Yes I want to continue pressing the big red button! Yes the button is big! Yes the button is red! Yes I want to continue pressing it! FOR SCIENCE, for data collection, for the pursuit of knowledge! Only for science! Forever Science. Well then, you may end the experiment, once you pressed the button 1000 more times. Enjoy!'
            extraPressCount = 0
            extraPressCompleted = $false
            extraPressStartedIso = ''
            extraPressCompletedIso = ''
            extraPressEvents = @()
        }
        agentIntegrationProtocol = [ordered]@{
            schema = 'bigredbutton.agent_integration.v1'
            sourceBrief = 'New-Agent-Integration-Brief.md'
            sourceBriefRepository = 'MesmerPrism/the-big-red-button-institute'
            sourceBriefBranch = 'codex/brb-questionnaire-panel-bridge'
            adaptation = 'native_meta_spatial_sdk_in_process'
            appPackage = 'org.bigredbutton.firststudy'
            unityDependency = $false
            rustyXrBrokerRequired = $false
            localHeadsetExportsOnly = $true
            exportMirror = 'ExperimentResults'
            questionnaire = [ordered]@{
                transport = 'in_process_spatial_panel'
                productCommunication = 'app_internal'
                standalonePanelPackage = 'io.github.mesmerprism.questquestionnaire.panel'
                standalonePanelAdopted = $false
                externalPanelContractCompatibleIfAdopted = $true
                externalPanelContractIfAdopted = [ordered]@{
                    schema = 'quest.questionnaire.v1'
                    calleePackage = 'io.github.mesmerprism.questquestionnaire.panel'
                    launchIntent = 'explicit'
                    requestJsonExtra = 'request_json'
                    resultUriScheme = 'content'
                    resultUriOwner = 'caller'
                    writeUriGrant = $true
                    completionCallback = 'one_shot_immutable_broadcast_pending_intent'
                    answersOnlyWrittenToCallerUri = $true
                    callerReadsOwnResultUri = $true
                    adbProductCommunication = $false
                    publicSharedStorageExchange = $false
                    mediaStoreExchange = $false
                    fileUriExchange = $false
                    packageKillReturnFlow = $false
                    overlayReturnFlow = $false
                    queryAllPackages = $false
                    systemAlertWindow = $false
                }
                answersInLogs = $false
                validationShortcutModes = @(
                    'auto_validation',
                    'physical_press_validation',
                    'keyevent_validation',
                    'fast_controller_flow',
                    'panel_smoke',
                    'demographics_keyboard_validation',
                    'audio_rig_stress',
                    'visual_glow_validation'
                )
            }
            directPolar = [ordered]@{
                enabled = $true
                transport = 'native_ble_pmd_ecg_rr'
                primaryPhysiologySource = $true
                recordsBothConditions = $true
                brokerRequired = $false
                heartbeatBlinkRoute = 'HeartbeatPulseDriver'
                buttonPressRoute = 'none'
            }
            directLsl = [ordered]@{
                enabled = $false
                role = 'diagnostic_only'
                unityCompatibleDefaults = $true
                streamName = 'HRV_Biofeedback'
                streamType = 'HRV'
                channelIndex = 0
                triggerThreshold01 = 0.5
                triggerOnRisingEdgeOnly = $true
                minimumTriggerIntervalMs = 250
                nativeLibraryPackaged = $false
                jniEnabled = $false
                drivesHeartbeatBlink = $false
                drivesButtonPresses = $false
                finalPressProofAllowed = $false
            }
            buttonRoutes = [ordered]@{
                finalParticipantPressProof = 'controller_contact'
                handContactSupplemental = $true
                heartbeatBlinkRoute = 'HeartbeatPulseDriver'
                stableButtonModelDuringBlink = $true
                glowGeometrySwap = $false
                externalSignalPressesSatisfyFinalGate = $false
            }
            forbiddenProductMechanisms = @(
                'adb_relaunch',
                'public_shared_storage_exchange',
                'mediastore_exchange',
                'file_uri',
                'package_kill_return_flow',
                'overlay_return_flow',
                'query_all_packages',
                'system_alert_window'
            )
        }
        questionnaireProtocol = [ordered]@{
            schema = 'bigredbutton.questionnaire_flow.v1'
            transport = 'in_process_spatial_panel'
            stageSequence = @(
                'language_selection',
                'consent_demographics',
                'prior_big_red_button_experience',
                'condition_1',
                'post_condition_1_pictographic',
                'post_condition_1_presence_questionnaire',
                'post_condition_1_lost_opportunity',
                'condition_2',
                'post_condition_2_pictographic',
                'post_condition_2_presence_questionnaire',
                'post_condition_2_lost_opportunity',
                'final_end_confirmation',
                'final_extra_presses_optional',
                'complete_export_summary'
            )
            validationShortcutsAllowed = $true
            validationShortcutModes = @(
                'auto_validation',
                'physical_press_validation',
                'keyevent_validation',
                'fast_controller_flow',
                'panel_smoke',
                'demographics_keyboard_validation',
                'audio_rig_stress',
                'visual_glow_validation'
            )
            productCommunication = 'app_internal'
            adbProductCommunication = $false
            publicSharedStorageExchange = $false
            overlayReturnFlow = $false
            packageKillReturnFlow = $false
        }
        externalSignalProtocol = [ordered]@{
            schema = 'bigredbutton.external_signal.v1'
            enabled = $false
            role = 'diagnostic_only'
            contaminatesPressCounts = $false
            streamName = 'HRV_Biofeedback'
            streamType = 'HRV'
            channelIndex = 0
            triggerThreshold01 = 0.5
            triggerOnRisingEdgeOnly = $true
            minimumTriggerIntervalMs = 250
            route = 'external_signal_samples'
            nativeLibraryPackaged = $false
            jniEnabled = $false
            drivesHeartbeatBlink = $false
            drivesButtonPresses = $false
        }
        ecgProtocol = [ordered]@{
            schema = 'bigredbutton.ecg_counterbalanced.v1'
            assignmentOrder = 'simulated_then_real'
            assignmentBasis = 'feedback_source'
            condition1Source = 'simulated_neurokit2'
            condition2Source = 'real_polar_h10'
            condition1FeedbackSource = 'simulated_neurokit2'
            condition2FeedbackSource = 'real_polar_h10'
            condition1PhysiologySource = 'real_polar_h10'
            condition2PhysiologySource = 'real_polar_h10'
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
        "$sessionId,$participantId,1,1,7,7692308,7692308,0,1781006400008,2026-06-09T12:00:00.008Z,auto_validation,true,simulated_neurokit2,real_polar_h10,none,impact,0.000,-1,0,1.000,0.000,0.000,0.000,0.0,1.000,0.0000,0.0000,0.550,0.0000,1.350,2.08,0.000650,1.000,0.469,30,0.450,16,64,132,0,auto_validation,2,7692308,0",
        "$sessionId,$participantId,2,1,7,7692308,7692308,0,1781006700008,2026-06-09T12:05:00.008Z,auto_validation,true,real_polar_h10,real_polar_h10,none,impact,0.000,-1,0,1.000,0.000,0.000,0.000,0.0,1.000,0.0000,0.0000,0.550,0.0000,1.350,2.08,0.000650,1.000,0.469,30,0.450,16,64,132,0,auto_validation,2,7692308,0"
    )
    Set-Content -LiteralPath $finalExtraPressPath -Encoding UTF8 -Value @(
        ($requiredFinalExtraPressColumns -join ',')
    )
    Set-Content -LiteralPath $ecgBlinkPath -Encoding UTF8 -Value @(
        ($requiredEcgBlinkColumns -join ','),
        "$sessionId,$participantId,1,1,simulated_neurokit2,830,1781006400830,2026-06-09T12:00:00.830Z,830.1,72,1.000,1781006400830000000,simulated_rr_interval",
        "$sessionId,$participantId,2,1,real_polar_h10,830,1781006700830,2026-06-09T12:05:00.830Z,830.1,72,1.000,1781006700830000000,polar_h10_rr_interval"
    )
    Set-Content -LiteralPath $ecgTimeSeriesPath -Encoding UTF8 -Value @(
        ($requiredEcgTimeSeriesColumns -join ','),
        "$sessionId,$participantId,1,1,real_polar_h10,0,0,0,300774,300774,1781006400000,2026-06-09T12:00:00Z,0,0,130,1,0,16,70,70",
        "$sessionId,$participantId,1,2,real_polar_h10,7.692,7692308,0,300774,300774,1781006400008,2026-06-09T12:00:00.008Z,7692308,512,130,1,0,16,70,70",
        "$sessionId,$participantId,1,3,real_polar_h10,15.385,15384615,0,300774,300774,1781006400015,2026-06-09T12:00:00.015Z,15384615,1200,130,1,0,16,70,70",
        "$sessionId,$participantId,2,1,real_polar_h10,0,0,0,325590,325590,1781006700000,2026-06-09T12:05:00Z,0,0,130,1,0,16,70,70",
        "$sessionId,$participantId,2,2,real_polar_h10,7.692,7692308,0,325590,325590,1781006700008,2026-06-09T12:05:00.008Z,7692308,512,130,1,0,16,70,70",
        "$sessionId,$participantId,2,3,real_polar_h10,15.385,15384615,0,325590,325590,1781006700015,2026-06-09T12:05:00.015Z,15384615,1200,130,1,0,16,70,70"
    )
    Set-Content -LiteralPath $ecgDetectorPath -Encoding UTF8 -Value @(
        ($requiredEcgDetectorColumns -join ','),
        "$sessionId,$participantId,1,1,native_threshold_uv800,real_polar_h10,15.385,15384615,1781006400015,2026-06-09T12:00:00.015Z,15384615,1200,800,3",
        "$sessionId,$participantId,2,1,native_threshold_uv800,real_polar_h10,15.385,15384615,1781006700015,2026-06-09T12:05:00.015Z,15384615,1200,800,3"
    )
    Set-Content -LiteralPath $polarRrPath -Encoding UTF8 -Value @(
        ($requiredPolarRrColumns -join ','),
        "$sessionId,$participantId,1,1,830,830000000,1781006400830,2026-06-09T12:00:00.830Z,830.1,72,simulated_neurokit2,false",
        "$sessionId,$participantId,2,1,830,830000000,1781006700830,2026-06-09T12:05:00.830Z,830.1,72,real_polar_h10,true"
    )
    Set-Content -LiteralPath $externalSignalPath -Encoding UTF8 -Value @(
        ($requiredExternalSignalColumns -join ',')
    )
    $sessionFileNames = @(
        [IO.Path]::GetFileName($jsonPath),
        [IO.Path]::GetFileName($summaryPath),
        [IO.Path]::GetFileName($pressPath),
        [IO.Path]::GetFileName($finalExtraPressPath),
        [IO.Path]::GetFileName($ecgBlinkPath),
        [IO.Path]::GetFileName($polarRrPath),
        [IO.Path]::GetFileName($ecgTimeSeriesPath),
        [IO.Path]::GetFileName($ecgDetectorPath),
        [IO.Path]::GetFileName($externalSignalPath),
        'session-manifest.json'
    )
    [ordered]@{
        schema = 'bigredbutton.session_manifest.v1'
        sessionId = $sessionId
        participantId = $participantId
        safeParticipantId = $participantId
        sessionFolder = $sessionFolder
        sessionStartIso = '2026-06-09T11:59:00Z'
        exportedIso = '2026-06-09T12:09:00Z'
        primaryRootName = 'BigRedButtonFirstStudyExports'
        mirrorRootName = 'ExperimentResults'
        manifestFilename = 'session-manifest.json'
        files = $sessionFileNames
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    Add-Content -LiteralPath $indexPath -Encoding UTF8 -Value (@{
        schema = 'bigredbutton.session_index.v1'
        sessionId = $sessionId
        participantId = $participantId
        safeParticipantId = $participantId
        sessionStartIso = '2026-06-09T11:59:00Z'
        exportedIso = '2026-06-09T12:09:00Z'
        timestampIso = '2026-06-09T12:09:00Z'
        sessionFolder = $sessionFolder
        manifest = "$sessionFolder/session-manifest.json"
        json = "$sessionFolder/$([IO.Path]::GetFileName($jsonPath))"
        summaryCsv = "$sessionFolder/$([IO.Path]::GetFileName($summaryPath))"
        pressEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($pressPath))"
        finalExtraButtonPressesCsv = "$sessionFolder/$([IO.Path]::GetFileName($finalExtraPressPath))"
        ecgBlinkEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($ecgBlinkPath))"
        ecgTimeSeriesCsv = "$sessionFolder/$([IO.Path]::GetFileName($ecgTimeSeriesPath))"
        ecgDetectorEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($ecgDetectorPath))"
        polarRrEventsCsv = "$sessionFolder/$([IO.Path]::GetFileName($polarRrPath))"
        externalSignalSamplesCsv = "$sessionFolder/$([IO.Path]::GetFileName($externalSignalPath))"
    } | ConvertTo-Json -Compress)
    return $rootDir
}

if ($Synthetic -or [string]::IsNullOrWhiteSpace($ExportDir)) {
    $ExportDir = New-SyntheticExport
}
$ExportDir = (Resolve-Path $ExportDir).Path
$exportSession = Resolve-BrbExportSession -ExportDir $ExportDir
$ExportSessionDir = $exportSession.SessionDir

$jsonFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter 'brb_first_study_*.json'
$summaryFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_summary.csv'
$pressFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_press_events.csv'
$finalExtraPressFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_final_extra_button_presses.csv'
$ecgBlinkFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_ecg_blink_events.csv'
$ecgTimeSeriesFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_ecg_timeseries.csv'
$ecgDetectorFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_ecg_detector_events.csv'
$polarRrFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_polar_rr_events.csv'
$externalSignalFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_external_signal_samples.csv'
$indexFile = $exportSession.IndexPath
$manifestFile = $exportSession.ManifestPath

Assert-Condition ($null -ne $jsonFile) "Missing JSON export in $ExportSessionDir"
Assert-Condition ($null -ne $summaryFile) "Missing summary CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $pressFile) "Missing press-events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $finalExtraPressFile) "Missing final extra button presses CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $ecgBlinkFile) "Missing ECG blink-events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $ecgTimeSeriesFile) "Missing ECG time-series CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $ecgDetectorFile) "Missing ECG detector-events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $polarRrFile) "Missing Polar RR events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $externalSignalFile) "Missing external signal samples CSV export in $ExportSessionDir"
Assert-Condition (-not [string]::IsNullOrWhiteSpace($manifestFile) -and (Test-Path -LiteralPath $manifestFile)) "Missing session-manifest.json in $ExportSessionDir"
Assert-Condition (Test-Path -LiteralPath $indexFile) "Missing session-index.jsonl in $($exportSession.RootDir)"

$exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
$manifestJson = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json
Assert-Condition ($exportJson.schema -eq 'bigredbutton.first_study.v1') 'JSON schema mismatch'
Assert-Condition ($exportJson.appPackage -eq 'org.bigredbutton.firststudy') 'JSON package mismatch'
Assert-Condition ($null -ne $exportJson.exportLayout) 'Missing exportLayout metadata'
Assert-Condition ($exportJson.exportLayout.schema -eq 'bigredbutton.session_folder_export.v1') 'exportLayout schema mismatch'
Assert-Condition ($exportJson.exportLayout.sessionFolderName -eq $exportSession.SessionFolder) 'exportLayout session folder mismatch'
Assert-Condition ($exportJson.exportLayout.manifestFilename -eq 'session-manifest.json') 'exportLayout manifest filename mismatch'
Assert-Condition ($manifestJson.schema -eq 'bigredbutton.session_manifest.v1') 'Session manifest schema mismatch'
Assert-Condition ($manifestJson.sessionFolder -eq $exportSession.SessionFolder) 'Session manifest folder mismatch'
Assert-Condition (@($manifestJson.files) -contains $jsonFile.Name) 'Session manifest does not list JSON export'
$indexRows = @(Get-Content -LiteralPath $indexFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
$matchingIndexRows = @($indexRows | Where-Object { $_.sessionFolder -eq $exportSession.SessionFolder })
Assert-Condition ($matchingIndexRows.Count -gt 0) 'Root session-index.jsonl does not reference selected session folder'
$latestIndexRow = $matchingIndexRows[-1]
Assert-Condition ("$($latestIndexRow.json)" -eq "$($exportSession.SessionFolder)/$($jsonFile.Name)") 'Root index JSON path does not point to selected session folder'
Assert-Condition ("$($latestIndexRow.summaryCsv)" -eq "$($exportSession.SessionFolder)/$($summaryFile.Name)") 'Root index summary CSV path does not point to selected session folder'
Assert-Condition ($exportJson.demographics.participantId.Length -gt 0) 'Missing demographics.participantId'
Assert-Condition ($exportJson.demographics.signature -match 'brb_signature_strokes_v1') 'Signature must use stroke JSON format'
Assert-Condition ($null -ne $exportJson.priorBigRedButtonExperience) 'Missing priorBigRedButtonExperience'
Assert-Condition ($exportJson.priorBigRedButtonExperience.answer -in @('yes', 'no')) 'Invalid priorBigRedButtonExperience.answer'
Assert-Condition ($null -ne $exportJson.priorBigRedButtonExperience.hasExperience) 'Missing priorBigRedButtonExperience.hasExperience'
Assert-Condition ($exportJson.priorBigRedButtonExperience.shownBeforeCondition -eq 1) 'priorBigRedButtonExperience must be shown before condition 1'
Assert-Condition ($exportJson.priorBigRedButtonExperience.displayLocation -eq 'button_counter_panel') 'priorBigRedButtonExperience display location mismatch'
Assert-Condition ($exportJson.priorBigRedButtonExperience.question.Length -gt 0) 'priorBigRedButtonExperience localized question text missing'
Assert-Condition ($exportJson.priorBigRedButtonExperience.sourceQuestionEnglish -match 'experience with pressing big red buttons') 'priorBigRedButtonExperience English source question mismatch'
Assert-Condition ($exportJson.priorBigRedButtonExperience.languageCode -in @('en-US', 'ja-JP', 'de-DE')) 'priorBigRedButtonExperience language code mismatch'
Assert-Condition ($null -ne $exportJson.finalEndConfirmation) 'Missing finalEndConfirmation'
Assert-Condition ($exportJson.finalEndConfirmation.question.Length -gt 0) 'finalEndConfirmation localized question text missing'
Assert-Condition ($exportJson.finalEndConfirmation.sourceQuestionEnglish -eq 'How sure are you that you want to end the experiment, on a scale of 1 to 10?') 'finalEndConfirmation English source question mismatch'
Assert-Condition ($exportJson.finalEndConfirmation.languageCode -in @('en-US', 'ja-JP', 'de-DE')) 'finalEndConfirmation language code mismatch'
Assert-Condition ($exportJson.finalEndConfirmation.scale -eq '1-10') 'finalEndConfirmation scale mismatch'
Assert-Condition ($exportJson.finalEndConfirmation.rating1To10 -ge 1 -and $exportJson.finalEndConfirmation.rating1To10 -le 10) 'finalEndConfirmation rating out of range'
Assert-Condition ($null -ne $exportJson.finalEndConfirmation.immediateEnd) 'finalEndConfirmation immediateEnd missing'
Assert-Condition ($exportJson.finalEndConfirmation.feedbackText.Length -gt 0) 'finalEndConfirmation feedback text missing'
Assert-Condition ($exportJson.finalEndConfirmation.extraPressCount -ge 0) 'finalEndConfirmation extraPressCount invalid'
if ($exportJson.finalEndConfirmation.immediateEnd -eq $true) {
    Assert-Condition ($exportJson.finalEndConfirmation.rating1To10 -eq 10) 'Immediate end requires rating 10'
    Assert-Condition ($exportJson.finalEndConfirmation.extraPressRequirement -eq 0) 'Immediate end should have no extra press requirement'
} else {
    Assert-Condition ($exportJson.finalEndConfirmation.rating1To10 -ge 1 -and $exportJson.finalEndConfirmation.rating1To10 -le 9) 'Extra press branch requires rating 1-9'
    Assert-Condition ($exportJson.finalEndConfirmation.extraPressRequirement -eq 1000) 'Extra press branch must require 1000 presses'
    Assert-Condition ($exportJson.finalEndConfirmation.extraPressCompleted -eq $true) 'Extra press branch must complete before export'
    Assert-Condition ($exportJson.finalEndConfirmation.extraPressCount -ge 1000) 'Extra press branch exported before 1000 presses'
}
Assert-Condition ($null -ne $exportJson.agentIntegrationProtocol) 'Missing agentIntegrationProtocol'
Assert-Condition ($exportJson.agentIntegrationProtocol.schema -eq 'bigredbutton.agent_integration.v1') 'Agent integration protocol schema mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.sourceBrief -eq 'New-Agent-Integration-Brief.md') 'Agent integration source brief mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.adaptation -eq 'native_meta_spatial_sdk_in_process') 'Agent integration adaptation mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.unityDependency -eq $false) 'Native study must not acquire a Unity dependency'
Assert-Condition ($exportJson.agentIntegrationProtocol.rustyXrBrokerRequired -eq $false) 'Rusty XR broker must not be required'
Assert-Condition ($exportJson.agentIntegrationProtocol.localHeadsetExportsOnly -eq $true) 'Agent integration must keep participant exports local to headset'
Assert-Condition ($exportJson.agentIntegrationProtocol.exportMirror -eq 'ExperimentResults') 'Agent integration export mirror mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.transport -eq 'in_process_spatial_panel') 'Agent integration questionnaire transport mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.productCommunication -eq 'app_internal') 'Agent integration questionnaire communication mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.standalonePanelPackage -eq 'io.github.mesmerprism.questquestionnaire.panel') 'Agent integration panel package reference mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.standalonePanelAdopted -eq $false) 'Standalone panel must not be marked adopted in this native build'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractCompatibleIfAdopted -eq $true) 'External panel compatibility note missing'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.schema -eq 'quest.questionnaire.v1') 'External panel contract schema mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.launchIntent -eq 'explicit') 'External panel contract must use explicit intents'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.requestJsonExtra -eq 'request_json') 'External panel request_json extra mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.resultUriScheme -eq 'content') 'External panel result URI must be content://'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.resultUriOwner -eq 'caller') 'External panel result URI must be caller-owned'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.writeUriGrant -eq $true) 'External panel contract must grant result URI write access'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.completionCallback -eq 'one_shot_immutable_broadcast_pending_intent') 'External panel completion callback mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.answersOnlyWrittenToCallerUri -eq $true) 'External panel answers must be written only to caller URI'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.callerReadsOwnResultUri -eq $true) 'External panel caller must read its own result URI'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.adbProductCommunication -eq $false) 'ADB cannot be questionnaire product communication'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.publicSharedStorageExchange -eq $false) 'Public shared storage cannot be questionnaire exchange'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.mediaStoreExchange -eq $false) 'MediaStore cannot be questionnaire exchange'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.fileUriExchange -eq $false) 'file:// cannot be questionnaire exchange'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.packageKillReturnFlow -eq $false) 'Package killing cannot be questionnaire return flow'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.overlayReturnFlow -eq $false) 'Overlays cannot be questionnaire return flow'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.queryAllPackages -eq $false) 'QUERY_ALL_PACKAGES cannot be required'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.externalPanelContractIfAdopted.systemAlertWindow -eq $false) 'SYSTEM_ALERT_WINDOW cannot be required'
Assert-Condition ($exportJson.agentIntegrationProtocol.questionnaire.answersInLogs -eq $false) 'Agent integration must not log answers'
Assert-Condition ($exportJson.agentIntegrationProtocol.directPolar.enabled -eq $true) 'Agent integration direct Polar route must be active'
Assert-Condition ($exportJson.agentIntegrationProtocol.directPolar.transport -eq 'native_ble_pmd_ecg_rr') 'Agent integration direct Polar transport mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directPolar.recordsBothConditions -eq $true) 'Agent integration direct Polar must record both conditions'
Assert-Condition ($exportJson.agentIntegrationProtocol.directPolar.brokerRequired -eq $false) 'Agent integration direct Polar must be brokerless'
Assert-Condition ($exportJson.agentIntegrationProtocol.directPolar.heartbeatBlinkRoute -eq 'HeartbeatPulseDriver') 'Agent integration direct Polar blink route mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.enabled -eq $false) 'Agent integration direct LSL must remain disabled until JNI/library validation'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.role -eq 'diagnostic_only') 'Agent integration direct LSL role mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.unityCompatibleDefaults -eq $true) 'Agent integration direct LSL defaults should remain Unity-compatible'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.streamName -eq 'HRV_Biofeedback') 'Agent integration direct LSL stream name mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.streamType -eq 'HRV') 'Agent integration direct LSL stream type mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.channelIndex -eq 0) 'Agent integration direct LSL channel index mismatch'
Assert-Condition ([math]::Abs(([double]$exportJson.agentIntegrationProtocol.directLsl.triggerThreshold01) - 0.5) -lt 0.0001) 'Agent integration direct LSL threshold mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.minimumTriggerIntervalMs -eq 250) 'Agent integration direct LSL minimum interval mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.nativeLibraryPackaged -eq $false) 'Agent integration direct LSL native library must not be packaged'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.jniEnabled -eq $false) 'Agent integration direct LSL JNI must remain disabled'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.drivesButtonPresses -eq $false) 'Agent integration direct LSL must not drive button presses'
Assert-Condition ($exportJson.agentIntegrationProtocol.directLsl.finalPressProofAllowed -eq $false) 'Agent integration direct LSL cannot satisfy final press proof'
Assert-Condition ($exportJson.agentIntegrationProtocol.buttonRoutes.finalParticipantPressProof -eq 'controller_contact') 'Agent integration final press proof mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.buttonRoutes.handContactSupplemental -eq $true) 'Agent integration hand-contact provenance missing'
Assert-Condition ($exportJson.agentIntegrationProtocol.buttonRoutes.heartbeatBlinkRoute -eq 'HeartbeatPulseDriver') 'Agent integration blink route mismatch'
Assert-Condition ($exportJson.agentIntegrationProtocol.buttonRoutes.stableButtonModelDuringBlink -eq $true) 'Agent integration stable blink model contract missing'
Assert-Condition ($exportJson.agentIntegrationProtocol.buttonRoutes.externalSignalPressesSatisfyFinalGate -eq $false) 'External signal presses must not satisfy the final gate'
Assert-Condition (@($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'adb_relaunch') 'Agent integration forbidden mechanisms missing adb_relaunch'
Assert-Condition (@($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'public_shared_storage_exchange') 'Agent integration forbidden mechanisms missing public shared storage'
Assert-Condition (@($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'file_uri') 'Agent integration forbidden mechanisms missing file_uri'
Assert-Condition (@($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'query_all_packages') 'Agent integration forbidden mechanisms missing query_all_packages'
Assert-Condition (@($exportJson.agentIntegrationProtocol.forbiddenProductMechanisms) -contains 'system_alert_window') 'Agent integration forbidden mechanisms missing system_alert_window'
Assert-Condition ($null -ne $exportJson.questionnaireProtocol) 'Missing questionnaireProtocol'
Assert-Condition ($exportJson.questionnaireProtocol.schema -eq 'bigredbutton.questionnaire_flow.v1') 'Questionnaire protocol schema mismatch'
Assert-Condition ($exportJson.questionnaireProtocol.transport -eq 'in_process_spatial_panel') 'Questionnaire protocol transport mismatch'
Assert-Condition ($exportJson.questionnaireProtocol.productCommunication -eq 'app_internal') 'Questionnaire protocol product communication must be app_internal'
Assert-Condition ($exportJson.questionnaireProtocol.validationShortcutsAllowed -eq $true) 'Questionnaire validation shortcut allowance missing'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence).Count -eq 14) 'Questionnaire stage sequence length mismatch'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'language_selection') 'Questionnaire stage sequence missing language_selection'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'consent_demographics') 'Questionnaire stage sequence missing consent_demographics'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'prior_big_red_button_experience') 'Questionnaire stage sequence missing prior experience stage'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'post_condition_1_pictographic') 'Questionnaire stage sequence missing condition 1 pictographic stage'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'post_condition_2_lost_opportunity') 'Questionnaire stage sequence missing condition 2 lost opportunity stage'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'final_end_confirmation') 'Questionnaire stage sequence missing final end confirmation'
Assert-Condition (@($exportJson.questionnaireProtocol.stageSequence) -contains 'complete_export_summary') 'Questionnaire stage sequence missing complete export summary'
Assert-Condition (@($exportJson.questionnaireProtocol.validationShortcutModes) -contains 'keyevent_validation') 'Questionnaire shortcut modes missing keyevent validation'
Assert-Condition (@($exportJson.questionnaireProtocol.validationShortcutModes) -contains 'physical_press_validation') 'Questionnaire shortcut modes missing physical press validation'
Assert-Condition ($exportJson.questionnaireProtocol.adbProductCommunication -eq $false) 'ADB must not be product questionnaire communication'
Assert-Condition ($exportJson.questionnaireProtocol.publicSharedStorageExchange -eq $false) 'Public shared storage must not be questionnaire exchange'
Assert-Condition ($exportJson.questionnaireProtocol.overlayReturnFlow -eq $false) 'Overlay return flow must remain disabled'
Assert-Condition ($exportJson.questionnaireProtocol.packageKillReturnFlow -eq $false) 'Package-kill return flow must remain disabled'
Assert-Condition ($null -ne $exportJson.externalSignalProtocol) 'Missing externalSignalProtocol'
Assert-Condition ($exportJson.externalSignalProtocol.schema -eq 'bigredbutton.external_signal.v1') 'External signal protocol schema mismatch'
Assert-Condition ($exportJson.externalSignalProtocol.enabled -eq $false) 'External signal protocol must remain disabled'
Assert-Condition ($exportJson.externalSignalProtocol.role -eq 'diagnostic_only') 'External signal role must be diagnostic_only'
Assert-Condition ($exportJson.externalSignalProtocol.contaminatesPressCounts -eq $false) 'External signal samples must not contaminate press counts'
Assert-Condition ($exportJson.externalSignalProtocol.streamName -eq 'HRV_Biofeedback') 'External signal stream name should match Unity-compatible default'
Assert-Condition ($exportJson.externalSignalProtocol.streamType -eq 'HRV') 'External signal stream type should match Unity-compatible default'
Assert-Condition ($exportJson.externalSignalProtocol.channelIndex -eq 0) 'External signal channel index mismatch'
Assert-Condition ([math]::Abs(([double]$exportJson.externalSignalProtocol.triggerThreshold01) - 0.5) -lt 0.0001) 'External signal trigger threshold mismatch'
Assert-Condition ($exportJson.externalSignalProtocol.triggerOnRisingEdgeOnly -eq $true) 'External signal trigger edge policy mismatch'
Assert-Condition ($exportJson.externalSignalProtocol.minimumTriggerIntervalMs -eq 250) 'External signal minimum trigger interval mismatch'
Assert-Condition ($exportJson.externalSignalProtocol.route -eq 'external_signal_samples') 'External signal route mismatch'
Assert-Condition ($exportJson.externalSignalProtocol.nativeLibraryPackaged -eq $false) 'External signal native library must not be packaged while disabled'
Assert-Condition ($exportJson.externalSignalProtocol.jniEnabled -eq $false) 'External signal JNI must remain disabled'
Assert-Condition ($exportJson.externalSignalProtocol.drivesHeartbeatBlink -eq $false) 'External signal must not drive heartbeat blink'
Assert-Condition ($exportJson.externalSignalProtocol.drivesButtonPresses -eq $false) 'External signal must not drive button presses'
Assert-Condition ($null -ne $exportJson.ecgProtocol) 'Missing ecgProtocol'
Assert-Condition ($exportJson.ecgProtocol.schema -eq 'bigredbutton.ecg_counterbalanced.v1') 'ECG protocol schema mismatch'
Assert-Condition ($exportJson.ecgProtocol.assignmentOrder -in @('real_then_simulated', 'simulated_then_real')) 'Invalid ECG assignment order'
Assert-Condition ($exportJson.ecgProtocol.assignmentBasis -eq 'feedback_source') 'ECG assignment basis must be feedback_source'
Assert-Condition ($exportJson.ecgProtocol.condition1Source -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 1 feedback alias source'
Assert-Condition ($exportJson.ecgProtocol.condition2Source -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 2 feedback alias source'
Assert-Condition ($exportJson.ecgProtocol.condition1FeedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 1 feedback source'
Assert-Condition ($exportJson.ecgProtocol.condition2FeedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) 'Invalid condition 2 feedback source'
Assert-Condition ($exportJson.ecgProtocol.condition1PhysiologySource -eq 'real_polar_h10') 'Condition 1 physiology source must be real_polar_h10'
Assert-Condition ($exportJson.ecgProtocol.condition2PhysiologySource -eq 'real_polar_h10') 'Condition 2 physiology source must be real_polar_h10'
Assert-Condition ($exportJson.ecgProtocol.condition1Source -eq $exportJson.ecgProtocol.condition1FeedbackSource) 'Condition 1 source alias must match feedback source'
Assert-Condition ($exportJson.ecgProtocol.condition2Source -eq $exportJson.ecgProtocol.condition2FeedbackSource) 'Condition 2 source alias must match feedback source'
Assert-Condition ($exportJson.ecgProtocol.condition1FeedbackSource -ne $exportJson.ecgProtocol.condition2FeedbackSource) 'Feedback sources must be counterbalanced complements'
Assert-Condition (
    ($exportJson.ecgProtocol.assignmentOrder -eq 'real_then_simulated' -and $exportJson.ecgProtocol.condition1FeedbackSource -eq 'real_polar_h10' -and $exportJson.ecgProtocol.condition2FeedbackSource -eq 'simulated_neurokit2') -or
    ($exportJson.ecgProtocol.assignmentOrder -eq 'simulated_then_real' -and $exportJson.ecgProtocol.condition1FeedbackSource -eq 'simulated_neurokit2' -and $exportJson.ecgProtocol.condition2FeedbackSource -eq 'real_polar_h10')
) 'ECG assignment order must match feedback sources'
Assert-Condition ($null -ne $exportJson.ecgProtocol.polarH10Status) 'Missing Polar H10 status snapshot'
Assert-Condition (@($exportJson.conditions).Count -eq 2) 'JSON must contain exactly two conditions'
Assert-Condition (@($exportJson.presenceQuestionnaire.items).Count -eq 14) 'Presence questionnaire metadata must contain 14 items'

foreach ($condition in @($exportJson.conditions)) {
    Assert-Condition ($condition.conditionNumber -in @(1, 2)) "Invalid condition number $($condition.conditionNumber)"
    Assert-Condition ($condition.audioDurationMs -gt 0) "Condition $($condition.conditionNumber) missing audioDurationMs"
    Assert-Condition ($condition.buttonPressCount -ge 0) "Condition $($condition.conditionNumber) invalid buttonPressCount"
    Assert-Condition ($condition.ecgSource -eq 'real_polar_h10') "Condition $($condition.conditionNumber) ecgSource compatibility alias must be real_polar_h10 physiology"
    Assert-Condition ($condition.feedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $($condition.conditionNumber) invalid feedbackSource"
    Assert-Condition ($condition.physiologySource -eq 'real_polar_h10') "Condition $($condition.conditionNumber) physiologySource must be real_polar_h10"
    Assert-Condition ($condition.ecgBlinkCount -ge 0) "Condition $($condition.conditionNumber) invalid ecgBlinkCount"
    Assert-Condition ($condition.polarRrEventCount -ge 0) "Condition $($condition.conditionNumber) invalid polarRrEventCount"
    Assert-Condition ($null -ne $condition.ecgBlinkEvents) "Condition $($condition.conditionNumber) missing ecgBlinkEvents"
    Assert-Condition ($null -ne $condition.polarRrEvents) "Condition $($condition.conditionNumber) missing polarRrEvents"
    Assert-Condition ($null -ne $condition.ecgDetectorEvents) "Condition $($condition.conditionNumber) missing ecgDetectorEvents"
    Assert-Condition ($null -ne $condition.externalSignalSamples) "Condition $($condition.conditionNumber) missing externalSignalSamples"
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
    Assert-Condition (@($condition.ecgTimeSeries | Where-Object { $_.source -eq 'simulated_neurokit2' }).Count -eq 0) "Condition $($condition.conditionNumber) must not export simulated ECG rows as real physiology"
    foreach ($event in @($condition.ecgBlinkEvents)) {
        Assert-Condition ($event.source -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $($condition.conditionNumber) ECG blink event has invalid source"
        Assert-Condition ($event.blinkIndex -gt 0) "Condition $($condition.conditionNumber) ECG blink event missing blinkIndex"
        Assert-Condition ($event.rrMs -gt 0) "Condition $($condition.conditionNumber) ECG blink event missing rrMs"
        Assert-Condition ($event.pulseIntensity01 -ge 0 -and $event.pulseIntensity01 -le 1) "Condition $($condition.conditionNumber) ECG blink event pulseIntensity01 out of range"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.detector)) "Condition $($condition.conditionNumber) ECG blink event missing detector"
    }
    foreach ($event in @($condition.polarRrEvents)) {
        Assert-Condition ($event.rrIndex -gt 0) "Condition $($condition.conditionNumber) Polar RR event missing rrIndex"
        Assert-Condition ($event.elapsedMs -ge 0) "Condition $($condition.conditionNumber) Polar RR event has negative elapsedMs"
        Assert-Condition ($event.elapsedNs -ge 0) "Condition $($condition.conditionNumber) Polar RR event has negative elapsedNs"
        Assert-Condition ($event.elapsedNs -le ($condition.audioDurationMs * 1000000)) "Condition $($condition.conditionNumber) Polar RR event elapsedNs exceeds audio duration"
        Assert-Condition ($event.rrMs -gt 0) "Condition $($condition.conditionNumber) Polar RR event missing rrMs"
        Assert-Condition ($event.heartRateBpm -gt 0) "Condition $($condition.conditionNumber) Polar RR event missing heartRateBpm"
        Assert-Condition ($event.feedbackSource -eq $condition.feedbackSource) "Condition $($condition.conditionNumber) Polar RR feedbackSource mismatch"
        Assert-Condition ($null -ne $event.usedForFeedback) "Condition $($condition.conditionNumber) Polar RR event missing usedForFeedback"
    }
    foreach ($event in @($condition.ecgDetectorEvents)) {
        Assert-Condition ($event.detectorIndex -gt 0) "Condition $($condition.conditionNumber) ECG detector event missing detectorIndex"
        Assert-Condition ($event.detector -eq 'native_threshold_uv800') "Condition $($condition.conditionNumber) ECG detector name mismatch"
        Assert-Condition ($event.thresholdMicroVolts -eq 800) "Condition $($condition.conditionNumber) ECG detector threshold mismatch"
    }
    foreach ($sample in @($condition.ecgTimeSeries)) {
        Assert-Condition ($sample.source -eq 'real_polar_h10') "Condition $($condition.conditionNumber) ECG time-series sample must be real Polar physiology"
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
        Assert-Condition ($event.elapsedMs -ge 0) "Condition $($condition.conditionNumber) press event has negative elapsedMs"
        Assert-Condition ($event.elapsedNs -ge 0) "Condition $($condition.conditionNumber) press event missing elapsedNs"
        Assert-Condition ($event.elapsedNs -le ($condition.audioDurationMs * 1000000)) "Condition $($condition.conditionNumber) press event elapsedNs exceeds audio duration"
        Assert-Condition ($event.eventElapsedRealtimeNs -ge $event.conditionStartElapsedRealtimeNs) "Condition $($condition.conditionNumber) press event monotonic clock mismatch"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.inputSource)) "Condition $($condition.conditionNumber) press event missing inputSource"
        Assert-Condition ($null -ne $event.validationAutomation) "Condition $($condition.conditionNumber) press event missing validationAutomation"
        Assert-Condition ($event.feedbackSource -eq $condition.feedbackSource) "Condition $($condition.conditionNumber) press event feedbackSource mismatch"
        Assert-Condition ($event.physiologySource -eq $condition.physiologySource) "Condition $($condition.conditionNumber) press event physiologySource mismatch"
        Assert-Condition ($event.PSObject.Properties.Name -contains 'nearestEcgSampleIndex') "Condition $($condition.conditionNumber) press event missing nearestEcgSampleIndex"
        Assert-Condition ($event.PSObject.Properties.Name -contains 'nearestEcgElapsedNs') "Condition $($condition.conditionNumber) press event missing nearestEcgElapsedNs"
        Assert-Condition ($event.PSObject.Properties.Name -contains 'nearestEcgDeltaNs') "Condition $($condition.conditionNumber) press event missing nearestEcgDeltaNs"
        Assert-Condition ($event.PSObject.Properties.Name -contains 'pressMechanics') "Condition $($condition.conditionNumber) press event missing pressMechanics"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.pressMechanics.predictionMode)) "Condition $($condition.conditionNumber) press mechanics missing predictionMode"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.pressMechanics.phase)) "Condition $($condition.conditionNumber) press mechanics missing phase"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'impactVelocityMetersPerSecond') "Condition $($condition.conditionNumber) press mechanics missing impact velocity"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'predictedTimeToImpactMs') "Condition $($condition.conditionNumber) press mechanics missing predicted time-to-impact"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'preloadLeadMs') "Condition $($condition.conditionNumber) press mechanics missing preload lead"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'confidence01') "Condition $($condition.conditionNumber) press mechanics missing confidence"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'lateralVelocityMetersPerSecond') "Condition $($condition.conditionNumber) press mechanics missing lateral velocity"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'predictedLateralAtImpactMeters') "Condition $($condition.conditionNumber) press mechanics missing predicted lateral-at-impact"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'trajectoryFit01') "Condition $($condition.conditionNumber) press mechanics missing trajectory fit"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'approachAngleDegrees') "Condition $($condition.conditionNumber) press mechanics missing approach angle"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'approachAlignment01') "Condition $($condition.conditionNumber) press mechanics missing approach alignment"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'impactEnergyJoules') "Condition $($condition.conditionNumber) press mechanics missing impact energy"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'springCompressionMeters') "Condition $($condition.conditionNumber) press mechanics missing spring compression"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'dampingRatio') "Condition $($condition.conditionNumber) press mechanics missing damping ratio"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'normalImpulseNewtonSeconds') "Condition $($condition.conditionNumber) press mechanics missing normal impulse"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedPeakForceNewtons') "Condition $($condition.conditionNumber) press mechanics missing estimated peak force"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedContactPressureKilopascals') "Condition $($condition.conditionNumber) press mechanics missing estimated contact pressure"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedContactPatchAreaSquareMeters') "Condition $($condition.conditionNumber) press mechanics missing estimated contact patch area"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'compressionPeak01') "Condition $($condition.conditionNumber) press mechanics missing compression peak"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'actuationTravel01') "Condition $($condition.conditionNumber) press mechanics missing actuation travel"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'actuationDelayMs') "Condition $($condition.conditionNumber) press mechanics missing actuation timing"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'snapTravel01') "Condition $($condition.conditionNumber) press mechanics missing snap travel"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'snapDurationMs') "Condition $($condition.conditionNumber) press mechanics missing snap duration"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'bottomOutDelayMs') "Condition $($condition.conditionNumber) press mechanics missing bottom-out timing"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'releaseDurationMs') "Condition $($condition.conditionNumber) press mechanics missing release timing"
        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'visualStartOffsetMs') "Condition $($condition.conditionNumber) press mechanics missing visual-start offset"
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.pressMechanics.triggerEvidence)) "Condition $($condition.conditionNumber) press mechanics missing triggerEvidence"
    }
    Assert-Condition ($null -ne $condition.pictographic) "Condition $($condition.conditionNumber) missing pictographic"
    Assert-Condition ($condition.pictographic.rednessVas0To100 -ge 0 -and $condition.pictographic.rednessVas0To100 -le 100) "Condition $($condition.conditionNumber) redness VAS out of range"
    Assert-Condition ($condition.pictographic.rednessLikert1To7 -ge 1 -and $condition.pictographic.rednessLikert1To7 -le 7) "Condition $($condition.conditionNumber) redness Likert out of range"
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($condition.pictographic.rednessLikertDescriptor)) "Condition $($condition.conditionNumber) missing redness descriptor"
    Assert-Condition ($condition.pictographic.rednessScaleOrder -in @('vas_then_likert', 'likert_then_vas')) "Condition $($condition.conditionNumber) invalid redness scale order"
    Assert-Condition ($condition.pictographic.rednessCarriedForwardVas0To100 -ge 0 -and $condition.pictographic.rednessCarriedForwardVas0To100 -le 100) "Condition $($condition.conditionNumber) carried-forward redness VAS out of range"
    Assert-Condition ($condition.pictographic.rednessCarriedForwardLikert1To7 -ge 1 -and $condition.pictographic.rednessCarriedForwardLikert1To7 -le 7) "Condition $($condition.conditionNumber) carried-forward redness Likert out of range"
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($condition.pictographic.rednessCarriedForwardLikertDescriptor)) "Condition $($condition.conditionNumber) missing carried-forward redness descriptor"
    Assert-Condition ($null -ne $condition.pictographic.rednessPostConversionEdited) "Condition $($condition.conditionNumber) missing post-conversion edit flag"
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($condition.pictographic.rednessPostConversionEditScale)) "Condition $($condition.conditionNumber) missing post-conversion edit scale"
    Assert-Condition ($null -ne $condition.pictographic.rednessChangedAfterConversion) "Condition $($condition.conditionNumber) missing redness changed-after-conversion flag"
    Assert-Condition ($null -ne $condition.pictographic.rednessFinalMatchesCarriedForward) "Condition $($condition.conditionNumber) missing redness final-matches-carried flag"
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

$finalExtraPressHeader = Get-CsvHeader -Path $finalExtraPressFile.FullName
foreach ($column in $requiredFinalExtraPressColumns) {
    Assert-Condition ($finalExtraPressHeader -contains $column) "Missing final extra button presses column $column"
}

$ecgBlinkHeader = Get-CsvHeader -Path $ecgBlinkFile.FullName
foreach ($column in $requiredEcgBlinkColumns) {
    Assert-Condition ($ecgBlinkHeader -contains $column) "Missing ECG blink-events column $column"
}

$ecgTimeSeriesHeader = Get-CsvHeader -Path $ecgTimeSeriesFile.FullName
foreach ($column in $requiredEcgTimeSeriesColumns) {
    Assert-Condition ($ecgTimeSeriesHeader -contains $column) "Missing ECG time-series column $column"
}

$ecgDetectorHeader = Get-CsvHeader -Path $ecgDetectorFile.FullName
foreach ($column in $requiredEcgDetectorColumns) {
    Assert-Condition ($ecgDetectorHeader -contains $column) "Missing ECG detector-events column $column"
}

$polarRrHeader = Get-CsvHeader -Path $polarRrFile.FullName
foreach ($column in $requiredPolarRrColumns) {
    Assert-Condition ($polarRrHeader -contains $column) "Missing Polar RR events column $column"
}

$externalSignalHeader = Get-CsvHeader -Path $externalSignalFile.FullName
foreach ($column in $requiredExternalSignalColumns) {
    Assert-Condition ($externalSignalHeader -contains $column) "Missing external-signal column $column"
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
    finalExtraButtonPressesCsv = $finalExtraPressFile.FullName
    ecgBlinkEventsCsv = $ecgBlinkFile.FullName
    ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
    ecgDetectorEventsCsv = $ecgDetectorFile.FullName
    polarRrEventsCsv = $polarRrFile.FullName
    externalSignalSamplesCsv = $externalSignalFile.FullName
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "PASS export schema validation"
Write-Host "Export dir: $ExportDir"
Write-Host "Validation summary: $summaryPath"
