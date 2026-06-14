# Global Writing Constraints

This folder stores the writing norms and handoff context for future AI-assisted paper work. Keep the LaTeX manuscript itself minimal: `main.tex` owns formatting and imports only the segment files in the paper root.

## Manuscript Structure

- `main.tex` controls document class, packages, bibliography style, figure path, title metadata, and section imports.
- `Introduction.tex`, `methods.tex`, `results.tex`, and `discussion.tex` contain manuscript prose only.
- `references.bib` is the primary bibliography file for the paper.
- `figures/` is the only intended location for manuscript figures and figure assets.
- Supporting notes, citation verification, and source archives may remain in non-compiled folders, but manuscript prose should not depend on hidden local paths.

## Evidence Rules

- Do not fabricate citations, statistics, participant outcomes, effect sizes, or implementation details.
- Treat the results section as a scaffold until participant-level data, questionnaire exports, physiology exports, condition assignments, and analysis outputs are archived.
- Use verified academic sources for empirical and theoretical claims.
- Cultural examples can motivate analysis, but they cannot substitute for evidence about behavior, physiology, attention, embodiment, or VR experience.
- Place citations next to the factual claim they support. Do not stack several claims and then dump citations at the end of a sentence or paragraph.
- If a sentence contains multiple factual claims, split the sentence or cite each clause directly.
- Use citations as evidence for a claim, not as decorative proof that a topic has literature.

## Voice

- Write in an academic style suitable for a computer science or HCI journal.
- Write parsimoniously. Prefer direct claims, compact paragraphs, and minimal repetition.
- Reduce redundancy aggressively. If a sentence restates a nearby claim without adding evidence, qualification, or conceptual precision, remove or merge it.
- Omit em dashes everywhere in manuscript prose, notes, captions, abstracts, titles, tables, and AI-generated drafts. Use commas, colons, semicolons, parentheses, or sentence breaks instead.
- Ground the style in deadpan satire, but frame every claim with utmost scientific seriousness.
- Use satire and sarcasm as controlled rhetorical texture, not as argument. The paper should read like an actual scientifically researched article that happens to study an object with absurd gravity.
- Keep humor dry, sparse, and conceptually useful.
- Do not let irony replace evidence.
- Preserve the core construct `pressability` as the multilevel relation among symbolism, affordance, agency, bodily reach, social legibility, novelty, and physiological coupling.

## Prose Discipline

- Lead with the claim, then give only the evidence or qualification needed to support it.
- Avoid ornate transitions, inflated phrasing, generic literature-review filler, and long throat-clearing.
- Prefer one precise sentence over two elegant but overlapping sentences.
- Each paragraph should have one central argumentative job. A good paragraph usually contains a claim, a cited premise, an example or consequence, and a payoff for the reader.
- Translate technical terms at first use. If a smart reader might ask what a phrase means in this paper, explain it in the same sentence or the next sentence.
- Avoid staccato chains of short declarative sentences. Formulated academic sentences should usually connect claim to implication, cited fact to consequence, or definition to function.
- Merge isolated satirical quips into analytic sentences when the joke does not also advance the argument.
- When listing things, aim for three items. If more than three are needed, group them into categories or split the sentence.
- Avoid long lists that make the prose feel like source accumulation rather than argument.
- Keep sarcasm legible through contrast between object and method, not through casual wording.
- Maintain terminological consistency across sections, especially for `pressability`, `oneness`, `secondness`, live feedback, sham feedback, presence, and peripersonal space.
- Before writing or revising any manuscript segment, read this file first.

## Inclusivity And Scope

- Do not universalize red-button symbolism; acknowledge cultural and historical variation.
- Keep accessibility, handedness, arm length, VR familiarity, sensing comfort, and mobility differences visible where they affect interpretation.
- State empirical boundaries directly instead of hiding them in vague caveats.
