[CmdletBinding()]
param(
    [string]$EvidenceDir = '',
    [string]$LogcatPath = '',
    [string]$ExportDir = '',
    [switch]$RequireExportEvidence,
    [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
    $EvidenceDir = (Resolve-Path $EvidenceDir).Path
    if ([string]::IsNullOrWhiteSpace($LogcatPath)) {
        $LogcatPath = Join-Path $EvidenceDir 'logcat-filtered.txt'
    }
    if ([string]::IsNullOrWhiteSpace($ExportDir)) {
        $candidateExportDir = Join-Path $EvidenceDir 'pulled\BigRedButtonFirstStudyExports'
        if (Test-Path -LiteralPath $candidateExportDir) {
            $ExportDir = $candidateExportDir
        }
    }
}
if ([string]::IsNullOrWhiteSpace($LogcatPath)) {
    throw 'Provide -LogcatPath or -EvidenceDir containing logcat-filtered.txt.'
}
$LogcatPath = (Resolve-Path $LogcatPath).Path
if (-not [string]::IsNullOrWhiteSpace($ExportDir)) {
    $ExportDir = (Resolve-Path $ExportDir).Path
}
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $outRoot = Join-Path $projectRoot 'artifacts\hand-contact-physics-evidence-validation'
    New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
    $OutPath = Join-Path $outRoot ("hand-contact-physics-evidence-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-MatchesCount {
    param([string]$Text, [string]$Pattern)
    return ([regex]::Matches($Text, $Pattern)).Count
}

$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'fail'
    error = ''
    evidenceDir = $EvidenceDir
    logcatPath = $LogcatPath
    exportDir = $ExportDir
    requireExportEvidence = [bool]$RequireExportEvidence
    predictivePreloadEvents = 0
    acceptedHandSelects = 0
    handContactPresses = 0
    handPressMechanicsEvents = 0
    visualOnlyPreloadEvents = 0
    jsonHandContactPressesWithMechanics = 0
    csvHandContactPressesWithMechanics = 0
}

try {
    $logText = Get-Content -Raw -LiteralPath $LogcatPath
    Assert-Condition (-not [string]::IsNullOrWhiteSpace($logText)) 'Logcat evidence is empty.'
    Assert-Condition (-not [regex]::IsMatch($logText, 'FATAL EXCEPTION|E/AndroidRuntime')) 'Fatal Android runtime marker found in hand-contact evidence.'

    $summary.predictivePreloadEvents = Get-MatchesCount $logText 'BRB_BUTTON_HAND_IMPACT_PREDICTED'
    $summary.visualOnlyPreloadEvents =
        Get-MatchesCount $logText 'BRB_BUTTON_HAND_IMPACT_PREDICTED[^\r\n]*predictivePreload=true[^\r\n]*counted=false[^\r\n]*sound=false'
    $summary.acceptedHandSelects = Get-MatchesCount $logText 'BRB_BUTTON_HAND_CONTACT_SELECT accepted=true'
    $summary.handContactPresses =
        Get-MatchesCount $logText 'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=hand_contact[^\r\n]*validationAutomation=false'
    $summary.handPressMechanicsEvents =
        Get-MatchesCount $logText 'BRB_BUTTON_PRESS_MECHANICS[^\r\n]*source=hand_contact[^\r\n]*predictionMode=(visual_preload|contact_only)[^\r\n]*impactVelocityMps=[0-9.]+[^\r\n]*triggerEvidence=hand_contact'

    Assert-Condition ($summary.predictivePreloadEvents -gt 0) 'Missing BRB_BUTTON_HAND_IMPACT_PREDICTED preload marker.'
    Assert-Condition ($summary.visualOnlyPreloadEvents -eq $summary.predictivePreloadEvents) 'Every predictive preload marker must be predictivePreload=true counted=false sound=false.'
    Assert-Condition ($summary.acceptedHandSelects -gt 0) 'Missing accepted hand-contact select marker.'
    Assert-Condition ($summary.handContactPresses -gt 0) 'Missing accepted BRB_BUTTON_PRESS source=hand_contact validationAutomation=false marker.'
    Assert-Condition ($summary.handPressMechanicsEvents -gt 0) 'Missing BRB_BUTTON_PRESS_MECHANICS source=hand_contact marker with prediction mode, impact velocity, and hand_contact trigger evidence.'

    if (-not [string]::IsNullOrWhiteSpace($ExportDir)) {
        $jsonFiles = @(Get-ChildItem -Path $ExportDir -Recurse -File -Filter '*.json')
        foreach ($file in $jsonFiles) {
            try {
                $json = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
            } catch {
                continue
            }
            if ($json.PSObject.Properties.Name -notcontains 'conditions') {
                continue
            }
            foreach ($condition in @($json.conditions)) {
                foreach ($event in @($condition.pressEvents)) {
                    if ($event.inputSource -eq 'hand_contact' -and $null -ne $event.pressMechanics) {
                        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.pressMechanics.predictionMode)) "JSON hand_contact press missing predictionMode in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'lateralVelocityMetersPerSecond') "JSON hand_contact press missing lateralVelocityMetersPerSecond in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'predictedLateralAtImpactMeters') "JSON hand_contact press missing predictedLateralAtImpactMeters in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'trajectoryFit01') "JSON hand_contact press missing trajectoryFit01 in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'approachAngleDegrees') "JSON hand_contact press missing approachAngleDegrees in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'approachAlignment01') "JSON hand_contact press missing approachAlignment01 in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'impactEnergyJoules') "JSON hand_contact press missing impactEnergyJoules in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'springCompressionMeters') "JSON hand_contact press missing springCompressionMeters in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'dampingRatio') "JSON hand_contact press missing dampingRatio in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'normalImpulseNewtonSeconds') "JSON hand_contact press missing normalImpulseNewtonSeconds in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedPeakForceNewtons') "JSON hand_contact press missing estimatedPeakForceNewtons in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedContactPressureKilopascals') "JSON hand_contact press missing estimatedContactPressureKilopascals in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'estimatedContactPatchAreaSquareMeters') "JSON hand_contact press missing estimatedContactPatchAreaSquareMeters in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'actuationTravel01') "JSON hand_contact press missing actuationTravel01 in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'actuationDelayMs') "JSON hand_contact press missing actuationDelayMs in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'snapTravel01') "JSON hand_contact press missing snapTravel01 in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.PSObject.Properties.Name -contains 'snapDurationMs') "JSON hand_contact press missing snapDurationMs in $($file.FullName)"
                        Assert-Condition (-not [string]::IsNullOrWhiteSpace($event.pressMechanics.triggerEvidence)) "JSON hand_contact press missing triggerEvidence in $($file.FullName)"
                        Assert-Condition ($event.pressMechanics.triggerEvidence -like 'hand_contact*') "JSON hand_contact triggerEvidence must begin with hand_contact in $($file.FullName)"
                        $summary.jsonHandContactPressesWithMechanics += 1
                    }
                }
            }
        }

        $pressCsvFiles = @(Get-ChildItem -Path $ExportDir -Recurse -File -Filter '*press_events.csv')
        foreach ($file in $pressCsvFiles) {
            foreach ($row in @(Import-Csv -LiteralPath $file.FullName)) {
                if ($row.input_source -eq 'hand_contact' -and -not [string]::IsNullOrWhiteSpace($row.press_mechanics_trigger_evidence)) {
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_prediction_mode)) "CSV hand_contact press missing prediction mode in $($file.FullName)"
                    Assert-Condition ($row.press_mechanics_trigger_evidence -like 'hand_contact*') "CSV hand_contact trigger evidence must begin with hand_contact in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_impact_velocity_mps)) "CSV hand_contact press missing impact velocity in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_lateral_velocity_mps)) "CSV hand_contact press missing lateral velocity in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_predicted_lateral_at_impact_m)) "CSV hand_contact press missing predicted lateral-at-impact in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_trajectory_fit_0_1)) "CSV hand_contact press missing trajectory fit in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_approach_angle_deg)) "CSV hand_contact press missing approach angle in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_approach_alignment_0_1)) "CSV hand_contact press missing approach alignment in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_impact_energy_j)) "CSV hand_contact press missing impact energy in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_spring_compression_m)) "CSV hand_contact press missing spring compression in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_damping_ratio)) "CSV hand_contact press missing damping ratio in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_normal_impulse_n_s)) "CSV hand_contact press missing normal impulse in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_estimated_peak_force_n)) "CSV hand_contact press missing estimated peak force in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_estimated_contact_pressure_kpa)) "CSV hand_contact press missing estimated contact pressure in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_estimated_contact_patch_area_m2)) "CSV hand_contact press missing estimated contact patch area in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_actuation_travel_0_1)) "CSV hand_contact press missing actuation travel in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_actuation_delay_ms)) "CSV hand_contact press missing actuation delay in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_snap_travel_0_1)) "CSV hand_contact press missing snap travel in $($file.FullName)"
                    Assert-Condition (-not [string]::IsNullOrWhiteSpace($row.press_mechanics_snap_duration_ms)) "CSV hand_contact press missing snap duration in $($file.FullName)"
                    $summary.csvHandContactPressesWithMechanics += 1
                }
            }
        }
    }

    if ($RequireExportEvidence) {
        Assert-Condition (-not [string]::IsNullOrWhiteSpace($ExportDir)) 'Export evidence is required but no export directory was supplied or discovered.'
        Assert-Condition ($summary.jsonHandContactPressesWithMechanics -gt 0) 'Export JSON is required to contain a hand_contact press with pressMechanics.'
        Assert-Condition ($summary.csvHandContactPressesWithMechanics -gt 0) 'Press-events CSV is required to contain a hand_contact row with press_mechanics_* fields.'
    }

    $summary.status = 'pass'
} catch {
    $summary.error = $_.Exception.Message
    $summary.status = 'fail'
} finally {
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding UTF8
}

Write-Host "Hand-contact physics evidence validation summary: $OutPath"
if ($summary.status -ne 'pass') {
    throw "Hand-contact physics evidence validation failed: $($summary.error)"
}
Write-Host 'PASS hand-contact physics evidence validation'
