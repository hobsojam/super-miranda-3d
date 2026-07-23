# Claude Instructions

Read and follow `AGENTS.md` before doing any work in this repository. It
points to `STAGE_DESIGN.md` for stage pacing decisions and `BACKLOG.md` for
open project decisions, plus setup, test, lint, and build commands. If
`AGENTS.md` and this file ever conflict, `AGENTS.md` wins.

## Project Overview

Super Miranda 3D is a Godot 4.7 lane-based arcade shooter inspired by
Tempest, framed as forward motion through a neon tunnel called the Storm.
The player slides between 16 lanes on the rim of a fixed tube route and
fires straight down the current lane; enemies that reach the rim without
being destroyed become anchored obstacles that grow the hazard field. See
`README.md` for the full player-facing description.

## Setup

Install Godot 4.7 (stable), GL Compatibility renderer. Open `project.godot`
directly — no addons or external package manager dependencies are
configured. Import resources before running headless checks:
`godot --headless --path . --import`.

## Development Commands

- Run: open `project.godot` in the Godot editor and press Play, or
  `godot --path .`. Main scene: `res://scenes/storm_preview.tscn`.
- Lint: `pip install "gdtoolkit==4.*"` then `gdlint .` (matches CI).
- Syntax check a script:
  `godot --headless --path . --check-only --script <path>`.

## Tests

`godot --headless --path . --script tests/run_tests.gd`. Run this after
touching anything under `scripts/`.

## Build

`export_presets.cfg` has a "Windows Desktop" preset. Install matching
export templates first, create the output directory (Godot won't), then:
`godot --headless --path . --export-release "Windows Desktop" build/windows/super-miranda-3d.exe`.
See `AGENTS.md` for the full setup steps (export templates). `build/` is
gitignored. CI stops at
import/lint/test/smoke-load (`.github/workflows/ci.yml`) — building this
preset in CI and publishing releases is on `BACKLOG.md`, not done yet.

## Keep Docs And Commits Portable

Never write anything security-relevant (credentials, API keys, tokens,
internal URLs) or specific to one person's machine (absolute paths,
personal directory layouts, local tool install locations) into this
repo — including `README.md`, `AGENTS.md`, `CLAUDE.md`, commit messages,
and code comments. Prefer commands that assume a standard PATH-available
tool over anything tied to one contributor's environment.

## Architecture

- `scripts/storm_stage.gd` (`StormStage`) is the per-run controller: tracks
  distance along the route, drives stage transitions, and owns the
  extracted runtimes below.
- `scripts/storm_tube.gd` (`StormTube`) builds a fixed, hand-authored
  Catmull-Rom spline once; `scripts/storm_camera.gd` reads progress along
  it. `scripts/storm_player.gd` is the lane-locked player ship.
- Stage content is plain data: `scripts/stage_one_definition.gd` and
  `scripts/stage_two_definition.gd` each return arrays of
  `{distance, lane, kind}` hazards/pickups/gate pairs that `StormStage`
  consumes — adding stage content means editing these arrays, not engine
  code.
- Per-run state is split into extracted runtime classes, each following the
  same extraction pattern out of `storm_stage.gd`:
  `scripts/stage_hazard_runtime.gd`, `scripts/stage_pickup_runtime.gd`,
  `scripts/stage_projectile_runtime.gd`, `scripts/rim_obstacle_manager.gd`,
  `scripts/enemy_skill_runtime.gd`.
- `scripts/stage_rules.gd` centralizes shared tunable constants (time
  bonus, gate lanes, anchor decay). `scripts/stage_hud.gd` owns all
  overlay/UI states (start, pause, game over, stage clear, complete).
