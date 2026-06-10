# Workflow Lessons

## Native Quest MR Path

Quest natively supports mixed-reality overlays: enable system passthrough, then render app-owned 3D content in the same XR/spatial scene. Raw camera access is not required for this experiment because the app only needs the real room as background, not camera pixels for computer vision.

## Practical Stack Decision

Meta Spatial SDK is the pragmatic no-Unity path here:

- Kotlin app lifecycle and file export.
- `scene.enablePassthrough(true)` for MR background.
- Compose-backed spatial panels for demographics/questionnaires.
- Spatial entities/panels for the button stimulus.

Raw OpenXR with `XR_FB_passthrough` is possible, but it would require more rendering and input plumbing for the same study UI. Use raw OpenXR only if Meta Spatial SDK blocks a core requirement.

## Meta Spatial Visual/Input Porting Lessons

When translating Unity interaction assets, do not assume Unity collider/material primitives map one-to-one into Meta Spatial SDK. For the Big Red Button, a cap-shaped press target was practical as one centered `IsdkBoxCollider` plus six ring boxes, with a source-level latch to reproduce Unity's active-interactor debounce. For glow, MesmerPrism's Unity reference drives the button material itself: runtime tint interpolates from `0.82,0.22,0.22` to `1.0,0.72,0.72`, emission interpolates from black to `7.0,1.10,0.85`, and optional point lights sit close to the cap surface. Meta Spatial SDK 0.13 `Mesh` exposes the model URI and shader override, but not a Unity-like per-material handle for a loaded GLB renderer. The native participant-facing approximation is therefore GLB material variant swapping: keep the original model for idle and swap to `models/glow/BigRedButtonGlowLevel01.glb` through `32.glb` for progressively brighter/emissive cap materials, assisted only by small native point lights. The native pulse envelope now mirrors Unity's blink timing more closely: 320 ms, ease-in/out from peak to idle, and a 250 ms refractory. In headset screenshots, Unity's raw emission peak washes out in Meta Spatial, so keep the native variants tonemapped to a hot red/orange peak instead of white. Subtle metal-bezel warmth can help sell surface emission, but keep the dark base preserved; changing the base material reads like a different object rather than reflected light. Do not use transparent cap-shell, dome, halo, or canopy geometry for the participant-facing heartbeat glow. Retain flat Compose glow only as an explicitly disabled fallback.

## Validation Pattern

Use a runged validation ladder:

1. Static study contract validation.
2. APK build.
3. Quest install and foreground launch.
4. In-headset visual check for passthrough, button, and questionnaire panels.
5. Full run export pull.
6. Live Polar H10 PMD ECG smoke.
7. Physical input plus physiology export gate for actual Quest controller contact/press behavior and full-window real ECG evidence.

Do not treat ADB taps, Android keyevents, gaze dwell, keyboard input, or visible flat UI buttons as proof of the participant-facing controller press interaction.

When runtime exports are not available yet, use `tools/validate-export-schema.ps1 -Synthetic` only as a contract check. After a headset run, point the same script at the pulled `BigRedButtonFirstStudyExports` folder and validate real JSON/CSV output before claiming the data gate passed.

For this app, `brb.autoValidation` is the accepted no-human Quest flow gate. It must wait for real `MediaPlayer` completion for both MP3s and then pull/validate real app exports. Keep it separate from the physical input gate: app-triggered validation presses prove export/count plumbing, not controller contact with the modeled button.

Do not rerun the full real-duration autorun as a routine check. It takes about 10.5 minutes because it waits through both instruction tracks. It already passed once for the current app on Quest 3S `3487C10J0P01ZY` on 2026-06-09, with evidence in `artifacts/qav/20260609-170003`. Rerun it only when audio files, MediaPlayer condition timing, condition transitions, or export plumbing changed. For ordinary code/docs/layout/input changes, use exact audio hash/duration validation plus build/static/schema checks and a short Quest smoke.

If `adb` is not available on PATH, use the project-local Android platform-tools bundle first: `artifacts\toolchain\android-platform-tools\platform-tools\adb.exe`. This avoids slow recursive drive searches and was sufficient to reach Quest 3S `3487C10J0P01ZY` for the 2026-06-09 smoke suite.

Do not identify the main JSON export by excluding filenames containing broad words such as `summary`; those words can appear in participant IDs or generated test names. Select `brb_first_study_*.json` directly for the main JSON export, and select summary/press CSV files by their exact suffixes.

On Windows, avoid long `adb pull` destinations for exported study files because the generated session filenames are long. Current scripts pull each device file to a short `%TEMP%` path first, then move it into a shortened artifact directory such as `artifacts/qav/<runId>` or `artifacts/qpv/<runId>`.

For the physical gate, use `brb.physicalPressValidation` through `tools/run-quest-physical-press-validation.ps1`. This mode auto-starts the two conditions and auto-submits non-press questionnaire fields after real audio completion, but it never creates button presses. A human operator must press with a Quest controller, and the script checks logcat, JSON, and press-events CSV for `controller_contact`.

Before running the final physical gate, read `docs/physical-validation-operator-guide.md`. The physical script now writes `operator-checklist.txt` into each `artifacts/qpv/<runId>` folder, runs the live Polar H10 smoke first by default, prints live `c1Controller` and `c2Controller` counts while waiting, pulls both `BigRedButtonFirstStudyExports` and `ExperimentResults`, calls `tools/validate-export-schema.ps1` and `tools/validate-physical-press-evidence.ps1` on both pulled folders, and fails if button press evidence contains `auto_validation` sources or `controller_contact` rows marked as validation automation. It also fails if the real-Polar condition lacks 130 Hz PMD ECG rows covering the audio window, RR blink rows, sequential and strictly increasing high-resolution timing, PMD frame/package metadata, or the low-latency `requestedMtu=70` setup marker. Keep this strict: questionnaire autosubmission is allowed in hidden physical validation mode, but button presses must be human controller-contact presses and physiology evidence must come from a worn H10.

Treat the SideQuest-readable `ExperimentResults` folder as a first-class export target, not a convenience copy. Fast qkv validation and final physical validation should both pull and validate it, including raw ECG time-series files and controller-contact provenance, because experimenters will retrieve data from that folder in practice. Also byte-compare the pulled mirror against `BigRedButtonFirstStudyExports` by file name, size, and SHA-256; independently valid but divergent folders are not acceptable experiment evidence.

The app logs `BRB_CONDITION_PRESS_SOURCES` at every audio-condition end. This marker is intended for final physical-gate debugging: it reports total, controller-contact, interim-panel, scene-object-fallback, and automation counts for that condition.

Use `tools/test-physical-press-evidence-validator.ps1` when changing final-gate evidence logic. It creates synthetic clean and contaminated exports/logcat evidence; the clean case must pass and contaminated cases must fail. Current contaminated cases include automation, missing contact-select/source-summary evidence, missing real ECG samples, missing real blink rows, bad real sample rate, short ECG coverage, invalid PMD package metadata, and missing low-latency config.

Use `tools/run-local-preflight.ps1` as the strongest routine non-headset gate. It builds the APK, runs static study validation, exact audio validation, synthetic export schema validation, physical-evidence validator tests, and layout previews. It intentionally does not replace headset visual smoke or the human physical controller-contact/live-physiology export gate.

Use `tools/run-quest-controller-contact-smoke.ps1` before the slow physical export gate. It starts the same native contact path, waits only for a real `controller_contact` press, captures logcat/screenshot evidence, and force-stops the app. It is the right routine check for controller-collider regressions because it avoids another full audio wait.

The live Polar smoke, controller-contact smoke, and full physical validation scripts all write structured JSON summaries on failure as well as on pass. Short intentional failures under `artifacts/qpolar/<runId>`, `artifacts/qcs/<runId>`, or `artifacts/qpv/<runId>` are useful to prove script behavior and APK identity, but they are not participant evidence and cannot satisfy the live-H10 or physical-controller gates.

When `tools/run-quest-physical-press-validation.ps1` fails during its live Polar precheck, preserve the child `artifacts/qpolar/<runId>/quest-polar-h10-live-smoke-summary.json` path in the parent `artifacts/qpv/<runId>/quest-physical-press-validation-summary.json` as `polarPrecheckSummary`. This makes the final-gate failure auditable without guessing which H10 smoke attempt caused the full run to abort.

Use `tools/run-final-hardware-gates.ps1` for the final operator session when both a headset operator and worn Polar H10 are ready. It runs live Polar H10 PMD ECG smoke first, then the fast controller-contact smoke unless explicitly skipped, then the full controller-contact/live-H10 export validation with `-SkipPolarPrecheck` because the same wrapper has just proven live PMD ECG. It writes `artifacts/final-hardware-gates/<runId>/final-hardware-gates-summary.json`; a `-DryRun` summary proves only command construction and ordering, not hardware evidence.

`tools/write-readiness-report.ps1` records the latest final-wrapper dry run as `finalHardwareGateWrapperDryRunPass`, checks that it matches the current APK hash, and now requires it for software readiness. This is useful command-order evidence for handoff, but it must remain separate from the live H10 and physical controller-contact pass flags.

`tools/run-final-hardware-gates.ps1` now refreshes readiness and the machine-readable goal audit after dry runs, failures, and real passes unless `-SkipPostRunAudit` is supplied. Keep this behavior: a failed live-H10 or controller-contact attempt is still useful evidence when it is tied to the current APK and automatically rolled into readiness plus `goal-completion-audit.json`.

When chaining readiness and goal completion audits, pass the freshly generated readiness JSON explicitly to `tools/write-goal-completion-audit.ps1 -ReadinessJson <path>`. Relying on "latest readiness report" can race if reports are generated in the same second or another tool writes a report concurrently; the final hardware wrapper should fail its post-run audit rather than silently binding the goal audit to an older readiness report.

When a final hardware wrapper is writing its own post-run audit, readiness must be bound to that wrapper summary with `tools/write-readiness-report.ps1 -FinalHardwareGateSummaryPath <summary>`. Ordinary readiness generation should not blindly select the newest `artifacts/final-hardware-gates` folder, because a just-created failed or in-progress wrapper can have no validated post-run binding yet. Without the explicit override, readiness should select the latest dry-run wrapper summary that already has a passing `tools/validate-final-hardware-postrun-audit.ps1` artifact. This two-mode behavior lets a fresh wrapper bootstrap its own audit while keeping normal operator handoff immune to stale or half-written wrapper folders.

Use `tools/validate-final-hardware-postrun-audit.ps1` after a final hardware wrapper run when you need a compact machine-readable proof that the wrapper summary, post-run readiness report, and post-run goal audit agree. It checks that the goal audit's `readinessJson` equals the wrapper's `postRunAudit.readinessReport`, that readiness points back to the same final wrapper summary, that APK hashes match, and that a dry run does not allow completion.

Use `tools/test-final-hardware-postrun-audit-validator.ps1` when changing final-wrapper audit binding logic. It creates synthetic valid dry-run, valid real-pass, and valid incomplete-bootstrap chains, then confirms stale readiness links, goal/readiness status mismatches, dry-run completion allowance, incomplete-readiness completion allowance, APK hash mismatches, and failed post-run audit status are rejected. The incomplete-bootstrap case allows readiness `status=incomplete` to pair with goal-audit `status=incomplete_software_or_headset_gates` only when the wrapper/readiness/goal paths and APK hashes still agree. Keep this pattern for future wrapper validators: behavioral pass/fail cases catch evidence-chain regressions that static source checks can miss.

Keep the final wrapper post-run audit chain as an explicit software requirement in `tools/write-goal-completion-audit.ps1`. Readiness can check `finalHardwarePostRunAuditValidatorTestPass` and `finalHardwarePostRunAuditValidationPass`, but the requirement-level audit should also expose a proven `final_hardware_postrun_audit_chain` row so a close-out review can see that wrapper/readiness/goal-audit binding was verified before software is called proven.

Use `tools/write-final-hardware-operator-handoff.ps1 -RefreshAudit -RequireReady` immediately before a human/H10 operator session. It refreshes readiness, writes a goal audit against that exact readiness JSON, and emits a concise `artifacts/final-operator-handoff/<runId>` JSON/Markdown packet with the APK hash, audit-chain checks, missing external gates, and final wrapper command. Treat status `ready_for_operator_external_gates` as permission to start the human hardware gates, not as evidence that live Polar H10 or controller-contact pressing has passed.

Use `docs/completion-audit.md` as the close-out checklist. It separates proven local/headset evidence from the final unproven physical controller-contact/live-physiology export gate, so future agents do not accidentally treat no-human autorun evidence as physical input or real-H10 evidence.

The readiness report status is allowed to become `complete` only when software/headset/qkv gates pass on the current APK, standalone live Polar H10 PMD ECG smoke passes, and the full physical controller-contact/live-H10 export validation passes. A passing local preflight or qkv run is not enough to close the goal.

Participant-facing questionnaire UI should read like task instructions, not methods text. Do not show labels such as "Adapted IPQ", "pictographic scale", "Lost Opportunity quotient", logged variables, scoring purpose, or instrument rationale on headset panels. Keep those names in docs/export metadata for researchers, and validate this split with `tools/validate-study.ps1`.

For Quest text entry, use the native movable system keyboard when participants expect a close keyboard panel they can reposition or exit. The custom loose keyboard panel was removed for demographics because it added another interaction surface and drifted from native keyboard expectations. Keep Name and Age as real editable `TextField`s, use `KeyboardType.Text`/`KeyboardType.Number`, and call `InputMethodManager.restartInput(...)` on focus retargets so switching from Name to Age or back refreshes the visible keyboard mode. Validate this with `tools/test-native-keyboard-contract.ps1`, `BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT`, `BRB_SOFT_KEYBOARD_REQUEST`, `BRB_SOFT_KEYBOARD_SWITCH`, and qkv comparisons for text/numeric mode plus text-to-number retarget evidence. The native keyboard contract should fail if `useLooseKeyboard`, `requestLooseKeyboard`, `LooseKeyboard`, or `BRB_LOOSE_KEYBOARD` returns to the activity.

Quest visual smoke can be blocked by a previously foregrounded OpenXR app even when `am start` prints success. `tools/run-quest-visual-layout-smoke.ps1` now inspects focused/resumed activity lines after launch; if a non-Oculus package such as `com.example.rustyxr.opengles` is still foreground, it force-stops that package once and relaunches the Big Red Button app before waiting for `BRB_BUTTON_SPATIAL_LAYOUT`. Keep this pattern for future headset smoke scripts that depend on immersive foreground focus.

For compact VR demographics panels, make no-scroll a source-level contract. Keep the intake screen inside the fixed 1180x820 panel by tightening header/body text, choice-row heights, signature-pad height, and the start button height. Use local layout previews for clean readability and headset panel smoke for gaze-line placement/glitch behavior.

For pictographic closeness/presence tasks, separate visible geometry from exported meaning. The visible horizontal control should be a distance-from-self axis: the self marker anchors the left/start position, moving right places the button farther away, and the slider thumb and button marker move together. Exports can still keep `feltCloseness0To100` as higher-is-closer for analysis, with `selfButtonDistanceUnits` storing the visible distance. Validate both the source mapping and qkv expected-vs-observed values after flipping an axis.

When a task deliberately converts between response formats, store both final answers and the order instead of overwriting one with the other. The redness task uses `rednessVas0To100`, `rednessLikert1To7`, `rednessLikertDescriptor`, and `rednessScaleOrder`, and qkv validation compares both conversion directions. A missing conversion audio asset should be represented by a dedicated placeholder cue/log marker so the behavior remains testable until the real clip is supplied.

For heartbeat-driven button visuals, prefer model-shaped warm emission over a flat overlay. In this project, the current accepted workaround for the lack of loaded-GLB material mutation is 32 opaque GLB material variants plus small native surface lights, not transparent Compose or mesh halo overlays. Keep `BRB_HEARTBEAT_FLASH` as timing evidence and inspect a real headset screenshot for gross framing.

For hand tracking, add it as provenance-separated supplemental input, not as an undocumented replacement for the controller path. `IsdkSystem.getHandForPointerEvent(event)` can distinguish hand-tracked selects; log/export those as `hand_contact`, keep `controller_contact` separate, and preserve the final hardware gate unless the protocol explicitly changes.

Use `tools/run-quest-panel-smoke.ps1` for routine headset evidence of demographics styling, the first Button Experience panel, and questionnaire intro/glitch markers. This hidden mode must not start audio, start a condition, or export data; it exists so panel/glitch regressions can be checked without another full audio wait.

Use `tools/run-quest-visual-layout-smoke.ps1` for routine headset evidence of the in-condition modeled button and the seated visual-angle contract. It launches hidden physical-validation mode, waits only for condition 1 plus `BRB_BUTTON_SPATIAL_LAYOUT`, captures a screenshot/log, and force-stops before full audio completion. It does not replace the human controller-contact smoke or physical export gate.

When a short headset script clears logcat before launch, make sure the required marker is emitted after the relevant runtime transition, not only during early scene setup. `BRB_BUTTON_SPATIAL_LAYOUT` is intentionally logged at each condition start as well as scene setup so `run-quest-visual-layout-smoke.ps1` can verify the current run.

When headset smoke scripts filter logcat, always create the filtered evidence file even if no lines match, and keep a full-log fallback. A 2026-06-10 visual-smoke rerun captured the screenshot successfully but failed because `Select-String | Set-Content` produced no `logcat-filtered.txt`; the script now writes `logcat-full.txt`, always writes `logcat-filtered.txt`, and falls back to full log parsing before deciding the runtime marker is missing.

Do not treat every `AndroidRuntime` logcat line as fatal on Quest. Shell helper commands can emit benign `AndroidRuntime` startup/shutdown lines. The validation scripts should fail on `FATAL EXCEPTION` or `E/AndroidRuntime`, not bare `AndroidRuntime`.

Use `tools/run-quest-smoke-suite.ps1` when a Quest is attached and you need the strongest short non-human headset gate. It runs visual-layout smoke plus panel/glitch smoke and writes a combined suite summary. It still does not prove physical controller-contact pressing.

Use `tools/run-quest-keyevent-questionnaire-validation.ps1` to validate questionnaire passability/data logging without waiting through full audio. It launches `brb.keyeventValidation`, which shortcuts the instruction-audio wait but drives bounded up/down/left/right/enter-equivalent commands through the app's `handleControllerDirection()` and submit route, then pulls both `BigRedButtonFirstStudyExports` and `ExperimentResults`, compares expected-vs-observed JSON/CSV values, and writes `export-mirror-comparison.json`. ADB `input keyevent` did not reliably reach Meta Spatial SDK panels in immersive mode, so do not treat raw ADB keyevents as the proof transport for questionnaire passability; use the app-side directional replay markers and export comparisons. The qkv summary records APK SHA-256/size, native keyboard text/numeric mode and text-to-number retarget markers, panel-exit keyboard hide markers, explicit `direction=enter` submit replay markers, redness VAS/Likert conversion markers and exported values, `exportMirrorMatched`, ECG capture-duration comparisons, ECG sample-rate comparisons, exact ECG window comparisons (`0..audioDurationMs` plus `audioDurationMs * 1,000,000` ns), and simulated RR blink proof (`ECG sources counterbalanced complement`, `simulated ECG blink rows match JSON count`, `simulated ECG blink runtime marker observed`, `simulated heartbeat visual flash observed`, and simulated time-series row-count equality). `tools/write-readiness-report.ps1` fails software readiness unless the latest qkv run passed on the current APK hash, pulled the expected `ExperimentResults` files, proved the export mirror byte match, proved the ECG capture windows equal the instruction-audio durations at 130 Hz in both milliseconds and nanoseconds, proved native keyboard text/numeric mode and retarget evidence, proved redness conversion/export evidence, and proved the simulated RR driver produced exported blink rows plus runtime flash markers.

When qkv combines multiple logcat snapshots, a single runtime line may appear many times in `$logText`. For "shown once" checks, count unique matching log lines rather than raw regex matches over the concatenated snapshots. The prior Big Red Button experience prompt validation uses this pattern so repeated snapshots do not look like repeated UI display.

The final hardware dry-run wrapper can refresh APK/readiness/goal-audit binding after software-only changes, but the pre-run operator handoff may exit nonzero while external live-H10/controller-contact gates are still incomplete. If the goal is only to refresh a dry-run post-run audit chain for local preflight, run `tools/run-final-hardware-gates.ps1 -DryRun -SkipPreRunHandoff`; this still does not count as hardware evidence.

When representing the Big Red Button inside 2D questionnaire panels, do not fall back to a generic red oval. Use an asset rendered from the same `BigRedButton.glb` model and center the visual exactly on the circle center. The current thumbnail is generated by `tools/create-pictographic-button-thumbnail.ps1`, which renders the GLB geometry/materials directly instead of cropping a stale headset screenshot.

For questionnaire transition sounds, preserve the supplied glitch assets and keep them separate from the study instruction MP3s. The current transition assets are `app/src/main/res/raw/questionnaire_intro_glitch.mp3` and `app/src/main/res/raw/questionnaire_outro_glitch.mp3`; they drive a blue software-failure style overlay while panels appear/disappear. If these assets change, update provenance and hashes in `tools/validate-study.ps1`.

For questionnaire/control feedback sounds, keep cues short and separate from study instruction audio. Current cues are `ui_choice_blip.wav`, `ui_navigation_blip.wav`, and the placeholder button press asset `sfx/button-press-placeholder-kenney-bong.ogg`. Static validation hash-locks these assets and checks active playback hooks.

For Polar H10 integration on native Quest, use both layers now: the standard BLE Heart Rate Service supplies HR/RR events for heartbeat blinking, and the Polar PMD service supplies raw ECG samples for waveform export. Relevant UUIDs are Heart Rate Service `0000180d-0000-1000-8000-00805f9b34fb`, Heart Rate Measurement `00002a37-0000-1000-8000-00805f9b34fb`, PMD Service `fb005c80-02e7-f387-1cad-8acd2d8df0c8`, PMD Control Point `fb005c81-02e7-f387-1cad-8acd2d8df0c8`, and PMD Data `fb005c82-02e7-f387-1cad-8acd2d8df0c8`. ECG PMD frames use a 10-byte header and 3-byte little-endian signed microvolt samples at 130 Hz on Polar H10.

The app requests `BluetoothGatt.CONNECTION_PRIORITY_HIGH` and starts with the minimum ECG MTU 70 for the user's low-latency/small-packet requirement. Polar BLE SDK issue guidance notes that MTU 70 yields the smallest ECG packet size, about 19 samples at 130 Hz; if the PMD control point returns invalid MTU, the client retries larger fallback MTUs. For ECG sample settings, parse the PMD measurement settings response and select the highest advertised sample rate and resolution, falling back to H10 defaults of 130 Hz and 14-bit only when settings are unavailable. Keep this behavior unless headset/Polar validation shows a better latency-throughput tradeoff.

The raw ECG export is windowed to condition audio playback. Anchor `startedElapsedNs` immediately before `MediaPlayer.start()` and log `BRB_CONDITION_AUDIO_START_ANCHOR ... anchor=pre_media_player_start`; otherwise the real PMD stream can be shifted a few milliseconds late relative to the instruction audio. Real Polar samples are clipped to `0..audioDurationMs` and exported as observed; do not fabricate missing real samples to make counts match expected. Simulated ECG should generate the expected 130 Hz count for the exact MP3 duration. Validators should require `ecgCaptureDurationMs == audioDurationMs`, `ecgCaptureDurationNs == audioDurationMs * 1,000,000`, `ecgAudioWindowStartMs == 0`, `ecgAudioWindowEndMs == audioDurationMs`, `ecgSampleRateHz == 130`, the dedicated `*_ecg_timeseries.csv`, per-sample `elapsed_ns`, repeated audio-window columns in the CSV, and per-condition expected/observed sample counts. The final physical validator currently requires at least 95 percent real-Polar sample coverage, requested MTU 70 evidence, first/last samples close to the audio-window boundaries, sequential sample indices, strictly increasing `elapsed_ns`, a median sample interval shaped like 130 Hz, and no large sample gaps; lower coverage or coarse/non-monotonic timing should be treated as a data-quality failure, not silently accepted.

Use `tools/run-quest-polar-h10-live-smoke.ps1` for real H10 proof. It launches the normal intake screen and watches `BRB_POLAR_H10_STATUS`; the gate passes only with detection, connection, PMD readiness, `ecgStreaming=true`, nonzero raw ECG samples, and `ecgSampleRateHz=130`. A simulated ECG export or an app build/static pass is not evidence that a real H10 streamed into the headset.

For simulated heartbeat/RR stimuli, package a fixed CSV asset and hash-lock it. The current asset is `app/src/main/assets/ecg/neurokit2_simulated_rr_intervals_ms.csv`, generated from NeuroKit2, and validation expects SHA-256 `80D612CEC91C511471F19347C0B76A997FAF0E4AB785E2003B10179C819801C1`.

When adding new event streams, export them both in JSON and in a dedicated CSV. The ECG blink stream is written to `*_ecg_blink_events.csv`, and the raw ECG waveform stream is written to `*_ecg_timeseries.csv`; `tools/validate-export-schema.ps1` and the fast Quest keyevent validation both require these exports.

## Asset Handling

Avoid duplicating large study audio inside the app source tree. The Gradle source set should package the existing files from `../audio-assets/final` directly.

Treat study audio as immutable stimuli. For this study, validate both exact hash and exact duration before claiming an APK is current:

- condition 1 SHA-256 `A3767727AE935BE2455282F52C4765833DA9C04F95EDA81BA0354C7E1CE4F0C6`, duration `300.773878` s
- condition 2 SHA-256 `E52E53640DF5398FEC3DFE328877CBE429EDD3F5D3AB60E5A19FB1C6EBAD48A7`, duration `325.590204` s

The model asset from the related Big Red Button repos established the interaction contract, but the old low-poly/unlit sample was not visually realistic enough in native passthrough. The current app packages `app/src/main/assets/models/BigRedButton.glb`, generated by `tools/create-realistic-button-model.ps1` as a smoother GLB with a glossy red cap, dark base, metal bezel, and a `pressed` animation.

For model validation, do not rely on filename or hash alone. `tools/validate-study.ps1` now parses the GLB JSON and checks mesh/material counts, smooth-detail vertex/triangle counts, the `button` node, the `pressed` animation, and scaled dimensions against the collider envelope.

For interaction layout validation, preserve the seated tabletop geometry: button cap/contact center at `y=1.04`, nominal seated eye line `y=1.28`, and `z=0.48` in front of the participant. This computes to about 26.6 degrees downward and 34.3 degrees apparent diameter, which keeps the top-facing 3D button visible and reachable. The app logs `BRB_BUTTON_SPATIAL_LAYOUT`, and the static validator recomputes these angles from source constants.

Short button press sounds must be separate assets, never baked into the long instruction MP3s. The staged placeholder is `app/src/main/assets/sfx/button-press-placeholder-kenney-bong.ogg` from Kenney Interface Sounds, licensed CC0. Do not wire it into data-collection behavior until the press path, sound timing, export fields, and validation checks are implemented.

For future audio-motion matching, analyze the final sound envelope first, then align the GLB `pressed` animation or native keyframe motion so maximum button depression occurs at the main transient peak.

Model facts to preserve:

- expected SHA-256: `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`
- runtime URI: `apk:///models/BigRedButton.glb`
- scale: `16.0f`
- current origin: `x=0`, `y=0.82`, `z=0.48`
- current shader handling: the model entity does not set `defaultShaderOverride = SceneMaterial.UNLIT_SHADER`; preserve the GLB/material PBR path so the button does not flatten into a red blob

Procedural meshes are acceptable only as disabled fallback/collision helpers, and any such helper must be invisible or clearly subordinate to the model. Do not restore the visible circular Compose button. The current Compose panel is only a transparent interim press target; the final behavior must be driven by Quest controller contact with the modeled button or an aligned invisible helper collider.

## Reusing The Existing Button Repo

The old Unity repo's complex collider code should not be copied into the native app. Port only semantics that affect the experiment contract:

- center/recenter the button in front of the viewer through the Spatial SDK view origin when a condition starts
- keep the button at the old runtime's reachable 0.48 m distance
- require participants to physically press the 3D button with a Quest controller, matching the original controller-based interaction
- align any invisible native helper collider to the 3D button cap/pressable area
- suppress contact during the first 350 ms of a condition
- accept at most one press every 180 ms
- log suppressed presses separately from accepted `BRB_BUTTON_PRESS` events

Current native contact implementation:

- `IsdkBoxCollider` is attached to an invisible entity aligned with the button cap.
- `IsdkSystem` pointer observer filters events to the collider entity.
- Only `PointerEventType.Select` with `InteractionEventSourceBehavior.COLLIDER_HOVER_CONTACT_ACTUATE` is accepted as `controller_contact`.
- Every accepted press carries input provenance in JSON/CSV exports so autorun presses remain distinguishable from real controller-contact presses.
