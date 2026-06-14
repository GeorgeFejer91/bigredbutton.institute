# Big Red Button First Study MR App

Native Meta Quest 3 mixed-reality experiment for the first Big Red Button study. This is not a Unity project.

The app is built with Kotlin, Jetpack Compose panels, and Meta Spatial SDK. It enables passthrough on scene start, places a reachable 3D Big Red Button model in front of the participant during each audio condition, requires controller-based physical button pressing, then shows a larger 2D questionnaire pop-up panel between conditions.

## Participant Flow

1. Consent and demographics: app-assigned participant ID, name, age, four-choice gender, three-choice handedness, consent checkbox, and trigger/pointer signature pad.
2. One-time pre-condition prompt: asks about prior Big Red Button experience, plays the selected feedback clip, waits 15 seconds, then plays `pre_start_instructions.mp3` before `Start experiment` appears.
3. Condition 1: button is visible and controller-pressable for the full `first-big-red-button-vr-study-instructions-final.mp3` instruction track.
4. Post-condition 1 button experience task: asks how close and how present the button felt, then logs felt closeness and felt button presence without showing research variable names to the participant.
5. Post-condition 1 session experience ratings: adapted IPQ items shown without naming the source instrument to the participant.
6. Post-condition 1 additional time rating: logs `Lost Opportunity for better results quotient` without showing the internal quotient name to the participant.
7. Condition 2: button is visible and controller-pressable for the full `first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3` instruction track.
8. Post-condition 2 repeats the same neutral participant-facing response tasks.
9. Completion writes local JSON, summary CSV, press-event CSV, ECG blink-event CSV, Polar RR-event CSV, raw ECG time-series CSV, and `session-index.jsonl` to the standard export folder and a SideQuest-friendly `ExperimentResults` mirror.

## Design Notes

- Passthrough is enabled with `scene.enablePassthrough(true)`.
- Locomotion is disabled for the study.
- The button model is placed at approximately reachable distance: `x=0`, `z=0.48`, matching the prior Big Red Button runtime's 0.48 m head-distance target.
- The button is positioned as a human-facing seated interaction target: cap/contact center `y=1.04`, nominal seated eye height `y=1.28`, distance `z=0.48`. This gives an approximately 26.6 degree downward viewing angle and 34.3 degree apparent button diameter, so the participant sees the top of the 3D button clearly while it remains within controller reach.
- The questionnaire panel is a 2D spatial pop-up at `x=0`, `y=1.52`, `z=1.55`, with `scene.setViewOrigin(0,0,0,0)` called before each spawn so the panel lands in the participant's current gaze line.
- The participant-facing button is the packaged 3D model `app/src/main/assets/models/BigRedButton.glb`. The original Meta/Unity sample asset was too low-poly in native passthrough, so the study now packages a smoother GLB with a glossy domed red cap, metal bezel, dark base, and the same `pressed` animation contract. Expected SHA-256: `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`.
- The final participant-facing interaction must match the original controller-based setup: the participant reaches out with a Quest controller and physically presses the 3D button. Gaze selection, ADB input, keyboard input, Android taps, and visible flat 2D buttons are not valid final input paths.
- A model-aligned invisible ISDK box collider sits over the button cap and accepts only `COLLIDER_HOVER_CONTACT_ACTUATE` select events as `controller_contact` presses. This is the native no-Unity port of the controller-contact press path and still needs physical headset validation.
- A transparent spatial Compose panel still sits over the model as an interim fallback target; it is not the visible button and exports as `transparent_panel_interim`. Presses have a 350 ms startup suppression window and a 180 ms cooldown, ported from the existing Big Red Button mechanism.
- An old digital red counter floats above the 3D button during audio conditions and increments from the accepted button press count.
- Accepted button presses play the temporary swappable cue `app/src/main/assets/sfx/button-press-placeholder-kenney-bong.ogg`. Questionnaire choice/navigation controls play `ui_choice_blip.wav` and `ui_navigation_blip.wav`.
- The intake panel includes a PMD-aware Polar H10 validity strip. Its green check is reserved for full physiology readiness: HR/RR plus raw PMD ECG samples streaming at 130 Hz. HR/RR-only detection is shown as a waiting state. In full participant/physical runs, both button/audio conditions record real Polar H10 PMD ECG and RR physiology. The counterbalanced condition variable is the Big Red Button glow `feedbackSource`: one condition uses real Polar RR feedback and the other uses `simulated_neurokit2` sham RR feedback from `app/src/main/assets/ecg/neurokit2_simulated_rr_intervals_ms.csv`. PMD ECG capture requests high BLE connection priority, starts with the minimum ECG MTU 70 for lower-latency packets, selects the highest advertised sample rate/resolution before falling back to H10 defaults, anchors the condition/ECG clock immediately before `MediaPlayer.start()`, and stores ECG samples clipped to an exact `0..audioDurationMs` instruction-audio window with sequential sample indices and nanosecond monotonic capture metadata.
- The public new-agent integration brief is represented natively as `agentIntegrationProtocol` in the JSON export plus `BRB_AGENT_INTEGRATION_CONTRACT` at startup. It records that this app remains a no-Unity Meta Spatial SDK study, keeps questionnaires in-process, uses direct brokerless Polar PMD ECG/RR as the active physiology path, keeps LSL/external signal routing disabled and diagnostic-only until a Quest-tested JNI/library path exists, and preserves `controller_contact` as the final participant press proof.
- Participant-facing questionnaire panels use task titles and response instructions. Researcher-facing instrument names, scoring notes, variable names, and adapted-IPQ rationale remain in documentation and export metadata rather than on the headset panels.
- The demographics panel uses the Big Red Button Institute website direction: warm paper background, editorial header, red accent rule, and restrained bordered form fields.
- The button experience task uses `app/src/main/res/drawable-nodpi/big_red_button_model_thumbnail.png`, rendered directly from the same `BigRedButton.glb` geometry/materials used during interaction, and draws it centered on the circle center.
- Questionnaire panels now use blue software-failure style intro/outro transitions. `questionnaire_intro_glitch.mp3` plays while panels appear, and `questionnaire_outro_glitch.mp3` plays while panels disappear before the next button/audio condition. Both transitions drive a blue flicker overlay and are hash-checked by validation.
- Name uses a visible app-owned pop-out QWERTY keyboard panel that appears when the Name field is focused, placed by headset-centered radial visual angle to the left of the main questionnaire, with both panels facing the user and the keyboard kept out of the form's view. It provides Space/Back/Clear/Next and direct hardware/ADB keyevent fallback. It no longer depends on the Quest system IME and is not integrated into the questionnaire panel. Age uses an in-panel 0-100 slider saved to the same `demographics.age` export field, so Age has no IME owner. Participant ID is generated under the hood; gender is `male`, `female`, `other`, or `prefer_not_to_say`; handedness is `left`, `right`, or `ambidextrous`.
- The temporary CC0 button sound placeholder is active as press feedback. See [docs/button-press-sound-and-motion.md](docs/button-press-sound-and-motion.md) before replacing it or retiming button motion to a final sound envelope.
- A procedural dome/base fallback remains in code but is disabled for the participant-facing stimulus.
- The Gradle build stages only the two final instruction MP3s from `../audio-assets/final`; the demo MP4s are not packaged into the APK.
- Do not re-encode, trim, normalize, or otherwise alter the two final MP3s. Audio validation checks the original SHA-256 hashes and exact ffprobe durations.

## Data Exports

On completion, exports are written on the headset under both paths below. Validation treats `ExperimentResults` as the practical SideQuest retrieval mirror, so headset validation pulls both folders and byte-compares file names, sizes, and SHA-256 hashes.

```text
/sdcard/Android/data/org.bigredbutton.firststudy/files/BigRedButtonFirstStudyExports
/sdcard/Android/data/org.bigredbutton.firststudy/files/ExperimentResults
```

Files per completed session:

- `brb_first_study_<participant>_<session>.json`
- `brb_first_study_<participant>_<session>_summary.csv`
- `brb_first_study_<participant>_<session>_press_events.csv`
- `brb_first_study_<participant>_<session>_ecg_blink_events.csv`
- `brb_first_study_<participant>_<session>_polar_rr_events.csv`
- `brb_first_study_<participant>_<session>_ecg_timeseries.csv`
- `session-index.jsonl`

Main logged variables:

- demographics and consent fields
- native integration protocol metadata for the new-agent brief, including direct Polar, disabled diagnostic LSL defaults, in-process questionnaire routing, and forbidden product communication mechanisms
- condition 1 and 2 button press counts
- condition 1 and 2 press-event timestamps, elapsed milliseconds/nanoseconds, shared monotonic-clock alignment fields, feedback/physiology sources, nearest ECG sample index, and `input_source`/`validation_automation`
- condition 1 and 2 source-specific press counts for `controller_contact`, `transparent_panel_interim`, `scene_object_fallback`, and `auto_validation`
- feedback assignment order, Polar H10 status fields, condition-specific feedback source, condition-specific physiology source, and condition-specific ECG blink/RR counts
- ECG blink-event rows with source, RR interval, heart-rate estimate, elapsed milliseconds, Unix time, and ISO timestamp
- Polar RR-event rows with elapsed milliseconds/nanoseconds, Unix/ISO timestamp, RR interval, heart-rate estimate, feedback source, and whether that RR event was used for glow feedback
- raw real Polar ECG time-series rows with source, condition-relative elapsed milliseconds and nanoseconds, repeated audio-window start/end/duration fields, Unix/ISO timestamp, Polar sensor timestamp, microvolts, 130 Hz sample rate, frame/package metadata, requested/negotiated MTU, and final-gate checks for sequential monotonic high-resolution timing
- condition 1 and 2 felt closeness score
- condition 1 and 2 self-button distance units
- condition 1 and 2 felt presence score
- condition 1 and 2 button presence circle radius units
- condition 1 and 2 adapted IPQ raw item scores, reverse-scored item scores, subscale means, and total mean
- condition 1 and 2 `Lost Opportunity for better results quotient`

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-apk.ps1
```

Output:

```text
app\build\outputs\apk\debug\app-debug.apk
```

## Local Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-local-preflight.ps1
```

The local preflight builds the debug APK, runs the static study contract, checks audio hashes/durations, validates a synthetic export schema including ECG blink and raw ECG time-series exports, tests the physical-press evidence validator, and renders local layout previews. It does not launch the headset and does not replace the final human physical controller-contact/live-H10 export gate.

After a passing local preflight, short Quest smoke suite, and fast Quest directional/questionnaire export validation, generate the current readiness summary:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-readiness-report.ps1
```

The report status should remain `ready_except_physical_and_live_polar_gates` until a human-worn Quest controller-contact export run and a live Polar H10 PMD ECG smoke have passed. After live Polar passes but before physical pressing, the expected status is `ready_except_physical_gate`. After both the standalone live Polar smoke and the full physical controller-contact/live-H10 export gate pass on the current APK, the readiness status becomes `complete`.

Then write the requirement-level completion audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-goal-completion-audit.ps1
```

This writes `artifacts\goal-completion-audit\<runId>\goal-completion-audit.json`. It should keep `completionAllowed=false` until live Polar H10 streaming, human controller-contact smoke, and the full controller-contact/live-H10 export gate pass on the current APK.
When another script has just generated a readiness report, pass it explicitly with `-ReadinessJson <path-to-readiness-report.json>` so the goal audit is bound to that exact readiness source.

Individual gates:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-study.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-audio-assets.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\render-layout-previews.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-export-schema.ps1 -Synthetic
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test-physical-press-evidence-validator.ps1
```

Use `-SkipBuild` for a fast static check.

## Quest Install And Export Pull

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\install-launch-quest.ps1 -Serial <quest-serial>
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\pull-exports.ps1 -Serial <quest-serial>
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-export-schema.ps1 -ExportDir .\local-export-pulls\<pull-folder>\BigRedButtonFirstStudyExports
```

If `adb.exe` is not on PATH, pass `-AdbPath C:\path\to\platform-tools\adb.exe` to the install and pull scripts.

For a no-human full-flow Quest export validation that waits for the real MP3 durations, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-autovalidation.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This launches the hidden `brb.autoValidation` mode, waits for both `MediaPlayer` completion events, auto-submits questionnaire responses, pulls exports, and validates JSON/CSV. It proves the APK flow and data path on device; it does not prove physical Quest controller input.

This full real-duration autorun is intentionally slow and has already passed once for the current audio and condition-flow implementation on 2026-06-09. Use it as a release/timing gate after audio, condition-flow, or export-plumbing changes only. For routine checks, use `validate-audio-assets.ps1` to confirm the MP3 hashes/durations and rely on build/static/schema checks plus short Quest smoke.

For a fast human-operated check that the Quest controller physically reaches the native contact collider, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-controller-contact-smoke.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This launches the first condition and waits only until a real `controller_contact` press appears in logcat, then stops the app. It is deliberately fast and does not validate exports.

For a live Polar H10 check that raw PMD ECG samples are reaching the headset/app, wear the Polar H10 and use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-polar-h10-live-smoke.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This launches the intake screen, watches `BRB_POLAR_H10_STATUS`, and passes only when the app reports Polar detection, connection, PMD readiness, `ecgStreaming=true`, nonzero raw ECG samples, and `130 Hz`. It does not run the full experiment or prove physical button pressing.

For a no-audio panel/glitch headset smoke that captures the demographics panel and first Button Experience panel, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-panel-smoke.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This launches hidden `brb.panelSmoke` mode. It does not start study audio, does not start a condition, and does not export data. It verifies panel visibility plus the questionnaire intro MP3 and blue glitch markers.

For a short in-condition 3D button layout smoke, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-visual-layout-smoke.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This launches hidden physical-validation mode, waits only for condition 1 and the `BRB_BUTTON_SPATIAL_LAYOUT` marker, captures a screenshot/log, and force-stops before full audio completion. It validates the current human-facing placement without proving physical controller input.

To run both short non-human headset gates as one suite:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-smoke-suite.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This runs the visual-layout smoke and the panel/glitch smoke and writes a combined summary under `artifacts\quest-smoke-suite`. It does not replace the human physical controller-contact/live-H10 export gate.

Before the final operator-run hardware gate, write a handoff artifact that verifies the current APK, readiness report, goal audit, and final post-run audit-chain row all agree:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-final-hardware-operator-handoff.ps1 -RefreshAudit -RequireReady
```

This writes `artifacts\final-operator-handoff\<runId>\final-operator-handoff.json` and `.md`. A handoff status of `ready_for_operator_external_gates` means the software/readiness/audit chain is coherent enough to start the human/H10 gates; it is not evidence that live Polar H10 streaming or human controller-contact pressing has passed.

For the final operator-run hardware gate, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-final-hardware-gates.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This wrapper runs the live Polar H10 PMD ECG smoke, then the fast controller-contact smoke, then the full physical export gate in one ordered session and writes `artifacts\final-hardware-gates\<runId>\final-hardware-gates-summary.json`. It also writes a pre-run operator handoff and refreshes readiness plus the goal completion audit after dry runs, failures, and real passes unless `-SkipPostRunAudit` is supplied; the generated readiness is bound to the wrapper summary that just ran, and the generated goal audit is bound to that exact readiness JSON. Use `-DryRun` only to verify command construction; it is not hardware evidence.

The underlying full physical export gate is:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-quest-physical-press-validation.ps1 -Serial <quest-serial> -AdbPath C:\path\to\platform-tools\adb.exe
```

This first runs the live Polar H10 PMD ECG smoke by default, then launches hidden `brb.physicalPressValidation` mode only if 130 Hz raw ECG samples are streaming. The app auto-starts the two real audio conditions and auto-submits non-press questionnaire fields after each `MediaPlayer` completion, but it never creates fake presses. A human operator must press the modeled Big Red Button with a Quest controller during both conditions while a worn Polar H10 streams real physiology throughout both conditions. The script pulls exports and requires `controller_contact` presses in JSON, press-events CSV, and logcat.

Read [docs/physical-validation-operator-guide.md](docs/physical-validation-operator-guide.md) before running the final physical gate. The script also writes `operator-checklist.txt` into each physical-validation artifact folder, pulls and validates both `BigRedButtonFirstStudyExports` and the SideQuest-readable `ExperimentResults` mirror, byte-compares the pulled mirror files, and fails if the live Polar precheck fails, if button press evidence is marked as automation, if either condition has insufficient 130 Hz PMD ECG coverage, if either real-Polar ECG window is not exactly the instruction-audio duration in milliseconds and nanoseconds, if ECG rows are not sequential/monotonic with a 130 Hz-shaped median sample interval, if Polar RR rows are absent, if controller presses lack `elapsed_ns` or nearest-ECG linkage within the threshold, or if the requested MTU 70 minimum-packet PMD setup marker is missing. Use `-SkipPolarPrecheck` only when intentionally reusing already-proven live H10 evidence for a same-session run.

To re-audit a completed physical run independently, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-physical-press-evidence.ps1 -ExportDir <pulled BigRedButtonFirstStudyExports folder> -LogcatPath <logcat-filtered.txt>
```

See [docs/validation-ladder.md](docs/validation-ladder.md) before claiming headset readiness.

Latest manual visual-inspection notes are recorded in [docs/visual-validation-notes.md](docs/visual-validation-notes.md).

Current evidence snapshot, 2026-06-13:

- APK SHA-256 `C706C57E4B814AD920B74C187ECE834933581F8A886DF1D8D89B343D1B6372A2`, size `165366005` bytes.
- `tools/build-apk.ps1` passed, and the APK was installed/uploaded to Quest 3S `3487C10J0P01ZY` by `artifacts/quest-demographics-direct-keyboard/20260613-152127/quest-demographics-direct-keyboard-validation-summary.json`.
- Static validation `artifacts/local-validation/validation-20260613-153139.json`, including compact no-scroll demographics, app-owned Name keyboard plus Age 0-100 slider/no-IME checks, removed mixed-owner keyboard path checks, calibrated pictographic distance-axis controls, thicker pictographic circles, warm heartbeat emission, dual controller/hand contact provenance, qkv/readiness gates, final-wrapper post-run audit checks, goal-completion audit checks, explicit readiness-source binding for goal audits, explicit final-wrapper summary binding for post-run readiness, validated dry-run wrapper selection for ordinary readiness, final hardware post-run audit validator checks, visual-smoke full-log fallback evidence, the goal-audit `final_hardware_postrun_audit_chain` row, the final operator handoff contract, ECG audio-window proof, pre-`MediaPlayer.start()` condition/ECG anchoring, simulated blink/runtime flash, minimum-MTU Polar smoke checks, high-resolution real-Polar timing checks, physical export mirror equality checks, final physical precheck backlink checks, and final hardware wrapper ordering checks.
- Exact audio validation `artifacts/audio-validation/audio-validation-20260613-025021.json`; both final MP3 hashes and durations remain unchanged.
- Synthetic export schema validation `artifacts/export-schema-validation/export-schema-validation-20260610-132618.json`, requiring `*_ecg_timeseries.csv` with `elapsed_ns` and audio-window columns plus `*_polar_rr_events.csv` and press alignment columns.
- Demographics keyboard contract `artifacts/native-keyboard-validation/native-keyboard-validation-20260613-152759.json`; it fails if the removed loose-keyboard, hidden bridge, SpatialTextField, or Android EditText ownership paths return and confirms the app-owned Name keyboard plus the Age 0-100 slider/no-IME contract.
- Direct keyboard validation `artifacts/quest-demographics-direct-keyboard/20260613-152127/quest-demographics-direct-keyboard-validation-summary.json`; it types `Georgex`, Backspace, Space, `Fejer`, Enter, and Age `34` against the installed APK with raw keyevents.
- Focused demographics smoke `artifacts/quest-demographics-keyboard/20260613-152350/quest-demographics-keyboard-validation-summary.json` and repeated-entry stress `artifacts/quest-demographics-keypress-stress/20260613-152428/quest-demographics-keypress-stress-summary.json` passed on the current APK.
- Physical evidence validator test `artifacts/ppe-tests/t-20260610-132618/physical-evidence-validator-test-summary.json`, rejecting one-condition-only Polar recording, simulated ECG rows in the sham feedback condition, missing press `elapsed_ns`, missing nearest-ECG linkage, oversized press-to-ECG gaps, missing Polar RR rows, missing low-latency config, and non-monotonic `elapsed_ns`.
- Final hardware post-run audit validator behavioral test `artifacts/final-hardware-postrun-audit-tests/t-20260610-132625/final-hardware-postrun-audit-validator-test-summary.json`, proving the binding verifier accepts valid dry-run, valid real-pass, and valid incomplete-bootstrap chains and rejects stale readiness links, status mismatches, dry-run completion allowance, incomplete-readiness completion allowance, APK hash mismatches, and failed post-run audit status.
- Local layout previews `artifacts/layout-previews/preview-20260613-152759`, including the current app-owned Name keyboard, button, Button Experience, presence questionnaire, and Lost Opportunity previews.
- Quest panel/glitch smoke `artifacts/quest-panel-smoke/20260613-152617/quest-panel-smoke-summary.json`; direct keyboard screenshots are in `artifacts/quest-demographics-direct-keyboard/20260613-152127`.
- Fast Quest directional/data validation `artifacts/qkv/20260613-152518/quest-keyevent-questionnaire-validation-summary.json` includes app-owned Name keyboard evidence, Age slider/no-IME evidence, panel-exit keyboard hide evidence, enter-submit replay evidence, `exportMirrorMatched=true`, exact ECG audio-window proof, feedback counterbalance/sham blink runtime flash proof, press `elapsed_ns` export proof, and the updated pictographic replay expectation: condition 2 right/right/up/up exports closeness `40` and presence `60`.
- Final hardware wrapper dry run `artifacts/final-hardware-gates/20260610-130944/final-hardware-gates-summary.json`, status `dry_run`, proves command ordering only and records `preRunHandoff.status=pass` plus `postRunAudit.status=pass` with generated readiness/goal-audit paths. Its post-run readiness is bound to this exact wrapper summary, and its goal audit is bound to the same readiness JSON written during the wrapper post-run audit.
- Final hardware post-run audit binding verifier `artifacts/final-hardware-postrun-audit-validation/validation-20260610-132626/final-hardware-postrun-audit-validation.json`, status `pass`, proves the wrapper summary, readiness report, and goal audit form one consistent evidence chain.
- Fresh live Polar H10 PMD ECG smoke attempt `artifacts/qpolar/20260610-134648/quest-polar-h10-live-smoke-summary.json`, status `fail`, current APK SHA-256 `55E3B082077BD55D939D1610E5FEC7AC56641B8FA62C201804AEE322CC951C2A`, `detected=false`, `ecgStreaming=false`, `ecgSamples=0`. It waited 45 seconds and proves the current-APK failure-summary path only.
- Fresh controller-contact smoke attempt `artifacts/qcs/20260610-114301/quest-controller-contact-smoke-summary.json`, status `fail`, current APK SHA-256 `55E3B082077BD55D939D1610E5FEC7AC56641B8FA62C201804AEE322CC951C2A`, `pressDetected=false`, `controllerContactPresses=0`. It proves the current-APK no-operator failure-summary path only.
- Readiness report `artifacts/readiness-report/report-20260610-134802/readiness-report.md`, status `ready_except_physical_and_live_polar_gates`; it requires the current full local preflight, current Quest smoke suite, current qkv evidence, current-APK hardware attempt summaries, current final hardware wrapper dry run, final hardware post-run audit validator behavioral test, and final hardware post-run audit binding validation for software readiness.
- Goal completion audit `artifacts/goal-completion-audit/20260610-134803/goal-completion-audit.json`, status `ready_except_physical_and_live_polar_gates`, `readinessJson=artifacts/readiness-report/report-20260610-134802/readiness-report.json`, `softwareRequirementsProven=true`, `externalHardwareRequirementsProven=false`, `completionAllowed=false`, and proven software row `final_hardware_postrun_audit_chain=true`.
- Final operator handoff `artifacts/final-operator-handoff/handoff-20260610-134804/final-operator-handoff.md`, status `ready_for_operator_external_gates`, confirms the APK hash, readiness report, goal audit, final post-run audit-chain row, and ADB readiness for Quest 3S serial `3487C10J0P01ZY` before the human/H10 run.
- Full physical/live-H10 export gate remains open: latest short failure-summary path is `artifacts/qpv/20260610-115825/quest-physical-press-validation-summary.json`, which now links `polarPrecheckSummary` to `artifacts/qpolar/20260610-115826/quest-polar-h10-live-smoke-summary.json`.

## Psychometric Note

The presence questionnaire adapts the Igroup Presence Questionnaire wording to the button context. The app logs the adapted item wording and reverse-scoring metadata in the JSON export, but the participant-facing panel does not name the instrument or explain scoring. Treat this as an adapted instrument in study methods, not as a newly validated questionnaire.

See [docs/psychometrics.md](docs/psychometrics.md) for the instrument rationale and citation boundary.
