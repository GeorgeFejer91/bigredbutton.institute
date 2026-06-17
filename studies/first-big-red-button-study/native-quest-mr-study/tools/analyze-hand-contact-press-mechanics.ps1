[CmdletBinding()]
param(
    [string]$ExportDir = '',
    [string]$EvidenceDir = '',
    [string]$OutDir = '',
    [string]$OutPath = '',
    [switch]$IncludeAutomation,
    [switch]$RequireHandContact
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'export-session-layout.ps1')
$invariantCulture = [Globalization.CultureInfo]::InvariantCulture

function Resolve-MechanicsExportDir {
    if (-not [string]::IsNullOrWhiteSpace($ExportDir)) {
        return (Resolve-Path -LiteralPath $ExportDir).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($EvidenceDir)) {
        $evidenceRoot = (Resolve-Path -LiteralPath $EvidenceDir).Path
        foreach ($candidate in @(
            (Join-Path $evidenceRoot 'pulled\BigRedButtonFirstStudyExports'),
            (Join-Path $evidenceRoot 'pulled\ExperimentResults')
        )) {
            if (Test-Path -LiteralPath $candidate) {
                return (Resolve-Path -LiteralPath $candidate).Path
            }
        }
        throw "No pulled export folder found under evidence directory: $evidenceRoot"
    }
    throw 'Provide -ExportDir or -EvidenceDir.'
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Test-Truthy {
    param([object]$Value)
    if ($null -eq $Value) {
        return $false
    }
    if ($Value -is [bool]) {
        return [bool]$Value
    }
    return "$Value" -match '^(?i:true|1|yes)$'
}

function Get-PropertyValue {
    param([object]$Object, [string]$Name, [object]$Default = $null)
    if ($null -eq $Object) {
        return $Default
    }
    if ($Object.PSObject.Properties.Name -contains $Name) {
        return $Object.$Name
    }
    return $Default
}

function Convert-ToNullableDouble {
    param([object]$Value)
    if ($null -eq $Value) {
        return $null
    }
    $text = "$Value"
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    return [double]::Parse($text, $invariantCulture)
}

function Convert-ToNullableInt64 {
    param([object]$Value)
    if ($null -eq $Value) {
        return $null
    }
    $text = "$Value"
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    return [int64]::Parse($text, $invariantCulture)
}

function Get-Percentile {
    param([double[]]$SortedValues, [double]$Percentile)
    if ($SortedValues.Count -eq 0) {
        return $null
    }
    if ($SortedValues.Count -eq 1) {
        return $SortedValues[0]
    }
    $position = ($SortedValues.Count - 1) * $Percentile
    $lower = [math]::Floor($position)
    $upper = [math]::Ceiling($position)
    if ($lower -eq $upper) {
        return $SortedValues[$lower]
    }
    $weight = $position - $lower
    return ($SortedValues[$lower] * (1.0 - $weight)) + ($SortedValues[$upper] * $weight)
}

function Get-Stats {
    param([object[]]$Rows, [string]$Property)
    $values =
        @($Rows |
            ForEach-Object { Get-PropertyValue $_ $Property } |
            Where-Object { $null -ne $_ } |
            ForEach-Object { [double]$_ } |
            Sort-Object)
    if ($values.Count -eq 0) {
        return [ordered]@{
            n = 0
            mean = $null
            sd = $null
            min = $null
            q25 = $null
            median = $null
            q75 = $null
            max = $null
        }
    }
    $sum = ($values | Measure-Object -Sum).Sum
    $mean = $sum / $values.Count
    $sd = $null
    if ($values.Count -gt 1) {
        $sumSquares = 0.0
        foreach ($value in $values) {
            $sumSquares += [math]::Pow($value - $mean, 2)
        }
        $sd = [math]::Sqrt($sumSquares / ($values.Count - 1))
    }
    return [ordered]@{
        n = $values.Count
        mean = [math]::Round($mean, 6)
        sd = if ($null -eq $sd) { $null } else { [math]::Round($sd, 6) }
        min = [math]::Round($values[0], 6)
        q25 = [math]::Round((Get-Percentile -SortedValues $values -Percentile 0.25), 6)
        median = [math]::Round((Get-Percentile -SortedValues $values -Percentile 0.50), 6)
        q75 = [math]::Round((Get-Percentile -SortedValues $values -Percentile 0.75), 6)
        max = [math]::Round($values[$values.Count - 1], 6)
    }
}

function Get-MetricBlock {
    param([object[]]$Rows)
    $metrics = [ordered]@{}
    foreach ($metric in @(
        'impactVelocityMps',
        'preloadLeadMs',
        'confidence01',
        'trajectoryFit01',
        'approachAngleDeg',
        'approachAlignment01',
        'impactEnergyJ',
        'springCompressionM',
        'estimatedPeakForceN',
        'estimatedContactPressureKpa',
        'compressionPeak01',
        'actuationDelayMs',
        'snapDurationMs',
        'bottomOutDelayMs',
        'releaseDurationMs'
    )) {
        $metrics[$metric] = Get-Stats -Rows $Rows -Property $metric
    }
    return $metrics
}

function Find-SessionJson {
    param([string]$SessionDir)
    $jsonFiles = @(Get-ChildItem -LiteralPath $SessionDir -Filter '*.json' -File | Sort-Object LastWriteTime -Descending)
    foreach ($file in $jsonFiles) {
        if ($file.Name -eq 'session-manifest.json') {
            continue
        }
        try {
            $json = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
        } catch {
            continue
        }
        if ($json.PSObject.Properties.Name -contains 'conditions') {
            return [pscustomobject]@{
                Path = $file.FullName
                Json = $json
            }
        }
    }
    throw "No session JSON with a conditions array found in $SessionDir"
}

if ([string]::IsNullOrWhiteSpace($OutPath)) {
    if ([string]::IsNullOrWhiteSpace($OutDir)) {
        $OutDir = Join-Path $projectRoot ('artifacts\hand-contact-press-mechanics-analysis\analysis-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $OutPath = Join-Path $OutDir 'press-mechanics-analysis.json'
} else {
    $OutPath = [IO.Path]::GetFullPath($OutPath)
    $OutDir = Split-Path -Parent $OutPath
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$rowsCsvPath = Join-Path $OutDir 'press-mechanics-events.csv'

$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'fail'
    error = ''
    exportDir = ''
    evidenceDir = $EvidenceDir
    sessionDir = ''
    sessionSource = ''
    jsonPath = ''
    includeAutomation = [bool]$IncludeAutomation
    requireHandContact = [bool]$RequireHandContact
    eventRowsCsv = $rowsCsvPath
    totalPressesWithMechanics = 0
    handContactPressesWithMechanics = 0
    handContactVisualPreloadPresses = 0
    handContactContactOnlyPresses = 0
    controllerContactPressesWithMechanics = 0
    validationAutomationPressesIncluded = 0
    preloadUseRateAmongHandContact = $null
    byInputSource = @()
    byPredictionMode = @()
    byCondition = @()
    publicationMetrics = [ordered]@{}
    publicationMetricDefinitions = [ordered]@{
        preloadUseRateAmongHandContact = 'visual_preload hand_contact presses divided by all analyzed hand_contact presses'
        impactVelocityMps = 'accepted normal hand/controller approach speed at contact, meters per second'
        preloadLeadMs = 'visual preload lead time before accepted contact, milliseconds'
        confidence01 = 'model confidence for predictive preload/contact mechanics, 0 to 1'
        trajectoryFit01 = 'approach-trajectory stability/convergence fit, 0 to 1'
        springCompressionM = 'virtual spring compression inferred from impact energy, meters'
        estimatedPeakForceN = 'model-derived peak normal force estimate, not measured hand force'
        estimatedContactPressureKpa = 'estimatedPeakForce divided by assumed contact patch area, kPa'
        actuationDelayMs = 'accepted-contact to actuation/snap timing estimate, milliseconds'
    }
}

try {
    $resolvedExportDir = Resolve-MechanicsExportDir
    $summary.exportDir = $resolvedExportDir
    $session = Resolve-BrbExportSession -ExportDir $resolvedExportDir
    $summary.sessionDir = $session.SessionDir
    $summary.sessionSource = $session.Source
    $sessionJson = Find-SessionJson -SessionDir $session.SessionDir
    $summary.jsonPath = $sessionJson.Path
    $json = $sessionJson.Json

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($condition in @($json.conditions)) {
        $conditionNumber = Convert-ToNullableInt64 (Get-PropertyValue $condition 'conditionNumber')
        foreach ($event in @($condition.pressEvents)) {
            $mechanics = Get-PropertyValue $event 'pressMechanics'
            if ($null -eq $mechanics) {
                continue
            }
            $isAutomation = Test-Truthy (Get-PropertyValue $event 'validationAutomation')
            if ($isAutomation -and -not $IncludeAutomation) {
                continue
            }
            $inputSource = "$(Get-PropertyValue $event 'inputSource' '')"
            $predictionMode = "$(Get-PropertyValue $mechanics 'predictionMode' '')"
            $rows.Add([pscustomobject][ordered]@{
                sessionId = "$(Get-PropertyValue $json 'sessionId' '')"
                participantId = "$(Get-PropertyValue $json 'participantId' '')"
                conditionNumber = $conditionNumber
                pressIndex = Convert-ToNullableInt64 (Get-PropertyValue $event 'pressIndex')
                elapsedMs = Convert-ToNullableDouble (Get-PropertyValue $event 'elapsedMs')
                elapsedNs = Convert-ToNullableInt64 (Get-PropertyValue $event 'elapsedNs')
                inputSource = $inputSource
                validationAutomation = $isAutomation
                predictionMode = $predictionMode
                phase = "$(Get-PropertyValue $mechanics 'phase' '')"
                impactVelocityMps = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'impactVelocityMetersPerSecond')
                predictedTimeToImpactMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'predictedTimeToImpactMs')
                preloadLeadMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'preloadLeadMs')
                confidence01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'confidence01')
                lateralVelocityMps = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'lateralVelocityMetersPerSecond')
                predictedLateralAtImpactM = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'predictedLateralAtImpactMeters')
                trajectoryFit01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'trajectoryFit01')
                approachAngleDeg = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'approachAngleDegrees')
                approachAlignment01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'approachAlignment01')
                impactEnergyJ = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'impactEnergyJoules')
                springCompressionM = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'springCompressionMeters')
                dampingRatio = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'dampingRatio')
                normalImpulseNS = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'normalImpulseNewtonSeconds')
                estimatedPeakForceN = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'estimatedPeakForceNewtons')
                estimatedContactPressureKpa = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'estimatedContactPressureKilopascals')
                estimatedContactPatchAreaM2 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'estimatedContactPatchAreaSquareMeters')
                compressionPeak01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'compressionPeak01')
                actuationTravel01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'actuationTravel01')
                actuationDelayMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'actuationDelayMs')
                snapTravel01 = Convert-ToNullableDouble (Get-PropertyValue $mechanics 'snapTravel01')
                snapDurationMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'snapDurationMs')
                bottomOutDelayMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'bottomOutDelayMs')
                releaseDurationMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'releaseDurationMs')
                visualStartOffsetMs = Convert-ToNullableInt64 (Get-PropertyValue $mechanics 'visualStartOffsetMs')
                triggerEvidence = "$(Get-PropertyValue $mechanics 'triggerEvidence' '')"
            })
        }
    }

    $eventRows = @($rows.ToArray())
    Assert-Condition ($eventRows.Count -gt 0) 'No press events with pressMechanics were found after applying filters.'
    $handRows = @($eventRows | Where-Object { $_.inputSource -eq 'hand_contact' })
    if ($RequireHandContact) {
        Assert-Condition ($handRows.Count -gt 0) 'No hand_contact press events with pressMechanics were found.'
    }

    $eventRows | Export-Csv -LiteralPath $rowsCsvPath -NoTypeInformation -Encoding UTF8

    $summary.totalPressesWithMechanics = $eventRows.Count
    $summary.handContactPressesWithMechanics = $handRows.Count
    $summary.handContactVisualPreloadPresses = @($handRows | Where-Object { $_.predictionMode -eq 'visual_preload' }).Count
    $summary.handContactContactOnlyPresses = @($handRows | Where-Object { $_.predictionMode -eq 'contact_only' }).Count
    $summary.controllerContactPressesWithMechanics = @($eventRows | Where-Object { $_.inputSource -eq 'controller_contact' }).Count
    $summary.validationAutomationPressesIncluded = @($eventRows | Where-Object { $_.validationAutomation }).Count
    if ($handRows.Count -gt 0) {
        $summary.preloadUseRateAmongHandContact =
            [math]::Round($summary.handContactVisualPreloadPresses / [double]$handRows.Count, 6)
    }

    $summary.byInputSource =
        @($eventRows |
            Group-Object -Property inputSource |
            ForEach-Object {
                [ordered]@{
                    inputSource = $_.Name
                    count = $_.Count
                    metrics = Get-MetricBlock -Rows @($_.Group)
                }
            })
    $summary.byPredictionMode =
        @($eventRows |
            Group-Object -Property predictionMode |
            ForEach-Object {
                [ordered]@{
                    predictionMode = $_.Name
                    count = $_.Count
                    metrics = Get-MetricBlock -Rows @($_.Group)
                }
            })
    $summary.byCondition =
        @($eventRows |
            Group-Object -Property conditionNumber |
            ForEach-Object {
                [ordered]@{
                    conditionNumber = [int]$_.Name
                    count = $_.Count
                    handContactCount = @($_.Group | Where-Object { $_.inputSource -eq 'hand_contact' }).Count
                    metrics = Get-MetricBlock -Rows @($_.Group)
                }
            })
    $summary.publicationMetrics = [ordered]@{
        allPresses = Get-MetricBlock -Rows $eventRows
        handContactPresses = Get-MetricBlock -Rows $handRows
        controllerContactPresses = Get-MetricBlock -Rows @($eventRows | Where-Object { $_.inputSource -eq 'controller_contact' })
        visualPreloadHandContactPresses = Get-MetricBlock -Rows @($handRows | Where-Object { $_.predictionMode -eq 'visual_preload' })
        contactOnlyHandContactPresses = Get-MetricBlock -Rows @($handRows | Where-Object { $_.predictionMode -eq 'contact_only' })
    }
    $summary.status = 'pass'
} catch {
    $summary.error = $_.Exception.Message
    $summary.status = 'fail'
} finally {
    $summary | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $OutPath -Encoding UTF8
}

Write-Host "Hand-contact press mechanics analysis summary: $OutPath"
if ($summary.status -ne 'pass') {
    throw "Hand-contact press mechanics analysis failed: $($summary.error)"
}
Write-Host "Event rows CSV: $rowsCsvPath"
Write-Host 'PASS hand-contact press mechanics analysis'
