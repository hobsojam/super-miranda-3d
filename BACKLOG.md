# Backlog

## Pickup Feedback

- Life and purge pickups work mechanically.
- Collection should read more clearly during play. Add a stronger pickup effect,
  HUD notice, or sound mix touch so the player immediately understands that the
  item was collected.
- Purge is an instant clearance pulse. It clears anchored obstacles when
  collected; it is not a shield and does not prevent future damage.

## Refactor Enemy Skills

Move enemy skill behavior out of `StormStage` now that hazards, pickups, rim
obstacles, audio, HUD, and projectiles have their own support classes.

Candidate scope:

- Spiker retreat, lane stepping, and spike drop cadence.
- Pulsar firing cadence and bolt spawn requests.
- Keep score, damage, sounds, and marker effects in `StormStage` until there is
  a cleaner event boundary.

## Refactor Stage Flow

Extract the start/restart/stage-clear/continue/game-over state transitions once
the active gameplay loops are thinner.

This should cover:

- Run state flags and transition timers.
- Stage start/reset setup.
- Stage clear and game complete transitions.
- Player/runner input enablement during overlays.

Avoid doing this before enemy skill extraction, because stage flow still touches
almost every system.

## Fullscreen Mode

F11/Alt+Enter shortcut and a pause-menu checkbox are done. Godot's embedded
editor preview does not support fullscreen at all, so this can only be
verified in a real packaged build — see Windows Build Automation below for
how to produce one.

Still open:

- Persisting the choice across sessions if project settings support it
  cleanly.
- Confirming UI scale and tunnel framing hold up in an actual standalone
  build, not just in theory.

## Windows Build Automation

`export_presets.cfg` now has a local "Windows Desktop" preset (see
`AGENTS.md` for how to run it) so a real `.exe` can be built and playtested
by hand. Not done yet:

- A CI job that runs the export on push/PR and uploads the `.exe` as a
  workflow artifact, so builds don't depend on anyone's local export
  templates. Needs the matching Godot export templates cached/installed on
  the CI runner (`.tpz` package matching `GODOT_VERSION`/`GODOT_RELEASE` in
  `.github/workflows/ci.yml`).
- Deciding whether `rcedit` (needed to embed the icon/version info into the
  `.exe`) is worth installing in CI, or whether CI builds ship with a
  generic Explorer icon.
- Automated GitHub Releases publishing the `.exe` (e.g. on version tags),
  once there's an actual versioning scheme for the project.

## Environmental Hazards

Explore tube hazards that are part of the stage rather than enemies.

Possible directions:

- Raised wall sections that damage on collision.
- Lava or charged pits on lanes that must be avoided.
- Missing tube sections where staying on that lane causes a fatal fall or heavy crash damage.

Design questions:

- Should environmental hazards be fixed to lanes, move along the tube, or pulse on and off?
- Are they visible far enough ahead to support fair lane planning?
- Can the player shoot them, or are they purely navigation hazards?
- Do they become anchored obstacles like enemies, or pass by as terrain?
