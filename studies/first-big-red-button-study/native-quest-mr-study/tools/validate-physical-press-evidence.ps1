[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ExportDir,
    [Parameter(Mandatory = $true)]
    [string]$LogcatPath,
    [int]$MinCondition1ControllerPresses = 1,
    [int]$MinCondition2ControllerPresses = 1,
    [int]$MinRealPolarEcgSamples = 1,
    [int]$MinRealPolarBlinkEvents = 1,
    [double]$MinRealPolarEcgCoverageRatio = 0.95,
    [double]$MaxRealPolarEcgBoundaryGapMs = 1000.0,
    [double]$MaxRealPolarEcgMedianDeltaErrorRatio = 0.25,
    [int]$MaxRealPolarEcgSampleGapMs = 250,
    [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ExportDir = (Resolve-Path $ExportDir).Path
$LogcatPath = (Resolve-Path $LogcatPath).Path
if ([string]::IsNullOrWhiteSpace($OutPath)) {
    $outRoot = Join-Path $projectRoot 'artifacts\physical-evidence-validation'
    New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
    $OutPath = Join-Path $outRoot ("physical-evidence-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
}

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Test-Truthy {
    param($Value)
    if ($null -eq $Value) {
        return $false
    }
    if ($Value -is [bool]) {
        return $Value
    }
    return "$Value".Trim().ToLowerInvariant() -eq 'true'
}

function Get-IntValue {
    param($Value, [string]$Name)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        throw "Missing integer value for $Name"
    }
    return [int]::Parse("$Value", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-Int64Value {
    param($Value, [string]$Name)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        throw "Missing integer value for $Name"
    }
    return [int64]::Parse("$Value", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-DoubleValue {
    param($Value, [string]$Name)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace("$Value")) {
        throw "Missing numeric value for $Name"
    }
    return [double]::Parse("$Value", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-ConditionSourceSummaryControllerCount {
    param(
        [string]$Text,
        [int]$Condition
    )
    $matches = [regex]::Matches(
        $Text,
        "BRB_CONDITION_PRESS_SOURCES condition=$Condition total=\d+ controllerContact=(\d+)"
    )
    if ($matches.Count -eq 0) {
        return $null
    }
    return [int]$matches[$matches.Count - 1].Groups[1].Value
}

$jsonFile =
    Get-ChildItem -LiteralPath $ExportDir -Filter 'brb_first_study_*.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
$pressFile =
    Get-ChildItem -LiteralPath $ExportDir -Filter '*_press_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
$ecgBlinkFile =
    Get-ChildItem -LiteralPath $ExportDir -Filter '*_ecg_blink_events.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
$ecgTimeSeriesFile =
    Get-ChildItem -LiteralPath $ExportDir -Filter '*_ecg_timeseries.csv' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

Assert-Condition ($null -ne $jsonFile) "Missing JSON export in $ExportDir"
Assert-Condition ($null -ne $pressFile) "Missing press-events CSV export in $ExportDir"
Assert-Condition ($null -ne $ecgBlinkFile) "Missing ECG blink-events CSV export in $ExportDir"
Assert-Condition ($null -ne $ecgTimeSeriesFile) "Missing ECG time-series CSV export in $ExportDir"

$exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
$conditions = @($exportJson.conditions)
$condition1 = $conditions | Where-Object { $_.conditionNumber -eq 1 } | Select-Object -First 1
$condition2 = $conditions | Where-Object { $_.conditionNumber -eq 2 } | Select-Object -First 1
Assert-Condition ($null -ne $condition1) 'Missing condition 1 in JSON export'
Assert-Condition ($null -ne $condition2) 'Missing condition 2 in JSON export'

$realPolarConditions = @($conditions | Where-Object { $_.ecgSource -eq 'real_polar_h10' })
$simulatedConditions = @($conditions | Where-Object { $_.ecgSource -eq 'simulated_neurokit2' })
Assert-Condition ($realPolarConditions.Count -eq 1) "Expected exactly one real_polar_h10 condition, found $($realPolarConditions.Count)"
Assert-Condition ($simulatedConditions.Count -eq 1) "Expected exactly one simulated_neurokit2 condition, found $($simulatedConditions.Count)"

$realPolarCondition = $realPolarConditions[0]
$realPolarConditionNumber = Get-IntValue $realPolarCondition.conditionNumber 'real Polar condition number'
$realPolarAudioDurationMs = Get-IntValue $realPolarCondition.audioDurationMs "condition $realPolarConditionNumber audioDurationMs"
$realPolarCaptureDurationMs = Get-IntValue $realPolarCondition.ecgCaptureDurationMs "condition $realPolarConditionNumber ecgCaptureDurationMs"
$realPolarCaptureDurationNs = Get-Int64Value $realPolarCondition.ecgCaptureDurationNs "condition $realPolarConditionNumber ecgCaptureDurationNs"
$realPolarCaptureStartedElapsedNs = Get-Int64Value $realPolarCondition.ecgCaptureStartedElapsedNs "condition $realPolarConditionNumber ecgCaptureStartedElapsedNs"
$realPolarCaptureEndedElapsedNs = Get-Int64Value $realPolarCondition.ecgCaptureEndedElapsedNs "condition $realPolarConditionNumber ecgCaptureEndedElapsedNs"
$realPolarAudioWindowStartMs = Get-IntValue $realPolarCondition.ecgAudioWindowStartMs "condition $realPolarConditionNumber ecgAudioWindowStartMs"
$realPolarAudioWindowEndMs = Get-IntValue $realPolarCondition.ecgAudioWindowEndMs "condition $realPolarConditionNumber ecgAudioWindowEndMs"
$realPolarAudioWindowDurationMs = Get-IntValue $realPolarCondition.ecgAudioWindowDurationMs "condition $realPolarConditionNumber ecgAudioWindowDurationMs"
$realPolarSampleRateHz = Get-IntValue $realPolarCondition.ecgSampleRateHz "condition $realPolarConditionNumber ecgSampleRateHz"
$realPolarExpectedSamples = Get-IntValue $realPolarCondition.ecgExpectedSampleCount "condition $realPolarConditionNumber ecgExpectedSampleCount"
$realPolarSampleCount = Get-IntValue $realPolarCondition.ecgTimeSeriesSampleCount "condition $realPolarConditionNumber ecgTimeSeriesSampleCount"
$realPolarBlinkCount = Get-IntValue $realPolarCondition.ecgBlinkCount "condition $realPolarConditionNumber ecgBlinkCount"
$realPolarRequestedMtu = Get-IntValue $realPolarCondition.ecgRequestedMtu "condition $realPolarConditionNumber ecgRequestedMtu"
$realPolarNegotiatedMtu = Get-IntValue $realPolarCondition.ecgNegotiatedMtu "condition $realPolarConditionNumber ecgNegotiatedMtu"
$requiredRealPolarSampleCount = [math]::Max($MinRealPolarEcgSamples, [int][math]::Floor($realPolarExpectedSamples * $MinRealPolarEcgCoverageRatio))

Assert-Condition (
    $realPolarCaptureDurationMs -eq $realPolarAudioDurationMs
) "Real Polar condition $realPolarConditionNumber ECG capture duration must equal audio duration: capture=$realPolarCaptureDurationMs audio=$realPolarAudioDurationMs"
Assert-Condition (
    $realPolarCaptureDurationNs -eq ([int64]$realPolarAudioDurationMs * 1000000L)
) "Real Polar condition $realPolarConditionNumber ECG capture ns duration must equal audio duration: captureNs=$realPolarCaptureDurationNs audioMs=$realPolarAudioDurationMs"
Assert-Condition (
    ($realPolarCaptureEndedElapsedNs - $realPolarCaptureStartedElapsedNs) -eq ([int64]$realPolarAudioDurationMs * 1000000L)
) "Real Polar condition $realPolarConditionNumber ECG capture ns window must equal audio duration"
Assert-Condition (
    $realPolarAudioWindowStartMs -eq 0 -and $realPolarAudioWindowEndMs -eq $realPolarAudioDurationMs -and $realPolarAudioWindowDurationMs -eq $realPolarAudioDurationMs
) "Real Polar condition $realPolarConditionNumber ECG audio window fields must be 0..audio duration"
Assert-Condition (
    $realPolarSampleRateHz -eq 130
) "Real Polar condition $realPolarConditionNumber ECG sample rate should be 130 Hz, found $realPolarSampleRateHz"
Assert-Condition (
    $realPolarExpectedSamples -gt 0
) "Real Polar condition $realPolarConditionNumber missing expected ECG sample count"
Assert-Condition (
    $realPolarSampleCount -ge $requiredRealPolarSampleCount
) "Real Polar condition $realPolarConditionNumber ECG sample coverage too low: expected at least $requiredRealPolarSampleCount from $realPolarExpectedSamples ($MinRealPolarEcgCoverageRatio coverage), found $realPolarSampleCount"
Assert-Condition (
    $realPolarBlinkCount -ge $MinRealPolarBlinkEvents
) "Real Polar condition $realPolarConditionNumber blink evidence too low: expected at least $MinRealPolarBlinkEvents, found $realPolarBlinkCount"
Assert-Condition (
    $realPolarRequestedMtu -gt 0
) "Real Polar condition $realPolarConditionNumber missing requested MTU"
Assert-Condition (
    $realPolarRequestedMtu -eq 70
) "Real Polar condition $realPolarConditionNumber should use requested MTU 70 for minimum-packet low-latency PMD readout, found $realPolarRequestedMtu"
Assert-Condition (
    $realPolarNegotiatedMtu -ge 0
) "Real Polar condition $realPolarConditionNumber invalid negotiated MTU"

$allJsonPressEvents = @($conditions | ForEach-Object { @($_.pressEvents) })
$condition1ControllerPressEvents = @($condition1.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
$condition2ControllerPressEvents = @($condition2.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
$condition1ControllerPresses = $condition1ControllerPressEvents.Count
$condition2ControllerPresses = $condition2ControllerPressEvents.Count

$pressRows = @(Import-Csv -LiteralPath $pressFile.FullName)
$ecgBlinkRows = @(Import-Csv -LiteralPath $ecgBlinkFile.FullName)
$ecgTimeSeriesRows = @(Import-Csv -LiteralPath $ecgTimeSeriesFile.FullName)
$csvCondition1ControllerPressRows =
    @($pressRows | Where-Object { $_.condition_number -eq '1' -and $_.input_source -eq 'controller_contact' })
$csvCondition2ControllerPressRows =
    @($pressRows | Where-Object { $_.condition_number -eq '2' -and $_.input_source -eq 'controller_contact' })
$csvCondition1ControllerPresses = $csvCondition1ControllerPressRows.Count
$csvCondition2ControllerPresses = $csvCondition2ControllerPressRows.Count
$csvRealPolarBlinkRows =
    @($ecgBlinkRows | Where-Object { $_.condition_number -eq "$realPolarConditionNumber" -and $_.source -eq 'real_polar_h10' })
$csvRealPolarTimeSeriesRows =
    @($ecgTimeSeriesRows | Where-Object { $_.condition_number -eq "$realPolarConditionNumber" -and $_.source -eq 'real_polar_h10' })

$logText = Get-Content -Raw -LiteralPath $LogcatPath
$logControllerPressMarkers =
    ([regex]::Matches(
        $logText,
        'BRB_BUTTON_PRESS condition=\d+ index=\d+ source=controller_contact validationAutomation=false'
    )).Count
$acceptedContactSelects =
    ([regex]::Matches($logText, 'BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true')).Count
$logAutomatedPressMarkers =
    ([regex]::Matches(
        $logText,
        'BRB_BUTTON_PRESS .*source=auto_validation|BRB_BUTTON_PRESS .*validationAutomation=true'
    )).Count
$sourceSummaryCondition1ControllerPresses = Get-ConditionSourceSummaryControllerCount -Text $logText -Condition 1
$sourceSummaryCondition2ControllerPresses = Get-ConditionSourceSummaryControllerCount -Text $logText -Condition 2
$lowLatencyConfigMarkers =
    ([regex]::Matches(
        $logText,
        'BRB_POLAR_H10_LOW_LATENCY_CONFIG .*requestedMtu=70.*strategy=minimum_mtu_low_latency_ecg'
    )).Count
$realPolarCaptureStartMarkers =
    ([regex]::Matches(
        $logText,
        "BRB_ECG_CAPTURE_START condition=$realPolarConditionNumber source=real_polar_h10 .*audioDurationMs=$realPolarAudioDurationMs .*sampleRateHz=130"
    )).Count
$realPolarCaptureEndMarkers =
    ([regex]::Matches(
        $logText,
        "BRB_ECG_CAPTURE_END condition=$realPolarConditionNumber source=real_polar_h10 .*audioDurationMs=$realPolarAudioDurationMs .*sampleRateHz=130 .*actualSamples=$realPolarSampleCount .*captureWindowMs=$realPolarCaptureDurationMs"
    )).Count

$jsonAutomatedPresses =
    @($allJsonPressEvents | Where-Object { $_.inputSource -eq 'auto_validation' -or (Test-Truthy $_.validationAutomation) }).Count
$csvAutomatedPresses =
    @($pressRows | Where-Object { $_.input_source -eq 'auto_validation' -or (Test-Truthy $_.validation_automation) }).Count
$jsonControllerPressesMarkedAutomated =
    @($allJsonPressEvents | Where-Object { $_.inputSource -eq 'controller_contact' -and (Test-Truthy $_.validationAutomation) }).Count
$csvControllerPressesMarkedAutomated =
    @($pressRows | Where-Object { $_.input_source -eq 'controller_contact' -and (Test-Truthy $_.validation_automation) }).Count

Assert-Condition (
    $condition1ControllerPresses -ge $MinCondition1ControllerPresses
) "Condition 1 controller_contact presses too low: expected at least $MinCondition1ControllerPresses, found $condition1ControllerPresses"
Assert-Condition (
    $condition2ControllerPresses -ge $MinCondition2ControllerPresses
) "Condition 2 controller_contact presses too low: expected at least $MinCondition2ControllerPresses, found $condition2ControllerPresses"
Assert-Condition (
    $condition1ControllerPresses -eq $csvCondition1ControllerPresses
) "Condition 1 JSON/CSV controller_contact mismatch: json=$condition1ControllerPresses csv=$csvCondition1ControllerPresses"
Assert-Condition (
    $condition2ControllerPresses -eq $csvCondition2ControllerPresses
) "Condition 2 JSON/CSV controller_contact mismatch: json=$condition2ControllerPresses csv=$csvCondition2ControllerPresses"
Assert-Condition (
    $logControllerPressMarkers -ge ($condition1ControllerPresses + $condition2ControllerPresses)
) "Logcat controller_contact markers fewer than exported controller_contact events: log=$logControllerPressMarkers export=$($condition1ControllerPresses + $condition2ControllerPresses)"
Assert-Condition (
    $acceptedContactSelects -ge ($condition1ControllerPresses + $condition2ControllerPresses)
) "Accepted controller-contact select markers fewer than exported controller_contact events: accepted=$acceptedContactSelects export=$($condition1ControllerPresses + $condition2ControllerPresses)"
Assert-Condition (
    $null -ne $sourceSummaryCondition1ControllerPresses
) 'Missing condition 1 BRB_CONDITION_PRESS_SOURCES marker in logcat'
Assert-Condition (
    $null -ne $sourceSummaryCondition2ControllerPresses
) 'Missing condition 2 BRB_CONDITION_PRESS_SOURCES marker in logcat'
Assert-Condition (
    $sourceSummaryCondition1ControllerPresses -eq $condition1ControllerPresses
) "Condition 1 source-summary controllerContact count mismatch: summary=$sourceSummaryCondition1ControllerPresses export=$condition1ControllerPresses"
Assert-Condition (
    $sourceSummaryCondition2ControllerPresses -eq $condition2ControllerPresses
) "Condition 2 source-summary controllerContact count mismatch: summary=$sourceSummaryCondition2ControllerPresses export=$condition2ControllerPresses"
Assert-Condition ($jsonAutomatedPresses -eq 0) "Physical press evidence contains automated button presses in JSON: $jsonAutomatedPresses"
Assert-Condition ($csvAutomatedPresses -eq 0) "Physical press evidence contains automated button presses in CSV: $csvAutomatedPresses"
Assert-Condition ($logAutomatedPressMarkers -eq 0) "Physical press evidence contains automated button press markers in logcat: $logAutomatedPressMarkers"
Assert-Condition (
    $jsonControllerPressesMarkedAutomated -eq 0
) "JSON controller_contact press events are marked validationAutomation=true: $jsonControllerPressesMarkedAutomated"
Assert-Condition (
    $csvControllerPressesMarkedAutomated -eq 0
) "CSV controller_contact press rows are marked validation_automation=true: $csvControllerPressesMarkedAutomated"
Assert-Condition (
    $lowLatencyConfigMarkers -gt 0
) 'Missing Polar H10 low-latency PMD ECG config marker with requestedMtu=70'
Assert-Condition (
    $realPolarCaptureStartMarkers -gt 0
) "Missing real Polar ECG capture start marker for condition $realPolarConditionNumber"
Assert-Condition (
    $realPolarCaptureEndMarkers -gt 0
) "Missing real Polar ECG capture end marker for condition $realPolarConditionNumber"
Assert-Condition (
    $csvRealPolarBlinkRows.Count -eq $realPolarBlinkCount
) "Real Polar blink JSON/CSV mismatch: json=$realPolarBlinkCount csv=$($csvRealPolarBlinkRows.Count)"
Assert-Condition (
    $csvRealPolarTimeSeriesRows.Count -eq $realPolarSampleCount
) "Real Polar ECG time-series JSON/CSV mismatch: json=$realPolarSampleCount csv=$($csvRealPolarTimeSeriesRows.Count)"
Assert-Condition (
    $csvRealPolarBlinkRows.Count -ge $MinRealPolarBlinkEvents
) "Real Polar blink CSV rows too low: expected at least $MinRealPolarBlinkEvents, found $($csvRealPolarBlinkRows.Count)"
Assert-Condition (
    $csvRealPolarTimeSeriesRows.Count -ge $requiredRealPolarSampleCount
) "Real Polar ECG time-series CSV rows too low: expected at least $requiredRealPolarSampleCount, found $($csvRealPolarTimeSeriesRows.Count)"

$realPolarElapsedValues = New-Object System.Collections.Generic.List[double]
$realPolarElapsedNsValues = New-Object System.Collections.Generic.List[int64]
$realPolarRowsWithInvalidRate = 0
$realPolarRowsWithInvalidPackage = 0
$realPolarRowsWithInvalidFrame = 0
$realPolarRowsWithInvalidMtu = 0
$realPolarRowsOutOfWindow = 0
$realPolarRowsWithInvalidSampleIndex = 0
$realPolarRowsWithNonMonotonicElapsedNs = 0
$realPolarElapsedNsDeltas = New-Object System.Collections.Generic.List[int64]
$previousSampleIndex = 0
$previousElapsedNs = $null
foreach ($row in $csvRealPolarTimeSeriesRows) {
    $sampleIndex = Get-IntValue $row.sample_index 'real Polar ECG sample_index'
    $elapsed = Get-DoubleValue $row.elapsed_ms 'real Polar ECG elapsed_ms'
    $elapsedNs = Get-Int64Value $row.elapsed_ns 'real Polar ECG elapsed_ns'
    $realPolarElapsedValues.Add($elapsed)
    $realPolarElapsedNsValues.Add($elapsedNs)
    if ($sampleIndex -ne ($previousSampleIndex + 1)) {
        $realPolarRowsWithInvalidSampleIndex += 1
    }
    if ($null -ne $previousElapsedNs) {
        $deltaNs = $elapsedNs - [int64]$previousElapsedNs
        if ($deltaNs -le 0) {
            $realPolarRowsWithNonMonotonicElapsedNs += 1
        } else {
            $realPolarElapsedNsDeltas.Add($deltaNs)
        }
    }
    $previousSampleIndex = $sampleIndex
    $previousElapsedNs = $elapsedNs
    if ((Get-IntValue $row.sample_rate_hz 'real Polar ECG sample_rate_hz') -ne 130) {
        $realPolarRowsWithInvalidRate += 1
    }
    if ((Get-IntValue $row.package_size_bytes 'real Polar ECG package_size_bytes') -le 0) {
        $realPolarRowsWithInvalidPackage += 1
    }
    if ((Get-IntValue $row.frame_index 'real Polar ECG frame_index') -le 0) {
        $realPolarRowsWithInvalidFrame += 1
    }
    if ((Get-IntValue $row.requested_mtu 'real Polar ECG requested_mtu') -ne 70) {
        $realPolarRowsWithInvalidMtu += 1
    }
    if ((Get-IntValue $row.audio_window_start_ms 'real Polar ECG audio_window_start_ms') -ne 0 -or
        (Get-IntValue $row.audio_window_end_ms 'real Polar ECG audio_window_end_ms') -ne $realPolarAudioDurationMs -or
        (Get-IntValue $row.audio_window_duration_ms 'real Polar ECG audio_window_duration_ms') -ne $realPolarAudioDurationMs) {
        $realPolarRowsOutOfWindow += 1
    } elseif ($elapsed -lt 0 -or $elapsed -gt $realPolarAudioDurationMs -or $elapsedNs -lt 0 -or $elapsedNs -gt ([int64]$realPolarAudioDurationMs * 1000000L)) {
        $realPolarRowsOutOfWindow += 1
    }
}
$realPolarFirstSampleElapsedMs = ($realPolarElapsedValues | Measure-Object -Minimum).Minimum
$realPolarLastSampleElapsedMs = ($realPolarElapsedValues | Measure-Object -Maximum).Maximum
$realPolarFirstSampleElapsedNs = ($realPolarElapsedNsValues | Measure-Object -Minimum).Minimum
$realPolarLastSampleElapsedNs = ($realPolarElapsedNsValues | Measure-Object -Maximum).Maximum
$sortedRealPolarElapsedNsDeltas = @($realPolarElapsedNsDeltas | Sort-Object)
$realPolarMedianSampleDeltaNs = 0.0
$realPolarMaxSampleDeltaNs = 0L
if ($sortedRealPolarElapsedNsDeltas.Count -gt 0) {
    $middle = [int][math]::Floor($sortedRealPolarElapsedNsDeltas.Count / 2)
    if (($sortedRealPolarElapsedNsDeltas.Count % 2) -eq 0) {
        $realPolarMedianSampleDeltaNs =
            ([double]$sortedRealPolarElapsedNsDeltas[$middle - 1] + [double]$sortedRealPolarElapsedNsDeltas[$middle]) / 2.0
    } else {
        $realPolarMedianSampleDeltaNs = [double]$sortedRealPolarElapsedNsDeltas[$middle]
    }
    $realPolarMaxSampleDeltaNs = [int64]($sortedRealPolarElapsedNsDeltas | Measure-Object -Maximum).Maximum
}
$expectedRealPolarSampleDeltaNs = 1000000000.0 / [double]$realPolarSampleRateHz
$realPolarMedianDeltaErrorRatio =
    [math]::Abs($realPolarMedianSampleDeltaNs - $expectedRealPolarSampleDeltaNs) / $expectedRealPolarSampleDeltaNs
$maxRealPolarEcgSampleGapNs = [int64]$MaxRealPolarEcgSampleGapMs * 1000000L
Assert-Condition ($realPolarRowsWithInvalidRate -eq 0) "Real Polar ECG CSV rows with non-130 Hz sample rate: $realPolarRowsWithInvalidRate"
Assert-Condition ($realPolarRowsWithInvalidPackage -eq 0) "Real Polar ECG CSV rows with invalid PMD package size: $realPolarRowsWithInvalidPackage"
Assert-Condition ($realPolarRowsWithInvalidFrame -eq 0) "Real Polar ECG CSV rows with invalid PMD frame index: $realPolarRowsWithInvalidFrame"
Assert-Condition ($realPolarRowsWithInvalidMtu -eq 0) "Real Polar ECG CSV rows without requested MTU 70: $realPolarRowsWithInvalidMtu"
Assert-Condition ($realPolarRowsOutOfWindow -eq 0) "Real Polar ECG CSV rows outside audio window: $realPolarRowsOutOfWindow"
Assert-Condition ($realPolarRowsWithInvalidSampleIndex -eq 0) "Real Polar ECG sample_index values are not sequential: $realPolarRowsWithInvalidSampleIndex"
Assert-Condition ($realPolarRowsWithNonMonotonicElapsedNs -eq 0) "Real Polar ECG elapsed_ns values are not strictly increasing: $realPolarRowsWithNonMonotonicElapsedNs"
Assert-Condition ($realPolarElapsedNsDeltas.Count -gt 0) "Real Polar ECG time-series needs at least two samples for sample-interval validation"
Assert-Condition (
    $realPolarMedianDeltaErrorRatio -le $MaxRealPolarEcgMedianDeltaErrorRatio
) "Real Polar ECG median sample interval does not match $realPolarSampleRateHz Hz: medianDeltaNs=$realPolarMedianSampleDeltaNs expectedDeltaNs=$expectedRealPolarSampleDeltaNs errorRatio=$realPolarMedianDeltaErrorRatio max=$MaxRealPolarEcgMedianDeltaErrorRatio"
Assert-Condition (
    $realPolarMaxSampleDeltaNs -le $maxRealPolarEcgSampleGapNs
) "Real Polar ECG sample gap too large for continuous high-resolution capture: maxDeltaNs=$realPolarMaxSampleDeltaNs maxAllowedNs=$maxRealPolarEcgSampleGapNs"
Assert-Condition (
    $realPolarFirstSampleElapsedMs -le $MaxRealPolarEcgBoundaryGapMs
) "Real Polar ECG first sample starts too late: first=${realPolarFirstSampleElapsedMs}ms maxGap=${MaxRealPolarEcgBoundaryGapMs}ms"
Assert-Condition (
    $realPolarLastSampleElapsedMs -ge ($realPolarAudioDurationMs - $MaxRealPolarEcgBoundaryGapMs)
) "Real Polar ECG last sample ends too early: last=${realPolarLastSampleElapsedMs}ms audio=${realPolarAudioDurationMs}ms maxGap=${MaxRealPolarEcgBoundaryGapMs}ms"

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    exportDir = $ExportDir
    logcatPath = $LogcatPath
    json = $jsonFile.FullName
    pressEventsCsv = $pressFile.FullName
    ecgBlinkEventsCsv = $ecgBlinkFile.FullName
    ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
    minCondition1ControllerPresses = $MinCondition1ControllerPresses
    minCondition2ControllerPresses = $MinCondition2ControllerPresses
    minRealPolarEcgSamples = $MinRealPolarEcgSamples
    minRealPolarBlinkEvents = $MinRealPolarBlinkEvents
    minRealPolarEcgCoverageRatio = $MinRealPolarEcgCoverageRatio
    maxRealPolarEcgBoundaryGapMs = $MaxRealPolarEcgBoundaryGapMs
    maxRealPolarEcgMedianDeltaErrorRatio = $MaxRealPolarEcgMedianDeltaErrorRatio
    maxRealPolarEcgSampleGapMs = $MaxRealPolarEcgSampleGapMs
    condition1ControllerPresses = $condition1ControllerPresses
    condition2ControllerPresses = $condition2ControllerPresses
    csvCondition1ControllerPresses = $csvCondition1ControllerPresses
    csvCondition2ControllerPresses = $csvCondition2ControllerPresses
    logControllerPressMarkers = $logControllerPressMarkers
    acceptedContactSelects = $acceptedContactSelects
    sourceSummaryCondition1ControllerPresses = $sourceSummaryCondition1ControllerPresses
    sourceSummaryCondition2ControllerPresses = $sourceSummaryCondition2ControllerPresses
    jsonAutomatedPresses = $jsonAutomatedPresses
    csvAutomatedPresses = $csvAutomatedPresses
    logAutomatedPressMarkers = $logAutomatedPressMarkers
    jsonControllerPressesMarkedAutomated = $jsonControllerPressesMarkedAutomated
    csvControllerPressesMarkedAutomated = $csvControllerPressesMarkedAutomated
    realPolarConditionNumber = $realPolarConditionNumber
    realPolarAudioDurationMs = $realPolarAudioDurationMs
    realPolarCaptureDurationMs = $realPolarCaptureDurationMs
    realPolarCaptureDurationNs = $realPolarCaptureDurationNs
    realPolarCaptureStartedElapsedNs = $realPolarCaptureStartedElapsedNs
    realPolarCaptureEndedElapsedNs = $realPolarCaptureEndedElapsedNs
    realPolarAudioWindowStartMs = $realPolarAudioWindowStartMs
    realPolarAudioWindowEndMs = $realPolarAudioWindowEndMs
    realPolarAudioWindowDurationMs = $realPolarAudioWindowDurationMs
    realPolarSampleRateHz = $realPolarSampleRateHz
    realPolarExpectedSamples = $realPolarExpectedSamples
    realPolarRequiredSamples = $requiredRealPolarSampleCount
    realPolarSampleCount = $realPolarSampleCount
    realPolarBlinkCount = $realPolarBlinkCount
    csvRealPolarTimeSeriesRows = $csvRealPolarTimeSeriesRows.Count
    csvRealPolarBlinkRows = $csvRealPolarBlinkRows.Count
    realPolarRequestedMtu = $realPolarRequestedMtu
    realPolarNegotiatedMtu = $realPolarNegotiatedMtu
    realPolarFirstSampleElapsedMs = $realPolarFirstSampleElapsedMs
    realPolarLastSampleElapsedMs = $realPolarLastSampleElapsedMs
    realPolarFirstSampleElapsedNs = $realPolarFirstSampleElapsedNs
    realPolarLastSampleElapsedNs = $realPolarLastSampleElapsedNs
    realPolarMedianSampleDeltaNs = $realPolarMedianSampleDeltaNs
    expectedRealPolarSampleDeltaNs = $expectedRealPolarSampleDeltaNs
    realPolarMedianDeltaErrorRatio = $realPolarMedianDeltaErrorRatio
    realPolarMaxSampleDeltaNs = $realPolarMaxSampleDeltaNs
    realPolarRowsWithInvalidSampleIndex = $realPolarRowsWithInvalidSampleIndex
    realPolarRowsWithNonMonotonicElapsedNs = $realPolarRowsWithNonMonotonicElapsedNs
    lowLatencyConfigMarkers = $lowLatencyConfigMarkers
    realPolarCaptureStartMarkers = $realPolarCaptureStartMarkers
    realPolarCaptureEndMarkers = $realPolarCaptureEndMarkers
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding UTF8
Write-Host "PASS physical press evidence validation"
Write-Host "Summary: $OutPath"
