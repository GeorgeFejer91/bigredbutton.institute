# Button Asset Catalogue

This catalogue keeps the Big Red Button visual and sound assets traceable across
the native XR study and the imported Unity app.

## Native XR Button

- Project: `native-quest-mr-study`
- Runtime path: `app/src/main/assets/models/BigRedButton.glb`
- APK URI: `apk:///models/BigRedButton.glb`
- SHA-256: `4BA2C479EAE6A103ADCE0B7D0AB70C94A5F21A12435DD90ACD0071F66EF5F52B`
- Size: `88132` bytes
- Role: canonical native Quest participant-facing button model
- Notes: generated smooth native study GLB with `pressed` animation. Do not
  overwrite in place; add new variants beside it and update the runtime catalog.

## MesmerPrism Unity Button

- Project: `unity-mesmerprism-latest`
- Imported source: `https://github.com/MesmerPrism/the-big-red-button-institute.git`
- Imported ref: `codex/brb-rusty-morphospace-manifold-example`
- Imported commit: `f94aa66`
- Asset paths:
  - `Assets/Models/BigRedButton.glb`
  - `Assets/StreamingAssets/Models/BigRedButton.glb`
- SHA-256: `5B0E13AC4854C8E508BA7EAD8807E7D655EDB169F88FE39A16AFD2BCD4EE8887`
- Size: `221924` bytes
- Upstream asset title: Big Red Button
- Creator: Charlie
- Source: `https://poly.pizza/m/lTyNXwkDgX`
- License: Creative Commons Attribution 3.0 Unported, CC BY 3.0
- Attribution source: `unity-mesmerprism-latest/THIRD_PARTY_NOTICES.md`
- Notes: imported Unity project uses this model as the visible button. The
  latest MesmerPrism commit does not include `NativeQuestStudyBigRedButton.glb`.

## Native Heartbeat Glow Assets

- Stable native path: `HeartbeatPulseDriver` plus native cap-surface point
  lights in `native-quest-mr-study`.
- Retired/provenance variants:
  `native-quest-mr-study/app/src/main/assets/models/glow/BigRedButtonGlowLevel01.glb`
  through `BigRedButtonGlowLevel32.glb`.
- Rule: physiological heartbeat glow may change light intensity or validated
  material variants, but it must not count as press evidence. Press evidence
  remains controller-contact or supplemental hand-contact.

## Unity Heartbeat And Press Sound Assets

Unity heartbeat glow behavior is implemented in
`unity-mesmerprism-latest/Assets/Scripts/BigRedButtonBlinkController.cs`.
It drives cap material tint/emission and a surface light rig in Unity.

Unity button sound effects imported in the latest MesmerPrism subtree:

| Asset | SHA-256 |
| --- | --- |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect01.m4a` | `FA59DC1300FA65447897B700A07E79DF2437CB7B6E4433307E9D067B0053E7E7` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect02.m4a` | `A75216DE967E8FB01200BFB62D6C7DBE9C20FABEE1151BFD4D1477073047024F` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect03.m4a` | `22BC518F1EBEF6204B318504794D3B829806907425FBB18545B7BB414D6D2A43` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect04.m4a` | `D8C6359B9773972BC007F9B4CB295B092099F4F96AE3FD471851D97D98FF7F23` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect05.m4a` | `E91E57AAF89098E45D6C2B1DEF965C747A61B008A577FF1ADC10046A02E8356D` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect06.m4a` | `02E0E60425DB33A498145A0382354F3ED8744F6468FAD34B3AA4E4B2F3389ABE` |
| `Assets/Audio/BigRedButtonSoundEffects/ButtonSoundEffect07.m4a` | `4B4CBE8A6EB9DD5A2DB14B07CBCBAAB322550427D2EB7958A8DDA39EC7280ECF` |

Native study press sound remains the separately catalogued placeholder in
`audio-assets/localized/shared/button_press/` unless a future stimulus pass
promotes one of these Unity assets with license and perceptual validation.
