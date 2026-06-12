# Physical Validation Operator Guide

Use this guide only for the final physical controller-contact gate. This is not a routine smoke test because it waits through both full instruction tracks.

## Command

Before the operator session, generate the current software/audit-chain handoff:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-final-hardware-operator-handoff.ps1 -RefreshAudit -RequireReady
```

This writes `artifacts\final-operator-handoff\<runId>\final-operator-handoff.json` and `.md`. It should report `ready_for_operator_external_gates`, meaning the APK hash, readiness report, goal audit, and final post-run audit-chain row agree. It does not prove live Polar H10 streaming or physical controller-contact pressing.

Recommended one-command final sequence:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This runs live Polar H10 PMD ECG smoke first, then a fast controller-contact smoke, then the full physical export validation. It writes a combined summary to `artifacts\final-hardware-gates\<runId>\final-hardware-gates-summary.json`. Use `-DryRun` only before the operator session to verify command construction; `dryRun=true` is not evidence that any headset hardware gate passed.

Underlying full physical export command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-physical-press-validation.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

The default wait budget is 760 seconds. That covers condition 1 audio at about 5:01, condition 2 audio at about 5:26, and the hidden questionnaire autosubmission delays.

This is now a combined final gate: it proves physical Quest controller-contact pressing and full-run real Polar H10 ECG export evidence in the same run.

By default the full physical script runs `tools\run-quest-polar-h10-live-smoke.ps1` before the full audio run. If the Polar H10 is not detected, connected, PMD-ready, and streaming 130 Hz samples, the full physical validation does not start. Use `-SkipPolarPrecheck` only when a same-session live H10 check has already passed and you intentionally want to avoid repeating the no-audio precheck. The final wrapper uses that same-session pattern after its standalone live H10 step.

After completion, the script pulls both `BigRedButtonFirstStudyExports` and the SideQuest-friendly `ExperimentResults` mirror from the headset. Both folders must pass schema validation and physical controller-contact/live-Polar evidence validation, then pass a byte-for-byte mirror comparison of file names, file sizes, and SHA-256 hashes.

## Operator Steps

1. Wear the Quest and hold a tracked Quest controller.
2. Wear a wetted, awake Polar H10 near the headset before launch.
3. Start the script from the native app folder.
4. When condition 1 begins, physically press the modeled 3D Big Red Button with the controller at least once.
5. Keep the headset and Polar H10 on while condition 1 audio finishes. The hidden validation mode submits non-press questionnaire fields automatically.
6. When condition 2 begins, physically press the modeled 3D Big Red Button with the controller at least once.
7. Keep the headset and Polar H10 on until the script reports completion and pulls exports.

While waiting, the script prints live `c1Controller` and `c2Controller` counts from logcat. At each condition end, the app logs `BRB_CONDITION_PRESS_SOURCES`, which reports source-specific press counts for controller contact, interim panel, scene-object fallback, and automation.

Do not use ADB taps, Android keyevents, keyboard input, gaze, or visible flat UI elements as proof of button pressing.

## Pass Criteria

The script accepts the final gate only when all are true:

- logcat contains `BRB_BUTTON_PRESS ... source=controller_contact`
- logcat contains accepted `BRB_BUTTON_CONTROLLER_CONTACT_SELECT accepted=true` markers for the controller-contact presses
- pulled JSON contains `controller_contact` press events in both conditions
- pulled press-events CSV contains matching `controller_contact` rows in both conditions
- controller-contact rows are not marked `validationAutomation=true` or `validation_automation=true`
- no `auto_validation` button press source appears in logcat, JSON, or CSV
- condition-end logcat includes source-specific `BRB_CONDITION_PRESS_SOURCES` markers whose controller-contact counts match the exports
- exactly one condition has `feedbackSource=real_polar_h10` and exactly one has `feedbackSource=simulated_neurokit2`; both conditions have `physiologySource=real_polar_h10`
- each condition's `ecgCaptureDurationMs` equals its instruction `audioDurationMs`
- each condition's `ecgCaptureDurationNs` equals `audioDurationMs * 1,000,000`, with `ecgAudioWindowStartMs=0` and `ecgAudioWindowEndMs=audioDurationMs`
- both conditions export 130 Hz real PMD ECG samples in `*_ecg_timeseries.csv` with `elapsed_ns` and audio-window columns; sham/simulated feedback never appears as real ECG rows
- each condition's real-Polar time-series rows have sequential `sample_index`, strictly increasing `elapsed_ns`, a median sample interval consistent with 130 Hz, and no large sample gaps
- both conditions have at least 95 percent of their expected 130 Hz samples, with first/last samples covering the audio window within the validator boundary gap
- both conditions export real Polar RR evidence in `*_polar_rr_events.csv`, with `used_for_feedback=true` only in the real-feedback condition
- controller-contact press rows include `elapsed_ns` and nearest real ECG sample linkage within the validator threshold
- real-Polar ECG rows include positive PMD frame/package metadata and requested MTU 70
- logcat includes `BRB_POLAR_H10_LOW_LATENCY_CONFIG ... requestedMtu=70 ... minimum_mtu_low_latency_ecg`
- logcat includes real-Polar `BRB_ECG_CAPTURE_START` and `BRB_ECG_CAPTURE_END` markers for both audio windows
- the script records a passing `polarPrecheckSummary` unless `-SkipPolarPrecheck` was intentionally supplied
- export schema validation passes on the pulled headset files from both export folders
- physical evidence validation passes on both the primary export folder and the SideQuest-readable `ExperimentResults` mirror
- `export-mirror-comparison.json` reports matching file names, sizes, and SHA-256 hashes across the primary export folder and the `ExperimentResults` mirror

If this guide and the script disagree, treat the script as authoritative and update this guide in the same change.

## Independent Recheck

After a physical run, the same evidence can be rechecked without relaunching the app:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-physical-press-evidence.ps1 -ExportDir <pulled BigRedButtonFirstStudyExports folder> -LogcatPath <logcat-filtered.txt>
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-physical-press-evidence.ps1 -ExportDir <pulled ExperimentResults folder> -LogcatPath <logcat-filtered.txt>
```

The final physical script calls this validator automatically after pulling exports. The local harness `tools\test-physical-press-evidence-validator.ps1` creates synthetic clean and contaminated cases to verify that this validator accepts real-looking controller-contact plus real-Polar ECG/RR evidence in both conditions and rejects automation-contaminated, simulated-ECG-contaminated, misaligned, or physiology-incomplete evidence.
