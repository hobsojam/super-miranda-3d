# Stage Design

This describes the pacing shape every Storm stage should follow, and how to
express that shape using the existing per-stage data files
(`scripts/stage_one_definition.gd`, `scripts/stage_two_definition.gd`, and
any future `stage_N_definition.gd`).

Stages are authored as flat, distance-keyed lists — `hazards()`, `pickups()`,
and `gate_pairs()`, each entry a `{distance, lane, kind}` triple. There is no
phase concept in the engine itself. Phases are a pacing pattern for how you
lay out those distances, not a new mechanic to build.

## The five-phase curve

A tension curve, not a strict formula. Distances are illustrative, not
prescriptive — scale them to the stage's actual `route_length` and to how
much the player already knows coming in from prior stages.

1. **Orientation** — the stage opens empty or near-empty. No threats, no
   decisions. The player re-establishes control, rhythm, and lane position
   before anything is asked of them. Later stages can shorten this
   (returning players need less runway than first-timers) but shouldn't cut
   it entirely — a hard cut from "stage clear" straight into danger reads as
   unfair, not exciting.

2. **Introduce something new** — the stage's one new idea debuts alone,
   uncontested, so the player can learn its behavior in isolation. "New"
   doesn't have to mean a new enemy kind — it can be a new hazard, a new
   pickup, a new obstacle shape (Stage 2's `gate_post`/`gate_field` pair is a
   good example: the *gate itself* is the new idea, not an enemy), or a
   twist on something already known (a familiar enemy kind appearing in a
   pattern or density the player hasn't seen). Whatever it is, it should
   appear without competing for attention against anything else unfamiliar.

3. **Escalate** — combine what's known. Layer the new element from phase 2
   together with elements the player already knows, either from earlier in
   this stage or carried over from previous stages. Density climbs, but
   nothing wholly unfamiliar shows up here — the challenge comes from
   combination and pacing, not from another surprise.

4. **False summit** — tension drops, but not to empty. This should feel
   like "I made it," not like a bug. A pickup, a breather, a single easy and
   familiar beat — something that lets the player exhale and feel rewarded
   — works better than dead space, which just reads as the stage having
   nothing left to show. Rewards aren't exclusive to this phase — hand out
   pickups anywhere they earn their keep (a defensive tool ahead of an
   escalate section, for instance) — but phase 4 is where a reward carries
   the most weight, because it's positioned as "you made it this far." The
   contrast with phase 5 is the point: the drop only pays off if the player
   believes it.

5. **Fight to the finish** — the requirement is a real challenge climax:
   enemies, hazards, pressure, at the stage's highest density. That's what
   phase 5 *means*. A gate, a portal, a boss, or some other capstone
   encounter are all valid ways to also give the climax a visible shape and
   a moment to aim at, and worth considering — but none of them is the
   definition, and a stage doesn't need one to nail phase 5. Density and
   combination alone are enough, as long as it reads as a deliberate spike.
   What phase 5 must not be is anticlimactic: a bare distance check with
   nothing happening is the one failure mode to avoid, independent of
   whether any capstone mechanic is in play.

## Applying it to a stage

Each phase is just a distance band in that stage's `hazards()` /
`pickups()` / `gate_pairs()` arrays — no phase field, no engine change. When
authoring or reviewing a stage:

- Mark out roughly where each phase starts along the route before placing
  individual entries, the same way a level designer blocks out a map before
  detailing it.
- Phase boundaries don't need to be sharp. What matters is the *trend* —
  density and unfamiliarity should rise, dip, then spike, not wander.
- A stage can reuse phase 2's "new idea" slot for something that's new to
  *this* stage even if it existed in an earlier one (e.g. Stage 2
  introducing gates is new to Stage 2 even though Stage 1 already had every
  enemy kind).
- Rewards aren't pinned to phase 4 specifically — place a pickup wherever
  it earns its keep along the curve. Phase 4 is just the one place a reward
  is guaranteed to land, because that's what makes it a false summit rather
  than a random lull.
- Check the shape by reading the stage definition file as a distance-sorted
  list and asking: where's the empty runway, where's the first unfamiliar
  thing, where does it combine with what's known, where's the exhale, and
  where does it peak? "What's the player looking at when it ends" only
  matters if the stage actually has a capstone mechanic — density alone can
  carry phase 5 just as well.

## Applied example (Stage 1)

Stage 1's original layout only nailed phase 1 (empty 0–720); every enemy
kind was introduced and escalated back-to-back with no lull, and it ended
on a flat distance check. It's since been rebalanced to hit all five
phases: each kind (flipper → spiker → splitter → pulsar → exploder) gets
its own solo debut with real spacing, phase 3 combines flipper + spiker
before pulsar/exploder are introduced, phase 4 thins out to one easy
flipper plus the `life` pickup as a reward beat, and phase 5 combines
everything at higher density than before.

Density alone wasn't quite enough, though — with just a harder mix of
known enemies, the finale read as "more of the same, faster" rather than
an ending, because nothing in it was mechanically different from what came
before. The fix was one single gate as a capstone, not a gauntlet (Stage 2
already owns gates as a recurring mechanic): a lone, generously wide gate
placed right at the very end, revealed early enough to sit on the horizon
through most of phase 5. That's the practical version of "a capstone is
optional, not the definition" — Stage 1 didn't need one to satisfy the
letter of phase 5, but it needed one to actually feel like a finish line.
See `scripts/stage_one_definition.gd` and `BACKLOG.md` for any remaining
open stage-content decisions.

## Applied example (Stage 4)

Stage 4 uses the tube itself as the new idea. Fixed reactor panels pulse
through inactive, warning, and active states; active panels damage the player
on contact, cannot be shot, and never become rim obstacles. The route stays
comparatively straight so the player can read lane safety well ahead.

The first two panel bands appear without enemies. Phase 3 combines
complementary and alternating panel patterns with familiar enemy kinds. Phase 4
powers the reactor down around a life pickup. Phase 5 restores the panels at
their highest density and closes on a twelve-panel band with a four-lane safe
corridor, using the terrain pattern itself as the capstone instead of another
gate gauntlet.

## Applied example (Stage 5)

Stage 5 turns the route into a shrinking forward-axis vortex and introduces
rotating storm fronts. Each front blocks most of the tube but carries a bright,
continuously moving safe opening. The fronts cannot be shot and do not anchor;
the player must predict where the opening will be at the moment of crossing.

Phase 2 teaches two wide, slow openings without enemy interference. Phase 3
alternates rotation direction while combining the fronts with known enemies,
then introduces the first narrow opening. Phase 4 opens into a long quiet eye
with a life pickup. Phase 5 tightens the route, narrows every later opening, and
finishes on the fastest front at the core.

## Backlog: future stage shape ideas

Ideas for stages beyond Stage 5, not yet built or scheduled. Route shape
is the interesting design space here, not enemy content - phase pacing
still applies to whichever shape gets picked, the same way it applied to
Stage 2's corkscrew and Stage 3's weave.

The real lesson from building Stage 2 and Stage 3 is that a shape idea
and a *safe, working* shape are different amounts of effort. Both stages
needed real bugs found and fixed after the first reasonable-looking
attempt - direction reversals at segment seams, aliased-looking bends
that were actually fine, and (Stage 3, most seriously) a hand-placed
zigzag whose Catmull-Rom curvature at each vertex was tighter than the
tube's own cross-section radius, which pinches the inside wall. See
`scripts/stage_two_definition.gd` and `scripts/stage_three_definition.gd`
for how that was fixed: build the shape as an explicit parametric formula
(a real sine wave for Stage 3, a real helix for Stage 2's corkscrew),
finely sampled and emitted by arc length, so curvature is a derivable,
checkable property instead of an accident of how far apart hand-placed
points happen to be - and actually check it (radius of curvature at the
tightest point vs. `StormTube.radius`), not just render-sample turn angle,
which only catches aliasing.

Ideas buildable with that same technique (no engine changes, just a new
`stage_N_definition.gd`):

- **Braid / figure-eight** - two interleaved lateral oscillations at
  different frequencies (a Lissajous-style curve) so the path visibly
  crosses over itself, rather than just swinging side to side like
  Stage 3.
- **Ascending drill** - the corkscrew's exact math, but coiling around
  the forward travel axis (a barrel roll) instead of a downward axis,
  which Stage 2 deliberately avoided in favor of the "coiled snake" read.
  Genuinely different screen feel now that the technique is understood.
- **Vertical undulation ("dunes")** - Stage 3's sine-wave technique
  applied to y instead of x: cresting and dipping rather than weaving
  left-right.
- **Tightening vortex** - corkscrew math with radius shrinking as a
  function of distance, like being pulled into a drain. Reads well as a
  finale set-piece.
- **Wide sweeping canyon** - one or two big, low-frequency S-bends rather
  than repeated oscillation - emphasizes scale over rhythm, a different
  pacing character from Stage 3's constant weave.
- **Combined diagonal weave** - x and y oscillating together without a
  full rotation, a middle ground between Stage 3's weave and Stage 2's
  corkscrew.

Ideas that would need actual engine work first, not just a new stage-
definition file:

- **Widening/narrowing tube** - `StormTube.radius` is a single fixed
  value today, not distance-varying. A "breathing" tube needs real
  changes to `storm_tube.gd`'s mesh-building and lane-ring math, not just
  new route data.
- **Hazard density or behavior tied to tube radius** - depends on the
  above existing first.
