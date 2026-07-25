# Backlog

## Stage 2 Hazard Placement Review

Stage 2 now has its own tube route (`StageTwoDefinition.route()`: gentle
slope, corkscrew, ascending switchback) instead of sharing Stage 1's
shape. Playtesting found the last third too sparse, so the switchback now
builds through nine enemies before the closing gate gauntlet.

The remaining review is visibility rather than density: check that hazards
still read fairly against the corkscrew and climb, and whether
`hazard_reveal_distance` (currently one shared 520 constant) needs a
per-stage override now that curve sharpness varies between stages.

## Stage 5 Playtest Review

Stage 5's rotating storm fronts are implemented with a 620-unit reveal
distance, five-lane openings during introduction, and three-lane openings in
the finale. Playtest whether the moving opening remains readable against the
tightening vortex at both minimum and maximum travel speed. In particular,
check whether the last three fronts need wider openings or slower rotation;
keep this as tuning rather than changing collision rules without evidence.
