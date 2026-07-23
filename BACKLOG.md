# Backlog

## Windows Build Automation

`export_presets.cfg` has a local "Windows Desktop" preset (see `AGENTS.md`
for how to run it), CI builds it on every push/PR and uploads the `.exe`
as a workflow artifact (`windows-build` job in
`.github/workflows/ci.yml`), and pushing a `vMAJOR.MINOR.PATCH` tag (see
`AGENTS.md`'s Versioning section) runs `.github/workflows/release.yml` to
export the build, zip it, and publish a GitHub Release via
`gh release create`.

Not verified yet: the release workflow has never actually run against a
real tag push, only YAML-validated. Watch the first `v*` tag push closely
and be ready to fix it live.

## Stage 2 Hazard Placement Review

Stage 2 now has its own tube route (`StageTwoDefinition.route()`: gentle
slope, corkscrew, ascending switchback) instead of sharing Stage 1's
shape. Existing hazard/pickup/gate distances still fit — none get
rejected against the new (slightly longer) route length — but they were
originally placed against the old shared curve, so what's actually
happening at each distance (which bend, how sharp) has changed. Worth a
pass to check hazards still read fairly against the corkscrew and climb
specifically, and whether `hazard_reveal_distance` (currently one shared
520 constant) needs a per-stage override now that curve sharpness varies
between stages.

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
