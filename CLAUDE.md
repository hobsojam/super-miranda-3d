# Claude Instructions

Read and follow `AGENTS.md` before doing any work in this repository. It
points to `STAGE_DESIGN.md` for stage pacing decisions and `BACKLOG.md` for
open project decisions, plus setup, test, lint, and build commands. If
`AGENTS.md` and this file ever conflict, `AGENTS.md` wins.

## Project Overview

Super Miranda 3D is a Godot 4.7 lane-based arcade shooter inspired by
Tempest, framed as forward motion through a neon tunnel called the Storm.
The player slides between 16 lanes on the rim of a tube route (each stage
authors its own route shape) and fires straight down the current lane;
enemies that reach the rim without being destroyed become anchored
obstacles that grow the hazard field. See `README.md` for the full
player-facing description.

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
gitignored. CI also builds this preset on every push/PR and uploads the
`.exe` as a workflow artifact; publishing GitHub Releases on version tags
is still on `BACKLOG.md`.

## Versioning

Releases are tagged `vMAJOR.MINOR.PATCH`. See `AGENTS.md` for when to
suggest a version bump — never create or push a tag without the user
confirming the version number first.

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
- `scripts/storm_tube.gd` (`StormTube`) builds a hand-authored Catmull-Rom
  spline from whichever control points it's given via `rebuild_route()`;
  `scripts/storm_camera.gd` reads progress along it. `scripts/storm_player.gd`
  is the lane-locked player ship.
- **Route control-point axes don't map to screen directions the way you'd
  expect, and that mapping isn't even constant along a route.**
  `StormTube`'s local `right`/`up` frame is rotation-minimizing (parallel-
  transported: each sample's `right` is the previous sample's `right`
  projected onto the new tangent plane, no extra twist added), starting
  from a hardcoded `right = world +X` — which works out to `up = world -Y`
  at the route's start. So a stage's control points using raw `+X`/`+Y`
  offsets do not correspond to screen-right/screen-up; verify empirically
  (replicate `storm_camera.gd`'s pose + `look_at` math — e.g.
  `Transform3D().looking_at(...)`, not `Node3D.look_at()` on a node outside
  the tree, which silently no-ops) rather than assuming. The mapping also
  isn't fixed along the route: the frame rotates as the path curves, so it
  stays close to constant across one bounded bend (well under a full turn)
  but cycles through a full rotation once per revolution on anything that
  spirals further than that — which is why an early multi-revolution
  corkscrew route shape read as repeatedly flipping direction with no
  actual bug in its construction (see `scripts/stage_two_definition.gd`'s
  git history for the debugging trail).
- Stage content is plain data: `scripts/stage_one_definition.gd` and
  `scripts/stage_two_definition.gd` each return a `route()` control-point
  array plus arrays of `{distance, lane, kind}` hazards/pickups/gate pairs
  that `StormStage` consumes — adding stage content or reshaping a stage's
  tube means editing these, not engine code. `StormStage` calls
  `_storm.rebuild_route(_stage_route(stage))` at every stage
  start/continue/preview transition, so each stage can have a physically
  different route; nothing downstream (hazards, pickups, markers, rim
  obstacles) needs to know the shape, since everything is addressed by
  `(distance, lane)` through `StormTube.sample_at_distance()`.
- Per-run state is split into extracted runtime classes, each following the
  same extraction pattern out of `storm_stage.gd`:
  `scripts/stage_hazard_runtime.gd`, `scripts/stage_pickup_runtime.gd`,
  `scripts/stage_projectile_runtime.gd`, `scripts/rim_obstacle_manager.gd`,
  `scripts/enemy_skill_runtime.gd`, `scripts/stage_flow_runtime.gd` (the last
  owns run/stage state flags and timers; the start/advance/continue/game-over
  transition orchestration that reads and writes them still lives in
  `storm_stage.gd`, since it also needs the audio/HUD/runner/player nodes).
- `scripts/stage_rules.gd` centralizes shared tunable constants (time
  bonus, gate lanes, anchor decay). `scripts/stage_hud.gd` owns all
  overlay/UI states (start, pause, game over, stage clear, complete).
