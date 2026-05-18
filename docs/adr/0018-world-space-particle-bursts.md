# 18. World-space particle bursts

Date: 2026-05-18

## Status

Accepted

## Context

The TODO calls for particles on three triggers — dot collection, ghost
hits, player shooting. They are render-only juice, but more structurally
involved than [ADR-0017](0017-screen-shake-on-player-hit.md) (screen
shake), since they:

- have many concurrent instances (vs one shake at a time),
- spawn at specific world points (not view-wide),
- need a render path the existing primitive flow can absorb.

Open decisions: where they live, what coordinate space, who ticks them,
how to bound count.

## Decision

Tracer-bullet ships **dot-collection only**. Ghost-hit + shooting reuse
the same `Particles` API in follow-ups, no system churn.

- **Data model**: plain `Array` of `Hash` particles in `Particles#list`
  (no SoA, no object pool). Hash shape matches DR primitives so renders
  blit straight into `outputs.solids`.
- **Soft cap**: `MAX_PARTICLES = 256`. Overflow drops the oldest via
  `Array#shift`. Backpressure under pathological eat-rates without
  needing a pool.
- **Coordinate space**: **world**. Burst spawns at the eaten cell's
  centre; particles travel ~½ cell. Camera-transformed via the existing
  `Renderer#project` seam, so they inherit toroidal X seam handling and
  the ADR-0017 screen shake for free.
- **Ownership**: `Game`-owned `@particles` (matches `@projectiles`,
  `@track_popups`). No `args.state` global — particles don't outlive a
  `Game` instance.
- **Spawn seam**: `Game#player_eat_pellets`, right after
  `@pellets.eat(...)`. The eat path already knows the cell + colour;
  no new event channel needed.
- **Recipe** (`Particles::DOT_BURST_*`): 6 particles per dot, 12 per
  power-pellet (white), 4×4 world px squares, random direction at
  1.5–3.0 px/frame, 18-frame lifetime, linear alpha fade. No gravity.
- **Tick**: `Particles#tick` called once per `tick_playing`. Frozen in
  `paused` / `dying` / `eat_freeze` — mirrors `Play clock`
  ([ADR-0013](0013-play-clock-pause-excluded.md)) and the [ADR-0017]
  shake. A pause-mid-burst resumes the same particles in flight.
- **Render order**: above pellets, below actors + HUD. Cleared per-
  `Game` rebuild via `@particles = Particles.new` in `initialize`.
- **REDUCED FLASH**: ignored. Particles are diegetic eat-confirmation,
  not strobe — the setting gates jolts (screen shake) only.

## Consequences

- One new module, one tick call, one spawn call, one renderer method.
  No new event bus, no scene plumbing.
- Hash-per-particle creates short-lived GC pressure; profile once
  ghost-hit + shooting are wired, before reaching for a pool.
- `Particles#burst` generalises: ghost-hit follow-up calls it with a
  white/red recipe at the ghost centre; muzzle-flash calls it with a
  directional recipe at the player nose. No interface change planned.
- Bursts seam-wrap correctly via `project()`, including bursts spawned
  on a tunnel cell. Verified by reading the seam, not by test.
