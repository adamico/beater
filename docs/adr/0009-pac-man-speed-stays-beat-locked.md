# Pac-Man's own speed stays beat-locked; level progression scales ghosts only

Level progression ports the per-level difficulty data from the OG (the *Pac-Man Dossier* Table A.1 — see [docs/OG/pacman_dossier_extracts.md](../OG/pacman_dossier_extracts.md)) into a `LevelConfig` lookup: ghost speed ratios, ghost tunnel speed, Cruise Elroy dot thresholds and speeds, and the scatter/chase phase table all advance with the level. Table A.1's **Pac-Man Speed** and **Pac-Man Dots Speed** columns (which drop to 0.9 on levels 2–4 and 21+) are deliberately *not* applied — Pac-Man's traversal speed stays fixed at `PLAYER_SPEED = CELL_SIZE / FRAMES_PER_CELL`, i.e. exactly 4 cells per beat.

The reason is the rhythm hook. Pac-Man's motion is beat-locked by design (ADR-0001 in `dragonruby-macos/mygame/docs/adr/`, and the "Tempo source of truth" / "Beat step" terms in CONTEXT.md): the music is built on him crossing 4 cells per beat. Scaling his base speed by 0.9 would drift him off that grid, desyncing the core hook from the visuals for the sake of OG fidelity on a single column. Ghosts are not beat-locked, so scaling *their* speeds per level is free and is the real difficulty curve anyway.

Rejected — apply per-level Pac-Man speed and accept the beat drift: faithful to the OG but breaks the one mechanic that makes Beater not-Pac-Man.

Rejected — apply it but re-derive BPM per level so 4 cells/beat still holds: couples difficulty progression to musical tempo, which the track design does not want; difficulty would become un-tunable without re-cutting the stems.

Consequence: `LevelConfig` has no Pac-Man-speed entry, and the player is never re-seeded on level change (`apply_level_config` touches ghosts, Elroy thresholds, and the phase scheduler only). The Fright. and Bonus columns of Table A.1 are also unused — frightened state was removed in [ADR-0007](0007-finite-ammo-manual-fire.md) and no fruit/bonus system exists yet.
