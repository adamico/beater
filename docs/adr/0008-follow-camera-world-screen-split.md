# Follow camera with a world-space / screen-space split

> **Status:** accepted. Supersedes [ADR-0002](0002-tunnel-wrap-clipped-render-target.md).

At 16:9 the static whole-maze view left ~53% of the screen empty and made the player sprite read tiny; the sprite's tall 64×96 canvas also cramped maze design (TG3). We split coordinates into **world space** (authoritative — all gameplay, physics, collision, beat-sync; unit `CELL_SIZE = 96` world px) and **screen space** (the 1280×720 output), bridged by a render-only **Camera** that follows the player so a zoomed-in maze scrolls. No gameplay code knows the camera exists.

`CELL_SIZE` is set to **96** specifically so the 64×96 player sprite renders **native and unscaled** — it fills one cell vertically, killing the "tall sprite constrains the maze" problem — and so the camera runs at a fixed integer **`zoom = 1.0`** (96 screen px/cell, pixel-perfect, ~13×7.5 cells visible). `zoom` stays a real `Camera` parameter for future settings/accessibility but is not exposed or animated.

The camera is **asymmetric by axis**, a direct consequence of the maze topology (ADR-0001): **Y clamps** to maze bounds (never shows void above/below), **X never clamps** — it follows freely and the world is drawn **modulo world-width**, so seam-straddling content is drawn twice and tiles seamlessly. This replaces ADR-0002's static clipped target. Follow style is hard-lock (camera centre = player centre) with eased directional look-ahead deferred to playtest.

## Considered Options

- **Bump `CELL_SIZE` on a static camera** — capped at ~21px by the 34-row maze height; barely helps, doesn't fix the tall-sprite constraint. Rejected.
- **Redesign the maze shorter** — discards Pac-Man layout fidelity, still doesn't fix the tall sprite. Rejected.
- **`zoom` ≠ 1.0** — any non-integer zoom reintroduces sprite-scaling blur; `zoom = 2.0` shows a claustrophobic ~6.7×3.75 cells. Rejected.
- **Per-primitive camera transform, no render target** — simpler, but a render target is needed anyway for the planned minimap/radar (it needs the whole maze as a texture). Rejected in favour of the RT path.

## Consequences

- One **static `world_target`** render target holds walls only (drawn once, 2880×3264). Pellets stay live primitives (cheap, ~240/frame, and the minimap gets them for free); actors/projectiles are always live primitives on top. Main view blits the camera sub-rect 1–2× for the seam.
- `GridProjection` keeps grid→world mapping but its `offset_x/offset_y` go to 0 (`OFFSET_X`/`OFFSET_Y` deleted) — all translation moves into the `Camera`. `Game` owns `@camera`, updates it after player movement, before render.
- World-space sizes (pellets, sprites) become `CELL_SIZE`-relative so they never drift again; the player sprite-scale chain is deleted. Screen-space UI (HUD ammo row) is tuned against the viewport directly. The eat-freeze popup is world-anchored and camera-transformed.
- Input needs no inverse transform — control is keyboard-only, no screen→world picking.
