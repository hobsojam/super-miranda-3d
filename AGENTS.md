# Agent Notes

Guidance for coding agents working in this repo (this project has been
worked on by both Claude and Codex).

## Read before working on stage content

- **`STAGE_DESIGN.md`** — the pacing curve stages should follow (orientation,
  introduce something new, escalate, false summit, fight to the finish).
  Read this before adding, reordering, or tuning anything in a
  `stage_N_definition.gd` file, or before proposing how a stage should end.
- **`BACKLOG.md`** — open, unresolved design decisions, currently "Pickup
  Feedback And Defensive Item" and "Environmental Hazards". Check it before
  making a call on anything it lists as undecided, and add a new section
  rather than silently picking an answer when you hit an open design
  question of your own.

## Setup

- Install Godot 4.4 (stable), GL Compatibility renderer. Open
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

There is no packaged export yet — no `export_presets.cfg` is committed, and
CI does not build one; it only imports resources, lints, runs tests, and
does a headless smoke load (`.github/workflows/ci.yml`). To produce a
runnable build, add an export preset via Godot's Project > Export first.

## Working alongside other agents

Multiple agents may be active in this repo at once, sometimes in the same
checkout. Don't switch branches or force-push over another agent's
in-progress work; if you're unsure whether a branch is someone else's,
check its recent commits before touching it.
