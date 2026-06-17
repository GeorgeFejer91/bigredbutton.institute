# First Big Red Button Study Workspace

This directory is the shared home for the first Big Red Button study family.
It keeps the native Quest/XR study, the Unity reference app, and reusable
knowledge assets in one versioned place while preserving each project's build
shape.

## Project Folders

- `native-quest-mr-study/` - Native Meta Quest XR study app. This is the
  canonical location for hand-contact mechanics, controller-contact validation,
  Polar H10 integration, German/Japanese/English localization, ElevenLabs and
  transcription protocols, headset validation tools, and publication-oriented
  `For-AI` research notes.
- `unity-mesmerprism-latest/` - MesmerPrism Unity app imported as a Git subtree
  from `https://github.com/MesmerPrism/the-big-red-button-institute.git`,
  branch `codex/brb-rusty-morphospace-manifold-example`, commit `f94aa66`.
  This is the canonical Unity-based app copy in this repository.
- `audio-assets/` - Shared localized runtime audio library used by the native
  study. Speech lives in locale folders, shared cues live under `shared/`, and
  manifest/catalog metadata must stay in sync with native validation.
- `shared-library/` - Cross-project indexes for button assets, language/TTS
  protocols, research knowledge, and monorepo versioning rules.

## Rules Of Thumb

- Keep project outputs out of Git: native `app/build/`, native `artifacts/`,
  Unity `Library/`, `Temp/`, `Obj/`, `Builds/`, logs, screenshots, and APKs.
- Do not overwrite button assets in place. Add or update an indexed variant and
  record path, hash, source, license, and consuming project.
- Keep native study scripts compatible with `native-quest-mr-study/`; that path
  intentionally remains stable.
- Pull future MesmerPrism Unity updates through the subtree workflow documented
  in `shared-library/versioning.md`.

## Quick Validation

From this directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-project-library.ps1
```

Native software checks still run from `native-quest-mr-study/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-localized-audio.ps1 -RequireJapaneseAudio -RequireGermanAudio
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\validate-study.ps1 -SkipBuild
```
