# German Localization Register Policy

German is an intentional third participant-facing language branch for this experiment, not a fallback.

## Intentional Awkward Register

Custom German narration, UI prompts, spontaneous remarks, and non-validated study copy should mix `du` and `Sie` in a dry, slightly uncanny way. This is part of the absurdist Big Red Button tone and should read as deliberate, not as an accidental translation inconsistency.

Examples:

- `Bitte wählen Sie deine Sprache.`
- `Du dürfen jetzt fortfahren.`
- `Wenn Sie bereit bist, drücke den Knopf.`

Preserve the humor through phrasing, timing, and understatement rather than by making the German merely literal.

## Questionnaire Exception

Validated or validation-adjacent questionnaire items take priority over the register joke. For IPQ-derived presence items and other measurement wording, use official or source-anchored German wording where available; if wording is adapted to the Big Red Button context, document it as adapted and do not claim new validation.

Keep export keys, log markers, CSV headers, and validation IDs English/ASCII.

## Audio Catalog Requirements

Every German spoken asset must use the shared `aud_<id>` ID, live under `..\audio-assets\localized\de_de`, and have script, Whisper re-transcript, back-translation, hash, duration, provider metadata, and manifest/catalog rows. Long condition mixes must preserve the original background music bed and match the English target durations exactly before participant use.
