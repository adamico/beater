# Beater — domain language

Maze chase game with a rhythm hook. Diverges from OG Pac-Man where called out. ADRs in [docs/adr/](docs/adr/).

## Terms

- **Ammo** — integer count of bullets the player currently holds. Starts at 0 on each new level, increases by `AMMO_PER_POWER_PELLET` (= 5) per power-pellet pickup, no cap. Decremented by 1 per fired bullet. Carries across player death; resets to 0 on level complete. See [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md).

- **Fire input** — edge-triggered key press (Space / controller south) that spends one ammo and spawns a projectile in the player's current travel direction. No-op when ammo is 0 or `player.direction == NONE`. No rate limit beyond edge-trigger.

- **Empty-mag** — fire input pressed with 0 ammo. Silent no-op; HUD already signals 0 via the icon row.

- **Projectile** — bullet spawned by the fire input. Travels at 2× player speed in the firing direction. Walls stop, tunnels wrap. Despawns on wall hit or any non-(eaten, in-house) ghost contact. A frightened/vulnerable ghost variant no longer exists — bullets kill any active ghost via `EatSequencer.on_ghost_eaten`. In-flight count is uncapped; cleared on player death and level complete. See [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md).

- **Body-contact** — overlap between player rect and any non-house, non-eaten ghost rect. Always fatal to the player. Originally introduced in ADR-0006 and unchanged by ADR-0007.

- **Eat chain** — running multiplier (200 → 400 → 800 → 1600) applied on consecutive ghost kills, owned by `EatSequencer`. Reset boundary is currently unbounded for the level — the frightened-window reset was removed when frightened state was deleted; the planned combo-bonus rework will introduce a time-windowed reset (see [docs/TODO.md](docs/TODO.md) grill backlog).

- **Eat freeze** — short pause the game enters when a ghost is killed; popup is shown via `EatSequencer.popup`. Other contacts cannot resolve during the freeze. Retained under ADR-0007; tuning deferred to playtest.

- **HUD ammo row** — bottom-strip readout: up to 5 bullet icons, with a `+` glyph appended when ammo exceeds 5. Always visible.

- **Tunnel** — explicit `t`-marked cell that slows ghosts and wraps movement toroidally on X. See [ADR-0005](docs/adr/0005-explicit-tunnel-tile.md), [ADR-0001](docs/adr/0001-toroidal-maze-x-axis.md).

- **Role** — passability class on a tile (player, ghost, ghost-eaten, ghost-leaving). Drives which actors can enter. See [ADR-0004](docs/adr/0004-passability-roles-via-tiles.md).

- **World space** — authoritative coordinate space for all gameplay, physics, collision and beat-sync. Unit is the cell: `CELL_SIZE = 96` world px (chosen so the 64×96 player sprite renders native, unscaled, fitting one cell vertically). Frozen w.r.t. the camera — no gameplay code knows the camera exists.

- **Screen space** — final pixel space of the 1280×720 output. HUD and popups live here directly. Actors / maze / pellets live in world space and are mapped to screen space by the **Camera**.

- **Camera** — pure view transform (world → screen): a `zoom` factor plus translation. Render-only; never feeds back into physics. Follows the player (hard-lock) so the zoomed-in maze scrolls: Y clamps to maze bounds, X follows freely and draws the world modulo world-width. Fixed `zoom = 1.0`. See [ADR-0008](docs/adr/0008-follow-camera-world-screen-split.md).
