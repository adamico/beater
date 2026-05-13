# Power pellet fires projectiles; body-contact is always fatal

In OG Pac-Man, a power pellet flips ghosts to frightened and the player kills them by walking into them. We diverge: while the frightened window is active the player automatically emits projectiles in the direction of travel, and projectiles are the only way to kill a frightened ghost. Body-contact with any ghost — frightened or not — kills the player.

The mechanic plays to the rhythm hook. Firing cadence is locked to the beat clock (`Audio::BeatClock`): one shot on each downbeat (`step % STEPS_PER_BEAT == 0`) for the duration of the frightened timer, plus one immediate shot on pellet pickup so the input feedback is not delayed by up to a beat. Projectile motion itself is plain pixel-per-tick (2× player speed); only the firing cadence is musical. Projectiles obey maze passability the same as the player: walls stop them, tunnels wrap them toroidally. They despawn on wall hit or any ghost hit. Hitting a frightened ghost routes through the existing `EatSequencer.on_ghost_eaten`, preserving the 200/400/800/1600 chain and the eat-freeze. Non-frightened ghosts consume the projectile with no effect; eaten ghosts (eyes returning home) are passed through.

Rejected — keep body-contact eats for frightened ghosts and add projectiles as a bonus: the projectile becomes optional and the OG feel persists. The point of the divergence is to make the power pellet a ranged tool, not a melee tool with an accessory.

Rejected — one volley per pickup instead of a continuous powered window: makes "missing" punishing and discards the existing `FrightenedTimer` as the natural armed-window. A finite-ammo variant pushes a counter into the HUD, which is MVP scope creep.

Rejected — fire on every 16th-note step: ~8 shots/sec trivializes the hunt and clutters the screen. Every-beat is sparse enough to read, dense enough to feel powerful within a ~6s window.

Rejected — route shots through `RhythmicSfxQueue`: the music is already the cue on every downbeat, layering a shot SFX muddies the mix. `enemy_eaten` remains the audio payoff. Revisit during polish if game-feel demands it.

Rejected — reuse `GridMover` for projectiles: `GridMover` exists for cell-aligned actors with turn queuing and corner snapping. Projectiles travel straight and despawn on contact. Forcing the mixin adds friction with no payoff.

Cost: the first real OG divergence. Players coming from Pac-Man muscle memory will mash into frightened ghosts and die. Test surface grows (projectile motion, beat-locked firing, multi-projectile ordering, regression that body-contact still kills). Accepted — the divergence is the point of the game.
