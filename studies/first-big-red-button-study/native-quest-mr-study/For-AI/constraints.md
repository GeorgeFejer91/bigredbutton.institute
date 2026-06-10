# Constraints

## Hard Constraints

- Do not use Unity.
- Do not convert the experiment into a website or browser-only app.
- Keep this as a native Meta Quest 3 MR/XR app.
- Keep the app inside `studies/first-big-red-button-study/native-quest-mr-study`.
- Keep participant data local to the headset.
- Save JSON and CSV exports from the installed APK itself.
- Final participant-facing button presses must be made by physically pressing the 3D button with a Quest controller, matching the original controller-based interaction design. Gaze selection, ADB input, Android taps, keyboard shortcuts, and visible flat 2D buttons are not valid final participant input paths.
- Final completion requires both real controller-contact evidence and live Polar H10 PMD ECG evidence in the exported full run. A press-only physical run or a simulated ECG export is not enough unless the user explicitly removes the physiology requirement.
- Do not commit generated APKs, build folders, local validation artifacts, screenshots, pulled exports, headset logs, or local machine-specific SDK paths.

## Architecture Constraints

- Use passthrough as the background. The app does not need raw camera pixels just to place a button over the real room.
- The preferred app stack is Meta Spatial SDK with Kotlin and Compose panels because it supports passthrough, spatial entities, and 2D panels without Unity.
- The participant-facing Big Red Button stimulus must be a native 3D model asset, preferably converted from the existing Big Red Button repo assets into a Quest-friendly runtime format. Do not rely on procedural dome/cylinder geometry as the final visible stimulus.
- The participant-facing press mechanism must be controller-contact based. A simple invisible hit surface or collider may be used if Meta Spatial SDK input requires it, but it must be spatially aligned with the 3D model and must not appear as a separate 2D button.
- The button must remain a human-facing seated interaction target. Current geometry is `z=0.48`, cap/contact center `y=1.04`, nominal seated eye height `y=1.28`, approximately 26.6 degrees downward and 34.3 degrees apparent diameter. Do not rotate, move, or rescale the model/collider without updating and rerunning the spatial-layout validation.
- The Big Red Button should be shown continuously during each condition audio track.
- The two final MP3 audio files are source-of-truth study stimuli. Do not edit, convert, normalize, trim, or re-encode them. The app packages byte-identical copies through generated Gradle asset staging only.
- Button press sound feedback must remain separate from the instruction MP3s. The current placeholder cue is packaged as its own short asset and plays only on accepted button presses. When the final sound is selected, hash-lock it and revalidate sound trigger behavior.
- Questionnaires should appear as 2D pop-up panels in the same XR session after each condition.
- Questionnaire panels should spawn in the participant's current gaze line. Current contract: reset view origin immediately before showing the panel and place it at `x=0`, `y=1.52`, `z=1.55`; log `BRB_QUESTIONNAIRE_PANEL_LAYOUT placement=current-gaze-line`.
- Demographics text entry must use the native Quest/system keyboard as the only participant text-entry path, not a custom/embedded keyboard inside the questionnaire panel. The system keyboard is participant-movable/closable and appears near the user; the app must keep the central questionnaire in gaze line, request text mode for Name, request numeric mode for Age, force `InputMethodManager.restartInput(...)` on field retargets, and sanitize age input to digits/max three characters. Keep `BRB_SYSTEM_KEYBOARD_FIELD_CONTRACT`, `BRB_SOFT_KEYBOARD_REQUEST`, `BRB_SOFT_KEYBOARD_SWITCH`, and `BRB_SOFT_KEYBOARD_HIDE` markers as lifecycle evidence. `tools/test-native-keyboard-contract.ps1` should fail if `useLooseKeyboard`, `requestLooseKeyboard`, `LooseKeyboard`, or `BRB_LOOSE_KEYBOARD` reappears in the activity.
- Participant-facing questionnaire panels must not name psychometric instruments, explain researcher hypotheses, show internal variable names, or expose scoring purpose. They should give only the instructions needed to answer the current task. Keep instrument names, scoring notes, adapted-IPQ rationale, and variable mappings in documentation, validation, and export metadata.
- The demographics/intake panel should preserve the Big Red Button Institute visual language: warm paper background, editorial serif title, red accent rule, and restrained bordered fields.
- Participant ID must be assigned under the hood, not typed by the participant. Gender must be a four-option choice: `male`, `female`, `other`, `prefer_not_to_say`. Handedness must be a three-option choice: `left`, `right`, `ambidextrous`.
- The button experience task must represent the button using the same 3D Big Red Button visual identity as the interaction stage. The current 2D panel uses a thumbnail rendered directly from `BigRedButton.glb`; keep it centered on the presence-circle center.
- The button experience task's horizontal control is a distance-from-self visual axis: the left end starts at the self marker, moving right places the button farther away, and the slider thumb and button marker must move in the same direction. Preserve the export semantics where `feltCloseness0To100` means higher is closer, and use `selfButtonDistanceUnits` for the visible distance.
- The button experience task must include clear endpoint labels: closeness `very close` to `very distant`, presence `small presence` to `large presence`. It must also include the redness response: condition 1 VAS first then seven-point Likert after the first VAS selection, condition 2 Likert first then VAS after the first Likert selection. Always export both final redness values and the scale order.
- The visible button should read as a realistic Big Red Button, not a low-poly red blob. Preserve the smooth GLB model and do not force its runtime material through the unlit shader path.
- Heartbeat/R-peak flashes should read as warm surface emission from the button body, not as a flat 2D halo. Prefer model-shaped amber/red/core glow layers or a true emissive material path if the native runtime exposes one safely.
- During button/audio conditions, keep the old digital red press counter above the modeled button and drive it from the accepted condition press count.
- Polar H10/RR and raw ECG support is part of the study protocol. The intake screen must show a PMD-aware signal validity status: the green check means HR/RR plus raw PMD ECG samples are streaming at 130 Hz, while HR/RR-only detection remains a waiting state. One condition must use `real_polar_h10`, and the other must use `simulated_neurokit2`; order is counterbalanced from prior exports and randomized only on ties. Real Polar capture should use the PMD ECG stream, select the highest advertised PMD ECG sample rate/resolution before falling back to H10 defaults, timestamp samples through PMD frame nanosecond timing, anchor the condition clock immediately before `MediaPlayer.start()`, and request high BLE connection priority plus the minimum ECG MTU 70 strategy with larger fallbacks only after PMD invalid-MTU responses. The final full-run validator must reject real-Polar conditions with missing or badly incomplete ECG time-series coverage, non-exact audio-window metadata, or missing requested-MTU-70 evidence.
- Questionnaire panel intro/outro transitions use the supplied `intro.mp3` and `outro.mp3` assets packaged as `questionnaire_intro_glitch.mp3` and `questionnaire_outro_glitch.mp3`. Both transitions should look like blue software-failure/glitch screens and must be hash-locked.
- Button pressing must be disabled or hidden during questionnaires.
- Locomotion should remain disabled during the study.

## Data Constraints

- Use stable ASCII variable names in CSV exports.
- Export all raw answers and scored values needed to audit derived scores.
- Press-event CSV must include every button press with condition number, press index, elapsed milliseconds, Unix time, and ISO timestamp.
- Press-event JSON/CSV must include input provenance so real `controller_contact` presses can be separated from `auto_validation`, `transparent_panel_interim`, and fallback sources.
- ECG protocol JSON must include assignment order, per-condition source, simulated RR asset metadata, and Polar H10 status snapshot.
- Summary CSV must include ECG assignment order, Polar H10 status fields, and each condition's ECG source and blink count.
- ECG blink-event CSV must include every exported blink event with condition number, blink index, source, elapsed milliseconds, Unix time, ISO timestamp, RR interval, and heart-rate estimate.
- Raw ECG time-series export must include every stored sample with condition number, sample index, source, elapsed milliseconds and nanoseconds within the condition-audio window, repeated audio-window start/end/duration columns, Unix time, ISO timestamp, sensor timestamp in nanoseconds when available, microvolts, sample rate, frame index/type, package size, requested MTU, and negotiated MTU.
- The exported ECG capture window duration must equal the actual instruction-audio duration for each condition in both milliseconds and nanoseconds: `ecgAudioWindowStartMs == 0`, `ecgAudioWindowEndMs == audioDurationMs`, `ecgCaptureDurationMs == audioDurationMs`, and `ecgCaptureDurationNs == audioDurationMs * 1,000,000`. Do not fabricate missing real Polar samples to force an exact count; instead export the raw samples observed inside the exact window plus expected/sample-count metadata. Simulated ECG should generate the expected 130 Hz sample count for the audio duration.
- Final-gate real Polar evidence must include one `real_polar_h10` condition, 130 Hz sample rate, real ECG rows in `*_ecg_timeseries.csv`, RR blink rows in `*_ecg_blink_events.csv`, PMD frame/package/requested-MTU metadata, requested MTU 70 evidence, low-latency setup evidence, sequential sample indices, strictly increasing `elapsed_ns`, a median sample interval matching the 130 Hz rate within tolerance, and no large sample gaps. The current validator threshold is at least 95 percent of expected 130 Hz samples with first/last samples near the audio-window boundaries.
- Summary CSV must include one row per completed session.
- Summary CSV and JSON must include condition-level redness fields: VAS 0-100, Likert 1-7, Likert descriptor, and scale order.
- JSON export must include instrument/item metadata and adapted IPQ item wording.
- Export completed sessions both to `BigRedButtonFirstStudyExports` and to a SideQuest-friendly `ExperimentResults` folder under the app's external files directory.
- Any final export validation must validate both export folders and byte-compare their file names, sizes, and SHA-256 hashes, because `ExperimentResults` is the practical SideQuest retrieval path for experimenters.

## Psychometrics Constraint

The presence questionnaire is an adapted Igroup Presence Questionnaire. Do not claim the adapted wording is itself validated. In methods language, call it an adapted IPQ or adapted presence questionnaire.

## Existing Button Mechanism Constraint

The sibling repo `D:\GithubVR\the-big-red-button-institute` contains the original Unity button behavior. Reuse study-facing semantics from it, but do not import a Unity dependency:

- reachable distance target: 0.48 m in front of the head
- startup contact suppression: 0.35 s
- press cooldown: 0.18 s
- button press events should be logged only during the audio condition stage
- presses should originate from controller contact with the modeled button or its aligned invisible helper collider; app-triggered validation presses must be clearly marked and cannot satisfy the physical input gate
- hand-tracked collider selects may be accepted for participant usability, but must be logged/exported as `hand_contact` separately from `controller_contact`. Unless the protocol changes, final physical proof still requires controller-contact evidence.

## 3D Model Requirement

The final visual target is a modeled Big Red Button object in front of the participant. Keep the original press timing and logging semantics, but back the visible stimulus with a packaged 3D asset. If collision/input requires a simple invisible or low-detail helper surface, document it clearly and keep it aligned with the model.

The final interaction target is the modeled button itself, not a questionnaire-style panel. Preserve the feeling that the participant reaches out with the controller and presses the button in space.

## Press Sound Placeholder

`app/src/main/assets/sfx/button-press-placeholder-kenney-bong.ogg` is a temporary Kenney Interface Sounds CC0 placeholder. It is active as button press feedback, but it is not the final reviewed study stimulus. Future agents should read `docs/button-press-sound-and-motion.md` before replacing it or changing the button motion timing.
