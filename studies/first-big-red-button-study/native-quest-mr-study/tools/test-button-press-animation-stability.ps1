[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$activityPath = Join-Path $projectRoot 'app\src\main\java\org\bigredbutton\firststudy\BigRedButtonStudyActivity.kt'
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$outputDir = Join-Path $projectRoot "artifacts\button-press-animation-stability\$runId"
$checks = New-Object System.Collections.Generic.List[object]

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail
    )
    $checks.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    })
}

function Get-KotlinLongConst {
    param(
        [string]$Text,
        [string]$Name
    )
    $pattern = "private const val\s+$([regex]::Escape($Name))\s*=\s*([0-9]+)L"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) {
        return $null
    }
    return [int64]::Parse($match.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
}

if (-not (Test-Path -LiteralPath $activityPath)) {
    throw "Activity file not found: $activityPath"
}

$activityText = Get-Content -Raw -LiteralPath $activityPath
$cooldownMs = Get-KotlinLongConst $activityText 'BUTTON_PRESS_COOLDOWN_MS'
$clipMs = Get-KotlinLongConst $activityText 'BUTTON_PRESS_ANIMATION_CLIP_MS'
$guardMs = Get-KotlinLongConst $activityText 'BUTTON_PRESS_MOTION_RESTART_GUARD_MS'

Add-Check 'press motion timing constants' (
    $cooldownMs -eq 180 -and
    $clipMs -eq 160 -and
    $guardMs -ge ($cooldownMs + 40) -and
    $guardMs -gt $clipMs
) "cooldownMs=$cooldownMs clipMs=$clipMs guardMs=$guardMs"

Add-Check 'accepted press keeps count and sound immediate' (
    [regex]::IsMatch(
        $activityText,
        'run\.pressEvents\.add\(event\)(?s:.*?)buttonPressCountState\.intValue = run\.pressEvents\.size(?s:.*?)BRB_BUTTON_PRESS(?s:.*?)playButtonPressedAnimation\(\)(?s:.*?)playButtonPressCue\(\)(?s:.*?)nextAllowedPressRealtimeMs = nowRealtimeMs \+ BUTTON_PRESS_COOLDOWN_MS'
    ) -and
    [regex]::IsMatch(
        $activityText,
        'finalExtraPressEvents\.add\(event\)(?s:.*?)buttonPressCountState\.intValue = finalExtraPressEvents\.size(?s:.*?)BRB_FINAL_EXTRA_BUTTON_PRESS(?s:.*?)playButtonPressedAnimation\(\)(?s:.*?)playButtonPressCue\(\)(?s:.*?)nextAllowedPressRealtimeMs = nowRealtimeMs \+ BUTTON_PRESS_COOLDOWN_MS'
    )
) 'visual restart guard does not delay accepted press accounting or press sound playback'

Add-Check 'press animation restart is guarded and cancelable' (
    $activityText.Contains('buttonPressMotionSequence') -and
    $activityText.Contains('lastButtonPressMotionStartRealtimeMs') -and
    $activityText.Contains('BRB_BUTTON_MODEL_ANIMATION_SCHEDULE state=deferred') -and
    $activityText.Contains('state=canceled reason=newer_press') -and
    $activityText.Contains('startButtonPressMotion(') -and
    $activityText.Contains('mainHandler.postDelayed(') -and
    $activityText.Contains('visualRestartGuardMs=$BUTTON_PRESS_MOTION_RESTART_GUARD_MS') -and
    -not $activityText.Contains('playButtonPressedAnimation(buttonModelEntity)')
) 'accepted presses can defer visual replay instead of snapping the GLB clip back to frame zero'

Add-Check 'runtime rapid-press stress hook exists' (
    $activityText.Contains('safeCommand == "button_press_animation_stress"') -and
    $activityText.Contains('BRB_BUTTON_PRESS_ANIMATION_STRESS state=scheduled') -and
    $activityText.Contains('BUTTON_PRESS_ANIMATION_STRESS_INTERVAL_MS = 200L') -and
    $activityText.Contains('PRESS_SOURCE_AUDIO_RIG_STRESS = "audio_rig_stress"') -and
    $activityText.Contains('recordButtonPress(PRESS_SOURCE_AUDIO_RIG_STRESS)') -and
    $activityText.Contains('inputSource == PRESS_SOURCE_AUDIO_RIG_STRESS')
) 'hidden on-device stress can schedule rapid accepted validation presses and marks them as automation'

Add-Check 'press animation uses stable visible model' (
    $activityText.Contains('applyStableButtonModelVisibility()') -and
    $activityText.Contains('target=stable_idle_model') -and
    $activityText.Contains('PlaybackType.CLAMP') -and
    $activityText.Contains('glowGeometrySwap=false') -and
    $activityText.Contains('heartbeatGlowMotion=false') -and
    -not $activityText.Contains('BRB_BUTTON_GLOW_MODEL_VARIANTS_READY') -and
    -not $activityText.Contains('modelGlow=glb_material_variant_swap')
) 'press motion targets the stable idle GLB while heartbeat glow stays light-only'

Add-Check 'pending press motion resets when button hides' (
    $activityText.Contains('resetButtonPressMotionState("button_hidden")') -and
    $activityText.Contains('resetButtonPressMotionState("final_extra_prompt_panel")') -and
    $activityText.Contains('BRB_BUTTON_MODEL_ANIMATION_RESET') -and
    $activityText.Contains('lastButtonPressMotionStartRealtimeMs = Long.MIN_VALUE')
) 'delayed visual motion cannot leak into the next hidden or prompt state'

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$failed = @($checks | Where-Object { -not $_.passed })
$summary = [pscustomobject]@{
    status = if ($failed.Count -eq 0) { 'pass' } else { 'fail' }
    generatedAt = (Get-Date).ToString('o')
    activityPath = $activityPath
    cooldownMs = $cooldownMs
    pressAnimationClipMs = $clipMs
    visualRestartGuardMs = $guardMs
    checks = @($checks.ToArray())
}
$summaryPath = Join-Path $outputDir 'button-press-animation-stability-summary.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 -LiteralPath $summaryPath

$checks | Format-Table name, passed, detail -AutoSize | Out-Host
Write-Host "Button press animation stability summary: $summaryPath"

if ($failed.Count -gt 0) {
    throw "Button press animation stability validation failed: $($failed.Count) check(s) failed."
}
