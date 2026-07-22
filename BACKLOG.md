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

Add a proper fullscreen/windowed toggle for playtesting and eventual packaged
builds.

Consider:

- Keyboard shortcut, probably Alt+Enter or F11.
- Menu or pause-menu toggle.
- Persisting the choice if project settings support it cleanly.
- Making sure UI scale and the tunnel framing still work after the mode switch.

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
