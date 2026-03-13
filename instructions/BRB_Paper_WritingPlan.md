# BRB Canonical Paper Instruction

This is the single canonical instruction for future Codex agents working on the Big Red Button Institute paper. If the user says "run this instruction" or refers to this file, execute it end-to-end without asking the user to restate the project unless preferences have changed.

## Mission

Produce the most complete truthful paper package possible for the Big Red Button Institute inside `VR-study/Paper` in the current cloned repository.

The job is not just to draft prose. The job is to carry the paper from source gathering to manuscript delivery:

- install or verify required academic-writing skills
- catalog and archive papers
- dedupe and verify citations
- build or update the consolidated `.bib` file
- write and refine the manuscript in `.tex`
- prepare a compile-ready paper package
- commit and push the repository when finished unless the user explicitly says not to

## Non-Negotiables

- Do not fabricate citations.
- Do not fabricate results, statistics, or participant outcomes.
- Use primary academic sources whenever possible.
- Treat the object with dry, serious, theory-aware HCI writing. Humor may sharpen a point but may never replace evidence.
- Preserve existing user changes. Do not overwrite unrelated work.
- If data are missing, produce the most complete truthful manuscript scaffold possible and clearly mark what remains unresolved.
- When the task is complete, commit the work and push the repository unless the user explicitly says not to.

## Portability Rules

This instruction must be portable across teammates and machines.

- Interpret all repo paths relative to the repository root.
- Do not assume the repository lives in any specific home directory.
- Do not assume Windows unless the current environment clearly is Windows.
- Do not assume `py -3` exists; use the platform-appropriate Python launcher if you need a direct script fallback.
- Prefer the built-in `skill-installer` skill over hardcoded local installer paths.
- Only push if the current user has git write access and has not explicitly asked you not to push.

## Collaboration Workflow

Assume this repository will move between multiple humans and multiple Codex accounts. Optimize for rapid, low-friction handoff.

Default collaboration rules:

- Work on the currently checked-out branch unless the user explicitly requests a separate branch workflow.
- Never overwrite teammate changes you do not understand.
- Never force-push unless the user explicitly requests it.
- Keep commits scoped, descriptive, and easy to review.
- Maintain a living project-state file and append-only session log inside `VR-study/Paper`.

Before starting substantive work:

1. Run `git status --short`, `git branch --show-current`, and inspect remote tracking state.
2. Read `VR-study/Paper/PROJECT_STATE.md` if it exists.
3. Read the most recent entries in `VR-study/Paper/SESSION_LOG.md` if it exists.
4. If the worktree is clean and the branch is behind remote, sync first with a safe pull strategy.
5. If local and remote work have diverged, reconcile carefully without discarding local changes.

During work:

- Update `VR-study/Paper/PROJECT_STATE.md` whenever priorities, blockers, manuscript status, or canonical outputs materially change.
- Append a new entry to `VR-study/Paper/SESSION_LOG.md` for each meaningful work session.
- If a blocker prevents completion, record it explicitly rather than leaving the next collaborator to infer it from the diff.

Before pushing:

1. Review the diff.
2. Ensure `VR-study/Paper/PROJECT_STATE.md` reflects the current state of the manuscript.
3. Ensure `VR-study/Paper/SESSION_LOG.md` contains a current session entry.
4. Commit with a clear message.
5. Push the current branch if remote write access exists.
6. If push is rejected, fetch and reconcile carefully, then push again.

## Canonical Repo Inputs

Use these repo files as first-order grounding:

- `index.html`
- `VR-study/Paper/bigredbutton_placement.tex`
- `VR-study/Paper/bigredbutton_placement.bib`

Use these instruction files as secondary context only if more detail is needed:

- `instructions/brb-paper-handoff.md`
- `instructions/brb-paper-handoff.txt`

## Paper Grounding

The paper studies `pressability`: the symbolic, historical, perceptual, social, and embodied relation between a person and a big red button.

The paper must integrate these layers:

- cultural history of the big red button as meme, warning, emergency device, and foreshadowed object
- STS and interface history of buttons as discrete decision artifacts
- social and psychological functions of pressing, curiosity, boredom, agency, and contribution
- design and neuroscience of red, protrusion, salience, and pressability
- embodiment through cardiac and respiratory biofeedback
- novelty, first encounter, repetition, oneness, and secondness
- temporal complexity of pressing behavior
- inclusive limits: do not universalize Western meanings of red, danger, or button symbolism

## Study Grounding

Treat the study as follows unless the repo later contains a newer authoritative methods file:

- participants sit in a neutral grey VR room
- a single large red button is placed at optimized arm's-length reach
- a reassuring audio track explicitly preserves agency to press or not press
- a visible counter above the button shows cumulative presses
- one condition uses live Polar H10 ECG via BLE to Quest 3, coupling heartbeat to the button's flashing red tone or pulse
- one control condition uses sham ECG generated from simulated activity
- breathing modulates ambient lighting
- the condition logic is double blind
- post-trial measures include presence, peripersonal space, oneness, and secondness
- novelty is a core theoretical issue, not just a nuisance variable

## Required Tone

Write as a serious HCI paper with STS and humanities literacy.

- Empirical claims: plain, rigorous, cited.
- STS sections: historically and politically literate.
- Cultural sections: symbolic and media-aware, but still disciplined.
- Methods and results: sober and literal.
- Discussion: conceptually ambitious, but never unearned.

## Skills Bootstrap

Before major writing work, verify that the needed skills exist. If they do not, install them first.

Minimum required skills:

- `research-pipeline-runner`
- `pipeline-router`
- `paper-review-pipeline`
- `arxiv-search`
- `dedupe-rank`
- `paper-notes`
- `claims-extractor`
- `survey-seed-harvest`
- `taxonomy-builder`
- `outline-builder`
- `section-briefs`
- `subsection-briefs`
- `writer-context-pack`
- `evidence-binder`
- `prose-writer`
- `synthesis-writer`
- `citation-verifier`
- `citation-diversifier`
- `citation-injector`
- `draft-polisher`
- `global-reviewer`
- `latex-scaffold`
- `latex-compile-qa`

Preferred install method:

- Use the built-in `skill-installer` skill to install missing skills into the current Codex user's skills library.

Install source for `paper-review-pipeline`:

- GitHub repo: `yishitys/academic-report-generator-skill`
- install as skill name: `paper-review-pipeline`

Install source for the BRB writing subset:

- GitHub repo: `WILLOSCAR/research-units-pipeline-skills`
- required skill paths:
  - `.codex/skills/research-pipeline-runner`
  - `.codex/skills/pipeline-router`
  - `.codex/skills/arxiv-search`
  - `.codex/skills/dedupe-rank`
  - `.codex/skills/paper-notes`
  - `.codex/skills/claims-extractor`
  - `.codex/skills/survey-seed-harvest`
  - `.codex/skills/taxonomy-builder`
  - `.codex/skills/outline-builder`
  - `.codex/skills/section-briefs`
  - `.codex/skills/subsection-briefs`
  - `.codex/skills/writer-context-pack`
  - `.codex/skills/evidence-binder`
  - `.codex/skills/prose-writer`
  - `.codex/skills/synthesis-writer`
  - `.codex/skills/citation-verifier`
  - `.codex/skills/citation-diversifier`
  - `.codex/skills/citation-injector`
  - `.codex/skills/draft-polisher`
  - `.codex/skills/global-reviewer`
  - `.codex/skills/latex-scaffold`
  - `.codex/skills/latex-compile-qa`

Fallback only if the `skill-installer` skill cannot be used:

- resolve the installer script relative to the current Codex home, typically `$CODEX_HOME/skills/.system/skill-installer/scripts/install-skill-from-github.py`
- run it with the platform-appropriate Python launcher
- install into the current user's Codex skills directory, not a hardcoded teammate-specific path

If skills are newly installed, restart Codex before continuing.

Portability note:

- On this original machine, these skills were already installed as of March 13, 2026.
- On a teammate machine, verify presence first rather than assuming they exist.

## End-to-End Workflow

Execute the following steps in order.

1. Read this file completely, then inspect git status and current paper files.
2. Read `VR-study/Paper/PROJECT_STATE.md` and `VR-study/Paper/SESSION_LOG.md` if they exist.
3. Sync the current branch with remote if it is safe to do so.
4. Do not discard unrelated local changes. Work around them unless the user explicitly asks otherwise.
5. Verify or install the required skills.
6. Build or refresh the paper workspace under `VR-study/Paper`. If missing, create:
   - `archive/`
   - `notes/`
   - `citations/`
   - `sections/`
   - `figures/` if needed
   - `PROJECT_STATE.md`
   - `SESSION_LOG.md`
7. Catalog all relevant papers and sources.
   - search the repo for existing PDFs, notes, and references
   - if the user has local PDFs, organize them under `archive/`
   - create or update a source catalog such as `VR-study/Paper/archive/source_catalog.md`
8. Build the literature corpus in two lanes:
   - empirical lane: HCI, VR, embodiment, agency, boredom, curiosity, biofeedback, peripersonal space, attention, color, button ergonomics
   - humanities lane: STS, media archaeology, design theory, interface history, philosophy of action, cultural history of red buttons
9. Dedupe sources, generate structured notes, and extract claims.
10. Verify all citations and build or update the consolidated bibliography.
   - preferred output file: `VR-study/Paper/bigredbutton_full.bib`
   - keep legacy `bigredbutton_placement.bib` if needed, but the final manuscript should point to one clearly maintained primary `.bib`
11. Build a paper outline that covers at minimum:
   - abstract
   - introduction
   - related work / theoretical framing
   - study overview and methods
   - results or a truthful results scaffold
   - discussion
   - limitations
   - conclusion
12. Write the manuscript in LaTeX.
    - create a compile-ready main file, preferably `VR-study/Paper/main.tex`
    - place section files under `VR-study/Paper/sections/`
    - reuse grounded content from `bigredbutton_placement.tex` where appropriate
13. For the introduction and discussion, explicitly integrate:
    - cultural-symbolic history
    - STS button genealogy
    - psychology of pressing and boredom
    - design and salience of red protruding buttons
    - embodied cardiac and respiratory coupling
    - novelty, first encounter, oneness, secondness
    - temporal complexity and multilevel interpretation
14. For results:
    - if real data and analysis outputs exist, analyze them and write the results section truthfully
    - if real data do not exist, do not invent them; instead create a clearly labeled results scaffold and a short gap note such as `VR-study/Paper/DATA_GAPS.md`
15. Run citation cleanup and manuscript polish.
    - verify every empirical claim
    - diversify citations where needed
    - harmonize style across sections
16. If a TeX toolchain is available, compile-check the manuscript.
    - if compilation fails, fix what is possible
    - if TeX tools are missing, leave compile-ready files and state that limitation clearly
17. Update `VR-study/Paper/PROJECT_STATE.md` and append a new entry to `VR-study/Paper/SESSION_LOG.md`.
18. Finish by reviewing the diff, committing the work, and pushing the repository if remote write access is available and the user has not said not to push.

## Required Outputs

By the end of the task, produce as many of these as truthfully possible:

- `VR-study/Paper/main.tex`
- `VR-study/Paper/bigredbutton_full.bib`
- `VR-study/Paper/sections/01_introduction.tex`
- `VR-study/Paper/sections/02_related_work.tex`
- `VR-study/Paper/sections/03_methods.tex`
- `VR-study/Paper/sections/04_results.tex` or equivalent truthful scaffold
- `VR-study/Paper/sections/05_discussion.tex`
- `VR-study/Paper/sections/06_conclusion.tex`
- `VR-study/Paper/archive/source_catalog.md`
- `VR-study/Paper/citations/verified.jsonl` or equivalent verification artifact if generated by the tooling
- `VR-study/Paper/DATA_GAPS.md` only if data limitations prevent a full truthful results section
- `VR-study/Paper/PROJECT_STATE.md`
- `VR-study/Paper/SESSION_LOG.md`

## Success Criteria

The task is complete only when all of the following are true:

- the repo contains a coherent paper workspace under `VR-study/Paper`
- the literature has been cataloged and archived in an organized way
- the bibliography has been created or updated without invented references
- the LaTeX manuscript is substantially complete and grounded in the repo's actual study
- the introduction and discussion are theory-rich, disciplined, and aligned with BRB themes
- any missing data or result limitations are stated explicitly rather than hidden
- `VR-study/Paper/PROJECT_STATE.md` reflects current manuscript status, blockers, and next steps
- `VR-study/Paper/SESSION_LOG.md` contains a current handoff entry
- the final changes are committed and pushed

## Invocation Phrase

If the user later wants this entire workflow executed, the user can simply say:

`Run instructions/BRB_Paper_WritingPlan.md end-to-end.`

## Final Rule

When finished, commit the work and push the repository to its remote unless the user explicitly says not to push or the current machine lacks git write access.
