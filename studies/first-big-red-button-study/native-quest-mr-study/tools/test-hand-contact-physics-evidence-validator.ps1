[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\hand-contact-physics-evidence-tests\t-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$validator = Join-Path $projectRoot 'tools\validate-hand-contact-physics-evidence.ps1'

function New-HandEvidenceCase {
    param(
        [string]$Name,
        [string]$LogText,
        [switch]$WithExport,
        [string]$TriggerEvidence = 'hand_contact:collider_hover_contact_actuate:cap_full_surface'
    )
    $dir = Join-Path $OutDir $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'logcat-filtered.txt') -Encoding UTF8 -Value $LogText
    if ($WithExport) {
        $exportDir = Join-Path $dir 'pulled\BigRedButtonFirstStudyExports'
        New-Item -ItemType Directory -Force -Path $exportDir | Out-Null
        $json = [ordered]@{
            sessionId = 'synthetic_hand_physics'
            participantId = 'P_SYNTH'
            conditions = @(
                [ordered]@{
                    conditionNumber = 1
                    pressEvents = @(
                        [ordered]@{
                            conditionNumber = 1
                            pressIndex = 1
                            inputSource = 'hand_contact'
                            validationAutomation = $false
                            pressMechanics = [ordered]@{
                                predictionMode = 'visual_preload'
                                phase = 'impact'
                                impactVelocityMetersPerSecond = 0.42
                                predictedTimeToImpactMs = 42
                                preloadLeadMs = 36
                                confidence01 = 0.84
                                lateralVelocityMetersPerSecond = -0.18
                                predictedLateralAtImpactMeters = 0.024
                                trajectoryFit01 = 0.92
                                approachAngleDegrees = 23.2
                                approachAlignment01 = 0.91
                                impactEnergyJoules = 0.0176
                                springCompressionMeters = 0.0148
                                dampingRatio = 0.55
                                normalImpulseNewtonSeconds = 0.0840
                                estimatedPeakForceNewtons = 4.989
                                estimatedContactPressureKilopascals = 7.68
                                estimatedContactPatchAreaSquareMeters = 0.00065
                                compressionPeak01 = 0.77
                                actuationTravel01 = 0.469
                                actuationDelayMs = 24
                                snapTravel01 = 0.301
                                snapDurationMs = 18
                                bottomOutDelayMs = 68
                                releaseDurationMs = 128
                                visualStartOffsetMs = 44
                                triggerEvidence = $TriggerEvidence
                            }
                        }
                    )
                }
            )
        }
        $json | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $exportDir 'brb_first_study_session.json') -Encoding UTF8
        Set-Content -LiteralPath (Join-Path $exportDir 'brb_first_study_press_events.csv') -Encoding UTF8 -Value @(
            'session_id,participant_id,condition_number,press_index,elapsed_ms,elapsed_ns,event_elapsed_realtime_ns,condition_start_elapsed_realtime_ns,unix_time_ms,iso_timestamp,input_source,validation_automation,feedback_source,physiology_source,press_mechanics_prediction_mode,press_mechanics_phase,press_mechanics_impact_velocity_mps,press_mechanics_predicted_time_to_impact_ms,press_mechanics_preload_lead_ms,press_mechanics_confidence_0_1,press_mechanics_lateral_velocity_mps,press_mechanics_predicted_lateral_at_impact_m,press_mechanics_trajectory_fit_0_1,press_mechanics_approach_angle_deg,press_mechanics_approach_alignment_0_1,press_mechanics_impact_energy_j,press_mechanics_spring_compression_m,press_mechanics_damping_ratio,press_mechanics_normal_impulse_n_s,press_mechanics_estimated_peak_force_n,press_mechanics_estimated_contact_pressure_kpa,press_mechanics_estimated_contact_patch_area_m2,press_mechanics_compression_peak_0_1,press_mechanics_actuation_travel_0_1,press_mechanics_actuation_delay_ms,press_mechanics_snap_travel_0_1,press_mechanics_snap_duration_ms,press_mechanics_bottom_out_delay_ms,press_mechanics_release_duration_ms,press_mechanics_visual_start_offset_ms,press_mechanics_trigger_evidence,nearest_ecg_sample_index,nearest_ecg_elapsed_ns,nearest_ecg_delta_ns',
            "synthetic_hand_physics,P_SYNTH,1,1,123,123000000,1123000000,1000000000,1781006400123,2026-06-09T12:00:00.123Z,hand_contact,false,simulated_neurokit2,real_polar_h10,visual_preload,impact,0.420,42,36,0.840,-0.180,0.024,0.920,23.2,0.910,0.0176,0.0148,0.550,0.0840,4.989,7.68,0.000650,0.770,0.469,24,0.301,18,68,128,44,$TriggerEvidence,7,123000000,0"
        )
    }
    return $dir
}

$validLog = @'
06-17 01:00:00.100 I/BigRedButtonStudy: BRB_BUTTON_HAND_IMPACT_PREDICTED target=button-cap-full-surface role=cap_full_surface distanceM=0.020 lateralM=0.032 normalVelocityMps=0.420 lateralVelocityMps=-0.180 predictedLateralAtImpactM=0.024 trajectoryFit=0.920 approachAngleDeg=23.2 approachAlignment=0.910 timeToImpactMs=42 confidence=0.840 impactEnergyJ=0.0000 springCompressionM=0.0000 dampingRatio=0.550 normalImpulseNewtonSeconds=0.0000 estimatedPeakForceN=0.000 estimatedContactPressureKPa=0.00 estimatedContactPatchAreaM2=0.000000 compressionPeak=0.260 actuationTravel=0.000 actuationDelayMs=0 snapTravel=0.000 snapDurationMs=0 phase=preload predictivePreload=true counted=false sound=false
06-17 01:00:00.142 I/BigRedButtonStudy: BRB_BUTTON_HAND_CONTACT_SELECT accepted=true target=button-cap-full-surface role=cap_full_surface key=hand-1 behavior=COLLIDER_HOVER_CONTACT_ACTUATE handOutlineAllowed=true predictionMode=visual_preload phase=impact impactVelocityMps=0.420 predictedTimeToImpactMs=42 preloadLeadMs=36 confidence=0.840 lateralVelocityMps=-0.180 predictedLateralAtImpactM=0.024 trajectoryFit=0.920 approachAngleDeg=23.2 approachAlignment=0.910 impactEnergyJ=0.0176 springCompressionM=0.0148 dampingRatio=0.550 normalImpulseNewtonSeconds=0.0840 estimatedPeakForceN=4.989 estimatedContactPressureKPa=7.68 estimatedContactPatchAreaM2=0.000650 compressionPeak=0.770 actuationTravel=0.469 actuationDelayMs=24 snapTravel=0.301 snapDurationMs=18 bottomOutDelayMs=68 releaseDurationMs=128 visualStartOffsetMs=44 triggerEvidence=hand_contact:collider_hover_contact_actuate:cap_full_surface
06-17 01:00:00.143 I/BigRedButtonStudy: BRB_BUTTON_PRESS condition=1 index=1 source=hand_contact validationAutomation=false elapsedMs=123 elapsedNs=123000000 feedbackSource=simulated_neurokit2 physiologySource=real_polar_h10
06-17 01:00:00.144 I/BigRedButtonStudy: BRB_BUTTON_PRESS_MECHANICS condition=1 index=1 source=hand_contact predictionMode=visual_preload phase=impact impactVelocityMps=0.420 predictedTimeToImpactMs=42 preloadLeadMs=36 confidence=0.840 lateralVelocityMps=-0.180 predictedLateralAtImpactM=0.024 trajectoryFit=0.920 approachAngleDeg=23.2 approachAlignment=0.910 impactEnergyJ=0.0176 springCompressionM=0.0148 dampingRatio=0.550 normalImpulseNewtonSeconds=0.0840 estimatedPeakForceN=4.989 estimatedContactPressureKPa=7.68 estimatedContactPatchAreaM2=0.000650 compressionPeak=0.770 actuationTravel=0.469 actuationDelayMs=24 snapTravel=0.301 snapDurationMs=18 bottomOutDelayMs=68 releaseDurationMs=128 visualStartOffsetMs=44 triggerEvidence=hand_contact:collider_hover_contact_actuate:cap_full_surface
'@

$cases = New-Object System.Collections.Generic.List[object]

function Invoke-Case {
    param(
        [string]$Name,
        [string]$LogText,
        [bool]$ShouldPass,
        [switch]$WithExport,
        [switch]$RequireExportEvidence,
        [string]$TriggerEvidence = 'hand_contact:collider_hover_contact_actuate:cap_full_surface'
    )
    $dir = New-HandEvidenceCase -Name $Name -LogText $LogText -WithExport:$WithExport -TriggerEvidence $TriggerEvidence
    $outPath = Join-Path $dir 'validation.json'
    $passed = $true
    $errorMessage = ''
    try {
        & $validator -EvidenceDir $dir -RequireExportEvidence:$RequireExportEvidence -OutPath $outPath | Out-Host
    } catch {
        $passed = $false
        $errorMessage = $_.Exception.Message
    }
    if ($passed -ne $ShouldPass) {
        throw "Case $Name expected pass=$ShouldPass but observed pass=$passed. $errorMessage"
    }
    $cases.Add([pscustomobject]@{
        name = $Name
        expectedPass = $ShouldPass
        passed = $passed
        error = $errorMessage
    })
}

Invoke-Case -Name 'valid-log-only' -LogText $validLog -ShouldPass $true
Invoke-Case -Name 'valid-log-and-export' -LogText $validLog -ShouldPass $true -WithExport -RequireExportEvidence
Invoke-Case -Name 'missing-preload' -LogText ($validLog -replace '(?m)^.*BRB_BUTTON_HAND_IMPACT_PREDICTED.*\r?\n?', '') -ShouldPass $false
Invoke-Case -Name 'preload-counted-true' -LogText ($validLog -replace 'counted=false', 'counted=true') -ShouldPass $false
Invoke-Case -Name 'missing-mechanics' -LogText ($validLog -replace '(?m)^.*BRB_BUTTON_PRESS_MECHANICS.*\r?\n?', '') -ShouldPass $false
Invoke-Case -Name 'export-required-missing' -LogText $validLog -ShouldPass $false -RequireExportEvidence
Invoke-Case -Name 'export-trigger-not-hand' -LogText $validLog -ShouldPass $false -WithExport -RequireExportEvidence -TriggerEvidence 'controller_contact:wrong_source'

$summary = [pscustomobject]@{
    status = 'pass'
    generatedAt = (Get-Date).ToString('o')
    validator = $validator
    cases = @($cases.ToArray())
}
$summaryPath = Join-Path $OutDir 'hand-contact-physics-evidence-validator-test-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$cases | Format-Table name, expectedPass, passed, error -AutoSize | Out-Host
Write-Host "PASS hand-contact physics evidence validator tests"
Write-Host "Summary: $summaryPath"
