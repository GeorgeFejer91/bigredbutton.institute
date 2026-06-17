# Language, TTS, And Transcription Protocols

The native Quest study owns the participant-facing language catalog.

## Canonical Runtime Library

- Root: `audio-assets/localized/`
- Manifest: `audio-assets/localized/manifest.json`
- Documentation table:
  `native-quest-mr-study/docs/audio-script-lookup-table.csv`
- Active locale folders:
  - `en_us`
  - `de_de`
  - `ja_jp`
- Shared cues:
  - `shared/questionnaire_ui`
  - `shared/questionnaire_transition`
  - `shared/button_press`
  - `shared/inactive`

## Protocol Sources

- Main native guide:
  `native-quest-mr-study/For-AI/speech-asset-protocol.md`
- German register policy:
  `native-quest-mr-study/For-AI/german-localization-register-policy.md`
- Native runtime integration:
  `native-quest-mr-study/app/src/main/java/org/bigredbutton/firststudy/BigRedButtonStudyActivity.kt`

## Validation

Run from `native-quest-mr-study/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-localized-audio.ps1 -RequireJapaneseAudio -RequireGermanAudio
```

Run this before claiming that the monorepo still preserves German, Japanese, and
English participant-facing audio routing.

## Unity Boundary

The imported Unity app can contain its own experimental audio assets, but native
study participant audio remains centralized in `audio-assets/localized/`.
Do not copy Unity audio into native runtime use until license/provenance,
duration, transcripts, back-translation, and native validation rows are added.
