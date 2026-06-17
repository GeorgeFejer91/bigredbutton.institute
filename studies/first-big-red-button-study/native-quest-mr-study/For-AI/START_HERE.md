# Start Here For AI Agents

Read this folder before editing the native Big Red Button first-study app.

Required order:

1. `project-goals.md`
2. `constraints.md`
3. `active-status.md`
4. `workflow-lessons.md`
5. `mesmerprism-unity-transplant-plan.md`
6. `../docs/new-agent-integration-audit.md`
7. `../README.md`
8. `../docs/validation-ladder.md`
9. `../docs/completion-audit.md`
10. `../docs/visual-validation-notes.md`
11. `../docs/physical-validation-operator-guide.md`
12. `../docs/hand-contact-physics-operator-guide.md`

## Project Identity

- Repo path: `D:\GithubVR\bigredbutton.institute`
- Study path: `studies/first-big-red-button-study`
- Native app path: `studies/first-big-red-button-study/native-quest-mr-study`
- Android package: `org.bigredbutton.firststudy`
- App type: native Meta Quest 3 mixed-reality app using Meta Spatial SDK, Kotlin, and Compose panels.
- Final interaction: participants must physically press the 3D Big Red Button with a Quest controller, matching the original Unity reference behavior. Automation and flat UI input are validation aids only.
- Current visual stimulus: smooth realistic `app/src/main/assets/models/BigRedButton.glb` with SHA-256 `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`. Do not restore the old low-poly/unlit button.
- Current button placement: 0.48 m in front of the participant, cap/contact center `y=1.04`, nominal seated eye line `y=1.28`, about 26.6 degrees downward and 34.3 degrees apparent diameter. Preserve this human-facing seated layout unless intentionally changing and revalidating it.
- Current pre-condition prompt: after demographics and before condition 1, the transparent counter panel asks whether the participant has experience pressing big red buttons. During this prompt the 3D button model and contact collider must remain hidden; the prompt is logged as `priorBigRedButtonExperience` and must occur only once before condition 1, never before condition 2. After the selected Yes/No feedback clip, the app waits 15 seconds, then `pre_start_instructions.mp3` plays while `Start experiment` remains hidden; the start control appears only after that clip completes.
- Press-sound note: a CC0 placeholder is active on accepted button presses, but it is not the final reviewed sound stimulus. Read `docs/button-press-sound-and-motion.md` before replacing it or retiming button motion.
- Current questionnaire/input note: demographics is a compact no-scroll panel. Name no longer depends on the Quest/system IME: focusing Name opens a separate visible app-owned pop-out spatial keyboard panel (`keyboard_panel`), not an integrated section inside the questionnaire panel. Keyboard placement is interpreted from the participant/headset field of view, not from flat screen coordinates: the questionnaire is on the central headset ray, the keyboard is on a neighboring left radial ray, both panels are oriented back toward the headset, and runtime layout evidence must report `radialReference=headset_center`, `orientation=faces_headset`, `nonObstructing=true`, and `fovVisible=true`. The keyboard writes directly to `demographics.name`, supports Space/Back/Clear/Next, accepts direct hardware/ADB keyevents while focused, caps at 80 characters, and does not auto-advance from partial text. Age is an intentional in-panel `ComposeSlider` from 0 to 100 that writes the same `demographics.age` export field and has no IME owner. Name Next/Enter hides the pop-out keyboard and visually focuses the Age slider. Keep the retired custom loose keyboard, hidden `EditText` bridge, UISet `SpatialTextField` demographics owner, Android `AndroidView(EditText)` Name/Age owners, Age numeric `EditText`, Age trigger-dial workaround, and integrated/in-questionnaire keyboard layout out unless the study design intentionally changes again. `tools/test-native-keyboard-contract.ps1` and `tools/validate-study.ps1` fail if mixed ownership or an integrated keyboard returns; `tools/run-quest-demographics-direct-keyboard-validation.ps1` proves raw keyevents type multi-character Name text directly into the APK, `tools/run-quest-demographics-directional-keyboard-export-validation.ps1` proves D-pad/Enter navigation through the pop-out keyboard into headset JSON/CSV export, and `tools/run-quest-demographics-keyboard-entry-validation.ps1` proves the app-owned keyboard command route plus Age slider clamp/value behavior.
- Current scripted questionnaire narration note: experimenter voiceover text should be peppered with dry science-nerd sarcasm, especially asides like serious researchers taking absurdly specific questionnaire history very seriously. Use the literal `... ` marker for interrupted trains of thought or self-corrections. Do not reveal the questionnaire's actual factor/subscale structure, scoring machinery, internal variable names, or hypotheses in participant-facing narration; keep those in researcher documentation/export metadata.
- Current speech-asset protocol: before generating or integrating any new participant-facing speech element, read `For-AI/speech-asset-protocol.md`. Runtime audio is centralized in `..\audio-assets\localized`: speech in `en_us` / `ja_jp` / `de_de`, shared cues in `shared\questionnaire_ui`, `shared\questionnaire_transition`, `shared\button_press`, and `shared\inactive`, and catalogue metadata in `manifest.json` plus `docs\audio-script-lookup-table.csv`. Do not add participant-facing audio back into `app\src\main\res\raw` or `app\src\main\assets\sfx`. German custom narration intentionally uses awkward mixed `du`/`Sie`; read `For-AI/german-localization-register-policy.md` before editing it. New localized speech must start in ignored `artifacts/`, promote approved MP3/scripts/transcripts into `..\audio-assets\localized`, update `..\audio-assets\localized\manifest.json`, add rows to `docs\audio-script-lookup-table.csv`, wire explicit Kotlin constants/log markers when runtime playback is needed, and validate with `tools\update-localized-audio-manifest.ps1`, `tools\validate-localized-audio.ps1 -RequireJapaneseAudio -RequireGermanAudio`, and `tools\validate-study.ps1`.
- Current pictographic note: the horizontal control is a distance-from-self visual axis. The VAS minimum thumb center aligns with the self pictogram center, the default VAS thumb positions align vertically with the default button depiction, and the closeness thumb and button marker share the same horizontal coordinate across the whole axis. Exports keep `feltCloseness0To100` as higher-is-closer and store visible distance separately as `selfButtonDistanceUnits`. Endpoint labels are `very close`/`very distant` and `small presence`/`large presence`.
- Current redness-note: the Button Experience task includes `How red did the button feel?`. Condition 1 starts with a VAS (`slightly red` to `very red`) and converts once to a seven-box Likert scale; condition 2 starts as Likert and converts once to VAS. Export both final values, `rednessScaleOrder`, the carried-forward closest analogue on both scales, and whether the participant changed away from that analogue after conversion. Keep Likert boxes inset/spaced from the VAS track so the exact correspondence is less visually obvious. The supplied changeover clips are active as `first_questionnaire_change` and `second_questionnaire_change_excuse`; participant runs play the full clips with transcript-synced visual micro-events (`supervisor_ping`, `seven_boxes_assemble`, `professional_warning`, `boxes_erased`, etc.) logged as `BRB_REDNESS_SCALE_CONVERSION_MICRO_EVENT`. Fast qkv replay logs the same cue `microTimeline` with `validationShortcut=true` and uses a short navigation cue so it does not wait through those clips.
- Current button input note: controller-contact remains the final physical proof source, but hand-tracked collider selects are accepted and exported as separate `hand_contact` provenance for usability. Hand tracking may use predictive visual preload for feel only: `BRB_BUTTON_HAND_IMPACT_PREDICTED` must remain `counted=false` and `sound=false`, aborted preload may emit `BRB_BUTTON_HAND_PRELOAD_RELEASE` with the same no-count/no-sound contract, and accepted press events still require ISDK contact/crossing evidence. The native press target is a seven-box `multi_box_cap` approximation with a source-level `ButtonContactLatch`; do not collapse it back to one broad box or a flat UI-only hit target.
- Current heartbeat visual note: heartbeat/RR flashes use `HeartbeatPulseDriver` while the original `BigRedButton.glb` remains the only visible button model at a fixed transform/scale (`BRB_BUTTON_GLOW_STABLE_SURFACE_READY`, `modelGlow=stable_idle_model_native_lights`). ECG/mock blinking changes only fixed native cap-surface point-light intensity; it must not swap visible GLB variants, change model visibility based on blink intensity, rescale, translate, rotate, or otherwise alter the button surface shape/placement. Retired generated GLB variants may remain under `app/src/main/assets/models/glow/` for provenance/reference, but they are not the participant-facing blink path. The native pulse envelope follows the Unity reference: 320 ms, `unity_ease_in_out_1_to_0`, 250 ms refractory, 16 frames at 20 ms. Heartbeat/ECG feedback must be glow-only, with geometric motion reserved for accepted physical button presses. No participant-facing transparent halo/canopy geometry should be used. The disabled 2D radial panel fallback (`MODEL_GLOW_PANEL_FALLBACK_ENABLED = false`) must not become the primary blink.
- Current press-motion note: accepted presses still count and play the press sound immediately, but the GLB `pressed` visual replay is guarded by `BUTTON_PRESS_MOTION_RESTART_GUARD_MS = 240L`, longer than both the 180 ms press cooldown and the 160 ms native clip, so rapid accepted presses defer/cancel visual restarts instead of snapping the animation. The hand-tracking path now records `pressMechanics` so preload mode, impact velocity, time-to-impact, confidence, lateral velocity, predicted lateral-at-impact, trajectory fit, approach angle, approach alignment, impact energy, virtual spring compression, damping ratio, estimated normal impulse, estimated peak force, estimated contact pressure, assumed contact patch area, compression peak, actuation travel/delay, snap-through travel/duration, bottom-out timing, release timing, and trigger evidence can be analyzed for publication. Force/pressure values are model-derived estimates from the virtual spring-damper and contact-area assumptions, not measured hand forces. Preserve `BRB_BUTTON_MODEL_ANIMATION`, `BRB_BUTTON_MODEL_ANIMATION_SCHEDULE`, `BRB_BUTTON_MODEL_ANIMATION_RESET`, `BRB_BUTTON_PRESS_MECHANICS`, and `BRB_BUTTON_PRESS_MECHANICS_PHASE`, run `tools/test-button-press-animation-stability.ps1` after changing press or glow visuals, and use `tools/run-quest-button-press-animation-stress.ps1` plus `tools/run-quest-hand-contact-physics-smoke.ps1` for short on-headset replay checks.
- Current literature/model note: `For-AI/hand-tracking-button-press-physics-model.tex` is the working publication catalogue for physically grounded hand-to-button press modeling. It documents the staged approach/contact/nonlinear compression/snap/bottom-out/release model, the HCI/haptics citation inventory, the seeded systematic-review protocol, Consensus seed queries, inclusion/exclusion criteria, extraction fields, evidence-to-mechanics mapping, publication analysis plan, manuscript hypotheses/claim boundaries, and the current Consensus MCP access limitation. The catalogue now includes button FD/FDVV work, impact activation, neuromechanics, visual-haptic simultaneity, audio-tactile/virtual-button timing, intentional binding/action-outcome delay, hand-object prediction, pseudo-haptic button/control surveys, virtual-hand deformation comparators, haptic proxy taxonomies, hand-based haptic VR surveys, wrist-haptic button/knob comparators, and machinery-control pseudo-haptics.
- Current signal-routing note: native Polar PMD ECG remains the primary physiological stream. The app now exports native threshold R-peak detector diagnostics and a disabled-by-default external/LSL signal CSV scaffold, but LSL is not active until an Android-compatible native library/JNI path is explicitly added and headset-tested.
- Current new-agent integration note: the public `New-Agent-Integration-Brief.md` is implemented here as a native contract, not as a Unity dependency. The JSON export contains `agentIntegrationProtocol`, and startup logs `BRB_AGENT_INTEGRATION_CONTRACT`; both state that questionnaires remain in-process, direct Polar PMD ECG/RR is active and brokerless, LSL stays disabled/diagnostic-only, external signals cannot satisfy the final press gate, and `controller_contact` remains the final participant proof.
- Polar note: raw Polar H10 ECG capture is now implemented through the PMD service, not only RR intervals. The client requests the minimum ECG MTU 70 first for low-latency packets, selects the highest advertised PMD ECG sample rate/resolution before falling back to H10 defaults, timestamps samples with nanosecond monotonic timing derived from PMD frame timestamps, and anchors `startedElapsedNs` immediately before `MediaPlayer.start()` with `BRB_CONDITION_AUDIO_START_ANCHOR ... anchor=pre_media_player_start`. Exports must include `*_ecg_timeseries.csv` with `elapsed_ns` plus audio-window start/end/duration columns, and each condition ECG window must be exactly `0..audioDurationMs` in milliseconds and `audioDurationMs * 1,000,000` in nanoseconds. The final physical validation gate now also requires real-Polar PMD ECG coverage, sequential sample indices, strictly increasing `elapsed_ns`, a median sample interval matching 130 Hz, no large sample gaps, and RR blink evidence in both the primary pulled export and the SideQuest-readable `ExperimentResults` mirror, then byte-compares the two export folders by file name, size, and SHA-256.

## First Checks

Run from the native app root:

```powershell
git -C D:\GithubVR\bigredbutton.institute status -sb
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-study.ps1 -SkipBuild
```

Use `rg` before broad file reads. Preserve unrelated user changes.

## Completion Rule For All App Changes

Do not treat an app/source change as finished after local-only validation. Every change intended for the native Quest app must be rebuilt into the APK, uploaded/installed on the connected Quest headset, and validated directly in-headset with the smallest relevant Quest gate before reporting the task complete. For participant-facing UI/layout changes, run a headset visual/panel smoke that captures the changed surface. For questionnaire/data-routing changes, run the fast Quest keyevent/export gate. For button-condition visuals, run visual-layout smoke. For controller-contact or live physiology changes, run the appropriate human/Polar hardware gate. If a Quest is unavailable, or headset validation cannot be run, say the task is not fully finished and list the exact missing headset gate.

For the strongest non-headset gate, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run-local-preflight.ps1
```

After local preflight, short Quest smoke suite evidence, and fast directional questionnaire/data evidence exist, refresh the current readiness report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-readiness-report.ps1
```

The readiness report intentionally requires `artifacts\qkv\<run>\quest-keyevent-questionnaire-validation-summary.json` to pass on the current APK hash, to have pulled the SideQuest-readable `ExperimentResults` JSON/CSV files, to report app-owned Name keyboard evidence, Age slider/no-IME evidence, panel-exit keyboard hide evidence, explicit `direction=enter` submit replay evidence, final prompt options-ready gating before replay, prior Big Red Button experience prompt/export evidence, and redness VAS/Likert conversion/export evidence, to report `exportMirrorMatched=true` with `export-mirror-comparison.json`, to prove the qkv ECG capture windows equal the instruction-audio durations at 130 Hz with exact millisecond and nanosecond window fields, and to prove the simulated RR driver produced exported blink rows plus runtime `BRB_ECG_BLINK`/`BRB_HEARTBEAT_FLASH` markers.

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
- Fast human hand-contact physics smoke: `tools\run-quest-hand-contact-physics-smoke.ps1`; this asks an operator to press with hand tracking and checks predictive preload logs plus accepted `hand_contact` mechanics evidence. It writes a smoke summary and invokes `tools\validate-hand-contact-physics-evidence.ps1` on the captured log/export artifacts; when export evidence is pulled, it also invokes `tools\analyze-hand-contact-press-mechanics.ps1` to produce `press-mechanics-analysis.json` and `press-mechanics-events.csv` for publication summaries. `tools\test-hand-contact-physics-evidence-validator.ps1` and `tools\test-hand-contact-press-mechanics-analysis.ps1` are the local behavioral tests for those evidence/analysis tools. This path is supplemental and does not satisfy the final controller-contact proof gate.
- Hand-contact physics operator handoff: `tools\write-hand-contact-physics-operator-handoff.ps1`; use it before a human hand-tracking smoke to bind the current APK hash, latest static validation, evidence-validator test artifact, mechanics-analysis test artifact, ADB readiness, and exact quick/export commands. The current handoff path is `artifacts\hand-contact-operator-handoff\handoff-20260617-032133\hand-contact-physics-operator-handoff.json`, status `ready_for_operator_hand_contact_physics_smoke`; it binds static validation `artifacts\local-validation\validation-20260617-032127.json`, evidence-validator test `artifacts\hand-contact-physics-evidence-tests\t-20260617-030145\hand-contact-physics-evidence-validator-test-summary.json`, mechanics-analysis test `artifacts\hand-contact-press-mechanics-analysis-tests\t-20260617-032022\hand-contact-press-mechanics-analysis-test-summary.json`, current APK SHA-256 `3308B3D49F569DED6AB25DFFF821277C9E59599A79257EF0DB65FBF8533A094C`, and ADB-ready Quest 3S serial `3487C10J0P01ZY`. This is not hardware evidence by itself.
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
