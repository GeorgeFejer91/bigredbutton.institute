# Start Here For AI Agents

Read this folder before editing the native Big Red Button first-study app.

Required order:

1. `project-goals.md`
2. `constraints.md`
3. `active-status.md`
4. `workflow-lessons.md`
5. `mesmerprism-unity-transplant-plan.md`
6. `../README.md`
7. `../docs/validation-ladder.md`
8. `../docs/completion-audit.md`
9. `../docs/visual-validation-notes.md`
10. `../docs/physical-validation-operator-guide.md`

## Project Identity

- Repo path: `D:\GithubVR\bigredbutton.institute`
- Study path: `studies/first-big-red-button-study`
- Native app path: `studies/first-big-red-button-study/native-quest-mr-study`
- Android package: `org.bigredbutton.firststudy`
- App type: native Meta Quest 3 mixed-reality app using Meta Spatial SDK, Kotlin, and Compose panels.
- Final interaction: participants must physically press the 3D Big Red Button with a Quest controller, matching the original Unity reference behavior. Automation and flat UI input are validation aids only.
- Current visual stimulus: smooth realistic `app/src/main/assets/models/BigRedButton.glb` with SHA-256 `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`. Do not restore the old low-poly/unlit button.
- Current button placement: 0.48 m in front of the participant, cap/contact center `y=1.04`, nominal seated eye line `y=1.28`, about 26.6 degrees downward and 34.3 degrees apparent diameter. Preserve this human-facing seated layout unless intentionally changing and revalidating it.
- Current pre-condition prompt: after demographics and before condition 1, the transparent counter panel asks whether the participant has experience pressing big red buttons. During this prompt the 3D button model and contact collider must remain hidden; the prompt is logged as `priorBigRedButtonExperience` and must occur only once before condition 1, never before condition 2. After the selected Yes/No feedback clip, `pre_start_instructions.mp3` plays while `Start experiment` remains hidden; the start control appears only after that clip completes.
- Press-sound note: a CC0 placeholder is active on accepted button presses, but it is not the final reviewed sound stimulus. Read `docs/button-press-sound-and-motion.md` before replacing it or retiming button motion.
- Current questionnaire/input note: demographics is a compact no-scroll panel. Name and Age now use visible `AndroidView(EditText)` controls embedded directly in the BRB warm-paper field shell, matching the reliable 2D APK pattern while keeping one real IME owner per visible field. Name uses text/capitalized-words input, `IME_ACTION_NEXT`, and max 80 characters. Age uses numeric input, `IME_ACTION_DONE`, digits-only sanitizer, and max 3 characters. The guided flow highlights the required label, focuses Name first, auto-retargets to Age after a stable valid Name or Name Next, and logs `platformControl=EditText`, `focusedView=EditText`, `inputOwner=androidViewEditText`, and `restartInput=true`. The retired custom loose keyboard, hidden `EditText` bridge, UISet `SpatialTextField` demographics owner, and Age trigger-dial workaround must stay out unless the study design intentionally changes. `tools/test-native-keyboard-contract.ps1` and `tools/validate-study.ps1` fail if mixed ownership returns, and `tools/run-quest-demographics-keyboard-entry-validation.ps1` uses a per-run session-scoped app-side validation command route to prove Name text/Next, Age number/Done, mixed-input cleanup, and exact export values. If manual headset IME still fails, the next deliberate fallback is a visible app-owned single keyboard with rectangular letters plus a digit pad, not a hidden bridge.
- Current pictographic note: the horizontal control is a distance-from-self visual axis. The VAS minimum thumb center aligns with the self pictogram center, the default VAS thumb positions align vertically with the default button depiction, and the closeness thumb and button marker share the same horizontal coordinate across the whole axis. Exports keep `feltCloseness0To100` as higher-is-closer and store visible distance separately as `selfButtonDistanceUnits`. Endpoint labels are `very close`/`very distant` and `small presence`/`large presence`.
- Current redness-note: the Button Experience task includes `How red did the button feel?`. Condition 1 starts with a VAS (`slightly red` to `very red`) and converts once to a seven-box Likert scale; condition 2 starts as Likert and converts once to VAS. Export both final values, `rednessScaleOrder`, the carried-forward closest analogue on both scales, and whether the participant changed away from that analogue after conversion. Keep Likert boxes inset/spaced from the VAS track so the exact correspondence is less visually obvious. The supplied changeover clips are active as `first_questionnaire_change` and `second_questionnaire_change_excuse`; participant runs play the full clips with transcript-synced visual micro-events (`supervisor_ping`, `seven_boxes_assemble`, `professional_warning`, `boxes_erased`, etc.) logged as `BRB_REDNESS_SCALE_CONVERSION_MICRO_EVENT`. Fast qkv replay logs the same cue `microTimeline` with `validationShortcut=true` and uses a short navigation cue so it does not wait through those clips.
- Current button input note: controller-contact remains the final physical proof source, but hand-tracked collider selects are accepted and exported as separate `hand_contact` provenance for usability. The native press target is a seven-box `multi_box_cap` approximation with a source-level `ButtonContactLatch`; do not collapse it back to one broad box or a flat UI-only hit target.
- Current heartbeat visual note: heartbeat/RR flashes use `HeartbeatPulseDriver` plus MesmerPrism-style GLB material variants (`BRB_BUTTON_GLOW_MODEL_VARIANTS_READY`, `modelGlow=glb_material_variant_swap`). The app keeps the original GLB for idle and swaps in `app/src/main/assets/models/glow/BigRedButtonGlowLevel01.glb` through `32.glb` for progressively brighter/emissive cap materials generated by `tools/create-button-glow-variants.py`. The native pulse envelope now follows the Unity reference more closely: 320 ms, `unity_ease_in_out_1_to_0`, 250 ms refractory, 16 frames at 20 ms. The current peak is contrast-tuned for Quest screenshots (`nativePeakEmission=3.35,0.095,0.026`) so the cap visibly warms toward red/orange without washing out to white under Unity's raw `7.0` emission. The generator adds only subtle metal-bezel warmth and preserves the dark base material; small native point lights assist the effect. Heartbeat/ECG feedback must be glow-only: do not play the GLB `pressed` animation on glow variants, and keep geometric motion reserved for accepted physical button presses. No participant-facing transparent halo/canopy geometry should be used. The disabled 2D radial panel fallback (`MODEL_GLOW_PANEL_FALLBACK_ENABLED = false`) must not become the primary blink.
- Current signal-routing note: native Polar PMD ECG remains the primary physiological stream. The app now exports native threshold R-peak detector diagnostics and a disabled-by-default external/LSL signal CSV scaffold, but LSL is not active until an Android-compatible native library/JNI path is explicitly added and headset-tested.
- Polar note: raw Polar H10 ECG capture is now implemented through the PMD service, not only RR intervals. The client requests the minimum ECG MTU 70 first for low-latency packets, selects the highest advertised PMD ECG sample rate/resolution before falling back to H10 defaults, timestamps samples with nanosecond monotonic timing derived from PMD frame timestamps, and anchors `startedElapsedNs` immediately before `MediaPlayer.start()` with `BRB_CONDITION_AUDIO_START_ANCHOR ... anchor=pre_media_player_start`. Exports must include `*_ecg_timeseries.csv` with `elapsed_ns` plus audio-window start/end/duration columns, and each condition ECG window must be exactly `0..audioDurationMs` in milliseconds and `audioDurationMs * 1,000,000` in nanoseconds. The final physical validation gate now also requires real-Polar PMD ECG coverage, sequential sample indices, strictly increasing `elapsed_ns`, a median sample interval matching 130 Hz, no large sample gaps, and RR blink evidence in both the primary pulled export and the SideQuest-readable `ExperimentResults` mirror, then byte-compares the two export folders by file name, size, and SHA-256.

## First Checks

Run from the native app root:

```powershell
git -C D:\GithubVR\bigredbutton.institute status -sb
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-study.ps1 -SkipBuild
```

Use `rg` before broad file reads. Preserve unrelated user changes.

For the strongest non-headset gate, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-local-preflight.ps1
```

After local preflight, short Quest smoke suite evidence, and fast directional questionnaire/data evidence exist, refresh the current readiness report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-readiness-report.ps1
```

The readiness report intentionally requires `artifacts\qkv\<run>\quest-keyevent-questionnaire-validation-summary.json` to pass on the current APK hash, to have pulled the SideQuest-readable `ExperimentResults` JSON/CSV files, to report native Name text-keyboard evidence, Age numeric-keyboard evidence, panel-exit keyboard hide evidence, explicit `direction=enter` submit replay evidence, final prompt options-ready gating before replay, prior Big Red Button experience prompt/export evidence, and redness VAS/Likert conversion/export evidence, to report `exportMirrorMatched=true` with `export-mirror-comparison.json`, to prove the qkv ECG capture windows equal the instruction-audio durations at 130 Hz with exact millisecond and nanosecond window fields, and to prove the simulated RR driver produced exported blink rows plus runtime `BRB_ECG_BLINK`/`BRB_HEARTBEAT_FLASH` markers.

After writing readiness, write the machine-readable goal audit:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-goal-completion-audit.ps1
```

The goal audit should show `softwareRequirementsProven=true`, a proven `final_hardware_postrun_audit_chain` software row, `completionAllowed=false`, and missing IDs `live_polar_h10_streaming`, `human_controller_contact_smoke`, and `full_physical_live_h10_export` until the final human/H10 gates actually pass.
If another script just generated readiness, pass the exact file to `tools\write-goal-completion-audit.ps1 -ReadinessJson <path>`; this prevents the goal audit from racing against latest-file discovery.

Before a human/H10 operator starts the final hardware gates, write the operator handoff:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-final-hardware-operator-handoff.ps1 -RefreshAudit -RequireReady
```

The handoff status should be `ready_for_operator_external_gates`, not `complete`. It confirms the APK/readiness/goal-audit chain is coherent and still lists the external live-H10/controller gates as missing.

Quest visual-layout smoke checks focused/resumed foreground after `am start`. If another non-Oculus OpenXR app is still foreground, it force-stops that package once and relaunches `org.bigredbutton.firststudy`; this was added after `com.example.rustyxr.opengles` blocked the first current visual-smoke attempt.

## Current Build Command

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build-apk.ps1
```

The expected debug APK is:

```text
app\build\outputs\apk\debug\app-debug.apk
```

## Headset Gates

- No-human flow/export gate: `tools\run-quest-autovalidation.ps1`. This already passed once for the current audio and condition-flow implementation on 2026-06-09; do not rerun it routinely because it waits through both full tracks.
- Fast no-audio panel/glitch smoke: `tools\run-quest-panel-smoke.ps1`
- Fast in-condition button visual/layout smoke: `tools\run-quest-visual-layout-smoke.ps1`
- Short non-human Quest smoke suite: `tools\run-quest-smoke-suite.ps1`
- Fast directional questionnaire/data export validation: `tools\run-quest-keyevent-questionnaire-validation.ps1`
- Current readiness summary: `tools\write-readiness-report.ps1`
- Current goal completion audit: `tools\write-goal-completion-audit.ps1`
- Live Polar H10 PMD ECG smoke: `tools\run-quest-polar-h10-live-smoke.ps1`
- Fast human controller-contact smoke: `tools\run-quest-controller-contact-smoke.ps1`
- Human controller-contact/live-H10 export gate: `tools\run-quest-physical-press-validation.ps1`; by default this runs `tools\run-quest-polar-h10-live-smoke.ps1` first, refuses to start the full audio run if live 130 Hz PMD ECG is not streaming, then pulls, validates, and byte-compares both `BigRedButtonFirstStudyExports` and `ExperimentResults`.
- Recommended final operator wrapper: `tools\run-final-hardware-gates.ps1`; this sequences live Polar H10 PMD ECG smoke, optional fast controller-contact smoke, and the full controller-contact/live-H10 export gate in one ordered run, writes `artifacts\final-hardware-gates\<runId>\final-hardware-gates-summary.json`, then refreshes readiness and the goal completion audit unless `-SkipPostRunAudit` is supplied. The wrapper passes the freshly generated readiness JSON explicitly into the goal audit. Use `-DryRun` only to verify command construction; a dry run is not hardware evidence.
- Final operator handoff: `tools\write-final-hardware-operator-handoff.ps1`; use `-RefreshAudit -RequireReady` before the final operator session to write a concise JSON/Markdown handoff with the current APK hash, readiness report, goal audit, missing external gates, and exact wrapper command. This is not hardware evidence.
- Final wrapper post-run audit binding verifier: `tools\validate-final-hardware-postrun-audit.ps1`; use it on a final-wrapper summary to prove the wrapper summary, generated readiness report, and generated goal audit point to each other and the same APK.
- Final wrapper post-run audit validator behavioral test: `tools\test-final-hardware-postrun-audit-validator.ps1`; local preflight runs this to prove the binding verifier accepts valid dry-run/real-pass chains and rejects stale readiness links, status mismatches, dry-run completion allowance, incomplete-readiness completion allowance, APK hash mismatches, and failed post-run audit status.
- Final wrapper readiness binding rule: `tools\run-final-hardware-gates.ps1` passes `-FinalHardwareGateSummaryPath <current summary>` to `tools\write-readiness-report.ps1` during its post-run audit. Ordinary readiness generation, without that override, selects only a dry-run wrapper summary that already has a passing post-run audit binding validation. This prevents a newer failed or in-progress wrapper folder from poisoning operator handoff readiness.
- Physical evidence recheck: `tools\validate-physical-press-evidence.ps1`
- Physical evidence validator local test: `tools\test-physical-press-evidence-validator.ps1`

The current completion audit is `docs/completion-audit.md`. Before the final human run, read `docs/physical-validation-operator-guide.md`. Do not mark the overall goal complete until the physical controller-contact export gate has passed with a worn Polar H10 and the pulled export passes `tools\validate-physical-press-evidence.ps1`, unless the user explicitly changes the requirement away from controller-based physical pressing or live H10 capture. Do not claim live Polar H10 ECG proof until `tools\run-quest-polar-h10-live-smoke.ps1` passes with a worn H10, and do not claim full-condition ECG proof until the final physical export gate passes. The readiness report status should be `complete` only after both the standalone live Polar smoke and the full physical controller-contact/live-H10 export gate pass on the current APK.

Physiology recording and button-glow feedback are separate concepts. In current full participant/physical runs, both audio conditions must record real Polar H10 ECG/RR physiology; only the glow `feedbackSource` is counterbalanced between `real_polar_h10` and `simulated_neurokit2`. Simulated/sham feedback must not be exported as real ECG time-series rows.

If `adb` is not on PATH, first try the project-local platform tools at `artifacts\toolchain\android-platform-tools\platform-tools\adb.exe`.

## Memory Rule

When you make a durable architectural decision, discover a reusable validation lesson, or resolve a problem that future agents are likely to hit again, update this `For-AI` folder in the same change.
