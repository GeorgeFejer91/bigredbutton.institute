# Button Press Sound And Motion Plan

This file tracks press-sound work for the native Quest app. A temporary placeholder cue is active on accepted button presses; final sound selection and motion-envelope matching are still future work.

## Placeholder Asset

The app contains and plays a temporary CC0 press-sound placeholder:

```text
app/src/main/assets/sfx/button-press-placeholder-kenney-bong.ogg
```

Provenance:

- source: Kenney Interface Sounds
- source page: `https://kenney.nl/assets/interface-sounds`
- direct pack URL: `https://kenney.nl/media/pages/assets/interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip`
- source file inside pack: `Audio/bong_001.ogg`
- license: Creative Commons Zero, CC0
- selected asset SHA-256: `D21D0F0B782445DB579D11E2506B24CD1AC9D664EE33AEAF807761AA7B6FD710`
- selected asset duration: `0.122834` s
- selected asset size: `4848` bytes

This is a replaceable placeholder. Do not present it as the final validated study sound.

## Integration Rules

- Do not edit, re-encode, trim, normalize, or otherwise alter the two long instruction MP3s.
- Play the press sound only after `recordButtonPress()` accepts a real press. Do not play it for startup-suppressed contacts or cooldown-suppressed contacts.
- The final participant-facing trigger must be the controller-contact 3D button press path, not ADB automation, gaze input, keyboard input, or a visible 2D button.
- The current implementation uses one-shot `MediaPlayer` playback and logs `BRB_SFX_PLAY cue=button_press ...` on accepted presses. If latency is perceptible on headset, move this short effect to `SoundPool`.
- Keep logging the active press-sound asset name/path, duration, and trigger time in runtime logs; add export fields if sound timing becomes a primary dependent variable.
- Treat the final press sound as a study stimulus. Hash-lock it in validation scripts before claiming the APK is ready for data collection.

## Audio-To-Motion Matching

The target behavior is that the Big Red Button's press trajectory feels mechanically tied to the sound. When the final button sound exists:

1. Analyze the audio envelope offline.
2. Detect sound onset, first transient peak, sustained/resonant body, and decay tail.
3. Retune the GLB `pressed` animation or native animation playback so the red cap reaches maximum depression at the main transient peak.
4. Match any hold-at-bottom interval to the sound's resonant body.
5. Match release motion to the decay tail.
6. Produce validation evidence: waveform/envelope plot overlaid with normalized button cap displacement.

The current MesmerPrism GLB has a `pressed` animation lasting about `0.958333` s. If the final sound is much shorter than the animation, either time-scale the animation or author a shorter native keyframe curve. The final choice should be driven by perceived mechanical believability, not by keeping the placeholder timing.

## Validation Requirements

Before replacing the placeholder or claiming final sound-motion readiness:

- Static validation checks the exact final sound asset path, SHA-256, duration, and license/provenance note.
- Build validation confirms the asset is packaged in the APK.
- Runtime validation confirms one sound trigger per accepted press and no sound trigger for suppressed contacts.
- Headset validation confirms the sound is audible over both instruction tracks without clipping or masking spoken instructions.
- Motion validation confirms the cap displacement peak aligns with the sound's main transient peak.
