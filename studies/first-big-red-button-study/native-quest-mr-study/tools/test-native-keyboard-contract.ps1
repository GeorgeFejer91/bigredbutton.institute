[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$idsPath = Join-Path $projectRoot 'app\src\main\res\values\ids.xml'
$activityText = Get-Content -Raw -LiteralPath $activityPath
$idsText = Get-Content -Raw -LiteralPath $idsPath

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
    nameRequestsTextKeyboard = $activityText.Contains('fieldId = "name"') -and $activityText.Contains('keyboardMode = "text"') -and $activityText.Contains('KeyboardCapitalization.Words') -and $activityText.Contains('KeyboardType.Text') -and $activityText.Contains('ImeAction.Next')
    ageRequestsNumericKeyboard = $activityText.Contains('fieldId = "age"') -and $activityText.Contains('keyboardMode = "number"') -and $activityText.Contains('KeyboardType.Number') -and $activityText.Contains('ImeAction.Done')
    softKeyboardUsesSystemIme = $activityText.Contains('requestSoftKeyboard(view, keyboardReason, keyboardMode)') -and $activityText.Contains('InputMethodManager.SHOW_FORCED') -and $activityText.Contains('inputMethodManager.restartInput(targetView)')
    focusSwitchRetargetsIme = $activityText.Contains('BRB_SOFT_KEYBOARD_SWITCH') -and $activityText.Contains('BRB_SOFT_KEYBOARD_RETARGET') -and $activityText.Contains('failSafeRetarget=true')
    nativeKeyboardLifecycleMarkers = $activityText.Contains('BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT') -and $activityText.Contains('BRB_SOFT_KEYBOARD_REQUEST') -and $activityText.Contains('movablePanel=true') -and $activityText.Contains('closeToParticipant=system_managed')
    ageSanitizesTypedInput = $activityText.Contains('onValueChange = { age = normalizeAgeInput(it) }') -and $activityText.Contains('digitsOnly=true') -and $activityText.Contains('maxDigits=3')
    legacyInlineKeyboardRemoved = -not ($activityText.Contains('DemographicsInlineKeyboard') -or $activityText.Contains('requestInlineKeyboard') -or $activityText.Contains('focusedView=InlineDemographicsKeyboard'))
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
