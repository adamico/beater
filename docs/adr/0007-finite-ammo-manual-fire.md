# Finite-ammo manual fire; frightened state removed

Supersedes [ADR-0006](0006-power-pellet-projectiles.md). The auto-fire-on-downbeat model proved to be a half-step away from OG rather than a real divergence: the frightened state still flipped ghost AI and the power pellet still defined a tense armed window. The mechanic now diverges all the way, in the Lady Bug / Lady Tut direction.

A power pellet grants 5 bullets to the player's ammo pool. Ammo stacks across pickups with no cap and starts at 0 on a fresh level. Firing is manual — Space on keyboard or the controller's south button, edge-triggered (one press → one bullet) — and travels in the player's current logical direction. When the player has no direction (stationary at spawn), fire is a no-op; when ammo is 0, fire is a silent no-op. Bullets behave exactly as in ADR-0006: pixel motion at 2× player speed, walls stop them, tunnels wrap them, despawn on wall or ghost contact. A bullet hitting any active ghost (chase, scatter, leaving) routes through `EatSequencer.on_ghost_eaten`, sending the ghost to `:eaten` and through the existing return-to-house / `ReleaseSchedule` rerelease. Bullets pass through `:eaten` and `:in_house` ghosts. Body-contact with any non-house, non-eaten ghost kills the player. The eat-freeze on kill is retained; tuning deferred to playtest.

The frightened state is removed in full: `FrightenedTimer`, `GhostStateMachine#enter_frightened` / `#restore_from_frightened`, `GhostControllers::Frightened`, `Ghost#frightened_sprite` and `FRIGHTENED_FLASH_*`, `GHOST_FRIGHTENED_SPEED` / `_RATIO`, the phase-scheduler pause-while-frightened argument, `ghost_eat_imminent?` and its audio duck call all retire. The power pellet pickup keeps firing `audio.on_power_pellet` for now (the cue still means "something significant happened"); a proper "ammo gained" SFX is deferred to the audio pass. `EatSequencer.reset_chain` loses both of its callers — the chain runs unbounded for the level until the combo-bonus rework replaces it (see [docs/TODO.md](../TODO.md) grill backlog).

HUD: a bullet-icon row anchored to the bottom strip below the maze, always visible. Up to 5 icons render; ammo above 5 renders as `5×icon` followed by a `+` glyph. The underlying counter remains uncapped; only the readout is clamped.

Lifecycle: bullets in flight are unbounded; both player death and level complete clear the projectile list. Ammo carries across player death (earned resource, not punished by it) and resets to 0 on level complete.

Rejected — keep ADR-0006's auto-fire on downbeats: the rhythm-lock was elegant but removed player agency over a finite resource. Auto-firing N free bullets per pellet is functionally equivalent to "frightened window," just with a projectile in flight. Manual fire makes ammo a decision.

Rejected — keep frightened state alongside finite ammo as a brief panic window: doubles the surface (ammo + timer + state flip + flee AI + frightened sprite). The point of moving to finite ammo is to collapse "armed window" and "ghost behavior" into one resource. Cosmetic panic does not justify the retained complexity.

Rejected — ammo cap (refill-to-5, or pickup-wasted-at-cap): collapses early/late-game ammo economy and punishes well-timed hoarding. The board's 4 pellets × 5 bullets already caps theoretical maximum at 20, which is below the kill ceiling.

Rejected — bullets stun rather than kill: spends a precious bullet to delay a threat. Reads as a weak weapon and forces a new "stunned" state plus timer. Killing reuses the existing `:eaten` plumbing for free.

Rejected — bullet rate limit beyond edge-trigger: ammo is already the cap. A min-cooldown adds a second invisible resource and would feel arbitrary on top of finite ammo.

Rejected — empty-mag click SFX or HUD flash: the icon row already telegraphs 0; layering audio/visual feedback on every empty press becomes noise during chases.

Cost: a chunk of code retires (timer, controller, sprite branches, audio duck plumbing), one test file deletes ([ghost_frightened_controller_tests.rb](../../dragonruby-macos/mygame/tests/ghost_frightened_controller_tests.rb)), and the existing eat-chain has no clean reset boundary until the combo-bonus grill lands. New surface — ammo container, fire-input edge detection, HUD stub — but the projectile motion + collision code from ADR-0006 carries over unchanged.
