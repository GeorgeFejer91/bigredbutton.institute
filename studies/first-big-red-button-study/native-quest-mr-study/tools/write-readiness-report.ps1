[CmdletBinding()]
param(
    [string]$OutDir = '',
    [string]$FinalHardwareGateSummaryPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $projectRoot ('artifacts\readiness-report\report-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-LatestRunDirectory {
    param([string]$RelativePath)
    $root = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path $root)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $root -Directory |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Get-LatestArtifactFile {
    param(
        [string]$RelativePath,
        [string]$Filter
    )
    $root = Join-Path $projectRoot $RelativePath
    if (-not (Test-Path $root)) {
        return $null
    }
    return Get-ChildItem -LiteralPath $root -File -Filter $Filter |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Test-FinalHardwareSummaryHasPassingValidation {
    param([string]$SummaryPath)
    $validationRoot = Join-Path $projectRoot 'artifacts\final-hardware-postrun-audit-validation'
    if (-not (Test-Path $validationRoot)) {
        return $false
    }
    $validationFiles =
        Get-ChildItem -LiteralPath $validationRoot -Recurse -File -Filter 'final-hardware-postrun-audit-validation.json' |
        Sort-Object LastWriteTime -Descending
    foreach ($validationFile in @($validationFiles)) {
        try {
            $validation = Read-JsonFile $validationFile.FullName
            if (
                (Get-JsonPropertyValue $validation 'status') -eq 'pass' -and
                (Same-Path (Get-JsonPropertyValue $validation 'summaryPath') $SummaryPath)
            ) {
                return $true
            }
        } catch {
            continue
        }
    }
    return $false
}

function Get-LatestValidatedFinalHardwareDryRunSummary {
    $root = Join-Path $projectRoot 'artifacts\final-hardware-gates'
    if (-not (Test-Path $root)) {
        return $null
    }
    $summaries =
        Get-ChildItem -LiteralPath $root -Recurse -File -Filter 'final-hardware-gates-summary.json' |
        Sort-Object LastWriteTime -Descending
    foreach ($summary in @($summaries)) {
        try {
            $json = Read-JsonFile $summary.FullName
            $postRunAudit = Get-JsonPropertyValue $json 'postRunAudit'
            if (
                (Get-JsonPropertyValue $json 'status') -eq 'dry_run' -and
                (Get-JsonPropertyValue $json 'dryRun') -eq $true -and
                (Get-JsonPropertyValue $postRunAudit 'status') -eq 'pass' -and
                (Test-FinalHardwareSummaryHasPassingValidation $summary.FullName)
            ) {
                return $summary
            }
        } catch {
            continue
        }
    }
    return $null
}

function Get-LatestFinalHardwareDryRunSummary {
    return Get-LatestValidatedFinalHardwareDryRunSummary
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        throw "Missing required JSON file: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-JsonPropertyValue {
    param(
        $Object,
        [string]$Name
    )
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ComparisonByName {
    param(
        $Comparisons,
        [string]$Name
    )
    if ($null -eq $Comparisons) {
        return $null
    }
    foreach ($comparison in @($Comparisons)) {
        if ((Get-JsonPropertyValue $comparison 'name') -eq $Name) {
            return $comparison
        }
    }
    return $null
}

function Get-StepByName {
    param(
        $Steps,
        [string]$Name
    )
    if ($null -eq $Steps) {
        return $null
    }
    foreach ($step in @($Steps)) {
        if ((Get-JsonPropertyValue $step 'name') -eq $Name) {
            return $step
        }
    }
    return $null
}

function Same-Path {
    param(
        [string]$Left,
        [string]$Right
    )
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }
    $leftFull = [IO.Path]::GetFullPath($Left)
    $rightFull = [IO.Path]::GetFullPath($Right)
    return [string]::Equals($leftFull, $rightFull, [StringComparison]::OrdinalIgnoreCase)
}

$apkPath = Join-Path $projectRoot 'app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path $apkPath)) {
    throw "Missing debug APK: $apkPath"
}
$apkItem = Get-Item -LiteralPath $apkPath
$apkHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkItem.FullName).Hash

$localPreflightDir = Get-LatestRunDirectory 'artifacts\local-preflight'
$questSmokeSuiteDir = Get-LatestRunDirectory 'artifacts\quest-smoke-suite'
$questKeyeventDir = Get-LatestRunDirectory 'artifacts\qkv'
$polarLiveSmokeDir = Get-LatestRunDirectory 'artifacts\qpolar'
$controllerContactSmokeDir = Get-LatestRunDirectory 'artifacts\qcs'
$physicalPressValidationDir = Get-LatestRunDirectory 'artifacts\qpv'
$finalHardwareGateSummaryFile = $null
if (-not [string]::IsNullOrWhiteSpace($FinalHardwareGateSummaryPath)) {
    $finalHardwareGateSummaryFile = Get-Item -LiteralPath (Resolve-Path -LiteralPath $FinalHardwareGateSummaryPath).Path
} else {
    $finalHardwareGateSummaryFile = Get-LatestFinalHardwareDryRunSummary
}
if ($null -eq $localPreflightDir) {
    throw 'No local preflight artifact was found.'
}
if ($null -eq $questSmokeSuiteDir) {
    throw 'No Quest smoke suite artifact was found.'
}
if ($null -eq $questKeyeventDir) {
    throw 'No Quest keyevent questionnaire validation artifact was found.'
}

$localPreflightPath = Join-Path $localPreflightDir.FullName 'local-preflight-summary.json'
$questSmokeSuitePath = Join-Path $questSmokeSuiteDir.FullName 'quest-smoke-suite-summary.json'
$questKeyeventPath = Join-Path $questKeyeventDir.FullName 'quest-keyevent-questionnaire-validation-summary.json'
$localPreflight = Read-JsonFile $localPreflightPath
$questSmokeSuite = Read-JsonFile $questSmokeSuitePath
$questKeyevent = Read-JsonFile $questKeyeventPath
$latestLocalValidationFile = Get-LatestArtifactFile 'artifacts\local-validation' 'validation-*.json'
$localValidationPath =
    if ($null -ne $latestLocalValidationFile) {
        $latestLocalValidationFile.FullName
    } else {
        $localPreflight.latestArtifacts.localValidation
    }
$latestNativeKeyboardValidationFile = Get-LatestArtifactFile 'artifacts\native-keyboard-validation' 'native-keyboard-validation-*.json'
$nativeKeyboardValidationPath =
    if ($null -ne $latestNativeKeyboardValidationFile) {
        $latestNativeKeyboardValidationFile.FullName
    } else {
        Get-JsonPropertyValue $localPreflight.latestArtifacts 'nativeKeyboardValidation'
    }
$nativeKeyboardValidation =
    if (-not [string]::IsNullOrWhiteSpace($nativeKeyboardValidationPath) -and (Test-Path $nativeKeyboardValidationPath)) {
        Read-JsonFile $nativeKeyboardValidationPath
    } else {
        $null
    }
$finalHardwarePostRunAuditValidatorTestPath = Get-JsonPropertyValue $localPreflight.latestArtifacts 'finalHardwarePostRunAuditValidatorTest'
$finalHardwarePostRunAuditValidatorTest =
    if (-not [string]::IsNullOrWhiteSpace($finalHardwarePostRunAuditValidatorTestPath) -and (Test-Path $finalHardwarePostRunAuditValidatorTestPath)) {
        Read-JsonFile $finalHardwarePostRunAuditValidatorTestPath
    } else {
        $null
    }
$finalHardwarePostRunAuditValidationPath = Get-JsonPropertyValue $localPreflight.latestArtifacts 'finalHardwarePostRunAuditValidation'
$finalHardwarePostRunAuditValidation =
    if (-not [string]::IsNullOrWhiteSpace($finalHardwarePostRunAuditValidationPath) -and (Test-Path $finalHardwarePostRunAuditValidationPath)) {
        Read-JsonFile $finalHardwarePostRunAuditValidationPath
    } else {
        $null
    }
$polarLiveSmokePath = $null
$polarLiveSmoke = $null
if ($null -ne $polarLiveSmokeDir) {
    $candidate = Join-Path $polarLiveSmokeDir.FullName 'quest-polar-h10-live-smoke-summary.json'
    if (Test-Path $candidate) {
        $polarLiveSmokePath = $candidate
        $polarLiveSmoke = Read-JsonFile $candidate
    }
}
$controllerContactSmokePath = $null
$controllerContactSmoke = $null
if ($null -ne $controllerContactSmokeDir) {
    $candidate = Join-Path $controllerContactSmokeDir.FullName 'quest-controller-contact-smoke-summary.json'
    if (Test-Path $candidate) {
        $controllerContactSmokePath = $candidate
        $controllerContactSmoke = Read-JsonFile $candidate
    }
}
$physicalPressValidationPath = $null
$physicalPressValidation = $null
if ($null -ne $physicalPressValidationDir) {
    $candidate = Join-Path $physicalPressValidationDir.FullName 'quest-physical-press-validation-summary.json'
    if (Test-Path $candidate) {
        $physicalPressValidationPath = $candidate
        $physicalPressValidation = Read-JsonFile $candidate
    }
}
$finalHardwareGatePath = $null
$finalHardwareGate = $null
if ($null -ne $finalHardwareGateSummaryFile) {
    $finalHardwareGatePath = $finalHardwareGateSummaryFile.FullName
    $finalHardwareGate = Read-JsonFile $finalHardwareGatePath
}

$localPreflightPass = $localPreflight.status -eq 'pass'
$nativeKeyboardContractPass = $null -ne $nativeKeyboardValidation -and $nativeKeyboardValidation.status -eq 'pass'
$finalHardwarePostRunAuditValidatorTestPass = $null -ne $finalHardwarePostRunAuditValidatorTest -and $finalHardwarePostRunAuditValidatorTest.status -eq 'pass'
$questSmokePass = $questSmokeSuite.status -eq 'pass'
$questKeyeventPass = $questKeyevent.status -eq 'pass'
$localHashMatches = $localPreflight.apk.sha256 -eq $apkHash
$questHashMatches = $questSmokeSuite.apk.sha256 -eq $apkHash
$questKeyeventApkSha256 = Get-JsonPropertyValue $questKeyevent 'apkSha256'
if ([string]::IsNullOrWhiteSpace($questKeyeventApkSha256)) {
    $questKeyeventApk = Get-JsonPropertyValue $questKeyevent 'apk'
    if ($null -ne $questKeyeventApk -and -not ($questKeyeventApk -is [string])) {
        $questKeyeventApkSha256 = Get-JsonPropertyValue $questKeyeventApk 'sha256'
    }
}
$questKeyeventHashMatches =
    (-not [string]::IsNullOrWhiteSpace($questKeyeventApkSha256)) -and
    $questKeyeventApkSha256 -eq $apkHash
$questKeyeventExperimentResultsPulled =
    (Test-Path (Get-JsonPropertyValue $questKeyevent 'json')) -and
    (Test-Path (Get-JsonPropertyValue $questKeyevent 'summaryCsv')) -and
    (Test-Path (Get-JsonPropertyValue $questKeyevent 'pressEventsCsv')) -and
    (Test-Path (Get-JsonPropertyValue $questKeyevent 'ecgBlinkEventsCsv')) -and
    (Test-Path (Get-JsonPropertyValue $questKeyevent 'ecgTimeSeriesCsv'))
$questKeyeventExportMirrorComparison = Get-JsonPropertyValue $questKeyevent 'exportMirrorComparison'
$questKeyeventExportMirrorMatched =
    (Get-JsonPropertyValue $questKeyevent 'exportMirrorMatched') -eq $true -and
    (-not [string]::IsNullOrWhiteSpace($questKeyeventExportMirrorComparison)) -and
    (Test-Path $questKeyeventExportMirrorComparison)
$questKeyeventComparisons = Get-JsonPropertyValue $questKeyevent 'comparisons'
$qkvCondition1EcgDuration = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG capture duration equals audio'
$qkvCondition2EcgDuration = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG capture duration equals audio'
$qkvCondition1EcgSampleRate = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG sample rate'
$qkvCondition2EcgSampleRate = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG sample rate'
$qkvCondition1EcgWindowStart = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG audio window start'
$qkvCondition2EcgWindowStart = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG audio window start'
$qkvCondition1EcgWindowEnd = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG audio window end equals audio'
$qkvCondition2EcgWindowEnd = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG audio window end equals audio'
$qkvCondition1EcgWindowDuration = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG audio window duration equals audio'
$qkvCondition2EcgWindowDuration = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG audio window duration equals audio'
$qkvCondition1EcgCaptureNs = Get-ComparisonByName $questKeyeventComparisons 'condition 1 ECG capture ns duration equals audio'
$qkvCondition2EcgCaptureNs = Get-ComparisonByName $questKeyeventComparisons 'condition 2 ECG capture ns duration equals audio'
$qkvEcgSourcesComplement = Get-ComparisonByName $questKeyeventComparisons 'ECG sources counterbalanced complement'
$qkvEcgAssignmentMatchesSources = Get-ComparisonByName $questKeyeventComparisons 'ECG assignment order matches condition sources'
$qkvSimulatedBlinkCount = Get-ComparisonByName $questKeyeventComparisons 'simulated ECG blink count exported'
$qkvSimulatedBlinkRows = Get-ComparisonByName $questKeyeventComparisons 'simulated ECG blink rows match JSON count'
$qkvSimulatedBlinkRuntimeMarker = Get-ComparisonByName $questKeyeventComparisons 'simulated ECG blink runtime marker observed'
$qkvSimulatedHeartbeatFlash = Get-ComparisonByName $questKeyeventComparisons 'simulated heartbeat visual flash observed'
$qkvSimulatedTimeSeriesCount = Get-ComparisonByName $questKeyeventComparisons 'simulated ECG time-series sample count equals expected'
$qkvSimulatedTimeSeriesRows = Get-ComparisonByName $questKeyeventComparisons 'simulated ECG time-series CSV rows match JSON count'
$qkvKeyboardRequest = Get-ComparisonByName $questKeyeventComparisons 'native keyboard request observed'
$qkvKeyboardNameTextMode = Get-ComparisonByName $questKeyeventComparisons 'native keyboard name text mode observed'
$qkvKeyboardAgeNumericMode = Get-ComparisonByName $questKeyeventComparisons 'native keyboard age numeric mode observed'
$qkvNativeKeyboardMovablePanel = Get-ComparisonByName $questKeyeventComparisons 'native keyboard movable panel contract observed'
$qkvNativeKeyboardTargetSwitch = Get-ComparisonByName $questKeyeventComparisons 'native keyboard text-to-number retarget observed'
$qkvStartupKeyboardTextMode = Get-ComparisonByName $questKeyeventComparisons 'startup native keyboard request uses text mode'
$qkvPanelExitKeyboardHide1 = Get-ComparisonByName $questKeyeventComparisons 'panel-exit keyboard hide before condition 1 observed'
$qkvPanelExitKeyboardHide2 = Get-ComparisonByName $questKeyeventComparisons 'panel-exit keyboard hide before condition 2 observed'
$qkvRednessCue = Get-ComparisonByName $questKeyeventComparisons 'redness conversion cue observed'
$qkvCondition1RednessVas = Get-ComparisonByName $questKeyeventComparisons 'condition 1 redness VAS'
$qkvCondition1RednessLikert = Get-ComparisonByName $questKeyeventComparisons 'condition 1 redness Likert'
$qkvCondition1RednessOrder = Get-ComparisonByName $questKeyeventComparisons 'condition 1 redness order'
$qkvCondition2RednessVas = Get-ComparisonByName $questKeyeventComparisons 'condition 2 redness VAS'
$qkvCondition2RednessLikert = Get-ComparisonByName $questKeyeventComparisons 'condition 2 redness Likert'
$qkvCondition2RednessOrder = Get-ComparisonByName $questKeyeventComparisons 'condition 2 redness order'
$qkvEnterSubmitReplay = Get-ComparisonByName $questKeyeventComparisons 'enter submit replay observed'
$qkvControllerSubmitReplay = Get-ComparisonByName $questKeyeventComparisons 'controller submit replay observed'
$questKeyeventEcgAudioWindowMatched =
    $null -ne $qkvCondition1EcgDuration -and
    $null -ne $qkvCondition2EcgDuration -and
    $null -ne $qkvCondition1EcgSampleRate -and
    $null -ne $qkvCondition2EcgSampleRate -and
    $null -ne $qkvCondition1EcgWindowStart -and
    $null -ne $qkvCondition2EcgWindowStart -and
    $null -ne $qkvCondition1EcgWindowEnd -and
    $null -ne $qkvCondition2EcgWindowEnd -and
    $null -ne $qkvCondition1EcgWindowDuration -and
    $null -ne $qkvCondition2EcgWindowDuration -and
    $null -ne $qkvCondition1EcgCaptureNs -and
    $null -ne $qkvCondition2EcgCaptureNs -and
    (Get-JsonPropertyValue $qkvCondition1EcgDuration 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgDuration 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgSampleRate 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgSampleRate 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgWindowStart 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgWindowStart 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgWindowEnd 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgWindowEnd 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgWindowDuration 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgWindowDuration 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgCaptureNs 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2EcgCaptureNs 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1EcgSampleRate 'observed') -eq 130 -and
    (Get-JsonPropertyValue $qkvCondition2EcgSampleRate 'observed') -eq 130
$questKeyeventEcgBlinkMatched =
    $null -ne $qkvEcgSourcesComplement -and
    $null -ne $qkvEcgAssignmentMatchesSources -and
    $null -ne $qkvSimulatedBlinkCount -and
    $null -ne $qkvSimulatedBlinkRows -and
    $null -ne $qkvSimulatedBlinkRuntimeMarker -and
    $null -ne $qkvSimulatedHeartbeatFlash -and
    $null -ne $qkvSimulatedTimeSeriesCount -and
    $null -ne $qkvSimulatedTimeSeriesRows -and
    (Get-JsonPropertyValue $qkvEcgSourcesComplement 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvEcgAssignmentMatchesSources 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedBlinkCount 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedBlinkRows 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedBlinkRuntimeMarker 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedHeartbeatFlash 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedTimeSeriesCount 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvSimulatedTimeSeriesRows 'pass') -eq $true
$questKeyeventKeyboardLifecycleMatched =
    $null -ne $qkvKeyboardRequest -and
    $null -ne $qkvKeyboardNameTextMode -and
    $null -ne $qkvKeyboardAgeNumericMode -and
    $null -ne $qkvNativeKeyboardMovablePanel -and
    $null -ne $qkvNativeKeyboardTargetSwitch -and
    $null -ne $qkvStartupKeyboardTextMode -and
    $null -ne $qkvPanelExitKeyboardHide1 -and
    $null -ne $qkvPanelExitKeyboardHide2 -and
    (Get-JsonPropertyValue $qkvKeyboardRequest 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvKeyboardNameTextMode 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvKeyboardAgeNumericMode 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvNativeKeyboardMovablePanel 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvNativeKeyboardTargetSwitch 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvStartupKeyboardTextMode 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvPanelExitKeyboardHide1 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvPanelExitKeyboardHide2 'pass') -eq $true
$questKeyeventRednessMatched =
    $null -ne $qkvRednessCue -and
    $null -ne $qkvCondition1RednessVas -and
    $null -ne $qkvCondition1RednessLikert -and
    $null -ne $qkvCondition1RednessOrder -and
    $null -ne $qkvCondition2RednessVas -and
    $null -ne $qkvCondition2RednessLikert -and
    $null -ne $qkvCondition2RednessOrder -and
    (Get-JsonPropertyValue $qkvRednessCue 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1RednessVas 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1RednessLikert 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition1RednessOrder 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2RednessVas 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2RednessLikert 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvCondition2RednessOrder 'pass') -eq $true
$questKeyeventEnterSubmitMatched =
    $null -ne $qkvEnterSubmitReplay -and
    $null -ne $qkvControllerSubmitReplay -and
    (Get-JsonPropertyValue $qkvEnterSubmitReplay 'pass') -eq $true -and
    (Get-JsonPropertyValue $qkvControllerSubmitReplay 'pass') -eq $true
$visualPass =
    $questSmokeSuite.visualLayout.facingParticipant -eq $true -and
    $questSmokeSuite.visualLayout.glbModelConfirmed -eq $true
$panelPass =
    $questSmokeSuite.panelGlitch.demographicsIntroCue -eq $true -and
    $questSmokeSuite.panelGlitch.firstQuestionnaireIntroCue -eq $true -and
    $questSmokeSuite.panelGlitch.demographicsGlitch -eq $true -and
    $questSmokeSuite.panelGlitch.firstQuestionnaireGlitch -eq $true -and
    $questSmokeSuite.panelGlitch.pictographicReady -eq $true -and
    $questSmokeSuite.panelGlitch.conditionStarted -eq $false -and
    $questSmokeSuite.panelGlitch.exportCreated -eq $false
$polarLiveSmokePass =
    $null -ne $polarLiveSmoke -and
    $polarLiveSmoke.status -eq 'pass' -and
    $polarLiveSmoke.apk.sha256 -eq $apkHash -and
    $polarLiveSmoke.ecgStreaming -eq $true -and
    $polarLiveSmoke.ecgSamples -gt 0 -and
    $polarLiveSmoke.ecgSampleRateHz -eq 130
$controllerContactSmokeApkSha256 =
    if ($null -ne $controllerContactSmoke) {
        $value = Get-JsonPropertyValue $controllerContactSmoke 'apkSha256'
        if ([string]::IsNullOrWhiteSpace($value)) {
            $apkValue = Get-JsonPropertyValue $controllerContactSmoke 'apk'
            if ($null -ne $apkValue -and -not ($apkValue -is [string])) {
                $value = Get-JsonPropertyValue $apkValue 'sha256'
            }
        }
        $value
    } else {
        $null
    }
$controllerContactSmokeHashMatches =
    (-not [string]::IsNullOrWhiteSpace($controllerContactSmokeApkSha256)) -and
    $controllerContactSmokeApkSha256 -eq $apkHash
$controllerContactSmokePass =
    $null -ne $controllerContactSmoke -and
    $controllerContactSmoke.status -eq 'pass' -and
    $controllerContactSmokeHashMatches -and
    $controllerContactSmoke.controllerContactPresses -ge 1 -and
    $controllerContactSmoke.acceptedContactSelects -ge 1
$physicalPressValidationApkSha256 =
    if ($null -ne $physicalPressValidation) {
        $value = Get-JsonPropertyValue $physicalPressValidation 'apkSha256'
        if ([string]::IsNullOrWhiteSpace($value)) {
            $apkValue = Get-JsonPropertyValue $physicalPressValidation 'apk'
            if ($null -ne $apkValue -and -not ($apkValue -is [string])) {
                $value = Get-JsonPropertyValue $apkValue 'sha256'
            }
        }
        $value
    } else {
        $null
    }
$physicalPressValidationHashMatches =
    (-not [string]::IsNullOrWhiteSpace($physicalPressValidationApkSha256)) -and
    $physicalPressValidationApkSha256 -eq $apkHash
$physicalPressValidationPass =
    $null -ne $physicalPressValidation -and
    $physicalPressValidation.status -eq 'pass' -and
    $physicalPressValidationHashMatches -and
    $physicalPressValidation.condition1ControllerPresses -ge 1 -and
    $physicalPressValidation.condition2ControllerPresses -ge 1 -and
    $physicalPressValidation.realPolarSampleCount -gt 0 -and
    $physicalPressValidation.realPolarBlinkCount -gt 0 -and
    (Get-JsonPropertyValue $physicalPressValidation 'exportMirrorMatched') -eq $true
$finalHardwareGateApkSha256 = $null
if ($null -ne $finalHardwareGate) {
    $finalHardwareGateApk = Get-JsonPropertyValue $finalHardwareGate 'apk'
    if ($null -ne $finalHardwareGateApk -and -not ($finalHardwareGateApk -is [string])) {
        $finalHardwareGateApkSha256 = Get-JsonPropertyValue $finalHardwareGateApk 'sha256'
    }
}
$finalHardwareGateHashMatches =
    (-not [string]::IsNullOrWhiteSpace($finalHardwareGateApkSha256)) -and
    $finalHardwareGateApkSha256 -eq $apkHash
$finalHardwareGateSteps = Get-JsonPropertyValue $finalHardwareGate 'steps'
$finalHardwareGatePolarStep = Get-StepByName $finalHardwareGateSteps 'live-polar-h10-pmd-ecg-smoke'
$finalHardwareGateContactStep = Get-StepByName $finalHardwareGateSteps 'fast-controller-contact-smoke'
$finalHardwareGatePhysicalStep = Get-StepByName $finalHardwareGateSteps 'full-controller-contact-live-h10-export-validation'
$finalHardwareGateDryRunPass =
    $null -ne $finalHardwareGate -and
    $finalHardwareGate.status -eq 'dry_run' -and
    (Get-JsonPropertyValue $finalHardwareGate 'dryRun') -eq $true -and
    $finalHardwareGateHashMatches -and
    (Get-JsonPropertyValue $finalHardwareGatePolarStep 'status') -eq 'dry_run' -and
    (Get-JsonPropertyValue $finalHardwareGateContactStep 'status') -eq 'dry_run' -and
    (Get-JsonPropertyValue $finalHardwareGatePhysicalStep 'status') -eq 'dry_run'
$finalHardwarePostRunAuditValidationPass =
    $null -ne $finalHardwarePostRunAuditValidation -and
    $finalHardwarePostRunAuditValidation.status -eq 'pass' -and
    $finalHardwarePostRunAuditValidation.apkSha256 -eq $apkHash -and
    (Same-Path (Get-JsonPropertyValue $finalHardwarePostRunAuditValidation 'summaryPath') $finalHardwareGatePath)

$softwareReady =
    $localPreflightPass -and
    $nativeKeyboardContractPass -and
    $finalHardwarePostRunAuditValidatorTestPass -and
    $questSmokePass -and
    $questKeyeventPass -and
    $localHashMatches -and
    $questHashMatches -and
    $questKeyeventHashMatches -and
    $questKeyeventExperimentResultsPulled -and
    $questKeyeventExportMirrorMatched -and
    $questKeyeventEcgAudioWindowMatched -and
    $questKeyeventEcgBlinkMatched -and
    $questKeyeventKeyboardLifecycleMatched -and
    $questKeyeventRednessMatched -and
    $questKeyeventEnterSubmitMatched -and
    $finalHardwareGateDryRunPass -and
    $finalHardwarePostRunAuditValidationPass -and
    $visualPass -and
    $panelPass

$status =
    if (-not $softwareReady) {
        'incomplete'
    } elseif ($polarLiveSmokePass -and $physicalPressValidationPass) {
        'complete'
    } elseif ($polarLiveSmokePass) {
        'ready_except_physical_gate'
    } else {
        'ready_except_physical_and_live_polar_gates'
    }

$report = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = $status
    projectRoot = $projectRoot
    apk = [pscustomobject]@{
        path = $apkItem.FullName
        sha256 = $apkHash
        sizeBytes = $apkItem.Length
        lastWriteTime = $apkItem.LastWriteTime.ToString('o')
    }
    checks = [pscustomobject]@{
        localPreflightPass = $localPreflightPass
        nativeKeyboardContractPass = $nativeKeyboardContractPass
        finalHardwarePostRunAuditValidatorTestPass = $finalHardwarePostRunAuditValidatorTestPass
        finalHardwarePostRunAuditValidationPass = $finalHardwarePostRunAuditValidationPass
        questSmokeSuitePass = $questSmokePass
        questKeyeventQuestionnaireValidationPass = $questKeyeventPass
        localPreflightApkHashMatchesCurrent = $localHashMatches
        questSmokeSuiteApkHashMatchesCurrent = $questHashMatches
        questKeyeventQuestionnaireApkHashMatchesCurrent = $questKeyeventHashMatches
        questKeyeventExperimentResultsPulled = $questKeyeventExperimentResultsPulled
        questKeyeventExportMirrorMatched = $questKeyeventExportMirrorMatched
        questKeyeventEcgAudioWindowMatched = $questKeyeventEcgAudioWindowMatched
        questKeyeventEcgBlinkMatched = $questKeyeventEcgBlinkMatched
        questKeyeventKeyboardLifecycleMatched = $questKeyeventKeyboardLifecycleMatched
        questKeyeventRednessMatched = $questKeyeventRednessMatched
        questKeyeventEnterSubmitMatched = $questKeyeventEnterSubmitMatched
        questVisualLayoutPass = $visualPass
        questPanelGlitchPass = $panelPass
        polarH10LiveSmokePass = $polarLiveSmokePass
        questControllerContactSmokePass = $controllerContactSmokePass
        questControllerContactSmokeApkHashMatchesCurrent = $controllerContactSmokeHashMatches
        questPhysicalPressValidationPass = $physicalPressValidationPass
        questPhysicalPressValidationApkHashMatchesCurrent = $physicalPressValidationHashMatches
        finalHardwareGateWrapperDryRunPass = $finalHardwareGateDryRunPass
        finalHardwareGateWrapperApkHashMatchesCurrent = $finalHardwareGateHashMatches
    }
    evidence = [pscustomobject]@{
        localPreflight = $localPreflightPath
        localValidation = $localValidationPath
        audioValidation = $localPreflight.latestArtifacts.audioValidation
        exportSchemaValidation = $localPreflight.latestArtifacts.exportSchemaValidation
        nativeKeyboardValidation = $nativeKeyboardValidationPath
        physicalEvidenceValidatorTest = $localPreflight.latestArtifacts.physicalEvidenceValidatorTest
        finalHardwarePostRunAuditValidatorTest = $finalHardwarePostRunAuditValidatorTestPath
        finalHardwarePostRunAuditValidation = $finalHardwarePostRunAuditValidationPath
        layoutPreview = $localPreflight.latestArtifacts.layoutPreview
        questSmokeSuite = $questSmokeSuitePath
        questVisualLayout = $questSmokeSuite.visualLayout.summary
        questPanelGlitch = $questSmokeSuite.panelGlitch.summary
        questKeyeventQuestionnaireValidation = $questKeyeventPath
        questKeyeventExportJson = Get-JsonPropertyValue $questKeyevent 'json'
        questKeyeventSummaryCsv = Get-JsonPropertyValue $questKeyevent 'summaryCsv'
        questKeyeventPressEventsCsv = Get-JsonPropertyValue $questKeyevent 'pressEventsCsv'
        questKeyeventEcgBlinkEventsCsv = Get-JsonPropertyValue $questKeyevent 'ecgBlinkEventsCsv'
        questKeyeventEcgTimeSeriesCsv = Get-JsonPropertyValue $questKeyevent 'ecgTimeSeriesCsv'
        questKeyeventDeviceExperimentResultsDir = Get-JsonPropertyValue $questKeyevent 'deviceExperimentResultsDir'
        questKeyeventExportMirrorComparison = $questKeyeventExportMirrorComparison
        questKeyeventEcgAudioWindow = [pscustomobject]@{
            condition1DurationMs = Get-JsonPropertyValue $qkvCondition1EcgDuration 'observed'
            condition1ExpectedDurationMs = Get-JsonPropertyValue $qkvCondition1EcgDuration 'expected'
            condition2DurationMs = Get-JsonPropertyValue $qkvCondition2EcgDuration 'observed'
            condition2ExpectedDurationMs = Get-JsonPropertyValue $qkvCondition2EcgDuration 'expected'
            condition1SampleRateHz = Get-JsonPropertyValue $qkvCondition1EcgSampleRate 'observed'
            condition2SampleRateHz = Get-JsonPropertyValue $qkvCondition2EcgSampleRate 'observed'
            condition1WindowStartMs = Get-JsonPropertyValue $qkvCondition1EcgWindowStart 'observed'
            condition2WindowStartMs = Get-JsonPropertyValue $qkvCondition2EcgWindowStart 'observed'
            condition1WindowEndMs = Get-JsonPropertyValue $qkvCondition1EcgWindowEnd 'observed'
            condition2WindowEndMs = Get-JsonPropertyValue $qkvCondition2EcgWindowEnd 'observed'
            condition1WindowDurationMs = Get-JsonPropertyValue $qkvCondition1EcgWindowDuration 'observed'
            condition2WindowDurationMs = Get-JsonPropertyValue $qkvCondition2EcgWindowDuration 'observed'
            condition1CaptureDurationNs = Get-JsonPropertyValue $qkvCondition1EcgCaptureNs 'observed'
            condition1ExpectedCaptureDurationNs = Get-JsonPropertyValue $qkvCondition1EcgCaptureNs 'expected'
            condition2CaptureDurationNs = Get-JsonPropertyValue $qkvCondition2EcgCaptureNs 'observed'
            condition2ExpectedCaptureDurationNs = Get-JsonPropertyValue $qkvCondition2EcgCaptureNs 'expected'
        }
        questKeyeventEcgBlinkDriver = [pscustomobject]@{
            sourcesComplement = Get-JsonPropertyValue $qkvEcgSourcesComplement 'pass'
            assignmentMatchesSources = Get-JsonPropertyValue $qkvEcgAssignmentMatchesSources 'pass'
            simulatedBlinkCount = Get-JsonPropertyValue $qkvSimulatedBlinkCount 'observed'
            simulatedBlinkCountExpected = Get-JsonPropertyValue $qkvSimulatedBlinkCount 'expected'
            simulatedBlinkRows = Get-JsonPropertyValue $qkvSimulatedBlinkRows 'observed'
            simulatedHeartbeatFlashObserved = Get-JsonPropertyValue $qkvSimulatedHeartbeatFlash 'pass'
            simulatedRuntimeBlinkObserved = Get-JsonPropertyValue $qkvSimulatedBlinkRuntimeMarker 'pass'
            simulatedTimeSeriesRows = Get-JsonPropertyValue $qkvSimulatedTimeSeriesRows 'observed'
            simulatedTimeSeriesExpectedRows = Get-JsonPropertyValue $qkvSimulatedTimeSeriesRows 'expected'
        }
        questKeyeventKeyboardLifecycle = [pscustomobject]@{
            keyboardRequestObserved = Get-JsonPropertyValue $qkvKeyboardRequest 'pass'
            nameTextKeyboardModeObserved = Get-JsonPropertyValue $qkvKeyboardNameTextMode 'pass'
            ageNumericKeyboardModeObserved = Get-JsonPropertyValue $qkvKeyboardAgeNumericMode 'pass'
            nativeKeyboardMovablePanelObserved = Get-JsonPropertyValue $qkvNativeKeyboardMovablePanel 'pass'
            nativeKeyboardTextToNumberRetargetObserved = Get-JsonPropertyValue $qkvNativeKeyboardTargetSwitch 'pass'
            startupTextKeyboardModeObserved = Get-JsonPropertyValue $qkvStartupKeyboardTextMode 'pass'
            beforeCondition1KeyboardHideObserved = Get-JsonPropertyValue $qkvPanelExitKeyboardHide1 'pass'
            beforeCondition2KeyboardHideObserved = Get-JsonPropertyValue $qkvPanelExitKeyboardHide2 'pass'
        }
        questKeyeventRednessConversion = [pscustomobject]@{
            conversionCueObserved = Get-JsonPropertyValue $qkvRednessCue 'pass'
            condition1Vas = Get-JsonPropertyValue $qkvCondition1RednessVas 'observed'
            condition1Likert = Get-JsonPropertyValue $qkvCondition1RednessLikert 'observed'
            condition1Order = Get-JsonPropertyValue $qkvCondition1RednessOrder 'observed'
            condition2Vas = Get-JsonPropertyValue $qkvCondition2RednessVas 'observed'
            condition2Likert = Get-JsonPropertyValue $qkvCondition2RednessLikert 'observed'
            condition2Order = Get-JsonPropertyValue $qkvCondition2RednessOrder 'observed'
        }
        questKeyeventEnterSubmitReplay = [pscustomobject]@{
            enterSubmitReplayObserved = Get-JsonPropertyValue $qkvEnterSubmitReplay 'pass'
            controllerSubmitReplayObserved = Get-JsonPropertyValue $qkvControllerSubmitReplay 'pass'
        }
        polarH10LiveSmoke = $polarLiveSmokePath
        questControllerContactSmoke = $controllerContactSmokePath
        questPhysicalPressValidation = $physicalPressValidationPath
        finalHardwareGateWrapper = $finalHardwareGatePath
        finalHardwareGateWrapperStatus = Get-JsonPropertyValue $finalHardwareGate 'status'
        finalHardwareGateWrapperDryRun = Get-JsonPropertyValue $finalHardwareGate 'dryRun'
        completionAudit = Join-Path $projectRoot 'docs\completion-audit.md'
        physicalOperatorGuide = Join-Path $projectRoot 'docs\physical-validation-operator-guide.md'
    }
    remainingHardGate = [pscustomobject]@{
        name = 'Human-worn Quest controller-contact plus live-H10 ECG export validation'
        command = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial <quest-serial> -AdbPath <adb.exe>'
        reason = 'The current evidence proves local build/contracts and short non-human Quest runtime gates, but not human physical controller-contact presses plus real Polar H10 ECG/blink evidence in full JSON/CSV exports.'
    }
    remainingExternalGates = @(
        [pscustomobject]@{
            name = 'Recommended ordered final hardware wrapper'
            command = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial <quest-serial> -AdbPath <adb.exe>'
            proven = $physicalPressValidationPass
        },
        [pscustomobject]@{
            name = 'Human-worn Quest controller-contact plus live-H10 ECG export validation'
            command = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-physical-press-validation.ps1 -Serial <quest-serial> -AdbPath <adb.exe>'
            proven = $physicalPressValidationPass
        },
        [pscustomobject]@{
            name = 'Fast human controller-contact smoke validation'
            command = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-controller-contact-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>'
            proven = $controllerContactSmokePass
        },
        [pscustomobject]@{
            name = 'Live Polar H10 PMD ECG streaming validation'
            command = 'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-polar-h10-live-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>'
            proven = $polarLiveSmokePass
        }
    )
}

$jsonPath = Join-Path $OutDir 'readiness-report.json'
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$mdPath = Join-Path $OutDir 'readiness-report.md'
$lines = @(
    '# Big Red Button First Study Readiness Report',
    '',
    "- Generated: $($report.generatedAt)",
    "- Status: $($report.status)",
    "- APK SHA-256: $apkHash",
    "- APK size: $($apkItem.Length) bytes",
    '',
    '## Current Gate Status',
    '',
    "- Local preflight: $($localPreflight.status) ($localPreflightPath)",
    "- Final hardware post-run audit validator behavioral test: $finalHardwarePostRunAuditValidatorTestPass ($finalHardwarePostRunAuditValidatorTestPath)",
    "- Final hardware post-run audit binding validation: $finalHardwarePostRunAuditValidationPass ($finalHardwarePostRunAuditValidationPath)",
    "- Quest smoke suite: $($questSmokeSuite.status) ($questSmokeSuitePath)",
    "- Quest directional questionnaire/data validation: $($questKeyevent.status) ($questKeyeventPath)",
    "- Quest directional APK match: $questKeyeventHashMatches hash=$questKeyeventApkSha256",
    "- Quest ExperimentResults export pulled: $questKeyeventExperimentResultsPulled json=$($report.evidence.questKeyeventExportJson)",
    "- Quest export mirror byte match: $questKeyeventExportMirrorMatched comparison=$questKeyeventExportMirrorComparison",
    "- Quest ECG audio-window match: $questKeyeventEcgAudioWindowMatched condition1=$($report.evidence.questKeyeventEcgAudioWindow.condition1DurationMs)ms/$($report.evidence.questKeyeventEcgAudioWindow.condition1ExpectedDurationMs)ms window=$($report.evidence.questKeyeventEcgAudioWindow.condition1WindowStartMs)..$($report.evidence.questKeyeventEcgAudioWindow.condition1WindowEndMs)ms ns=$($report.evidence.questKeyeventEcgAudioWindow.condition1CaptureDurationNs)/$($report.evidence.questKeyeventEcgAudioWindow.condition1ExpectedCaptureDurationNs) condition2=$($report.evidence.questKeyeventEcgAudioWindow.condition2DurationMs)ms/$($report.evidence.questKeyeventEcgAudioWindow.condition2ExpectedDurationMs)ms window=$($report.evidence.questKeyeventEcgAudioWindow.condition2WindowStartMs)..$($report.evidence.questKeyeventEcgAudioWindow.condition2WindowEndMs)ms ns=$($report.evidence.questKeyeventEcgAudioWindow.condition2CaptureDurationNs)/$($report.evidence.questKeyeventEcgAudioWindow.condition2ExpectedCaptureDurationNs) sampleRateHz=$($report.evidence.questKeyeventEcgAudioWindow.condition1SampleRateHz),$($report.evidence.questKeyeventEcgAudioWindow.condition2SampleRateHz)",
    "- Quest simulated ECG blink/runtime flash match: $questKeyeventEcgBlinkMatched sourcesComplement=$($report.evidence.questKeyeventEcgBlinkDriver.sourcesComplement) assignmentMatches=$($report.evidence.questKeyeventEcgBlinkDriver.assignmentMatchesSources) blinkRows=$($report.evidence.questKeyeventEcgBlinkDriver.simulatedBlinkRows) heartbeatFlash=$($report.evidence.questKeyeventEcgBlinkDriver.simulatedHeartbeatFlashObserved) timeSeriesRows=$($report.evidence.questKeyeventEcgBlinkDriver.simulatedTimeSeriesRows)/$($report.evidence.questKeyeventEcgBlinkDriver.simulatedTimeSeriesExpectedRows)",
    "- Quest keyboard lifecycle match: $questKeyeventKeyboardLifecycleMatched request=$($report.evidence.questKeyeventKeyboardLifecycle.keyboardRequestObserved) nameText=$($report.evidence.questKeyeventKeyboardLifecycle.nameTextKeyboardModeObserved) ageNumeric=$($report.evidence.questKeyeventKeyboardLifecycle.ageNumericKeyboardModeObserved) nativeMovablePanel=$($report.evidence.questKeyeventKeyboardLifecycle.nativeKeyboardMovablePanelObserved) textToNumberRetarget=$($report.evidence.questKeyeventKeyboardLifecycle.nativeKeyboardTextToNumberRetargetObserved) startupText=$($report.evidence.questKeyeventKeyboardLifecycle.startupTextKeyboardModeObserved) beforeC1=$($report.evidence.questKeyeventKeyboardLifecycle.beforeCondition1KeyboardHideObserved) beforeC2=$($report.evidence.questKeyeventKeyboardLifecycle.beforeCondition2KeyboardHideObserved)",
    "- Quest redness conversion match: $questKeyeventRednessMatched c1Vas=$($report.evidence.questKeyeventRednessConversion.condition1Vas) c1Likert=$($report.evidence.questKeyeventRednessConversion.condition1Likert) c1Order=$($report.evidence.questKeyeventRednessConversion.condition1Order) c2Vas=$($report.evidence.questKeyeventRednessConversion.condition2Vas) c2Likert=$($report.evidence.questKeyeventRednessConversion.condition2Likert) c2Order=$($report.evidence.questKeyeventRednessConversion.condition2Order)",
    "- Quest Enter-submit replay match: $questKeyeventEnterSubmitMatched enterReplay=$($report.evidence.questKeyeventEnterSubmitReplay.enterSubmitReplayObserved) submitReplay=$($report.evidence.questKeyeventEnterSubmitReplay.controllerSubmitReplayObserved)",
    "- Quest visual layout: facingParticipant=$($questSmokeSuite.visualLayout.facingParticipant), downwardAngleDeg=$($questSmokeSuite.visualLayout.downwardAngleDeg), angularDiameterDeg=$($questSmokeSuite.visualLayout.angularDiameterDeg)",
    "- Quest panel/glitch: demographicsIntroCue=$($questSmokeSuite.panelGlitch.demographicsIntroCue), firstQuestionnaireIntroCue=$($questSmokeSuite.panelGlitch.firstQuestionnaireIntroCue), demographicsGlitch=$($questSmokeSuite.panelGlitch.demographicsGlitch), firstQuestionnaireGlitch=$($questSmokeSuite.panelGlitch.firstQuestionnaireGlitch), pictographicReady=$($questSmokeSuite.panelGlitch.pictographicReady)",
    "- Live Polar H10 PMD ECG smoke: pass=$polarLiveSmokePass evidence=$polarLiveSmokePath",
    "- Fast controller-contact smoke: pass=$controllerContactSmokePass evidence=$controllerContactSmokePath",
    "- Full physical controller-contact/live-H10 export validation: pass=$physicalPressValidationPass evidence=$physicalPressValidationPath",
    "- Final hardware wrapper dry run: pass=$finalHardwareGateDryRunPass status=$($report.evidence.finalHardwareGateWrapperStatus) dryRun=$($report.evidence.finalHardwareGateWrapperDryRun) apkMatch=$finalHardwareGateHashMatches evidence=$finalHardwareGatePath",
    '',
    'A `pass=False` hardware line records the latest attempt state; it is not counted as participant evidence.',
    '',
    '## Remaining Gates',
    '',
    $report.remainingHardGate.name,
    '',
    '```powershell',
    $report.remainingHardGate.command,
    '```',
    '',
    $report.remainingHardGate.reason,
    '',
    'Live Polar H10 PMD ECG streaming validation',
    '',
    '```powershell',
    'powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-polar-h10-live-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>',
    '```',
    '',
    'This requires a worn, awake Polar H10 near the headset and passes only when raw PMD ECG samples stream at 130 Hz.'
)
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

if (-not $softwareReady) {
    throw "Readiness report generated but current evidence is incomplete: $jsonPath"
}

Write-Host "PASS readiness report"
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $mdPath"
