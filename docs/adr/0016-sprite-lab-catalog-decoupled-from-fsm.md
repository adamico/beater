# ADR-0016: Sprite Lab catalog decoupled from FSM state

## Status

Accepted — 2026-05-18

## Context

`Sprite Lab` is a dev-only scene (hidden in production via `$gtk.production?`)
that previews every entity sprite in every visual configuration so artwork
and animation changes can be eyeballed without driving the actor into the
relevant `Game state` through gameplay.

The obvious source for the "states" axis is the actor's FSM: enumerate
`Ghost`'s states (`:scatter`, `:chase`, `:eaten`, `:in_house`, `:imprisoned`,
…) and `Game state` (`:dying`, etc.) and show one menu item per value. This
is wrong in both directions:

- **The FSM under-specifies what the renderer actually does.** A ghost in
  `:chase` looks different depending on `enrage_step` (red overlay at
  `:enrage1`, stronger red + beat pulse at `:enrage2`), `armor_flash_ticks`
  (per-hit white flash), and the eaten-hit scale pulse. None of those are
  FSM states. A single FSM state maps to many distinct rendered outputs.
- **The FSM over-specifies what the lab needs.** `:in_house` and most
  transient transition states render identically to `:scatter` for the
  artist's purposes — listing them adds noise without payoff.

Either FSM-driven approach also couples the lab to internals it has no
business reading (state-machine constants, transition tables), which would
turn artwork-only changes into refactors of the lab.

## Decision

Sprite Lab owns a **catalog** — a hash declared in the scene file mapping
`entity → { state_label => lambda(ctx) }`. Each lambda returns the sprite
hash for the current tick using a real `Player` / `Ghost` instance held by
the catalog entry. Render-affecting state (`enrage_step`, `armor_flash`,
death-anim elapsed, …) is orthogonal: modifier toggles bound to keys mutate
the held instance before its `to_sprite` is invoked.

The catalog is the single source of "what's previewable." Adding a new
visual configuration = adding a catalog entry, not touching the FSM or its
consumers.

## Consequences

- Lab stays correct when actor render code changes (it calls `to_sprite` on
  the real class) but **does not** track new FSM states automatically — a
  new state that affects rendering needs a catalog entry. This is the right
  trade-off: not every FSM addition is visually distinct, and silently
  surfacing them would mislead the artist.
- The catalog duplicates a small amount of knowledge about which states
  matter visually. Acceptable: that list changes on the order of "when we
  add a new visual," which is also when the catalog needs editing anyway.
- Render-affecting state is a first-class concept in `CONTEXT.md` —
  documenting that visual modifiers live outside the FSM helps future
  readers understand why the lab's axes are split the way they are.
- The lab owns no `Game` instance and produces no audio, so its scene
  lifecycle in `main.rb` is trivial (drop the instance on swap-to-title,
  lazy-init on entry) — no `Audio::NativeBridge.reset_runtime_state!` dance.
