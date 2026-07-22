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
- Embedding the icon/version info into the `.exe` needs `rcedit`
  (Editor Settings > Export > Windows > Rcedit). Without it, the export
  still succeeds and the `.exe` gets a generic Explorer icon instead of
  the configured one — on Godot 4.4 this showed as an explicit warning in
  the export log, but on 4.7.1 the same missing-rcedit case is skipped
  silently with no warning at all, so don't take a clean export log as
  proof the icon was actually embedded.
- `build/` is gitignored — exported binaries are never committed.

CI does not build this preset yet; it only imports resources, lints, runs
tests, and does a headless smoke load (`.github/workflows/ci.yml`). See
`BACKLOG.md` for the planned CI build/release follow-up.

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
