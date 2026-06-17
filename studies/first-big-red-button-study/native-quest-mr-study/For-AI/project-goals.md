# Project Goals

## Primary Goal

Build a standalone native Meta Quest 3 mixed-reality APK for the first Big Red Button cognitive experiment. The app should run without Unity and without a browser runtime.

The participant-facing Big Red Button stimulus must be a real packaged 3D model asset rendered in the native Quest scene. A procedural button may be used only as a temporary fallback, collision helper, or validation aid; it is not the final participant-facing stimulus.

The 3D button should face the participant as a seated, within-reach press target. Current placement uses the original 0.48 m reach distance, cap/contact center at `y=1.04`, and nominal seated eye height `y=1.28`, producing approximately 26.6 degrees downward viewing angle and 34.3 degrees apparent diameter.

The final participant interaction must recreate the original controller-based Big Red Button behavior from the Unity reference: participants physically press the 3D button with a Quest controller. Do not replace this with gaze selection, Android taps, keyboard input, a flat visible 2D button, or app-triggered automation. Invisible helper colliders or panels are acceptable only when they are aligned to the 3D model and driven by controller contact.

Hand-tracked pressing is now supported as an additional usability path for participants who press without the controller, but it must remain provenance-separated as `hand_contact`. It is not a substitute for the final controller-contact validation gate unless the study protocol is intentionally changed. Hand tracking may visually preload button compression from stable approach velocity, time-to-impact estimates, and lateral trajectory convergence toward the cap, but prediction alone must never count a press, play the press sound, or satisfy final proof.

Button press feedback currently plays a temporary CC0 placeholder sound on accepted presses and shows an old digital red press counter above the modeled button. Future final press-sound feedback should make the button movement trajectory match the selected button sound's audio characteristics. The final sound must be treated as a study stimulus, hash-locked, and validated before use in data collection.

One button/audio condition should be driven by actual Polar H10 RR events plus raw PMD ECG samples over BLE, and the other by a fixed simulated NeuroKit2 RR/ECG sequence. The source order must be counterbalanced from prior exports and randomly assigned only when prior counts are tied. The button should blink on each RR/R-peak event from the active source, and the raw ECG time series should be captured across the exact instruction-audio window using the highest advertised PMD ECG sample rate/resolution available from the sensor, with H10 defaults used only as fallback. The exported ECG window must be exactly `0..audioDurationMs` with nanosecond capture metadata and sample-level `elapsed_ns` values, anchored by a condition clock set immediately before `MediaPlayer.start()`.

## Participant Flow

1. Consent and demographics.
2. One-time transparent XR prior-experience prompt in the button/counter location: keep the 3D Big Red Button model and contact collider hidden, ask whether the participant has experience pressing big red buttons, store Yes/No plus timestamp, show humorous feedback, play the supplied pre-start instructions clip, then allow `Start experiment`. This prompt occurs only before condition 1 and never before condition 2.
3. Condition 1: Big Red Button shown in front of the participant in passthrough/MR while `first-big-red-button-vr-study-instructions-final.mp3` plays; controller-based physical pressing is active for the full track.
4. Post-condition 1 button experience task, stored as the pictographic closeness/presence/redness measure. Redness starts as VAS, then converts to seven Likert boxes after the first VAS selection.
5. Post-condition 1 neutral session experience ratings, stored as adapted presence questionnaire responses.
6. Post-condition 1 neutral additional time rating, stored as the Lost Opportunity visual analog scale.
7. Condition 2: Big Red Button shown in front of the participant in passthrough/MR while `first-big-red-button-vr-study-instructions-second-instructions-5-final.mp3` plays; controller-based physical pressing is active for the full track.
8. Post-condition 2 button experience task. Redness starts as seven Likert boxes, then converts to VAS after the first Likert selection.
9. Post-condition 2 neutral session experience ratings.
10. Post-condition 2 neutral additional time rating.
11. Local JSON, summary CSV, press-event CSV, ECG blink-event CSV, raw ECG time-series CSV, and session index export.

## Required Variables

- participant ID
- name
- age
- gender
- handedness
- consent flag
- consent signature field
- prior Big Red Button pressing experience answer (`yes`/`no`), boolean, timestamp, and display location metadata
- condition 1 and 2 button press counts
- condition 1 and 2 ECG source assignment and blink counts
- condition 1 and 2 ECG blink-event timing, source, RR interval, and heart-rate estimate
- condition 1 and 2 raw ECG time-series rows, including source, elapsed milliseconds and nanoseconds within the audio window, repeated audio-window start/end/duration fields, Unix/ISO timestamp, Polar sensor timestamp when available, microvolts, sample rate, frame/package metadata, and requested/negotiated MTU
- condition 1 and 2 press-event timing details
- condition 1 and 2 press input provenance, sufficient to distinguish real controller-contact presses from validation automation
- condition 1 and 2 hand-contact press counts, logged separately from controller-contact counts
- condition 1 and 2 hand-contact mechanics fields for publication analysis: prediction mode, impact velocity, time-to-impact estimate, preload lead time, confidence, lateral velocity, predicted lateral-at-impact, trajectory fit, approach angle, approach alignment, impact energy, virtual spring compression, damping ratio, estimated normal impulse, estimated peak force, estimated contact pressure, assumed contact patch area, compression peak, actuation travel/delay, snap-through travel/duration, bottom-out timing, release timing, visual-start offset, and trigger evidence
- condition 1 and 2 felt closeness
- condition 1 and 2 self-button distance units
- condition 1 and 2 felt button presence
- condition 1 and 2 button presence radius units
- condition 1 and 2 redness VAS 0-100 value
- condition 1 and 2 redness Likert 1-7 value
- condition 1 and 2 redness Likert descriptor
- condition 1 and 2 redness scale order (`vas_then_likert` or `likert_then_vas`)
- condition 1 and 2 adapted IPQ item scores, scored subscales, and total mean
- condition 1 and 2 `Lost Opportunity for better results quotient`

## Validation Target

Finish only when the standalone APK builds and the strongest available validation gates have evidence for:

- passthrough/MR launch path
- 3D model Big Red Button placement, including the human-facing seated visual-angle contract
- controller-based physical pressing of the 3D button, with accepted press counts matching logs and exports
- hand-tracking press feel support that uses predictive visual preload only for visual continuity, with accepted `hand_contact` rows requiring contact/crossing evidence and remaining supplemental to controller-contact proof
- one press-sound trigger per accepted button press; when the final sound replaces the placeholder, button cap motion should align to the sound's main transient/envelope
- PMD-aware Polar H10 validity status, where the first-menu green check requires HR/RR plus raw PMD ECG samples streaming at 130 Hz; real Polar physiology recorded in both conditions; counterbalanced real-vs-sham feedback assignment; and heartbeat-driven button blinking
- Polar PMD raw ECG capture/export at 130 Hz, with exported millisecond and nanosecond capture-window durations matching each instruction-audio duration
- questionnaire panel layout
- demographics intake using a visible app-owned pop-out Name keyboard panel that appears on Name focus, is separate from the questionnaire panel, and is placed by headset-centered radial visual angle: questionnaire on the central ray, keyboard on a neighboring left ray, both oriented toward the headset, close to the user without obstructing the questionnaire. The Name keyboard must keep direct hardware/ADB keyevent fallback; Age remains an in-panel `ComposeSlider` from 0 to 100, preserving `demographics.name` and `demographics.age` export values with Name Next/Enter and slider/Done input contracts.
- Button Experience redness scale conversion and export of both final VAS and Likert values
- fast directional questionnaire/data export validation on the current APK hash, including pulled `ExperimentResults` JSON/CSV files
- audio track playback and condition timing
- data export completeness
- export pull/readability from headset when a Quest is available, including both `BigRedButtonFirstStudyExports` and the SideQuest-friendly `ExperimentResults` mirror, with validation evidence that the mirror matches the primary export byte-for-byte
