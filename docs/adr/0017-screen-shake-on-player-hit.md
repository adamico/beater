# 17. Screen shake on player hit

Date: 2026-05-18

## Status

Accepted

## Context

The `playing -> dying` transition (`Body-contact`) has a death animation
+ audio duck but no kinaesthetic punch. Player TODO calls for "screen
shake on player hit" as polish-after-MVP.

The camera (ADR-0008) is the single world->screen seam, already owns the
`dying`-phase eased return, and already hard-clamps Y to maze bounds.
Anything that perturbs the view should go through it.

Open trade-offs at decision time:

1. **Where it lives** — `Camera` field vs separate `ScreenShake` module
   offsetting world + HUD together.
2. **Pause interaction** — should shake countdown advance in `paused`?
3. **Clamp interaction** — does shake nudge the camera before or after
   the Y clamp? At map extremes a post-clamp shake briefly reveals void.
4. **Accessibility** — the `REDUCED FLASH` setting (`GameSettings`)
   already gates flashy juice; should shake honour it?

## Decision

Add the shake to `Camera` directly, not a separate system.

- **Trigger**: `Game#enter_dying` calls `@camera.shake!` once on the
  edge — same seat that decrements `Life` and begins the death anim.
- **Curve**: trauma decays linearly over 24 frames; per-axis offset
  scales with `trauma**2 * 8 px * (rand * 2 - 1)`, regenerated every
  frame. `rand` is fine — shake is render-only, never feeds physics
  (ADR-0008).
- **Scope**: applied **post-clamp** inside `Camera#to_screen` /
  `Camera#screen_xs`. HUD lives in screen-space and is untouched —
  matches the existing render-coordinate split. Void may peek a few px
  at maze Y-extremes; accepted as cheap polish.
- **Pause-coherence**: `Camera#tick_shake` is only called from
  `tick_dying` (phase 1). It does not advance in `tick_paused`, so a
  pause-mid-shake resumes at the same trauma. Mirrors the `Play clock`
  pause-exclusion rule (ADR-0013).
- **Hand-off to phase 2**: `enter_dying`'s phase-1 -> phase-2 transition
  calls `Camera#clear_shake!` so the shake never fights the eased
  camera return (ADR-0008 amendment in that ADR).
- **Accessibility**: `Camera#shake!` is a no-op when
  `GameSettings.get(:reduced_flash)` is true. Full skip, not halve —
  the setting already implies "no jolts".

## Consequences

- One shake fields cluster lives on `Camera`; no new system. World blit
  (which goes through `to_screen(0, 0)` in `Renderer#draw_world`) and
  all primitive blits (via `screen_xs`) shake together, automatically.
- HUD never shakes, which is the conventional arcade choice and keeps
  the `Life` row / `Ammo row` legible during the death anim.
- `rand`-driven offset means tests assert the *envelope*
  (`shake_ticks`, `shaking?`, no-op under reduced-flash), not exact px
  per frame. Consistent with how ADR-0008 keeps render outside the
  sim-determinism contract.
- Future juice triggers (ghost-hit, bullet-impact) can call
  `Camera#shake!` with smaller `trauma:` values — the seam generalises
  without an interface change.
- A few px of void may show at maze top/bottom during a death there.
  Acceptable; re-clamping the shake would kill the effect exactly where
  the player most often dies.
