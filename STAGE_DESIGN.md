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
everything at higher density than before. There's still no gate — density
and combination alone carry the climax, which is the point: phase 5 didn't
need a capstone mechanic to land. See `scripts/stage_one_definition.gd` and
`BACKLOG.md` for any remaining open stage-content decisions.
