# Backlog

## Windows Build Automation

`export_presets.cfg` has a local "Windows Desktop" preset (see `AGENTS.md`
for how to run it), and CI now builds it on every push/PR and uploads the
`.exe` as a workflow artifact (`windows-build` job in
`.github/workflows/ci.yml`). Not done yet:

- Automated GitHub Releases publishing the `.exe` on version tags
  (`vMAJOR.MINOR.PATCH` — see `AGENTS.md`'s Versioning section). Needs a
  release workflow triggered on `push: tags: ['v*']` that reuses the
  `windows-build` job's export steps, zips the result, and publishes it
  with `gh release create`.

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
