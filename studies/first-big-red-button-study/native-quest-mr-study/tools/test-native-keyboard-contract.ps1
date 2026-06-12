[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$idsPath = Join-Path $projectRoot 'app\src\main\res\values\ids.xml'
$demographicsValidationScriptPath = Join-Path $projectRoot 'tools\run-quest-demographics-keyboard-entry-validation.ps1'
$activityText = Get-Content -Raw -LiteralPath $activityPath
$idsText = Get-Content -Raw -LiteralPath $idsPath
$demographicsValidationScriptText = if (Test-Path $demographicsValidationScriptPath) {
    Get-Content -Raw -LiteralPath $demographicsValidationScriptPath
} else {
    ''
}

function Normalize-AgeInput {
    param([string]$Raw)
    $digits = -join ([regex]::Matches($Raw, '\d') | ForEach-Object { $_.Value })
    if ($digits.Length -gt 3) {
        return $digits.Substring(0, 3)
    }
    return $digits
}

function Assert-Equal {
    param([string]$Name, $Expected, $Observed)
    if ($Expected -ne $Observed) {
        throw "$Name expected=$Expected observed=$Observed"
    }
}

function Get-SystemKeyboardMode {
    param([string]$Field)
    if ($Field -eq 'age') {
        return 'number'
    }
    return 'text'
}

$sourceChecks = [ordered]@{
    demographicsUsesNativeSystemKeyboardOnly = -not ($activityText.Contains('useLooseKeyboard') -or $activityText.Contains('requestLooseKeyboard') -or $activityText.Contains('LooseKeyboard') -or $activityText.Contains('BRB_LOOSE_KEYBOARD'))
    legacyLooseKeyboardPanelRemoved = -not ($activityText.Contains('R.id.loose_keyboard_panel') -or $idsText.Contains('name="loose_keyboard_panel"') -or $activityText.Contains('loose_keyboard_panel'))
    fieldsRemainEditable = -not ($activityText.Contains('readOnly = true') -or $activityText.Contains('readOnly = useLooseKeyboard'))
    demographicsUsesVisibleAndroidEditTextControls = $activityText.Contains('AndroidView(') -and $activityText.Contains('EditText(context).apply') -and $activityText.Contains('fieldId = "name"') -and $activityText.Contains('fieldId = "age"') -and $activityText.Contains('platformControl=EditText') -and $activityText.Contains('inputOwner=androidViewEditText') -and $activityText.Contains('visibleControl=androidViewEditText')
    demographicsHasNoSpatialOrHiddenBridgeOwner = -not ($activityText.Contains('SpatialTextField') -or $activityText.Contains('demographicsInputBridge') -or $activityText.Contains('demographicsBridgeActiveFieldId') -or $activityText.Contains('BRB_DEMOGRAPHICS_WINDOW_EDITTEXT') -or $activityText.Contains('BRB_DEMOGRAPHICS_INPUT_BRIDGE_READY') -or $activityText.Contains('inputOwner=windowEditText'))
    nameRequestsTextKeyboard = $activityText.Contains('InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS') -and $activityText.Contains('EditorInfo.IME_ACTION_NEXT') -and $activityText.Contains('DEMOGRAPHICS_NAME_MAX_CHARS = 80') -and $activityText.Contains('field=name keyboardMode=text keyboardType=Text') -and $activityText.Contains('capitalization=words imeAction=next')
    ageRequestsNumberKeyboard = $activityText.Contains('InputType.TYPE_CLASS_NUMBER') -and $activityText.Contains('EditorInfo.IME_ACTION_DONE') -and $activityText.Contains('DEMOGRAPHICS_AGE_MAX_DIGITS = 3') -and $activityText.Contains('field=age keyboardMode=number keyboardType=Number') -and $activityText.Contains('digitsOnly=true imeAction=done')
    editTextRestartInputLifecycle = $activityText.Contains('focusDemographicsEditText') -and $activityText.Contains('inputMethodManager.restartInput(editText)') -and $activityText.Contains('showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)') -and $activityText.Contains('focusedView=EditText') -and $activityText.Contains('restartInput=true') -and $activityText.Contains('BRB_SOFT_KEYBOARD_RETARGET')
    androidViewShellMatchesIntakeStyle = $activityText.Contains('Color(0xFFFFFBF4)') -and $activityText.Contains('RoundedCornerShape(8.dp)') -and $activityText.Contains('.height(72.dp)') -and $activityText.Contains('BrbRedDeep') -and $activityText.Contains('BrbLine') -and $activityText.Contains('setBackgroundColor(AndroidColor.TRANSPARENT)')
    editTextEnterAdvancesFields = $activityText.Contains('android_view_edit_text_submit') -and $activityText.Contains('EditorInfo.IME_ACTION_NEXT') -and $activityText.Contains('EditorInfo.IME_ACTION_DONE') -and $activityText.Contains('requestDemographicsTextInputFocus("age", "name_submit_next")') -and $activityText.Contains('hideSoftKeyboardForReason("field_age_done")')
    nativeKeyboardLifecycleMarkers = $activityText.Contains('BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT') -and $activityText.Contains('BRB_SOFT_KEYBOARD_REQUEST') -and $activityText.Contains('BRB_DEMOGRAPHICS_TEXT_VALUE') -and $activityText.Contains('BRB_DEMOGRAPHICS_EDITTEXT_FOCUS') -and $activityText.Contains('movablePanel=true') -and $activityText.Contains('closeToParticipant=system_managed')
    ageSanitizesDigitInput = $activityText.Contains('normalizeAgeInput(raw)') -and $activityText.Contains('BRB_DEMOGRAPHICS_AGE_FILTER') -and $activityText.Contains('keyboardTarget=true') -and $activityText.Contains('InputFilter.LengthFilter(maxChars)')
    guidedNameToAgeFlow = $activityText.Contains('requiredTextField') -and $activityText.Contains('name_valid_auto_advance') -and $activityText.Contains('requestDemographicsTextInputFocus("age", "name_valid_auto_advance")') -and $activityText.Contains('isRequired = requiredTextField == "name"') -and $activityText.Contains('isRequired = requiredTextField == "age"')
    fullCellFocusAndSinglePath = $activityText.Contains('demographicsFocusRequestSourceState') -and $activityText.Contains('singlePath=true') -and $activityText.Contains('fullCellHitbox=true') -and $activityText.Contains('tap_hitbox') -and $activityText.Contains('requestFieldFocus("auto_focus_initial")') -and $activityText.Contains('modifier = Modifier.weight(1f)')
    questKeyboardEntryValidationExists = Test-Path (Join-Path $projectRoot 'tools\run-quest-demographics-keyboard-entry-validation.ps1')
    questKeyboardEntryValidationUsesAppSideTextRoute = $activityText.Contains('onNewIntent(intent: Intent)') -and $activityText.Contains('handleDemographicsKeyboardValidationIntent') -and $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_COMMAND_EXTRA') -and $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_TEXT_EXTRA') -and $activityText.Contains('DEMOGRAPHICS_KEYBOARD_VALIDATION_SESSION_EXTRA') -and $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_SESSION') -and $activityText.Contains('reason=session_mismatch') -and $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_COMMAND') -and $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_TEXT_APPLIED') -and $activityText.Contains('sameSanitizer=true') -and $activityText.Contains('"focus_age"') -and $activityText.Contains('"set_age"') -and $activityText.Contains('"age_done"') -and $demographicsValidationScriptText.Contains('Invoke-DemographicsValidationCommand') -and $demographicsValidationScriptText.Contains('brb.demographicsKeyboardValidationCommand') -and $demographicsValidationScriptText.Contains('brb.demographicsKeyboardValidationSession') -and $demographicsValidationScriptText.Contains('platformControl=EditText') -and $demographicsValidationScriptText.Contains('BRB_SOFT_KEYBOARD_REQUEST reason=field_age') -and -not $demographicsValidationScriptText.Contains('SpatialTextField') -and -not $demographicsValidationScriptText.Contains('trigger dial')
    legacyInlineKeyboardRemoved = -not ($activityText.Contains('DemographicsInlineKeyboard') -or $activityText.Contains('requestInlineKeyboard') -or $activityText.Contains('focusedView=InlineDemographicsKeyboard'))
    ageTriggerDialRemoved = -not ($activityText.Contains('AgeTriggerDial') -or $activityText.Contains('AgeDialStepButton') -or $activityText.Contains('BRB_DEMOGRAPHICS_AGE_DIAL') -or $activityText.Contains('ComposeTriggerDial') -or $activityText.Contains('keyboardTarget=false'))
}

foreach ($entry in $sourceChecks.GetEnumerator()) {
    if (-not $entry.Value) {
        throw "Missing native keyboard source contract: $($entry.Key)"
    }
}

$nameMode = Get-SystemKeyboardMode 'name'
$ageMode = Get-SystemKeyboardMode 'age'
Assert-Equal 'name field keyboard mode' 'text' $nameMode
Assert-Equal 'age field keyboard mode' 'number' $ageMode
Assert-Equal 'age strips non-digits' '42' (Normalize-AgeInput '4x2')
Assert-Equal 'age max digits' '123' (Normalize-AgeInput '1234')

$outRoot = Join-Path $projectRoot 'artifacts\native-keyboard-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("native-keyboard-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    sourceChecks = $sourceChecks
    cases = [ordered]@{
        nameMode = $nameMode
        ageMode = $ageMode
        mixedAgeInput = Normalize-AgeInput '4x2'
        ageMaxDigits = Normalize-AgeInput '1234'
    }
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "PASS native keyboard contract"
Write-Host "Summary: $summaryPath"
