# Beater — domain language

Maze chase game with a rhythm hook. Diverges from OG Pac-Man where called out. ADRs in [docs/adr/](docs/adr/).

## Terms

- **Frightened window** — the timed state opened by a power pellet during which ghosts flee and the player can kill them. Length owned by `FrightenedTimer`. In Beater, this is also the *armed window* for the player's auto-fire (see [Projectile](#projectile-fire)).

- **Projectile / fire** — while the frightened window is active, the player automatically emits one projectile per downbeat (and one immediately on pellet pickup), travelling in `player.direction`. Projectiles obey maze passability — walls stop, tunnels wrap. They despawn on wall hit or any ghost hit. Frightened-ghost hit routes through `EatSequencer.on_ghost_eaten`. Eaten ghosts (eyes-home) are passed through. See [ADR-0006](docs/adr/0006-power-pellet-projectiles.md).

- **Body-contact** — overlap between player rect and any ghost rect. Always fatal to the player in Beater, regardless of ghost state. The OG behavior where body-contact eats a frightened ghost is removed; projectiles are the only kill path. See [ADR-0006](docs/adr/0006-power-pellet-projectiles.md).

- **Downbeat** — beat-clock step where `step % STEPS_PER_BEAT == 0`. Quarter-note pulse at the running BPM. The cadence anchor for player auto-fire.

- **Eat chain** — running multiplier (200 → 400 → 800 → 1600) for consecutive ghost kills within one frightened window. Owned by `EatSequencer`. Resets when the frightened window ends. Multi-kill in a single tick is ordered by projectile spawn age, but in practice the eat-freeze prevents this from compounding.

- **Eat freeze** — short pause the game enters when a ghost is killed; popup is shown via `EatSequencer.popup`. Subsequent projectile/ghost contacts cannot resolve during the freeze.

- **Tunnel** — explicit `t`-marked cell that slows ghosts and wraps movement toroidally on X. See [ADR-0005](docs/adr/0005-explicit-tunnel-tile.md), [ADR-0001](docs/adr/0001-toroidal-maze-x-axis.md).

- **Role** — passability class on a tile (player, ghost, ghost-eaten, ghost-leaving). Drives which actors can enter. See [ADR-0004](docs/adr/0004-passability-roles-via-tiles.md).
