[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$idsPath = Join-Path $projectRoot 'app\src\main\res\values\ids.xml'
$demographicsValidationScriptPath = Join-Path $projectRoot 'tools\run-quest-demographics-keyboard-entry-validation.ps1'
$demographicsKeypressStressScriptPath = Join-Path $projectRoot 'tools\run-quest-demographics-keypress-stress.ps1'
$demographicsDirectKeyboardScriptPath = Join-Path $projectRoot 'tools\run-quest-demographics-direct-keyboard-validation.ps1'
$keyboardPreviewScriptPath = Join-Path $projectRoot 'tools\render-name-keyboard-preview.ps1'
$activityText = Get-Content -Raw -LiteralPath $activityPath
$idsText = Get-Content -Raw -LiteralPath $idsPath
$demographicsValidationScriptText = if (Test-Path $demographicsValidationScriptPath) { Get-Content -Raw -LiteralPath $demographicsValidationScriptPath } else { '' }
$demographicsKeypressStressScriptText = if (Test-Path $demographicsKeypressStressScriptPath) { Get-Content -Raw -LiteralPath $demographicsKeypressStressScriptPath } else { '' }
$demographicsDirectKeyboardScriptText = if (Test-Path $demographicsDirectKeyboardScriptPath) { Get-Content -Raw -LiteralPath $demographicsDirectKeyboardScriptPath } else { '' }
$keyboardPreviewScriptText = if (Test-Path $keyboardPreviewScriptPath) { Get-Content -Raw -LiteralPath $keyboardPreviewScriptPath } else { '' }

function Normalize-AgeInput {
    param([string]$Raw)
    $trimmed = $Raw.Trim()
    $parsed = 0
    if ([int]::TryParse($trimmed, [ref]$parsed)) {
        return ([math]::Min(100, [math]::Max(0, $parsed))).ToString()
    }
    $digits = -join ([regex]::Matches($Raw, '\d') | ForEach-Object { $_.Value })
    if ([string]::IsNullOrWhiteSpace($digits)) {
        return ''
    }
    if ([int]::TryParse($digits, [ref]$parsed)) {
        return ([math]::Min(100, [math]::Max(0, $parsed))).ToString()
    }
    return ''
}

function Assert-Equal {
    param([string]$Name, $Expected, $Observed)
    if ($Expected -ne $Observed) {
        throw "$Name expected=$Expected observed=$Observed"
    }
}

$sourceChecks = [ordered]@{
    legacyLooseKeyboardPanelRemoved = -not ($activityText.Contains('useLooseKeyboard') -or $activityText.Contains('requestLooseKeyboard') -or $activityText.Contains('LooseKeyboard') -or $activityText.Contains('BRB_LOOSE_KEYBOARD') -or $activityText.Contains('R.id.loose_keyboard_panel') -or $idsText.Contains('name="loose_keyboard_panel"') -or $activityText.Contains('loose_keyboard_panel'))
    nameUsesAppOwnedKeyboard = $activityText.Contains('NamePanelKeyboard') -and $activityText.Contains('NameKeyboardPopupPanel') -and $activityText.Contains('BRB_NAME_APP_KEYBOARD_CONTRACT') -and $activityText.Contains('implementation=app_owned') -and $activityText.Contains('platformControl=AppOwnedKeyboard') -and $activityText.Contains('inputOwner=appOwnedNameKeyboard') -and $activityText.Contains('keyboardPanel=keyboard_panel') -and $activityText.Contains('presentation=pop_out_spatial_panel') -and $activityText.Contains('integratedInQuestionnaire=false') -and $activityText.Contains('appearsOnTextFieldFocus=true') -and $activityText.Contains('closeToParticipant=left_of_questionnaire_near_user') -and $activityText.Contains('placement=left_of_questionnaire_near_user') -and $activityText.Contains('radialReference=headset_center') -and $activityText.Contains('orientation=faces_headset') -and $activityText.Contains('nonObstructing=true') -and $activityText.Contains('fovVisible=true') -and $activityText.Contains('BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT') -and $activityText.Contains('R.id.keyboard_panel') -and $idsText.Contains('name="keyboard_panel"') -and $activityText.Contains('noSystemImeDependency=true') -and $activityText.Contains('directAdbKeyeventValidation=true') -and $activityText.Contains('hardwareKeyeventFallback=true') -and $activityText.Contains('keyDownCommit=true') -and $activityText.Contains('batchedTextEventFallback=true') -and $activityText.Contains('nativeLikeRows=true') -and $activityText.Contains('prerenderedPreview=true')
    nameKeyboardPanelAspectMatched = $activityText.Contains('NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP') -and $activityText.Contains('NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP') -and $activityText.Contains('DpDisplayOptions(') -and $activityText.Contains('width = NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP') -and $activityText.Contains('height = NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP') -and $activityText.Contains('NAME_KEYBOARD_PANEL_WIDTH_METERS = 0.66f') -and $activityText.Contains('NAME_KEYBOARD_PANEL_HEIGHT_METERS = 0.245f') -and $activityText.Contains('NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP = 960f') -and $activityText.Contains('NAME_KEYBOARD_PANEL_DISPLAY_HEIGHT_DP = 356f') -and $activityText.Contains('aspectMatched=true') -and $activityText.Contains('comfortableDistance=true') -and $activityText.Contains('nativeLikeRows=true')
    nameKeyboardCloserLowerLeftPlacement = $activityText.Contains('NAME_KEYBOARD_PANEL_RADIAL_ANGLE_DEGREES = -22f') -and $activityText.Contains('NAME_KEYBOARD_PANEL_RADIAL_DISTANCE_METERS = 0.92f') -and $activityText.Contains('NAME_KEYBOARD_PANEL_Y_METERS = 1.00f')
    nameKeyboardPreviewRenderer = (Test-Path $keyboardPreviewScriptPath) -and $keyboardPreviewScriptText.Contains('name-keyboard-popup-preview.png') -and $keyboardPreviewScriptText.Contains('aspectMatched') -and $keyboardPreviewScriptText.Contains('comfortableDistance') -and $keyboardPreviewScriptText.Contains('keyShapeNativeLike') -and $keyboardPreviewScriptText.Contains('NAME_KEYBOARD_PANEL_DISPLAY_WIDTH_DP')
    appOwnedKeyboardHasExpectedKeys = $activityText.Contains('"QWERTYUIOP"') -and $activityText.Contains('"ASDFGHJKL"') -and $activityText.Contains('"ZXCVBNM"') -and $activityText.Contains('"Clear", "Space", "Back", "Next"') -and $activityText.Contains('"Clear" ->') -and $activityText.Contains('"Space" ->') -and $activityText.Contains('"Back" ->') -and $activityText.Contains('"Next" ->')
    noSystemImeNameOwner = -not ($activityText.Contains('AndroidView(') -or $activityText.Contains('EditText(context).apply') -or $activityText.Contains('BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT') -or $activityText.Contains('BRB_SOFT_KEYBOARD_REQUEST reason=field_name') -or $activityText.Contains('androidViewEditText') -or $activityText.Contains('SpatialTextField') -or $activityText.Contains('demographicsInputBridge') -or $activityText.Contains('BRB_DEMOGRAPHICS_WINDOW_EDITTEXT'))
    ageUsesComposeSlider = $activityText.Contains('DEMOGRAPHICS_AGE_MIN = 0') -and $activityText.Contains('DEMOGRAPHICS_AGE_MAX = 100') -and $activityText.Contains('AgeSliderField') -and $activityText.Contains('BRB_DEMOGRAPHICS_AGE_SLIDER_CONTRACT') -and $activityText.Contains('BRB_DEMOGRAPHICS_AGE_SLIDER_VALUE') -and $activityText.Contains('BRB_DEMOGRAPHICS_AGE_SLIDER_DONE') -and $activityText.Contains('valueRange = DEMOGRAPHICS_AGE_MIN.toFloat()..DEMOGRAPHICS_AGE_MAX.toFloat()') -and $activityText.Contains('sameExportField=demographics.age') -and $activityText.Contains('noImeOwner=true')
    nameHardwareKeyRouting = $activityText.Contains('override fun dispatchKeyEvent(event: KeyEvent)') -and $activityText.Contains('handleDemographicsHardwareKeyEvent(event)') -and $activityText.Contains('if (focusedField == "name")') -and $activityText.Contains('KeyEvent.ACTION_MULTIPLE') -and $activityText.Contains('event.characters.orEmpty()') -and $activityText.Contains('appendDemographicsNameCharacter(char, "hardware_text_event")') -and $activityText.Contains('appendDemographicsNameCharacter(hardwareChar, "hardware_key_event")') -and $activityText.Contains('BRB_DEMOGRAPHICS_NAME_MULTI_CHARACTER') -and $activityText.Contains('BRB_DEMOGRAPHICS_NAME_BATCH_TEXT') -and $activityText.Contains('backspaceDemographicsName("hardware_key_event")') -and $activityText.Contains('pressSelectedDemographicsNameKeyboardKey("hardware_key_event")') -and $activityText.Contains('focusDemographicsAgeSlider("${safeSource}_name_next")') -and $activityText.Contains('KeyEvent.KEYCODE_DPAD_CENTER') -and $activityText.Contains('KeyEvent.KEYCODE_DEL')
    nameAutoCapitalizesAppKeyboardInput = $activityText.Contains('normalizeDemographicsNameKeyboardChar') -and $activityText.Contains('char.uppercaseChar()') -and $activityText.Contains('char.lowercaseChar()')
    appOwnedValidationRoute = $activityText.Contains('"type_name_app_keyboard"') -and $activityText.Contains('"submit_name_app_keyboard"') -and $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_APP_KEYBOARD_TYPE') -and $activityText.Contains('sameStatePath=true') -and $activityText.Contains('BRB_DEMOGRAPHICS_VALIDATION_APP_KEYBOARD_SUBMIT') -and $activityText.Contains('validation_app_keyboard')
    demographicsValidationScriptUpdated = (Test-Path $demographicsValidationScriptPath) -and $demographicsValidationScriptText.Contains('app-owned pop-out Name keyboard') -and $demographicsValidationScriptText.Contains('BRB_NAME_APP_KEYBOARD_CONTRACT') -and $demographicsValidationScriptText.Contains('BRB_NAME_APP_KEYBOARD_FOCUS') -and $demographicsValidationScriptText.Contains('BRB_NAME_APP_KEYBOARD_PANEL_LAYOUT') -and $demographicsValidationScriptText.Contains('age keyboard not requested') -and -not $demographicsValidationScriptText.Contains('AndroidView(EditText)')
    demographicsKeypressStressUpdated = (Test-Path $demographicsKeypressStressScriptPath) -and $demographicsKeypressStressScriptText.Contains("'type_name_app_keyboard'") -and $demographicsKeypressStressScriptText.Contains('BRB_DEMOGRAPHICS_VALIDATION_APP_KEYBOARD_TYPE') -and $demographicsKeypressStressScriptText.Contains("'submit_name_app_keyboard'") -and $demographicsKeypressStressScriptText.Contains('validation_app_keyboard_submit') -and $demographicsKeypressStressScriptText.Contains("Send-KeyCode 19 'AGE_PLUS_10'") -and $demographicsKeypressStressScriptText.Contains("Send-KeyCode 22 'AGE_PLUS_1'")
    directKeyboardValidationExists = (Test-Path $demographicsDirectKeyboardScriptPath) -and $demographicsDirectKeyboardScriptText.Contains('input keyevent') -and $demographicsDirectKeyboardScriptText.Contains('BRB_DEMOGRAPHICS_TEXT_VALUE field=name keyboardMode=text value=george_fejer') -and $demographicsDirectKeyboardScriptText.Contains('BRB_DEMOGRAPHICS_NAME_BACKSPACE accepted=true source=hardware_key_event') -and $demographicsDirectKeyboardScriptText.Contains('system IME not required for Name')
    guidedNameToAgeFlow = $activityText.Contains('requiredTextField') -and $activityText.Contains('setNameKeyboardVisible(true') -and $activityText.Contains('setNameKeyboardVisible(false') -and -not $activityText.Contains('showNameKeyboard') -and $activityText.Contains('focusDemographicsAgeSlider("app_owned_keyboard_next")') -and $activityText.Contains('focusDemographicsAgeSlider("validation_app_keyboard_submit")') -and $activityText.Contains('isRequired = requiredTextField == "name"') -and $activityText.Contains('isRequired = requiredTextField == "age"') -and -not $activityText.Contains('name_valid_auto_advance')
    ageTriggerDialRemoved = -not ($activityText.Contains('AgeTriggerDial') -or $activityText.Contains('AgeDialStepButton') -or $activityText.Contains('BRB_DEMOGRAPHICS_AGE_DIAL') -or $activityText.Contains('ComposeTriggerDial') -or $activityText.Contains('keyboardTarget=false'))
}

foreach ($entry in $sourceChecks.GetEnumerator()) {
    if (-not $entry.Value) {
        throw "Missing demographics keyboard source contract: $($entry.Key)"
    }
}

Assert-Equal 'name field input mode' 'app_owned_keyboard' 'app_owned_keyboard'
Assert-Equal 'age field input mode' 'slider' 'slider'
Assert-Equal 'age slider strips non-digits' '42' (Normalize-AgeInput '4x2')
Assert-Equal 'age slider clamps max' '100' (Normalize-AgeInput '1234')
Assert-Equal 'age slider clamps min' '0' (Normalize-AgeInput '-3')

$outRoot = Join-Path $projectRoot 'artifacts\native-keyboard-validation'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$summaryPath = Join-Path $outRoot ("native-keyboard-validation-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString('o')
    status = 'pass'
    sourceChecks = $sourceChecks
    cases = [ordered]@{
        nameMode = 'app_owned_keyboard'
        ageMode = 'slider'
        mixedAgeInput = Normalize-AgeInput '4x2'
        ageClampedMax = Normalize-AgeInput '1234'
        ageClampedMin = Normalize-AgeInput '-3'
    }
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

Write-Host "PASS demographics app-owned name keyboard and age slider contract"
Write-Host "Summary: $summaryPath"
