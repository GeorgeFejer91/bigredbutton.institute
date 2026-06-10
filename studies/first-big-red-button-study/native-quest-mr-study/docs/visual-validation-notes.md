# Visual Validation Notes

Latest visual inspection: 2026-06-10 13:27.

## Fresh Headset Evidence

- Quest smoke suite: `artifacts/quest-smoke-suite/20260610-132347/quest-smoke-suite-summary.json`
- In-condition button screenshot: `artifacts/quest-visual-layout-smoke/20260610-132347/button-condition-screenshot.png`
- Demographics panel screenshot: `artifacts/quest-panel-smoke/20260610-132413/demographics-panel.png`
- Button Experience panel screenshot: `artifacts/quest-panel-smoke/20260610-132413/pictographic-panel.png`
- Current APK SHA-256 for this evidence: `55E3B082077BD55D939D1610E5FEC7AC56641B8FA62C201804AEE322CC951C2A`

Observed state:

- The headset screenshot shows passthrough behind the stimulus, with no virtual room around the participant.
- The 3D Big Red Button is centered in front of the participant, fully visible, and appears as a modeled dome/button object rather than a flat 2D button.
- The top cap is visible from a downward seated interaction angle. Runtime evidence reports `facingParticipant=true`, `downwardAngleDeg=26.6`, and `angularDiameterDeg=34.3`.
- The old digital red press counter is visible above the 3D button and uses a transparent passthrough background.
- The demographics panel spawns in the headset view with the Big Red Button Institute-style paper/red/serif aesthetic. Participant ID is not shown; gender is four-choice, handedness is three-choice, and the signature pad is a large pointer drawing field.
- The Button Experience panel spawns in the headset view with the same-button pictographic task; local preview evidence confirms the button thumbnail is centered in the presence circle, circle boundaries are thick, and closeness/presence/redness controls are visible.
- Current panel screenshots were captured during the blue glitch transition, so the aggressive blue stripe/tear overlay is visible and partly obscures text. Treat them as headset placement/glitch evidence, with local previews as the clearer layout evidence.
- The native Quest/system keyboard is an OS-managed surface, not a custom Compose panel. It is validated by qkv log evidence and the local native-keyboard preview rather than by a detached in-app keyboard screenshot.

## Fresh Local Preview Evidence

- Latest local preview folder: `artifacts/layout-previews/preview-20260610-132626`
- Native keyboard preview: `demographics-native-keyboard-preview.png`
- Button preview: `button-layout-preview.png`
- Demographics preview: `demographics-panel-preview.png`
- Button Experience preview: `pictographic-panel-preview.png`
- Session Experience preview pages: `ipq-panel-preview-page-1.png`, `ipq-panel-preview-page-2.png`
- Additional Time preview: `lost-opportunity-panel-preview.png`

Observed state:

- Local previews show the digital button counter, PMD-aware Polar H10 ECG-ready strip, expanded signature pad, and no obvious overlapping controls or clipped text.
- The native keyboard preview documents the central questionnaire plus OS-managed movable Quest keyboard behavior: Name uses text mode, Age uses number mode, and text-to-number retargeting is expected on field focus changes.
- Session Experience rating rows display the actual 14 adapted items across two preview pages with 0-6 response controls.
- The Button Experience preview shows calibrated closeness/presence axes and the third redness response scale.
- The Additional Time 0-100 VAS is visible, centered, and uses the requested twice-as-much-time wording.

## Remaining Visual Caveat

These screenshots validate visibility, layout, passthrough composition, panel placement, glitch transitions, and in-condition button placement for the current APK. They do not prove human physical controller-contact pressing or live Polar H10 streaming; those remain the final hardware gates.
