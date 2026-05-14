# Beater — domain language

Maze chase game with a rhythm hook. Diverges from OG Pac-Man where called out. ADRs in [docs/adr/](docs/adr/).

## Terms

- **Game state** — top-level state of a single run, owned by `Game`. One of `ready` (level intro, only at level start — not on respawn), `playing`, `dying`, `level_complete`, `game_over`. Transitions: `ready → playing`, `playing → dying`, `dying → playing` (respawn) or `dying → game_over` (no lives left), `playing → level_complete → ready` (next level). Replaces the former `@level_complete` boolean.

- **Life** — integer count of player retries in a run. Starts at 3 on new game. Carries across levels and across death; reset to 3 only on new-game-from-title. Decremented by 1 on entering `dying`. Reaching 0 routes `dying → game_over` instead of respawn. Losing a life does not reset `Ammo` (ammo carry-across is unchanged — see [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md)). No extra-life-from-score mechanic in the first slice (deferred).

- **Track** — one of the 4 music stems (`drums`, `bass`, `lead`, `chords`), each bound to a dot color via `Audio::Manager::DOT_COLORS` (red→drums, green→bass, blue→lead, yellow→chords). Eating a dot of a color advances its track.

- **Track completion** — per-`Track` progress ratio: dots eaten of that color ÷ total dots of that color in the level. Dot-based only (not time/score). Drives the audio progression mix and the HUD's 4 track meters. Backed by a live remaining-by-color counter on `Pellets` (decremented on eat), not a rescan. Reaching 100% (the colour's last dot eaten) awards a flat **1000-point track-completion bonus** (G1), fired per-track the instant the count hits 0 — with a score popup at that dot's cell, a HUD meter flash, and an audio stinger. Unlike `Eat freeze` it does not freeze the world. The popup runs on a `Game`-owned path, not `EatSequencer`.

- **HUD** — screen-space overlay. Shows score (run-long total), `Life` count as a row of player-sprite icons, the `HUD ammo row`, and 4 `Track completion` meters. Visible in `ready` / `playing` / `dying`; replaced by the centered "GAME OVER" label in `game_over`.

- **Ready** — level-intro `Game state`, entered at level start only (not on respawn). Actors placed and frozen; a beat-synced count-in (≈1 bar at `LEVEL_BPM`) plays metronome clicks, no track. Automatic `ready → playing` at count-in end, no input gate.

- **Dying** — `Game state` entered on `Body-contact`. World frozen (reuse the `EatSequencer.frozen?` pattern). Two phases: (1) fixed-frame death animation (~30–40 frames, not beat-synced) with music ducked out on an ease-out; (2) actors teleport to spawn cells, projectiles cleared, phase scheduler reset, then the `Camera` eases from its current position to the reset player while music eases back in to the current track-completion mix levels. Exits automatically: `dying → playing` when the ease completes if `Life > 0` (decremented on entry), else `dying → game_over`.

- **Game over** — terminal `Game state` reached from `dying` when `Life` hits 0. Shows a bare centered "GAME OVER" / "press any key" label (UI5 proper screen deferred). Press-any-key triggers a full `Game` rebuild via `request_game_reset` — the only remaining full-rebuild path. Title-screen routing wired in when UI1 lands.

- **Level** — integer difficulty index of the current run, owned by `Game`, starting at 1. Incremented in `start_next_level` (the in-place level loop); reset to 1 only by a full `Game` rebuild (game-over → `request_game_reset`). Drives `LevelConfig` lookups for ghost speed ratios, ghost tunnel speed, Cruise Elroy dot thresholds/speeds, and the scatter/chase phase table — all seeded through a single `Game#apply_level_config` seam called from `initialize` (level 1) and `start_next_level`. Pac-Man's own speed does **not** scale with level: it stays beat-locked at 4 cells/beat regardless (see [ADR-0009](docs/adr/0009-pac-man-speed-stays-beat-locked.md)). Not shown in the `HUD` — the OG communicates level only via the deferred fruit/bonus row, never a number.

- **LevelConfig** — frozen per-`Level` data table (`app/level_config.rb`) ported from the OG *Pac-Man Dossier* Table A.1 ([docs/OG/pacman_dossier_extracts.md](docs/OG/pacman_dossier_extracts.md)). Returns ghost speed/tunnel ratios, Elroy 1/2 dot thresholds and speed ratios, and the scatter/chase phase table for a given level; levels past the last explicit row clamp to it (the dossier's "21+" row). Speed values are **ratios** of `PLAYER_SPEED`, not absolute speeds, keeping the beat the single tempo source of truth. Elroy ratios may exceed 1.0 (faster than Pac-Man) from level 5 on — intended. The Fright. and Bonus columns of Table A.1 are unused (no frightened state per [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md), no fruit system yet).

- **Territory** — the dot quadrant owned by the ghost that scatters to its corner: red/top-left→Pinky, green/top-right→Blinky, blue/bottom-left→Clyde, yellow/bottom-right→Inky. The mapping falls out of existing scatter-target geometry. Dot colours are recoloured to match the owner ghost's identity colour, and the maze floor carries a subtle per-`Territory` tint. Designed but not yet implemented — see [ADR-0010](docs/adr/0010-quadrant-territory-enrage.md).

- **Enrage** — a ghost's discrete escalation level, keyed to its `Territory`'s clearance %. Monotonic (eaten dots never return). Staged: lower steps tighten targeting (ignore scatter, won't retreat to corner), higher steps ramp speed. Step thresholds are per-`Level` and steepen as levels rise. Replaces `Cruise Elroy` — the generalisation of Elroy to all four ghosts, region-scoped — so `LevelConfig`'s Elroy columns re-scope from maze-wide dot counts to per-`Territory` thresholds. The HUD's 4 colour meters are repurposed from `Track completion` to Enrage gauges. See [ADR-0010](docs/adr/0010-quadrant-territory-enrage.md).

- **Pacify** — finishing a `Territory` (its last colour dot eaten, on `Pellets#eat`'s `track_cleared` event) permanently despawns its owner ghost for the rest of the level, plus an `Enrage`-scaled score bonus. The carrot to Enrage's stick; a four-toothed difficulty sawtooth across a level. Persists through player death (clearance isn't reset). `ReleaseSchedule` skips despawned ghosts. Currently a plain despawn; a maze-layout prison cell that visibly traps the ghost is a deferred upgrade. See [ADR-0010](docs/adr/0010-quadrant-territory-enrage.md).

- **Ammo** — integer count of bullets the player currently holds. Starts at 0 on each new level, increases by `AMMO_PER_POWER_PELLET` (= 5) per power-pellet pickup, no cap. Decremented by 1 per fired bullet. Carries across player death; resets to 0 on level complete. See [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md).

- **Fire input** — edge-triggered key press (Space / controller south) that spends one ammo and spawns a projectile in the player's current travel direction. No-op when ammo is 0 or `player.direction == NONE`. No rate limit beyond edge-trigger.

- **Empty-mag** — fire input pressed with 0 ammo. Silent no-op; HUD already signals 0 via the icon row.

- **Projectile** — bullet spawned by the fire input. Travels at 2× player speed in the firing direction. Walls stop, tunnels wrap. Despawns on wall hit or any non-(eaten, in-house) ghost contact. A frightened/vulnerable ghost variant no longer exists — bullets kill any active ghost via `EatSequencer.on_ghost_eaten`. In-flight count is uncapped; cleared on player death and level complete. See [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md).

- **Body-contact** — overlap between player rect and any non-house, non-eaten ghost rect. Always fatal to the player. Originally introduced in ADR-0006 and unchanged by ADR-0007.

- **Eat chain** — time-windowed combo bonus owned by `EatSequencer` (G2). Consecutive ghost kills escalate the award through 200 → 400 → 800 → 1600 (capped). Each kill arms a `CHAIN_TIMEOUT_TICKS` window (180 ticks, ~3s); a kill within the window escalates, otherwise the chain resets to 200. Replaces the OG frightened-window chain — frightened state was deleted in [ADR-0007](docs/adr/0007-finite-ammo-manual-fire.md), so the chain is now bounded only by the timer, not by a power-pellet window.

- **Eat freeze** — short pause the game enters when a ghost is killed; popup is shown via `EatSequencer.popup`. Other contacts cannot resolve during the freeze. Retained under ADR-0007; tuning deferred to playtest.

- **HUD ammo row** — bottom-strip readout: up to 5 bullet icons, with a `+` glyph appended when ammo exceeds 5. Always visible.

- **Tunnel** — explicit `t`-marked cell that slows ghosts and wraps movement toroidally on X. See [ADR-0005](docs/adr/0005-explicit-tunnel-tile.md), [ADR-0001](docs/adr/0001-toroidal-maze-x-axis.md).

- **Role** — passability class on a tile (player, ghost, ghost-eaten, ghost-leaving). Drives which actors can enter. See [ADR-0004](docs/adr/0004-passability-roles-via-tiles.md).

- **World space** — authoritative coordinate space for all gameplay, physics, collision and beat-sync. Unit is the cell: `CELL_SIZE` = half the player sprite height (`Player::PLAYER_SPRITE_HEIGHT / 2` = 48 world px). The 64×96 player sprite renders native and unscaled, spanning a 2×2 cell area — a 2-cell tunnel then matches the sprite height exactly. Frozen w.r.t. the camera — no gameplay code knows the camera exists. See [ADR-0008](docs/adr/0008-follow-camera-world-screen-split.md).

- **Screen space** — final pixel space of the 1280×720 output. HUD and popups live here directly. Actors / maze / pellets live in world space and are mapped to screen space by the **Camera**.

- **Camera** — pure view transform (world → screen): a `zoom` factor plus translation. Render-only; never feeds back into physics. Follows the player (hard-lock) so the zoomed-in maze scrolls: Y clamps to maze bounds, X follows freely and draws the world modulo world-width. Fixed `zoom = 1.0`. During `Dying` phase 2 the camera leaves hard-lock and eases (ease-in-out, duration proportional to distance clamped to a min/max frame range, short toroidal path on X) from its current position to the reset player, then snaps back to hard-lock the frame `dying → playing` fires. See [ADR-0008](docs/adr/0008-follow-camera-world-screen-split.md).
