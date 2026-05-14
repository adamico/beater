# Follow camera with a world-space / screen-space split

> **Status:** accepted. Supersedes [ADR-0002](0002-tunnel-wrap-clipped-render-target.md).

At 16:9 the static whole-maze view left ~53% of the screen empty and made the player sprite read tiny; the sprite's tall 64×96 canvas also cramped maze design (TG3). We split coordinates into **world space** (authoritative — all gameplay, physics, collision, beat-sync; the unit is the cell) and **screen space** (the 1280×720 output), bridged by a render-only **Camera** that follows the player so a zoomed-in maze scrolls. No gameplay code knows the camera exists.

`CELL_SIZE` is derived as **half the player sprite height** (`Player::PLAYER_SPRITE_HEIGHT / 2` = 48 world px). The sprite renders **native and unscaled**, spanning a 2×2 cell area — playtest showed this reads better than a 1-cell sprite: a 2-cell-wide tunnel then spans exactly one sprite height, so the player fits the tunnel cleanly and the tall canvas no longer cramps maze design. The camera runs at a fixed integer **`zoom = 1.0`** (48 screen px/cell, pixel-perfect). `zoom` stays a real `Camera` parameter for future settings/accessibility but is not exposed or animated.

> **Note:** `CELL_SIZE` was initially set to 96 (sprite fits one cell). Playtest landed on 48 — half the sprite height — with the sprite overhanging its logical 1-cell rect. The half-sprite-height derivation is the durable rule; the exact px value follows the sprite asset.

The camera is **asymmetric by axis**, a direct consequence of the maze topology (ADR-0001): **Y clamps** to maze bounds (never shows void above/below), **X never clamps** — it follows freely and the world is drawn **modulo world-width**, so seam-straddling content is drawn twice and tiles seamlessly. This replaces ADR-0002's static clipped target. Follow style is hard-lock (camera centre = player centre).

**Directional look-ahead** (TG3, resolved in playtest): the camera leads the player along the travel axis by an eased 2D offset — target = `direction * lead-cells * CELL_SIZE`, eased per-frame (`offset += (target - offset) * ease`), decaying to zero when the player is stopped. The lead is configured per-axis in **cells** (`LOOK_AHEAD_CELLS_X/Y`) rather than as a viewport fraction: a 16:9 viewport already shows less vertically, so leading the same cell count both ways deliberately spends more of the budget on the scarce vertical dimension. The Y-clamp is applied *after* the offset, so look-ahead near the maze top/bottom is simply clamped away. The minimap idea floated in TG3 was dropped — the level is small and ghosts are usually already on-screen.

## Amendment — eased camera during `Dying` (2026-05-14)

Hard-lock holds for `playing`. One exception: the `Dying` `Game state`. On player death the actors teleport back to their spawn cells, which under hard-lock teleported the camera too — playtest judged the snap "not a very good effect." During `Dying` phase 2 the camera therefore **leaves hard-lock** and eases from its current position to the reset player: ease-in-out, duration proportional to distance (clamped to a min/max frame range), taking the **short toroidal path** on X to stay consistent with the modulo-world-width draw. It snaps back to hard-lock the frame `dying → playing` fires. This stays render-only — it never feeds back into physics, so the ADR's core split is intact; only the *follow style* is state-dependent. See `CONTEXT.md` **Dying** / **Camera**.

## Considered Options

- **Bump `CELL_SIZE` on a static camera** — capped at ~21px by the 34-row maze height; barely helps, doesn't fix the tall-sprite constraint. Rejected.
- **Redesign the maze shorter** — discards Pac-Man layout fidelity, still doesn't fix the tall sprite. Rejected.
- **`zoom` ≠ 1.0** — any non-integer zoom reintroduces sprite-scaling blur; `zoom = 2.0` shows a claustrophobic ~6.7×3.75 cells. Rejected.
- **Per-primitive camera transform, no render target** — simpler, but a render target is needed anyway for the planned minimap/radar (it needs the whole maze as a texture). Rejected in favour of the RT path.

## Consequences

- One **static `world_target`** render target holds walls only (drawn once, sized `playfield_w × playfield_h`). Pellets stay live primitives (cheap, ~240/frame, and the minimap gets them for free); actors/projectiles are always live primitives on top. Main view blits the camera sub-rect 1–2× for the seam.
- `GridProjection` keeps grid→world mapping but its `offset_x/offset_y` go to 0 (`OFFSET_X`/`OFFSET_Y` deleted) — all translation moves into the `Camera`. `Game` owns `@camera`, updates it after player movement, before render.
- World-space sizes (pellets, sprites) become `CELL_SIZE`-relative so they never drift again; the player sprite-scale chain is deleted. Screen-space UI (HUD ammo row) is tuned against the viewport directly. The eat-freeze popup is world-anchored and camera-transformed.
- Input needs no inverse transform — control is keyboard-only, no screen→world picking.
