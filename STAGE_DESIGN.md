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
   nothing left to show. The contrast with phase 5 is the point: the drop
   only pays off if the player believes it.

5. **Fight to the finish** — maximum density, combining everything the
   stage has introduced. This should end at something the player can see
   and aim for, not just a number ticking over. A gate (existing mechanic)
   is the natural finish line; a stage that has no gate mechanic yet is
   worth reconsidering rather than defaulting to "the road just stops."

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
- Check the shape by reading the stage definition file as a distance-sorted
  list and asking: where's the empty runway, where's the first unfamiliar
  thing, where does it combine with what's known, where's the exhale, where
  does it peak, and what's the player looking at when it ends?

## Current gap (Stage 1)

Stage 1 already has phase 1 (empty 0–720) and a rough version of phases 2–3
(flipper → spiker → splitter → pulsar → exploder, each debuting alone
before the mix at the end). It's missing phase 4: the run from the
`exploder` pair at 2600 straight into the final flipper/splitter/pulsar/
exploder mix at 2860 leaves no false-summit beat, so the finale reads as a
continuation of rising density rather than a deliberate spike. It also ends
on a bare route-length check with no gate, so there's nothing to aim at when
phase 5 resolves. See `BACKLOG.md` for other open stage-content decisions.
