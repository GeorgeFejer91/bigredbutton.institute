[CmdletBinding()]
param(
    [string]$OutDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\hand-contact-press-mechanics-analysis-tests\t-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$analyzer = Join-Path $projectRoot 'tools\analyze-hand-contact-press-mechanics.ps1'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function New-Mechanics {
    param(
        [string]$PredictionMode,
        [double]$Velocity,
        [int]$PreloadLeadMs,
        [double]$Confidence,
        [string]$TriggerEvidence
    )
    return [ordered]@{
        predictionMode = $PredictionMode
        phase = 'impact'
        impactVelocityMetersPerSecond = $Velocity
        predictedTimeToImpactMs = if ($PredictionMode -eq 'visual_preload') { 42 } else { -1 }
        preloadLeadMs = $PreloadLeadMs
        confidence01 = $Confidence
        lateralVelocityMetersPerSecond = -0.18
        predictedLateralAtImpactMeters = 0.024
        trajectoryFit01 = 0.92
        approachAngleDegrees = 23.2
        approachAlignment01 = 0.91
        impactEnergyJoules = [math]::Round(0.1 * $Velocity * $Velocity, 6)
        springCompressionMeters = [math]::Round(0.01 + (0.01 * $Velocity), 6)
        dampingRatio = 0.55
        normalImpulseNewtonSeconds = [math]::Round(0.2 * $Velocity, 6)
        estimatedPeakForceNewtons = [math]::Round(3.0 + (4.0 * $Velocity), 6)
        estimatedContactPressureKilopascals = [math]::Round(5.0 + (5.0 * $Velocity), 6)
        estimatedContactPatchAreaSquareMeters = 0.00065
        compressionPeak01 = [math]::Round(0.5 + (0.2 * $Velocity), 6)
        actuationTravel01 = 0.469
        actuationDelayMs = 24
        snapTravel01 = 0.301
        snapDurationMs = 18
        bottomOutDelayMs = 68
        releaseDurationMs = 128
        visualStartOffsetMs = $PreloadLeadMs
        triggerEvidence = $TriggerEvidence
    }
}

function New-PressEvent {
    param(
        [int]$Condition,
        [int]$Index,
        [string]$InputSource,
        [bool]$Automation,
        [hashtable]$Mechanics
    )
    return [ordered]@{
        conditionNumber = $Condition
        pressIndex = $Index
        elapsedMs = 100 + $Index
        elapsedNs = (100 + $Index) * 1000000
        inputSource = $InputSource
        validationAutomation = $Automation
        pressMechanics = $Mechanics
    }
}

function New-SyntheticExport {
    param([string]$Name, [object[]]$PressEvents)
    $dir = Join-Path $OutDir $Name
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $json = [ordered]@{
        sessionId = "session_$Name"
        participantId = 'P_SYNTH'
        conditions = @(
            [ordered]@{
                conditionNumber = 1
                pressEvents = @($PressEvents | Where-Object { $_.conditionNumber -eq 1 })
            },
            [ordered]@{
                conditionNumber = 2
                pressEvents = @($PressEvents | Where-Object { $_.conditionNumber -eq 2 })
            }
        )
    }
    $json | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $dir 'brb_first_study_session.json') -Encoding UTF8
    return $dir
}

$mixedExport = New-SyntheticExport -Name 'mixed-export' -PressEvents @(
    (New-PressEvent -Condition 1 -Index 1 -InputSource 'hand_contact' -Automation $false -Mechanics (New-Mechanics -PredictionMode 'visual_preload' -Velocity 0.42 -PreloadLeadMs 36 -Confidence 0.84 -TriggerEvidence 'hand_contact:cap')),
    (New-PressEvent -Condition 1 -Index 2 -InputSource 'hand_contact' -Automation $false -Mechanics (New-Mechanics -PredictionMode 'contact_only' -Velocity 0.21 -PreloadLeadMs 0 -Confidence 0.62 -TriggerEvidence 'hand_contact:cap')),
    (New-PressEvent -Condition 2 -Index 1 -InputSource 'controller_contact' -Automation $false -Mechanics (New-Mechanics -PredictionMode 'none' -Velocity 0.32 -PreloadLeadMs 0 -Confidence 1.0 -TriggerEvidence 'controller_contact:cap')),
    (New-PressEvent -Condition 2 -Index 2 -InputSource 'hand_contact' -Automation $true -Mechanics (New-Mechanics -PredictionMode 'visual_preload' -Velocity 0.50 -PreloadLeadMs 40 -Confidence 0.90 -TriggerEvidence 'hand_contact:automation'))
)

$analysisOut = Join-Path $OutDir 'mixed-analysis'
& $analyzer -ExportDir $mixedExport -OutDir $analysisOut -RequireHandContact | Out-Host
$summary = Get-Content -Raw -LiteralPath (Join-Path $analysisOut 'press-mechanics-analysis.json') | ConvertFrom-Json
Assert-Condition ($summary.status -eq 'pass') 'Mixed analysis did not pass.'
Assert-Condition ($summary.totalPressesWithMechanics -eq 3) 'Default analysis should exclude validation automation.'
Assert-Condition ($summary.handContactPressesWithMechanics -eq 2) 'Expected two non-automation hand_contact presses.'
Assert-Condition ($summary.handContactVisualPreloadPresses -eq 1) 'Expected one visual_preload hand_contact press.'
Assert-Condition ($summary.controllerContactPressesWithMechanics -eq 1) 'Expected one controller_contact press.'
Assert-Condition ([math]::Abs([double]$summary.preloadUseRateAmongHandContact - 0.5) -lt 0.0001) 'Unexpected preload use rate.'
Assert-Condition ((Import-Csv -LiteralPath (Join-Path $analysisOut 'press-mechanics-events.csv')).Count -eq 3) 'Expected three event CSV rows.'

$automationOut = Join-Path $OutDir 'include-automation-analysis'
& $analyzer -ExportDir $mixedExport -OutDir $automationOut -RequireHandContact -IncludeAutomation | Out-Host
$automationSummary = Get-Content -Raw -LiteralPath (Join-Path $automationOut 'press-mechanics-analysis.json') | ConvertFrom-Json
Assert-Condition ($automationSummary.totalPressesWithMechanics -eq 4) 'IncludeAutomation should include four mechanics rows.'
Assert-Condition ($automationSummary.validationAutomationPressesIncluded -eq 1) 'Expected one included automation row.'

$controllerOnlyExport = New-SyntheticExport -Name 'controller-only-export' -PressEvents @(
    (New-PressEvent -Condition 1 -Index 1 -InputSource 'controller_contact' -Automation $false -Mechanics (New-Mechanics -PredictionMode 'none' -Velocity 0.25 -PreloadLeadMs 0 -Confidence 1.0 -TriggerEvidence 'controller_contact:cap'))
)
$failedAsExpected = $false
try {
    & $analyzer -ExportDir $controllerOnlyExport -OutDir (Join-Path $OutDir 'controller-only-analysis') -RequireHandContact | Out-Host
} catch {
    $failedAsExpected = $true
}
Assert-Condition $failedAsExpected 'RequireHandContact should fail when no hand_contact mechanics row exists.'

$summaryPath = Join-Path $OutDir 'hand-contact-press-mechanics-analysis-test-summary.json'
[pscustomobject]@{
    status = 'pass'
    generatedAt = (Get-Date).ToString('o')
    analyzer = $analyzer
    mixedAnalysis = Join-Path $analysisOut 'press-mechanics-analysis.json'
    includeAutomationAnalysis = Join-Path $automationOut 'press-mechanics-analysis.json'
    controllerOnlyFailureChecked = $true
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host 'PASS hand-contact press mechanics analysis tests'
Write-Host "Summary: $summaryPath"
