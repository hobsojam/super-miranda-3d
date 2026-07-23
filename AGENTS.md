# Agent Notes

Guidance for coding agents working in this repo (this project has been
worked on by both Claude and Codex).

## Read before working on stage content

- **`STAGE_DESIGN.md`** — the pacing curve stages should follow (orientation,
  introduce something new, escalate, false summit, fight to the finish).
  Read this before adding, reordering, or tuning anything in a
  `stage_N_definition.gd` file, or before proposing how a stage should end.
- **`BACKLOG.md`** — open, unresolved design decisions. Check its current
  sections before making a call on anything it lists as undecided, and add
  a new section rather than silently picking an answer when you hit an open
  design question of your own.

## Setup

- Install Godot 4.7 (stable), GL Compatibility renderer. Open
  `project.godot` directly — there are no addons or external package
  manager dependencies (`project.godot` has no `[autoload]` or addons
  section).
- Import project resources before running headless checks:
  `godot --headless --path . --import`.

## Development commands

- **Run**: open `project.godot` in the Godot editor and press Play, or
  `godot --path .`. Main scene: `res://scenes/storm_preview.tscn`.
- **Lint GDScript**: `pip install "gdtoolkit==4.*"` then `gdlint .` (this is
  what CI runs — see `.github/workflows/ci.yml`).
- **Syntax check a script**:
  `godot --headless --path . --check-only --script <path>`.

## Tests

`godot --headless --path . --script tests/run_tests.gd`. Run this after
touching anything under `scripts/`.

## Build

`export_presets.cfg` has a "Windows Desktop" preset (self-contained
`--embed-pck` exe, icon at `assets/icon/icon.ico`). To build it:

- Install matching export templates first (Editor > Manage Export
  Templates, or extract the `templates/` folder from the
  `Godot_v<version>-stable_export_templates.tpz` package matching your
  installed editor to `%APPDATA%\Godot\export_templates\<version>.stable\`
  — e.g. `4.7.1.stable` for Godot 4.7.1). The template folder name must
  match the editor's exact version, including the patch number.
- Create the output directory before exporting — Godot does not create it:
  `mkdir -p build/windows`, then
  `godot --headless --path . --export-release "Windows Desktop" build/windows/super-miranda-3d.exe`.
- Icon/version info embedding into the `.exe` no longer needs the external
  `rcedit` tool — Godot 4.7's Windows exporter embeds it natively.
- `build/` is gitignored — exported binaries are never committed.

CI builds this preset too, on every push and pull request, and uploads the
`.exe` as a workflow artifact (`.github/workflows/ci.yml`'s `windows-build`
job) — useful for playtesting a PR without a local export template setup.
Automated GitHub Releases on version tags are still on `BACKLOG.md`.

## Versioning

Releases are tagged `vMAJOR.MINOR.PATCH` (semver with a `v` prefix). The
`0.1` tag predates this scheme and was never used for a release — ignore
it.

When wrapping up a PR or session that changes what a player would notice
in a build (new stage content, gameplay-affecting balance changes, new
features), mention to the user that a version bump may be worth cutting,
and suggest a MAJOR/MINOR/PATCH level based on the size of the change.
Don't create or push a version tag without the user confirming the exact
version number first — cutting a release is a user decision, not
something to automate.

## Keep docs and commits portable

Never write anything security-relevant (credentials, API keys, tokens,
internal URLs) or specific to one person's machine (absolute paths like
`C:\Users\...` or `/home/...`, personal directory layouts, local tool
install locations) into this repo — that includes `README.md`,
`AGENTS.md`, `CLAUDE.md`, commit messages, and code comments. Prefer
commands that assume a standard PATH-available tool (e.g. `godot ...`)
over anything tied to how one contributor's environment happens to be
set up.

## Working alongside other agents

Multiple agents may be active in this repo at once, sometimes in the same
checkout. Don't switch branches or force-push over another agent's
in-progress work; if you're unsure whether a branch is someone else's,
check its recent commits before touching it.
