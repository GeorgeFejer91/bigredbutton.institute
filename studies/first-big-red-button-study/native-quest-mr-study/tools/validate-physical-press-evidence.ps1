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
    [double]$MaxPressEcgAlignmentDeltaMs = 20.0,
    [string]$OutPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $PSScriptRoot 'export-session-layout.ps1')
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

function Get-Median {
    param([object[]]$Values)
    $sorted = @($Values | Sort-Object)
    if ($sorted.Count -eq 0) {
        return 0.0
    }
    $middle = [int][math]::Floor($sorted.Count / 2)
    if (($sorted.Count % 2) -eq 0) {
        return ([double]$sorted[$middle - 1] + [double]$sorted[$middle]) / 2.0
    }
    return [double]$sorted[$middle]
}

function Get-FirstPropertyValue {
    param(
        $Object,
        [string[]]$Names,
        [string]$DisplayName
    )
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            return $Object.$name
        }
    }
    throw "Missing value for $DisplayName"
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

function Validate-PressAlignmentRows {
    param(
        [object[]]$Rows,
        [int]$ConditionNumber,
        [int64]$AudioDurationNs,
        [int64]$MaxPressEcgAlignmentDeltaNs,
        [string]$Kind
    )
    foreach ($row in $Rows) {
        $elapsedNs = Get-Int64Value (Get-FirstPropertyValue $row @('elapsed_ns', 'elapsedNs') "$Kind condition $ConditionNumber press elapsed_ns") "$Kind condition $ConditionNumber press elapsed_ns"
        $eventElapsedRealtimeNs = Get-Int64Value (Get-FirstPropertyValue $row @('event_elapsed_realtime_ns', 'eventElapsedRealtimeNs') "$Kind condition $ConditionNumber press event_elapsed_realtime_ns") "$Kind condition $ConditionNumber press event_elapsed_realtime_ns"
        $conditionStartElapsedRealtimeNs = Get-Int64Value (Get-FirstPropertyValue $row @('condition_start_elapsed_realtime_ns', 'conditionStartElapsedRealtimeNs') "$Kind condition $ConditionNumber press condition_start_elapsed_realtime_ns") "$Kind condition $ConditionNumber press condition_start_elapsed_realtime_ns"
        $nearestSampleIndex = Get-IntValue (Get-FirstPropertyValue $row @('nearest_ecg_sample_index', 'nearestEcgSampleIndex') "$Kind condition $ConditionNumber press nearest_ecg_sample_index") "$Kind condition $ConditionNumber press nearest_ecg_sample_index"
        $nearestElapsedNs = Get-Int64Value (Get-FirstPropertyValue $row @('nearest_ecg_elapsed_ns', 'nearestEcgElapsedNs') "$Kind condition $ConditionNumber press nearest_ecg_elapsed_ns") "$Kind condition $ConditionNumber press nearest_ecg_elapsed_ns"
        $nearestDeltaNs = Get-Int64Value (Get-FirstPropertyValue $row @('nearest_ecg_delta_ns', 'nearestEcgDeltaNs') "$Kind condition $ConditionNumber press nearest_ecg_delta_ns") "$Kind condition $ConditionNumber press nearest_ecg_delta_ns"
        Assert-Condition ($elapsedNs -ge 0 -and $elapsedNs -le $AudioDurationNs) "$Kind condition $ConditionNumber controller press elapsed_ns outside audio window: $elapsedNs"
        Assert-Condition (($eventElapsedRealtimeNs - $conditionStartElapsedRealtimeNs) -eq $elapsedNs) "$Kind condition $ConditionNumber controller press monotonic alignment fields do not reconstruct elapsed_ns"
        Assert-Condition ($nearestSampleIndex -gt 0) "$Kind condition $ConditionNumber controller press missing nearest ECG sample index"
        Assert-Condition ($nearestElapsedNs -ge 0 -and $nearestElapsedNs -le $AudioDurationNs) "$Kind condition $ConditionNumber nearest ECG elapsed_ns outside audio window: $nearestElapsedNs"
        Assert-Condition ([math]::Abs($nearestDeltaNs) -le $MaxPressEcgAlignmentDeltaNs) "$Kind condition $ConditionNumber press-to-ECG alignment gap too large: deltaNs=$nearestDeltaNs maxNs=$MaxPressEcgAlignmentDeltaNs"
    }
}

function Validate-RealPolarCondition {
    param(
        [object]$Condition,
        [object[]]$PressRows,
        [object[]]$EcgBlinkRows,
        [object[]]$EcgTimeSeriesRows,
        [object[]]$PolarRrRows,
        [string]$LogText,
        [int]$MinRealPolarEcgSamples,
        [int]$MinRealPolarBlinkEvents,
        [double]$MinRealPolarEcgCoverageRatio,
        [double]$MaxRealPolarEcgBoundaryGapMs,
        [double]$MaxRealPolarEcgMedianDeltaErrorRatio,
        [int]$MaxRealPolarEcgSampleGapMs,
        [int64]$MaxPressEcgAlignmentDeltaNs
    )

    Assert-Condition ($Condition.PSObject.Properties.Name -contains 'feedbackSource') "Condition $($Condition.conditionNumber) missing feedbackSource"
    Assert-Condition ($Condition.PSObject.Properties.Name -contains 'physiologySource') "Condition $($Condition.conditionNumber) missing physiologySource"
    $conditionNumber = Get-IntValue $Condition.conditionNumber 'condition number'
    $feedbackSource = "$($Condition.feedbackSource)"
    $physiologySource = "$($Condition.physiologySource)"
    $audioDurationMs = Get-IntValue $Condition.audioDurationMs "condition $conditionNumber audioDurationMs"
    $audioDurationNs = [int64]$audioDurationMs * 1000000L
    $captureDurationMs = Get-IntValue $Condition.ecgCaptureDurationMs "condition $conditionNumber ecgCaptureDurationMs"
    $captureDurationNs = Get-Int64Value $Condition.ecgCaptureDurationNs "condition $conditionNumber ecgCaptureDurationNs"
    $captureStartedElapsedNs = Get-Int64Value $Condition.ecgCaptureStartedElapsedNs "condition $conditionNumber ecgCaptureStartedElapsedNs"
    $captureEndedElapsedNs = Get-Int64Value $Condition.ecgCaptureEndedElapsedNs "condition $conditionNumber ecgCaptureEndedElapsedNs"
    $audioWindowStartMs = Get-IntValue $Condition.ecgAudioWindowStartMs "condition $conditionNumber ecgAudioWindowStartMs"
    $audioWindowEndMs = Get-IntValue $Condition.ecgAudioWindowEndMs "condition $conditionNumber ecgAudioWindowEndMs"
    $audioWindowDurationMs = Get-IntValue $Condition.ecgAudioWindowDurationMs "condition $conditionNumber ecgAudioWindowDurationMs"
    $sampleRateHz = Get-IntValue $Condition.ecgSampleRateHz "condition $conditionNumber ecgSampleRateHz"
    $expectedSamples = Get-IntValue $Condition.ecgExpectedSampleCount "condition $conditionNumber ecgExpectedSampleCount"
    $sampleCount = Get-IntValue $Condition.ecgTimeSeriesSampleCount "condition $conditionNumber ecgTimeSeriesSampleCount"
    $realSampleCount = if ($Condition.PSObject.Properties.Name -contains 'realEcgTimeSeriesSampleCount') {
        Get-IntValue $Condition.realEcgTimeSeriesSampleCount "condition $conditionNumber realEcgTimeSeriesSampleCount"
    } else {
        $sampleCount
    }
    $blinkCount = Get-IntValue $Condition.ecgBlinkCount "condition $conditionNumber ecgBlinkCount"
    $polarRrEventCount = Get-IntValue $Condition.polarRrEventCount "condition $conditionNumber polarRrEventCount"
    $requestedMtu = Get-IntValue $Condition.ecgRequestedMtu "condition $conditionNumber ecgRequestedMtu"
    $negotiatedMtu = Get-IntValue $Condition.ecgNegotiatedMtu "condition $conditionNumber ecgNegotiatedMtu"
    $requiredRealPolarSampleCount = [math]::Max($MinRealPolarEcgSamples, [int][math]::Floor($expectedSamples * $MinRealPolarEcgCoverageRatio))

    Assert-Condition ($Condition.ecgSource -eq 'real_polar_h10') "Condition $conditionNumber ecgSource must be real_polar_h10 physiology alias"
    Assert-Condition ($physiologySource -eq 'real_polar_h10') "Condition $conditionNumber physiologySource must be real_polar_h10"
    Assert-Condition ($feedbackSource -in @('real_polar_h10', 'simulated_neurokit2')) "Condition $conditionNumber invalid feedbackSource: $feedbackSource"
    Assert-Condition ($captureDurationMs -eq $audioDurationMs) "Condition $conditionNumber ECG capture duration must equal audio duration: capture=$captureDurationMs audio=$audioDurationMs"
    Assert-Condition ($captureDurationNs -eq $audioDurationNs) "Condition $conditionNumber ECG capture ns duration must equal audio duration: captureNs=$captureDurationNs audioMs=$audioDurationMs"
    Assert-Condition (($captureEndedElapsedNs - $captureStartedElapsedNs) -eq $audioDurationNs) "Condition $conditionNumber ECG capture ns window must equal audio duration"
    Assert-Condition ($audioWindowStartMs -eq 0 -and $audioWindowEndMs -eq $audioDurationMs -and $audioWindowDurationMs -eq $audioDurationMs) "Condition $conditionNumber ECG audio window fields must be 0..audio duration"
    Assert-Condition ($sampleRateHz -eq 130) "Condition $conditionNumber ECG sample rate should be 130 Hz, found $sampleRateHz"
    Assert-Condition ($expectedSamples -gt 0) "Condition $conditionNumber missing expected ECG sample count"
    Assert-Condition ($sampleCount -ge $requiredRealPolarSampleCount) "Condition $conditionNumber real Polar ECG sample coverage too low: expected at least $requiredRealPolarSampleCount from $expectedSamples ($MinRealPolarEcgCoverageRatio coverage), found $sampleCount"
    Assert-Condition ($realSampleCount -eq $sampleCount) "Condition $conditionNumber realEcgTimeSeriesSampleCount must match ECG time-series sample count"
    Assert-Condition ($requestedMtu -gt 0) "Condition $conditionNumber missing requested MTU"
    Assert-Condition ($requestedMtu -eq 70) "Condition $conditionNumber should use requested MTU 70 for minimum-packet low-latency PMD readout, found $requestedMtu"
    Assert-Condition ($negotiatedMtu -ge 0) "Condition $conditionNumber invalid negotiated MTU"

    $conditionTimeSeriesRows = @($EcgTimeSeriesRows | Where-Object { $_.condition_number -eq "$conditionNumber" })
    $csvRealPolarTimeSeriesRows = @($conditionTimeSeriesRows | Where-Object { $_.source -eq 'real_polar_h10' })
    $csvSimulatedTimeSeriesRows = @($conditionTimeSeriesRows | Where-Object { $_.source -eq 'simulated_neurokit2' })
    $csvFeedbackBlinkRows = @($EcgBlinkRows | Where-Object { $_.condition_number -eq "$conditionNumber" -and $_.source -eq $feedbackSource })
    $csvRealPolarBlinkRows = @($EcgBlinkRows | Where-Object { $_.condition_number -eq "$conditionNumber" -and $_.source -eq 'real_polar_h10' })
    $csvSimulatedBlinkRows = @($EcgBlinkRows | Where-Object { $_.condition_number -eq "$conditionNumber" -and $_.source -eq 'simulated_neurokit2' })
    $csvPolarRrRows = @($PolarRrRows | Where-Object { $_.condition_number -eq "$conditionNumber" })

    $realPolarCaptureStartMarkers =
        ([regex]::Matches(
            $LogText,
            "BRB_ECG_CAPTURE_START condition=$conditionNumber source=real_polar_h10 .*audioDurationMs=$audioDurationMs .*sampleRateHz=130"
        )).Count
    $realPolarCaptureEndMarkers =
        ([regex]::Matches(
            $LogText,
            "BRB_ECG_CAPTURE_END condition=$conditionNumber source=real_polar_h10 .*audioDurationMs=$audioDurationMs .*sampleRateHz=130 .*actualSamples=$sampleCount .*captureWindowMs=$captureDurationMs"
        )).Count

    Assert-Condition ($realPolarCaptureStartMarkers -gt 0) "Missing real Polar ECG capture start marker for condition $conditionNumber"
    Assert-Condition ($realPolarCaptureEndMarkers -gt 0) "Missing real Polar ECG capture end marker for condition $conditionNumber"
    Assert-Condition ($csvSimulatedTimeSeriesRows.Count -eq 0) "Condition $conditionNumber contains simulated ECG rows in real physiology time-series: $($csvSimulatedTimeSeriesRows.Count)"
    Assert-Condition ($csvRealPolarTimeSeriesRows.Count -eq $sampleCount) "Condition $conditionNumber real Polar ECG time-series JSON/CSV mismatch: json=$sampleCount csv=$($csvRealPolarTimeSeriesRows.Count)"
    Assert-Condition ($csvRealPolarTimeSeriesRows.Count -ge $requiredRealPolarSampleCount) "Condition $conditionNumber real Polar ECG time-series CSV rows too low: expected at least $requiredRealPolarSampleCount, found $($csvRealPolarTimeSeriesRows.Count)"
    Assert-Condition ($csvPolarRrRows.Count -eq $polarRrEventCount) "Condition $conditionNumber Polar RR JSON/CSV mismatch: json=$polarRrEventCount csv=$($csvPolarRrRows.Count)"
    Assert-Condition ($csvPolarRrRows.Count -ge $MinRealPolarBlinkEvents) "Condition $conditionNumber Polar RR event rows too low: expected at least $MinRealPolarBlinkEvents, found $($csvPolarRrRows.Count)"
    Assert-Condition ($csvFeedbackBlinkRows.Count -eq $blinkCount) "Condition $conditionNumber feedback blink JSON/CSV mismatch: json=$blinkCount csv=$($csvFeedbackBlinkRows.Count)"
    if ($feedbackSource -eq 'real_polar_h10') {
        Assert-Condition ($csvRealPolarBlinkRows.Count -ge $MinRealPolarBlinkEvents) "Condition $conditionNumber real-feedback blink evidence too low: expected at least $MinRealPolarBlinkEvents, found $($csvRealPolarBlinkRows.Count)"
    } else {
        Assert-Condition ($csvSimulatedBlinkRows.Count -ge 1) "Condition $conditionNumber simulated-feedback blink evidence missing"
        Assert-Condition ($csvRealPolarBlinkRows.Count -eq 0) "Condition $conditionNumber sham feedback must not use real Polar RR to drive glow"
    }

    $rrRowsWithInvalidFeedbackSource = 0
    $rrRowsWithInvalidUsedForFeedback = 0
    $expectedUsedForFeedback = ($feedbackSource -eq 'real_polar_h10')
    foreach ($row in $csvPolarRrRows) {
        $rrElapsedNs = Get-Int64Value $row.elapsed_ns "condition $conditionNumber Polar RR elapsed_ns"
        if ($row.feedback_source -ne $feedbackSource) {
            $rrRowsWithInvalidFeedbackSource += 1
        }
        if ((Test-Truthy $row.used_for_feedback) -ne $expectedUsedForFeedback) {
            $rrRowsWithInvalidUsedForFeedback += 1
        }
        Assert-Condition ($rrElapsedNs -ge 0 -and $rrElapsedNs -le $audioDurationNs) "Condition $conditionNumber Polar RR elapsed_ns outside audio window: $rrElapsedNs"
        Assert-Condition ((Get-DoubleValue $row.rr_ms "condition $conditionNumber Polar RR rr_ms") -gt 0) "Condition $conditionNumber Polar RR row missing rr_ms"
        Assert-Condition ((Get-IntValue $row.heart_rate_bpm "condition $conditionNumber Polar RR heart_rate_bpm") -gt 0) "Condition $conditionNumber Polar RR row missing heart_rate_bpm"
    }
    Assert-Condition ($rrRowsWithInvalidFeedbackSource -eq 0) "Condition $conditionNumber Polar RR rows with feedback_source mismatch: $rrRowsWithInvalidFeedbackSource"
    Assert-Condition ($rrRowsWithInvalidUsedForFeedback -eq 0) "Condition $conditionNumber Polar RR rows with used_for_feedback mismatch: $rrRowsWithInvalidUsedForFeedback"

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
        $sampleIndex = Get-IntValue $row.sample_index "condition $conditionNumber real Polar ECG sample_index"
        $elapsed = Get-DoubleValue $row.elapsed_ms "condition $conditionNumber real Polar ECG elapsed_ms"
        $elapsedNs = Get-Int64Value $row.elapsed_ns "condition $conditionNumber real Polar ECG elapsed_ns"
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
        if ((Get-IntValue $row.sample_rate_hz "condition $conditionNumber real Polar ECG sample_rate_hz") -ne 130) {
            $realPolarRowsWithInvalidRate += 1
        }
        if ((Get-IntValue $row.package_size_bytes "condition $conditionNumber real Polar ECG package_size_bytes") -le 0) {
            $realPolarRowsWithInvalidPackage += 1
        }
        if ((Get-IntValue $row.frame_index "condition $conditionNumber real Polar ECG frame_index") -le 0) {
            $realPolarRowsWithInvalidFrame += 1
        }
        if ((Get-IntValue $row.requested_mtu "condition $conditionNumber real Polar ECG requested_mtu") -ne 70) {
            $realPolarRowsWithInvalidMtu += 1
        }
        if ((Get-IntValue $row.audio_window_start_ms "condition $conditionNumber real Polar ECG audio_window_start_ms") -ne 0 -or
            (Get-IntValue $row.audio_window_end_ms "condition $conditionNumber real Polar ECG audio_window_end_ms") -ne $audioDurationMs -or
            (Get-IntValue $row.audio_window_duration_ms "condition $conditionNumber real Polar ECG audio_window_duration_ms") -ne $audioDurationMs) {
            $realPolarRowsOutOfWindow += 1
        } elseif ($elapsed -lt 0 -or $elapsed -gt $audioDurationMs -or $elapsedNs -lt 0 -or $elapsedNs -gt $audioDurationNs) {
            $realPolarRowsOutOfWindow += 1
        }
    }

    Assert-Condition ($realPolarElapsedNsDeltas.Count -gt 0) "Condition $conditionNumber real Polar ECG time-series needs at least two samples for sample-interval validation"
    $realPolarFirstSampleElapsedMs = ($realPolarElapsedValues | Measure-Object -Minimum).Minimum
    $realPolarLastSampleElapsedMs = ($realPolarElapsedValues | Measure-Object -Maximum).Maximum
    $realPolarFirstSampleElapsedNs = ($realPolarElapsedNsValues | Measure-Object -Minimum).Minimum
    $realPolarLastSampleElapsedNs = ($realPolarElapsedNsValues | Measure-Object -Maximum).Maximum
    $realPolarMedianSampleDeltaNs = Get-Median @($realPolarElapsedNsDeltas)
    $realPolarMaxSampleDeltaNs = [int64]($realPolarElapsedNsDeltas | Measure-Object -Maximum).Maximum
    $expectedRealPolarSampleDeltaNs = 1000000000.0 / [double]$sampleRateHz
    $realPolarMedianDeltaErrorRatio =
        [math]::Abs($realPolarMedianSampleDeltaNs - $expectedRealPolarSampleDeltaNs) / $expectedRealPolarSampleDeltaNs
    $maxRealPolarEcgSampleGapNs = [int64]$MaxRealPolarEcgSampleGapMs * 1000000L

    Assert-Condition ($realPolarRowsWithInvalidRate -eq 0) "Condition $conditionNumber real Polar ECG CSV rows with non-130 Hz sample rate: $realPolarRowsWithInvalidRate"
    Assert-Condition ($realPolarRowsWithInvalidPackage -eq 0) "Condition $conditionNumber real Polar ECG CSV rows with invalid PMD package size: $realPolarRowsWithInvalidPackage"
    Assert-Condition ($realPolarRowsWithInvalidFrame -eq 0) "Condition $conditionNumber real Polar ECG CSV rows with invalid PMD frame index: $realPolarRowsWithInvalidFrame"
    Assert-Condition ($realPolarRowsWithInvalidMtu -eq 0) "Condition $conditionNumber real Polar ECG CSV rows without requested MTU 70: $realPolarRowsWithInvalidMtu"
    Assert-Condition ($realPolarRowsOutOfWindow -eq 0) "Condition $conditionNumber real Polar ECG CSV rows outside audio window: $realPolarRowsOutOfWindow"
    Assert-Condition ($realPolarRowsWithInvalidSampleIndex -eq 0) "Condition $conditionNumber real Polar ECG sample_index values are not sequential: $realPolarRowsWithInvalidSampleIndex"
    Assert-Condition ($realPolarRowsWithNonMonotonicElapsedNs -eq 0) "Condition $conditionNumber real Polar ECG elapsed_ns values are not strictly increasing: $realPolarRowsWithNonMonotonicElapsedNs"
    Assert-Condition ($realPolarMedianDeltaErrorRatio -le $MaxRealPolarEcgMedianDeltaErrorRatio) "Condition $conditionNumber real Polar ECG median sample interval does not match $sampleRateHz Hz: medianDeltaNs=$realPolarMedianSampleDeltaNs expectedDeltaNs=$expectedRealPolarSampleDeltaNs errorRatio=$realPolarMedianDeltaErrorRatio max=$MaxRealPolarEcgMedianDeltaErrorRatio"
    Assert-Condition ($realPolarMaxSampleDeltaNs -le $maxRealPolarEcgSampleGapNs) "Condition $conditionNumber real Polar ECG sample gap too large for continuous high-resolution capture: maxDeltaNs=$realPolarMaxSampleDeltaNs maxAllowedNs=$maxRealPolarEcgSampleGapNs"
    Assert-Condition ($realPolarFirstSampleElapsedMs -le $MaxRealPolarEcgBoundaryGapMs) "Condition $conditionNumber real Polar ECG first sample starts too late: first=${realPolarFirstSampleElapsedMs}ms maxGap=${MaxRealPolarEcgBoundaryGapMs}ms"
    Assert-Condition ($realPolarLastSampleElapsedMs -ge ($audioDurationMs - $MaxRealPolarEcgBoundaryGapMs)) "Condition $conditionNumber real Polar ECG last sample ends too early: last=${realPolarLastSampleElapsedMs}ms audio=${audioDurationMs}ms maxGap=${MaxRealPolarEcgBoundaryGapMs}ms"

    $jsonControllerPressEvents = @($Condition.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
    $csvControllerPressRows = @($PressRows | Where-Object { $_.condition_number -eq "$conditionNumber" -and $_.input_source -eq 'controller_contact' })
    Validate-PressAlignmentRows -Rows $jsonControllerPressEvents -ConditionNumber $conditionNumber -AudioDurationNs $audioDurationNs -MaxPressEcgAlignmentDeltaNs $MaxPressEcgAlignmentDeltaNs -Kind 'JSON'
    Validate-PressAlignmentRows -Rows $csvControllerPressRows -ConditionNumber $conditionNumber -AudioDurationNs $audioDurationNs -MaxPressEcgAlignmentDeltaNs $MaxPressEcgAlignmentDeltaNs -Kind 'CSV'

    return [pscustomobject]@{
        conditionNumber = $conditionNumber
        feedbackSource = $feedbackSource
        physiologySource = $physiologySource
        audioDurationMs = $audioDurationMs
        captureDurationMs = $captureDurationMs
        captureDurationNs = $captureDurationNs
        captureStartedElapsedNs = $captureStartedElapsedNs
        captureEndedElapsedNs = $captureEndedElapsedNs
        audioWindowStartMs = $audioWindowStartMs
        audioWindowEndMs = $audioWindowEndMs
        audioWindowDurationMs = $audioWindowDurationMs
        sampleRateHz = $sampleRateHz
        expectedSamples = $expectedSamples
        requiredSamples = $requiredRealPolarSampleCount
        sampleCount = $sampleCount
        realSampleCount = $realSampleCount
        blinkCount = $blinkCount
        polarRrEventCount = $polarRrEventCount
        csvRealPolarTimeSeriesRows = $csvRealPolarTimeSeriesRows.Count
        csvFeedbackBlinkRows = $csvFeedbackBlinkRows.Count
        csvPolarRrRows = $csvPolarRrRows.Count
        requestedMtu = $requestedMtu
        negotiatedMtu = $negotiatedMtu
        firstSampleElapsedMs = $realPolarFirstSampleElapsedMs
        lastSampleElapsedMs = $realPolarLastSampleElapsedMs
        firstSampleElapsedNs = $realPolarFirstSampleElapsedNs
        lastSampleElapsedNs = $realPolarLastSampleElapsedNs
        medianSampleDeltaNs = $realPolarMedianSampleDeltaNs
        expectedSampleDeltaNs = $expectedRealPolarSampleDeltaNs
        medianDeltaErrorRatio = $realPolarMedianDeltaErrorRatio
        maxSampleDeltaNs = $realPolarMaxSampleDeltaNs
        rowsWithInvalidSampleIndex = $realPolarRowsWithInvalidSampleIndex
        rowsWithNonMonotonicElapsedNs = $realPolarRowsWithNonMonotonicElapsedNs
        captureStartMarkers = $realPolarCaptureStartMarkers
        captureEndMarkers = $realPolarCaptureEndMarkers
    }
}

$exportSession = Resolve-BrbExportSession -ExportDir $ExportDir
$ExportSessionDir = $exportSession.SessionDir

$jsonFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter 'brb_first_study_*.json'
$pressFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_press_events.csv'
$ecgBlinkFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_ecg_blink_events.csv'
$ecgTimeSeriesFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_ecg_timeseries.csv'
$polarRrFile = Get-BrbExportSessionFile -SessionDir $ExportSessionDir -Filter '*_polar_rr_events.csv'

Assert-Condition ($null -ne $jsonFile) "Missing JSON export in $ExportSessionDir"
Assert-Condition ($null -ne $pressFile) "Missing press-events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $ecgBlinkFile) "Missing ECG blink-events CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $ecgTimeSeriesFile) "Missing ECG time-series CSV export in $ExportSessionDir"
Assert-Condition ($null -ne $polarRrFile) "Missing Polar RR events CSV export in $ExportSessionDir"

$exportJson = Get-Content -Raw -LiteralPath $jsonFile.FullName | ConvertFrom-Json
$conditions = @($exportJson.conditions)
$condition1 = $conditions | Where-Object { $_.conditionNumber -eq 1 } | Select-Object -First 1
$condition2 = $conditions | Where-Object { $_.conditionNumber -eq 2 } | Select-Object -First 1
Assert-Condition ($null -ne $condition1) 'Missing condition 1 in JSON export'
Assert-Condition ($null -ne $condition2) 'Missing condition 2 in JSON export'
Assert-Condition ($exportJson.ecgProtocol.assignmentOrder -in @('real_then_simulated', 'simulated_then_real')) 'Invalid feedback assignment order'
Assert-Condition ($exportJson.ecgProtocol.assignmentBasis -eq 'feedback_source') 'ECG assignment basis must be feedback_source'
Assert-Condition ($condition1.feedbackSource -ne $condition2.feedbackSource) 'Feedback sources must be counterbalanced complements'
Assert-Condition (@($conditions | Where-Object { $_.feedbackSource -eq 'real_polar_h10' }).Count -eq 1) 'Expected exactly one real_polar_h10 feedback condition'
Assert-Condition (@($conditions | Where-Object { $_.feedbackSource -eq 'simulated_neurokit2' }).Count -eq 1) 'Expected exactly one simulated_neurokit2 feedback condition'
Assert-Condition (@($conditions | Where-Object { $_.physiologySource -eq 'real_polar_h10' -and $_.ecgSource -eq 'real_polar_h10' }).Count -eq 2) 'Both conditions must record real_polar_h10 physiology'

$pressRows = @(Import-Csv -LiteralPath $pressFile.FullName)
$ecgBlinkRows = @(Import-Csv -LiteralPath $ecgBlinkFile.FullName)
$ecgTimeSeriesRows = @(Import-Csv -LiteralPath $ecgTimeSeriesFile.FullName)
$polarRrRows = @(Import-Csv -LiteralPath $polarRrFile.FullName)
$logText = Get-Content -Raw -LiteralPath $LogcatPath

$allJsonPressEvents = @($conditions | ForEach-Object { @($_.pressEvents) })
$condition1ControllerPressEvents = @($condition1.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
$condition2ControllerPressEvents = @($condition2.pressEvents | Where-Object { $_.inputSource -eq 'controller_contact' })
$condition1ControllerPresses = $condition1ControllerPressEvents.Count
$condition2ControllerPresses = $condition2ControllerPressEvents.Count
$csvCondition1ControllerPressRows =
    @($pressRows | Where-Object { $_.condition_number -eq '1' -and $_.input_source -eq 'controller_contact' })
$csvCondition2ControllerPressRows =
    @($pressRows | Where-Object { $_.condition_number -eq '2' -and $_.input_source -eq 'controller_contact' })
$csvCondition1ControllerPresses = $csvCondition1ControllerPressRows.Count
$csvCondition2ControllerPresses = $csvCondition2ControllerPressRows.Count

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

$jsonAutomatedPresses =
    @($allJsonPressEvents | Where-Object { $_.inputSource -eq 'auto_validation' -or (Test-Truthy $_.validationAutomation) }).Count
$csvAutomatedPresses =
    @($pressRows | Where-Object { $_.input_source -eq 'auto_validation' -or (Test-Truthy $_.validation_automation) }).Count
$jsonControllerPressesMarkedAutomated =
    @($allJsonPressEvents | Where-Object { $_.inputSource -eq 'controller_contact' -and (Test-Truthy $_.validationAutomation) }).Count
$csvControllerPressesMarkedAutomated =
    @($pressRows | Where-Object { $_.input_source -eq 'controller_contact' -and (Test-Truthy $_.validation_automation) }).Count

Assert-Condition ($condition1ControllerPresses -ge $MinCondition1ControllerPresses) "Condition 1 controller_contact presses too low: expected at least $MinCondition1ControllerPresses, found $condition1ControllerPresses"
Assert-Condition ($condition2ControllerPresses -ge $MinCondition2ControllerPresses) "Condition 2 controller_contact presses too low: expected at least $MinCondition2ControllerPresses, found $condition2ControllerPresses"
Assert-Condition ($condition1ControllerPresses -eq $csvCondition1ControllerPresses) "Condition 1 JSON/CSV controller_contact mismatch: json=$condition1ControllerPresses csv=$csvCondition1ControllerPresses"
Assert-Condition ($condition2ControllerPresses -eq $csvCondition2ControllerPresses) "Condition 2 JSON/CSV controller_contact mismatch: json=$condition2ControllerPresses csv=$csvCondition2ControllerPresses"
Assert-Condition ($logControllerPressMarkers -ge ($condition1ControllerPresses + $condition2ControllerPresses)) "Logcat controller_contact markers fewer than exported controller_contact events: log=$logControllerPressMarkers export=$($condition1ControllerPresses + $condition2ControllerPresses)"
Assert-Condition ($acceptedContactSelects -ge ($condition1ControllerPresses + $condition2ControllerPresses)) "Accepted controller-contact select markers fewer than exported controller_contact events: accepted=$acceptedContactSelects export=$($condition1ControllerPresses + $condition2ControllerPresses)"
Assert-Condition ($null -ne $sourceSummaryCondition1ControllerPresses) 'Missing condition 1 BRB_CONDITION_PRESS_SOURCES marker in logcat'
Assert-Condition ($null -ne $sourceSummaryCondition2ControllerPresses) 'Missing condition 2 BRB_CONDITION_PRESS_SOURCES marker in logcat'
Assert-Condition ($sourceSummaryCondition1ControllerPresses -eq $condition1ControllerPresses) "Condition 1 source-summary controllerContact count mismatch: summary=$sourceSummaryCondition1ControllerPresses export=$condition1ControllerPresses"
Assert-Condition ($sourceSummaryCondition2ControllerPresses -eq $condition2ControllerPresses) "Condition 2 source-summary controllerContact count mismatch: summary=$sourceSummaryCondition2ControllerPresses export=$condition2ControllerPresses"
Assert-Condition ($jsonAutomatedPresses -eq 0) "Physical press evidence contains automated button presses in JSON: $jsonAutomatedPresses"
Assert-Condition ($csvAutomatedPresses -eq 0) "Physical press evidence contains automated button presses in CSV: $csvAutomatedPresses"
Assert-Condition ($logAutomatedPressMarkers -eq 0) "Physical press evidence contains automated button press markers in logcat: $logAutomatedPressMarkers"
Assert-Condition ($jsonControllerPressesMarkedAutomated -eq 0) "JSON controller_contact press events are marked validationAutomation=true: $jsonControllerPressesMarkedAutomated"
Assert-Condition ($csvControllerPressesMarkedAutomated -eq 0) "CSV controller_contact press rows are marked validation_automation=true: $csvControllerPressesMarkedAutomated"
Assert-Condition ($lowLatencyConfigMarkers -gt 0) 'Missing Polar H10 low-latency PMD ECG config marker with requestedMtu=70'

$maxPressEcgAlignmentDeltaNs = [int64]($MaxPressEcgAlignmentDeltaMs * 1000000.0)
$conditionEvidence = @(
    Validate-RealPolarCondition -Condition $condition1 -PressRows $pressRows -EcgBlinkRows $ecgBlinkRows -EcgTimeSeriesRows $ecgTimeSeriesRows -PolarRrRows $polarRrRows -LogText $logText -MinRealPolarEcgSamples $MinRealPolarEcgSamples -MinRealPolarBlinkEvents $MinRealPolarBlinkEvents -MinRealPolarEcgCoverageRatio $MinRealPolarEcgCoverageRatio -MaxRealPolarEcgBoundaryGapMs $MaxRealPolarEcgBoundaryGapMs -MaxRealPolarEcgMedianDeltaErrorRatio $MaxRealPolarEcgMedianDeltaErrorRatio -MaxRealPolarEcgSampleGapMs $MaxRealPolarEcgSampleGapMs -MaxPressEcgAlignmentDeltaNs $maxPressEcgAlignmentDeltaNs
    Validate-RealPolarCondition -Condition $condition2 -PressRows $pressRows -EcgBlinkRows $ecgBlinkRows -EcgTimeSeriesRows $ecgTimeSeriesRows -PolarRrRows $polarRrRows -LogText $logText -MinRealPolarEcgSamples $MinRealPolarEcgSamples -MinRealPolarBlinkEvents $MinRealPolarBlinkEvents -MinRealPolarEcgCoverageRatio $MinRealPolarEcgCoverageRatio -MaxRealPolarEcgBoundaryGapMs $MaxRealPolarEcgBoundaryGapMs -MaxRealPolarEcgMedianDeltaErrorRatio $MaxRealPolarEcgMedianDeltaErrorRatio -MaxRealPolarEcgSampleGapMs $MaxRealPolarEcgSampleGapMs -MaxPressEcgAlignmentDeltaNs $maxPressEcgAlignmentDeltaNs
)

$totalRealPolarSampleCount = [int](($conditionEvidence | Measure-Object -Property sampleCount -Sum).Sum)
$totalRealPolarRequiredSamples = [int](($conditionEvidence | Measure-Object -Property requiredSamples -Sum).Sum)
$totalFeedbackBlinkCount = [int](($conditionEvidence | Measure-Object -Property blinkCount -Sum).Sum)
$totalPolarRrEventCount = [int](($conditionEvidence | Measure-Object -Property polarRrEventCount -Sum).Sum)
$totalAudioDurationMs = [int](($conditionEvidence | Measure-Object -Property audioDurationMs -Sum).Sum)
$totalCaptureDurationMs = [int](($conditionEvidence | Measure-Object -Property captureDurationMs -Sum).Sum)
$firstSampleElapsedMs = ($conditionEvidence | Measure-Object -Property firstSampleElapsedMs -Minimum).Minimum
$lastSampleElapsedMs = ($conditionEvidence | Measure-Object -Property lastSampleElapsedMs -Maximum).Maximum

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    exportDir = $ExportDir
    logcatPath = $LogcatPath
    json = $jsonFile.FullName
    pressEventsCsv = $pressFile.FullName
    ecgBlinkEventsCsv = $ecgBlinkFile.FullName
    ecgTimeSeriesCsv = $ecgTimeSeriesFile.FullName
    polarRrEventsCsv = $polarRrFile.FullName
    minCondition1ControllerPresses = $MinCondition1ControllerPresses
    minCondition2ControllerPresses = $MinCondition2ControllerPresses
    minRealPolarEcgSamples = $MinRealPolarEcgSamples
    minRealPolarBlinkEvents = $MinRealPolarBlinkEvents
    minRealPolarEcgCoverageRatio = $MinRealPolarEcgCoverageRatio
    maxRealPolarEcgBoundaryGapMs = $MaxRealPolarEcgBoundaryGapMs
    maxRealPolarEcgMedianDeltaErrorRatio = $MaxRealPolarEcgMedianDeltaErrorRatio
    maxRealPolarEcgSampleGapMs = $MaxRealPolarEcgSampleGapMs
    maxPressEcgAlignmentDeltaMs = $MaxPressEcgAlignmentDeltaMs
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
    realPolarConditionNumber = '1,2'
    realPolarConditionNumbers = @(1, 2)
    realPolarAudioDurationMs = $totalAudioDurationMs
    realPolarCaptureDurationMs = $totalCaptureDurationMs
    realPolarSampleCount = $totalRealPolarSampleCount
    realPolarRequiredSamples = $totalRealPolarRequiredSamples
    realPolarBlinkCount = $totalFeedbackBlinkCount
    realPolarPolarRrEventCount = $totalPolarRrEventCount
    realPolarFirstSampleElapsedMs = $firstSampleElapsedMs
    realPolarLastSampleElapsedMs = $lastSampleElapsedMs
    conditionRealPolarEvidence = $conditionEvidence
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutPath -Encoding UTF8
Write-Host "PASS physical press evidence validation"
Write-Host "Summary: $OutPath"
