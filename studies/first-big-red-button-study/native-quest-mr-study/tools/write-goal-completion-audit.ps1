[CmdletBinding()]
param(
    [string]$ReadinessJson = '',
    [switch]$RequireComplete
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Read-JsonFile {
    param([string]$Path)
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-LatestReadinessJson {
    $root = Join-Path $projectRoot 'artifacts\readiness-report'
    if (-not (Test-Path $root)) {
        throw "Readiness report folder not found: $root"
    }
    $latest =
        Get-ChildItem -Path $root -Recurse -Filter 'readiness-report.json' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latest) {
        throw "No readiness-report.json found under $root"
    }
    return $latest.FullName
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) {
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Add-Requirement {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [string]$Id,
        [string]$Requirement,
        [bool]$Proven,
        [string]$Evidence,
        [string]$Missing,
        [string]$Kind = 'software'
    )
    $Rows.Add([pscustomobject]@{
        id = $Id
        requirement = $Requirement
        kind = $Kind
        proven = $Proven
        evidence = $Evidence
        missing = if ($Proven) { '' } else { $Missing }
    }) | Out-Null
}

if ([string]::IsNullOrWhiteSpace($ReadinessJson)) {
    $ReadinessJson = Get-LatestReadinessJson
}
$ReadinessJson = (Resolve-Path $ReadinessJson).Path
$readiness = Read-JsonFile $ReadinessJson
$checks = $readiness.checks
$evidence = $readiness.evidence

$requirements = New-Object System.Collections.Generic.List[object]

Add-Requirement $requirements 'standalone_apk' 'Standalone native Quest APK builds and local contract gates pass on the current APK hash.' `
    ([bool](Get-PropertyValue $checks 'localPreflightPass') -and [bool](Get-PropertyValue $checks 'localPreflightApkHashMatchesCurrent')) `
    (Get-PropertyValue $evidence 'localPreflight') `
    'Run tools/build-apk.ps1 and tools/run-local-preflight.ps1 on the current APK.'

Add-Requirement $requirements 'native_keyboard_questionnaire_input' 'Demographics app-owned Name keyboard, direct keyevent fallback, Age slider input, and panel exit behavior are validated on the current APK.' `
    ([bool](Get-PropertyValue $checks 'nativeKeyboardContractPass') -and [bool](Get-PropertyValue $checks 'questKeyeventKeyboardLifecycleMatched')) `
    ((Get-PropertyValue $evidence 'nativeKeyboardValidation') + '; ' + (Get-PropertyValue $evidence 'questKeyeventQuestionnaireValidation')) `
    'Run tools/test-native-keyboard-contract.ps1, tools/run-quest-demographics-direct-keyboard-validation.ps1, and tools/run-quest-keyevent-questionnaire-validation.ps1.'

Add-Requirement $requirements 'quest_visual_passthrough_button' 'Quest headset visual gate proves the modeled button is in passthrough, centered, reachable, and facing the participant.' `
    ([bool](Get-PropertyValue $checks 'questSmokeSuitePass') -and [bool](Get-PropertyValue $checks 'questVisualLayoutPass')) `
    (Get-PropertyValue $evidence 'questVisualLayout') `
    'Run tools/run-quest-smoke-suite.ps1 or tools/run-quest-visual-layout-smoke.ps1 on the current APK.'

Add-Requirement $requirements 'quest_panel_glitch_layout' 'Quest headset panel gate proves demographics and first questionnaire panel placement plus glitch intro cues.' `
    ([bool](Get-PropertyValue $checks 'questSmokeSuitePass') -and [bool](Get-PropertyValue $checks 'questPanelGlitchPass')) `
    (Get-PropertyValue $evidence 'questPanelGlitch') `
    'Run tools/run-quest-smoke-suite.ps1 or tools/run-quest-panel-smoke.ps1 on the current APK.'

Add-Requirement $requirements 'audio_timing_and_ecg_window' 'Condition audio durations are preserved, and qkv ECG capture windows match the instruction-audio durations in ms and ns.' `
    ([bool](Get-PropertyValue $checks 'questKeyeventEcgAudioWindowMatched')) `
    ((Get-PropertyValue $evidence 'audioValidation') + '; ' + (Get-PropertyValue $evidence 'questKeyeventQuestionnaireValidation')) `
    'Run tools/validate-audio-assets.ps1 and tools/run-quest-keyevent-questionnaire-validation.ps1.'

Add-Requirement $requirements 'questionnaire_directional_replay' 'Questionnaires are passable by bounded up/down/left/right plus enter/submit replay, with expected-vs-observed exported values.' `
    ([bool](Get-PropertyValue $checks 'questKeyeventQuestionnaireValidationPass') -and [bool](Get-PropertyValue $checks 'questKeyeventEnterSubmitMatched')) `
    (Get-PropertyValue $evidence 'questKeyeventQuestionnaireValidation') `
    'Run tools/run-quest-keyevent-questionnaire-validation.ps1.'

Add-Requirement $requirements 'sidequest_exports' 'JSON/CSV outputs are pulled from the SideQuest-readable ExperimentResults folder and mirror the primary export byte-for-byte.' `
    ([bool](Get-PropertyValue $checks 'questKeyeventExperimentResultsPulled') -and [bool](Get-PropertyValue $checks 'questKeyeventExportMirrorMatched')) `
    ((Get-PropertyValue $evidence 'questKeyeventDeviceExperimentResultsDir') + '; ' + (Get-PropertyValue $evidence 'questKeyeventExportMirrorComparison')) `
    'Run qkv or a full export pull and compare BigRedButtonFirstStudyExports with ExperimentResults.'

Add-Requirement $requirements 'redness_conversion_exports' 'The post-condition redness response converts between VAS and Likert order and exports both final formats.' `
    ([bool](Get-PropertyValue $checks 'questKeyeventRednessMatched')) `
    (Get-PropertyValue $evidence 'questKeyeventQuestionnaireValidation') `
    'Run tools/run-quest-keyevent-questionnaire-validation.ps1 and inspect redness expected-vs-observed rows.'

Add-Requirement $requirements 'simulated_ecg_blink_exports' 'Simulated ECG/RR source drives runtime blink/flash markers and exported blink/time-series rows.' `
    ([bool](Get-PropertyValue $checks 'questKeyeventEcgBlinkMatched')) `
    ((Get-PropertyValue $evidence 'questKeyeventEcgBlinkEventsCsv') + '; ' + (Get-PropertyValue $evidence 'questKeyeventEcgTimeSeriesCsv')) `
    'Run tools/run-quest-keyevent-questionnaire-validation.ps1.'

Add-Requirement $requirements 'final_hardware_postrun_audit_chain' 'Final hardware wrapper post-run readiness and goal-audit binding checks are covered by behavioral tests and pass for the current evidence chain.' `
    ([bool](Get-PropertyValue $checks 'finalHardwarePostRunAuditValidatorTestPass') -and [bool](Get-PropertyValue $checks 'finalHardwarePostRunAuditValidationPass')) `
    ((Get-PropertyValue $evidence 'finalHardwarePostRunAuditValidatorTest') + '; ' + (Get-PropertyValue $evidence 'finalHardwarePostRunAuditValidation')) `
    'Run tools/run-local-preflight.ps1 so the final hardware post-run audit validator behavioral test and binding verifier are refreshed.'

Add-Requirement $requirements 'live_polar_h10_streaming' 'A worn Polar H10 streams raw PMD ECG samples at 130 Hz into the headset app.' `
    ([bool](Get-PropertyValue $checks 'polarH10LiveSmokePass')) `
    (Get-PropertyValue $evidence 'polarH10LiveSmoke') `
    'Run tools/run-quest-polar-h10-live-smoke.ps1 with a worn, awake Polar H10 near the headset.' `
    'external_hardware'

Add-Requirement $requirements 'human_controller_contact_smoke' 'A human physically presses the modeled 3D button with a Quest controller and reaches controller_contact logging.' `
    ([bool](Get-PropertyValue $checks 'questControllerContactSmokePass') -and [bool](Get-PropertyValue $checks 'questControllerContactSmokeApkHashMatchesCurrent')) `
    (Get-PropertyValue $evidence 'questControllerContactSmoke') `
    'Run tools/run-quest-controller-contact-smoke.ps1 with a headset operator pressing the modeled button.' `
    'external_hardware'

Add-Requirement $requirements 'full_physical_live_h10_export' 'The full two-condition export contains real controller_contact presses plus real Polar H10 ECG/blink evidence and byte-matched ExperimentResults files.' `
    ([bool](Get-PropertyValue $checks 'questPhysicalPressValidationPass') -and [bool](Get-PropertyValue $checks 'questPhysicalPressValidationApkHashMatchesCurrent')) `
    (Get-PropertyValue $evidence 'questPhysicalPressValidation') `
    'Run tools/run-final-hardware-gates.ps1 with a headset operator wearing the Polar H10.' `
    'external_hardware'

Add-Requirement $requirements 'final_hardware_wrapper_order' 'The final hardware wrapper command sequence is constructed for the current APK.' `
    ([bool](Get-PropertyValue $checks 'finalHardwareGateWrapperDryRunPass') -and [bool](Get-PropertyValue $checks 'finalHardwareGateWrapperApkHashMatchesCurrent')) `
    (Get-PropertyValue $evidence 'finalHardwareGateWrapper') `
    'Run tools/run-final-hardware-gates.ps1 -DryRun for the current APK.'

$softwareRequirements = @($requirements | Where-Object { $_.kind -ne 'external_hardware' })
$hardwareRequirements = @($requirements | Where-Object { $_.kind -eq 'external_hardware' })
$softwareProven = -not [bool]($softwareRequirements | Where-Object { -not $_.proven })
$hardwareProven = -not [bool]($hardwareRequirements | Where-Object { -not $_.proven })
$completionAllowed = $softwareProven -and $hardwareProven -and ((Get-PropertyValue $readiness 'status') -eq 'complete')

$status =
    if ($completionAllowed) {
        'complete'
    } elseif ($softwareProven) {
        'ready_except_physical_and_live_polar_gates'
    } else {
        'incomplete_software_or_headset_gates'
    }

$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $projectRoot "artifacts\goal-completion-audit\$runId"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$jsonPath = Join-Path $outDir 'goal-completion-audit.json'
$mdPath = Join-Path $outDir 'goal-completion-audit.md'

$audit = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = $status
    completionAllowed = $completionAllowed
    readinessJson = $ReadinessJson
    apk = $readiness.apk
    softwareRequirementsProven = $softwareProven
    externalHardwareRequirementsProven = $hardwareProven
    missingRequirementIds = @($requirements | Where-Object { -not $_.proven } | ForEach-Object { $_.id })
    requirements = $requirements
}
$audit | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Goal Completion Audit') | Out-Null
$lines.Add('') | Out-Null
$lines.Add("- Generated: $($audit.generatedAt)") | Out-Null
$lines.Add("- Status: $status") | Out-Null
$lines.Add("- Completion allowed: $completionAllowed") | Out-Null
$lines.Add("- APK SHA-256: $($readiness.apk.sha256)") | Out-Null
$lines.Add('- Readiness source: `' + $ReadinessJson + '`') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Requirement | Kind | Proven | Evidence / Missing |') | Out-Null
$lines.Add('| --- | --- | --- | --- |') | Out-Null
foreach ($row in $requirements) {
    $detail = if ($row.proven) { $row.evidence } else { $row.missing }
    $escapedRequirement = $row.requirement.Replace('|', '\|')
    $escapedDetail = ([string]$detail).Replace('|', '\|')
    $lines.Add("| $escapedRequirement | $($row.kind) | $($row.proven) | $escapedDetail |") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('Completion remains blocked by external hardware evidence until live Polar H10 PMD ECG streaming and full human controller-contact/live-H10 export validation both pass on the current APK.') | Out-Null
$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "PASS goal completion audit"
Write-Host "Status: $status"
Write-Host "Completion allowed: $completionAllowed"
Write-Host "JSON: $jsonPath"
Write-Host "Markdown: $mdPath"

if ($RequireComplete -and -not $completionAllowed) {
    throw "Goal completion audit is not complete. Missing: $($audit.missingRequirementIds -join ', ')"
}
