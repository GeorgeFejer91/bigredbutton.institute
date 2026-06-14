# Validation Ladder

Follow these gates in order. Do not claim a higher gate passed when a lower gate is unrun or blocked.

## 1. Static Study Contract

For the full non-headset preflight, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-local-preflight.ps1
```

This builds the APK and runs the static study contract, exact audio validation, synthetic export schema validation, native keyboard contract validation, physical-evidence validator tests, final hardware post-run audit validator behavioral tests, final hardware post-run audit binding validation when wrapper evidence exists, and layout preview rendering. It is the strongest routine local gate, but it does not prove headset passthrough rendering or physical controller-contact pressing.

For the static contract only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-study.ps1 -SkipBuild
```

Checks:

- manifest package and VR launch category
- passthrough feature declaration
- condition MP3 assets
- exact MP3 SHA-256 hashes and ffprobe durations
- 14 adapted IPQ items
- export directory and key variable names
- button press and suppression log markers
- 0.48 m reachable button distance, 350 ms startup suppression, and 180 ms press cooldown
- packaged native 3D model asset for the participant-facing Big Red Button stimulus: `app/src/main/assets/models/BigRedButton.glb`
- model SHA-256 `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`
- model GLB structure: at least four meshes/materials, smooth-detail vertex/triangle counts, node named `button`, animation named `pressed`, and dimensions that fit the current collider envelope
- runtime model must preserve its material/PBR path and must not be forced back through `defaultShaderOverride = SceneMaterial.UNLIT_SHADER`
- documentation and implementation must preserve controller-based physical pressing as the final participant input path
- button spatial constants keep the 3D model facing the participant as a seated interaction target: about 26.6 degrees below nominal eye height and about 34.3 degrees apparent diameter at the 0.48 m reach distance
- ISDK contact collider markers exist: `IsdkBoxCollider`, `COLLIDER_HOVER_CONTACT_ACTUATE`, and `inputSource=controller_contact`
- export provenance exists: `input_source` and `validation_automation`
- participant-facing questionnaire panels use neutral task instructions and do not expose instrument names, internal variable names, scoring purpose, or adapted-IPQ rationale
- demographics panel uses the Big Red Button Institute website-style intake treatment
- layout previews parse the actual Kotlin IPQ item text rather than placeholder rows
- the button experience task uses the model-derived `big_red_button_model_thumbnail.png` rather than a generic red oval, and the thumbnail is centered on the presence-circle center
- questionnaire intro/outro glitch MP3 assets exist, are hash-locked, and are hooked to panel appearance/disappearance with blue software-failure style transition markers
- digital press counter is visible above the 3D button and driven by accepted condition press count
- signature field is a trigger/pointer drawing pad that exports temporal stroke JSON
- questionnaire UI sounds and button press sound asset exist, are hash-locked, and are hooked to active controls
- Polar H10 BLE permissions/client, first-menu validity panel, counterbalanced real-vs-sham feedback assignment, simulated NeuroKit2 RR asset, heartbeat blink driver, Polar PMD raw ECG/RR stream, ECG/RR export fields, and final physical-gate real-Polar evidence checks for both conditions exist
- if the press-sound placeholder is replaced in the future, the final sound asset SHA-256, duration, source, and license must be validated separately from the instruction MP3s

## 2. APK Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-apk.ps1
```

Expected output:

```text
app\build\outputs\apk\debug\app-debug.apk
```

## 2b. Local Export Contract

Before headset runtime exports exist, run the synthetic schema gate:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-export-schema.ps1 -Synthetic
```

This validates the expected JSON, summary CSV, press-event CSV, ECG blink-event CSV, raw ECG time-series CSV, and session-index shape. It does not prove the installed APK wrote real runtime exports.

## 3. Quest Install And Foreground Launch

Use an explicit physical Quest serial.

```powershell
adb devices -l
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install-launch-quest.ps1 -Serial <quest-serial>
```

If `adb.exe` is not on PATH, pass `-AdbPath C:\path\to\platform-tools\adb.exe`.

Record:

- serial and model
- APK path
- install output
- foreground focus after launch
- any headset prompt that required human action

## 4. Runtime Visual Gate

In headset, confirm:

- passthrough background is visible
- the modeled red button is in front of the participant, visually faces the participant as a tabletop-style press target, and remains reachable
- the participant can physically press the modeled button with a Quest controller, or with an invisible helper collider aligned to the model
- logcat includes `BRB_BUTTON_CONTACT_EVENT` and accepted `BRB_BUTTON_CONTROLLER_CONTACT_SELECT` when the controller-contact path fires
- logcat includes `GLTF: Loading GLTF: 'apk:///models/BigRedButton.glb'`
- no questionnaire panel is visible during audio playback
- the digital press counter is visible above the modeled button and increments when accepted presses occur
- the button can blink from the active ECG source during the condition
- the questionnaire panel appears after the audio track completes
- the questionnaire intro MP3 and blue glitch transition play when demographics first appears and when the first post-condition questionnaire panel first appears; the questionnaire outro MP3 and blue glitch transition play when panels disappear
- condition 2 starts only after the post-condition 1 questionnaires are complete
- rapid double contacts do not overcount beyond the 180 ms cooldown

For a fast headset panel/glitch check without replaying study audio, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-panel-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This hidden `brb.panelSmoke` mode captures the demographics and first Button Experience panels, requires the questionnaire intro MP3 and blue glitch log markers, and fails if a condition starts or an export is created. It is a UI/glitch gate only; it does not validate audio timing or exports.

For a short in-condition button layout check, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-visual-layout-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This launches hidden physical-validation mode, waits for condition 1 plus `BRB_BUTTON_SPATIAL_LAYOUT`, screenshots the modeled button in passthrough, checks `facingParticipant=true`, and then stops before full audio completion. It is a visual/layout gate only; it does not prove controller-contact pressing or completed exports.

The visual-layout smoke also verifies focused/resumed foreground after `am start`. If another non-Oculus OpenXR app remains foreground, the script force-stops that package once and relaunches `org.bigredbutton.firststudy` before waiting for the spatial marker.

To run the current short non-human Quest runtime gates together:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-smoke-suite.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This installs the APK once, runs the visual-layout smoke, then runs the panel/glitch smoke with `-SkipInstall`, and records a combined summary under `artifacts\quest-smoke-suite`.

To validate questionnaire passability and data logging without waiting through both full instruction MP3s, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-keyevent-questionnaire-validation.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This launches `brb.keyeventValidation`, uses the app-side bounded directional replay route, requires app-owned Name keyboard markers, Age 0-100 slider/no-IME markers, panel-exit keyboard hide markers, plus explicit `direction=enter` submit replay markers, pulls both `BigRedButtonFirstStudyExports` and `ExperimentResults`, byte-compares the pulled export mirror, verifies that qkv ECG capture windows equal the instruction-audio durations at 130 Hz in both milliseconds and nanoseconds, requires the sham feedback RR driver to produce exported blink rows plus runtime `BRB_ECG_BLINK` and `BRB_HEARTBEAT_FLASH` markers, verifies simulated feedback rows are excluded from the real ECG time-series export, and writes expected-vs-observed comparisons under `artifacts\qkv`. It is evidence for questionnaire/data routing and feedback blink routing only, not for physical controller-contact pressing or live H10 streaming. Raw Name keyevents are covered by `tools\run-quest-demographics-direct-keyboard-validation.ps1`.

After local preflight, this short Quest smoke suite, and the fast keyevent questionnaire/data export validation all pass, write a readiness rollup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-readiness-report.ps1
```

Accept `ready_except_physical_gate` only when the report points at the current APK hash, current passing local/headset/keyevent evidence, pulled `ExperimentResults` files, qkv export-mirror equality, qkv ECG audio-window equality in milliseconds and nanoseconds, qkv simulated blink/runtime flash proof, qkv Name-keyboard/Age-slider lifecycle proof, qkv Enter-submit replay proof, and a current passing live Polar H10 smoke if Polar live evidence is being claimed. If a live H10 has not been validated yet, the report should say `ready_except_physical_and_live_polar_gates`. Accept `complete` only when the standalone live Polar smoke and the full physical controller-contact/live-H10 export validation both pass on the current APK.

Then write the requirement-level goal audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-goal-completion-audit.ps1
```

This audit converts the latest readiness report into machine-readable requirement rows. Before the final human/H10 run, it should report software/headset rows proven and `completionAllowed=false` because `live_polar_h10_streaming`, `human_controller_contact_smoke`, and `full_physical_live_h10_export` remain external hardware evidence.
It should also include a proven software row named `final_hardware_postrun_audit_chain`, backed by `finalHardwarePostRunAuditValidatorTestPass=true` and `finalHardwarePostRunAuditValidationPass=true`, so the wrapper/readiness/goal-audit binding proof is visible at the same requirement level as the other software gates.
When a readiness report was just generated by another script, call this with `-ReadinessJson <path-to-readiness-report.json>` so the audit is tied to that exact readiness source.
For wrapper post-run audits specifically, the wrapper calls `tools\write-readiness-report.ps1 -FinalHardwareGateSummaryPath <current summary>` so readiness points back to the summary that just ran. Outside that wrapper bootstrap path, ordinary readiness should select the latest wrapper dry-run summary that already has a passing post-run audit binding validation, not merely the newest wrapper folder.

Before handing the headset/H10 session to an operator, write the final operator handoff:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-final-hardware-operator-handoff.ps1 -RefreshAudit -RequireReady
```

This refreshes readiness, binds a goal audit to that exact readiness report, and writes `artifacts\final-operator-handoff\<runId>\final-operator-handoff.json` plus Markdown. Accept `ready_for_operator_external_gates` as a pre-run software/audit-chain handoff state only. It does not prove live Polar H10 streaming or human controller-contact pressing.

ADB screenshots are useful evidence, but passthrough screenshots can be compositor-dependent. Do not treat a black or incomplete screenshot alone as proof that the headset view failed.

Older model-smoke evidence such as `artifacts/quest-model-smoke/20260609-161335/model-condition-unlit.png` used the low-poly/unlit button and is now superseded for visual quality. Capture fresh Quest evidence after installing the realistic GLB build before making visual-readiness claims.

## 5. Export Gate

Complete a full two-condition run, then pull exports:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull-exports.ps1 -Serial <quest-serial>
```

If `adb.exe` is not on PATH, pass `-AdbPath C:\path\to\platform-tools\adb.exe`.

Inspect:

- JSON file exists
- summary CSV exists
- press-event CSV exists
- ECG blink-event CSV exists
- raw ECG time-series CSV exists
- `session-index.jsonl` contains a row for the run
- condition 1 and 2 button press counts match the press-event CSV
- press-event JSON/CSV includes `inputSource`/`input_source`, and real controller presses are marked `controller_contact`
- condition 1 and 2 pictographic distance/radius values are present
- condition 1 and 2 adapted IPQ raw/scored values are present
- condition 1 and 2 Lost Opportunity scores are present
- feedback assignment order, condition feedback/physiology source, Polar status, RR-event fields, and blink-event timing/source/RR fields are present
- condition ECG capture durations match instruction-audio durations in milliseconds and nanoseconds; `*_ecg_timeseries.csv` includes real Polar `elapsed_ns` plus audio-window columns; `*_polar_rr_events.csv` records real RR events; simulated feedback is excluded from real ECG physiology rows; real Polar samples are clipped to the audio window without fabricated padding
- condition start/ECG start is anchored before `MediaPlayer.start()` and logged with `BRB_CONDITION_AUDIO_START_ANCHOR ... anchor=pre_media_player_start`
- final real-Polar evidence in both conditions has sequential sample indices, strictly increasing `elapsed_ns`, a median sample interval consistent with 130 Hz, no large sample gaps, and controller presses linked to nearby ECG samples

Then validate the pulled export folders and confirm the SideQuest-readable `ExperimentResults` mirror is byte-identical to the primary export:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-export-schema.ps1 -ExportDir <pulled BigRedButtonFirstStudyExports folder>
```

For no-human APK flow validation, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-autovalidation.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This waits for the real audio durations and validates pulled JSON/CSV exports. It is stronger than a local schema check, but it still uses app-triggered validation presses and therefore does not prove physical controller input.

This is a release/timing gate, not a routine check. It already passed once for the current audio and condition-flow implementation on Quest 3S `3487C10J0P01ZY` on 2026-06-09, with evidence in `artifacts/qav/20260609-170003`. Do not rerun it after unrelated edits. Use `tools/validate-audio-assets.ps1` for routine confirmation that the MP3 files remain byte-identical and duration-identical.

For the final operator session, prefer the ordered hardware wrapper:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This runs live Polar H10 PMD ECG smoke, optional fast controller-contact smoke, and the full controller-contact/live-H10 export validation in sequence, then writes `artifacts\final-hardware-gates\<runId>\final-hardware-gates-summary.json`. It also refreshes `tools\write-readiness-report.ps1` and `tools\write-goal-completion-audit.ps1` after dry runs, failures, and real passes unless `-SkipPostRunAudit` is supplied; the goal audit receives the exact readiness JSON written by the same post-run audit. A `-DryRun` summary proves command construction only and must not be counted as live-H10 or physical-controller evidence.

To verify that the wrapper summary, post-run readiness report, and post-run goal audit form one consistent chain, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-final-hardware-postrun-audit.ps1 -SummaryPath <final-hardware-gates-summary.json>
```

For direct physical controller-contact validation or debugging the slow final step, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-physical-press-validation.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This first runs the live Polar H10 PMD ECG smoke unless `-SkipPolarPrecheck` is supplied. If the precheck fails, the slow two-track run does not start. After that it launches `brb.physicalPressValidation`, auto-starts the study, and auto-submits non-press questionnaire fields after real audio completion, but it does not create button presses. A human wearing the headset must press the modeled button with a Quest controller in both conditions while wearing a live Polar H10. The script accepts the gate only when logcat, JSON, and press-events CSV all show `controller_contact` presses, and when both conditions export valid real Polar PMD ECG/RR evidence.

Before running it, read [physical-validation-operator-guide.md](physical-validation-operator-guide.md). The script writes `operator-checklist.txt` into the run artifact folder and fails if the live Polar precheck fails, button press evidence contains `auto_validation` sources, controller-contact rows marked as validation automation, missing source-summary/contact-select evidence, missing real-Polar RR rows, simulated ECG rows in the real physiology export, insufficient 130 Hz PMD ECG coverage in either condition, coarse or non-monotonic real-Polar ECG timing, missing press-to-ECG linkage, ECG samples outside the audio window, divergent primary-vs-`ExperimentResults` mirror hashes, or a missing `BRB_POLAR_H10_LOW_LATENCY_CONFIG ... requestedMtu=70` marker.

The physical script also calls `tools\validate-physical-press-evidence.ps1` after pulling exports and writes `export-mirror-comparison.json` for the primary-vs-`ExperimentResults` hash comparison. Use the same validator to independently recheck a completed physical run's pulled `BigRedButtonFirstStudyExports` folder and `logcat-filtered.txt`. The validator's local pass/fail behavior is covered by `tools\test-physical-press-evidence-validator.ps1`, including failure cases for only one real-Polar condition, sham feedback filled with simulated ECG rows, missing press `elapsed_ns`, missing nearest ECG linkage, oversized press-to-ECG gaps, missing real ECG/RR rows, non-monotonic `elapsed_ns`, and missing low-latency setup.

## 5b. Live Polar H10 Gate

With a worn, awake Polar H10 near the headset, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-polar-h10-live-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This launches the normal intake screen and watches `BRB_POLAR_H10_STATUS`. Accept the gate only when the script reports detection, connection, PMD readiness, `ecgStreaming=true`, nonzero raw ECG samples, and `ecgSampleRateHz=130`.

This gate proves that real Polar PMD ECG samples reach the native headset app. It does not prove full-condition export timing and does not prove physical controller-contact button pressing. The final physical export gate still needs to be run afterward because it verifies that the real PMD ECG samples cover the actual instruction-audio window in the exported study files.

For ordinary participant/manual starts, a missing Polar H10 is a warning, not a Start-button blocker. The app should display the warning and log `BRB_POLAR_START_WARNING ... continuing=true participantPhysiologyEvidenceRequired=true`, then proceed into condition audio. This does not weaken the live-H10 gate or the final physical export gate: those validation scripts still fail unless real Polar H10 PMD ECG/RR evidence is present and aligned to both condition audio windows.

## 6. Physical Input Gate

A human operator wearing the headset must press the virtual button with the intended participant input method: a Quest controller physically contacting/pressing the 3D Big Red Button or an aligned invisible helper collider. Accept the gate only when logcat shows `BRB_BUTTON_PRESS` markers, the final export contains the same press count, and both conditions contain valid 130 Hz real Polar PMD ECG/RR evidence for their audio windows.

Do not use ADB taps, Android keyevents, gaze selection, keyboard input, or visible flat UI buttons as proof that Quest controller input works for the participant-facing button.

The autorun validation gate also does not close this gate. It proves on-device flow, audio completion, export shape, and app-side press logging only.

For a fast human-operated contact smoke before the full physical export gate, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-controller-contact-smoke.ps1 -Serial <quest-serial> -AdbPath <adb.exe>
```

This waits only for `BRB_BUTTON_PRESS ... source=controller_contact`, then force-stops the app. It proves the controller-contact input path reaches app-side press logging; it does not prove full audio completion or JSON/CSV export.

When the H10 and operator are both ready, `tools\run-final-hardware-gates.ps1` is the preferred final entry point because it performs the live-H10 smoke, fast contact smoke, and full export validation in a single ordered session.

## 7. Future Press-Sound Gate

The placeholder press cue is active, but final sound-envelope matching is not complete yet. When replacing the placeholder or changing the press-motion timing, validate:

- exactly one sound trigger per accepted controller-contact press
- no sound trigger for suppressed startup or cooldown contacts
- press sound remains separate from the two instruction MP3 files
- final sound asset hash and duration match the documented stimulus
- button cap maximum depression aligns with the sound's main transient peak
