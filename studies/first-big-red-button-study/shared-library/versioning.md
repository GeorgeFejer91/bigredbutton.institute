# Versioning And Subtree Workflow

The Unity project is imported as a Git subtree so its files live in the main
repository while still allowing upstream refreshes.

## Current Unity Subtree

- Prefix: `studies/first-big-red-button-study/unity-mesmerprism-latest`
- Remote: `mesmerprism-unity`
- Remote URL: `https://github.com/MesmerPrism/the-big-red-button-institute.git`
- Upstream ref: `codex/brb-rusty-morphospace-manifold-example`
- Imported commit: `f94aa66`
- Local subtree merge commit: `4822f65`

## Updating Unity From MesmerPrism

Run from repository root:

```powershell
git fetch mesmerprism-unity --prune
git for-each-ref refs/remotes/mesmerprism-unity --format="%(committerdate:iso-strict) %(objectname:short) %(refname:short) %(subject)" --sort=-committerdate
git subtree pull --prefix=studies/first-big-red-button-study/unity-mesmerprism-latest mesmerprism-unity codex/brb-rusty-morphospace-manifold-example --squash
```

If a different MesmerPrism branch becomes newer and should become canonical,
record the decision here before pulling it into the subtree.

## Local Sibling Checkouts

These sibling folders may remain as temporary external checkouts until the
monorepo import has been validated and the team agrees they can be archived:

- `D:\GithubVR\the-big-red-button-institute`
- `D:\GithubVR\the-big-red-button-institute-unity-version`

Do not delete them as part of routine monorepo work.

## Generated Outputs

Keep these out of Git:

- native: `native-quest-mr-study/app/build/`,
  `native-quest-mr-study/artifacts/`, `local-export-pulls/`, APKs, screenshots,
  headset logs
- Unity: `Library/`, `Temp/`, `Obj/`, `Build/`, `Builds/`, `Logs/`,
  `UserSettings/`, APKs, AABs, Unity packages, stack traces

The nested Unity `.gitignore` handles Unity-generated folders inside the subtree.
The repository root `.gitignore` also has broad generated-output guards.
