# Backlog

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

## Stage 5 Playtest Review

Stage 5's rotating storm fronts are implemented with a 620-unit reveal
distance, five-lane openings during introduction, and three-lane openings in
the finale. Playtest whether the moving opening remains readable against the
tightening vortex at both minimum and maximum travel speed. In particular,
check whether the last three fronts need wider openings or slower rotation;
keep this as tuning rather than changing collision rules without evidence.
