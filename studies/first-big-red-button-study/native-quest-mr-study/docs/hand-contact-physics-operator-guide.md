# Hand-Contact Physics Operator Guide

Use this guide for the supplemental hand-tracking button-press feel gate. It checks predictive visual preload, accepted `hand_contact` mechanics, and optional export rows. It does not replace the final `controller_contact` proof gate.

## Handoff

Before the operator session, generate the current APK-bound handoff:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-hand-contact-physics-operator-handoff.ps1 -CheckAdb -Serial <quest-serial> -AdbPath <adb.exe>
```

This writes `artifacts\hand-contact-operator-handoff\<runId>\hand-contact-physics-operator-handoff.json` and `.md`. It records the current debug APK hash, latest static validation summary, latest local evidence-validator test summary, ADB readiness, and exact smoke commands.

## Quick Smoke

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-hand-contact-physics-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe> -TimeoutSeconds 120
```

The operator should wear the Quest, enable hand tracking, put controllers down, and press the modeled 3D Big Red Button with a hand. The script waits for logcat evidence, saves a screenshot and logcat under `artifacts\qhps\<runId>`, then runs `tools\validate-hand-contact-physics-evidence.ps1` on the captured evidence.

## Export Evidence Mode

Use this longer mode when you want the pulled JSON and press-events CSV to prove `pressMechanics` for a hand press:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-hand-contact-physics-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe> -TimeoutSeconds 120 -RequireExportEvidence -ExportTimeoutSeconds 760
```

This still remains supplemental; it is useful for paper methods/data audit, not for replacing `controller_contact`.

When export evidence is pulled, the smoke also runs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\analyze-hand-contact-press-mechanics.ps1 -EvidenceDir artifacts\qhps\<runId> -RequireHandContact
```

The analysis output is written under `artifacts\qhps\<runId>\press-mechanics-analysis\` as `press-mechanics-analysis.json` and `press-mechanics-events.csv`. It summarizes preload use rate, input-source groups, prediction-mode groups, and descriptive mechanics for impact velocity, preload lead, confidence, trajectory fit, spring compression, force/pressure estimates, actuation, snap, bottom-out, and release timing.

## Pass Criteria

The hand-contact evidence validator requires:

- `BRB_BUTTON_HAND_IMPACT_PREDICTED` with `predictivePreload=true counted=false sound=false`
- optional aborted-preload evidence: `BRB_BUTTON_HAND_PRELOAD_RELEASE ... counted=false sound=false`
- `BRB_BUTTON_HAND_CONTACT_SELECT accepted=true`
- `BRB_BUTTON_PRESS ... source=hand_contact validationAutomation=false`
- `BRB_BUTTON_PRESS_MECHANICS ... source=hand_contact` with `predictionMode`, impact velocity, trajectory fit, approach angle/alignment, impact energy, spring compression, damping ratio, estimated impulse/force/pressure, assumed contact patch area, actuation travel/delay, snap-through travel/duration, and hand-contact trigger evidence
- if export evidence is required: JSON `pressMechanics` and press-events CSV `press_mechanics_*` fields for a `hand_contact` row, including lateral velocity, predicted lateral-at-impact, trajectory fit, approach angle/alignment, impact energy, spring compression, damping ratio, estimated impulse/force/pressure, assumed contact patch area, actuation travel/delay, and snap-through travel/duration

The local behavioral test is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-hand-contact-physics-evidence-validator.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-hand-contact-press-mechanics-analysis.ps1
```

These prove the validator accepts valid synthetic evidence and rejects missing preload, preload that counted or sounded, missing mechanics, missing required export evidence, and non-hand trigger evidence; and that the analyzer filters automation, requires hand contact when requested, and produces grouped publication summaries plus event-level CSV rows.

## Non-Goals

Do not use ADB taps, keyevents, gaze, or controller input to satisfy this smoke. The point is the feel of a hand approach, predictive visual preload, and accepted hand-contact mechanics. Final study completion still requires the separate controller-contact/live-H10 gate.
