# Dot quadrants are ghost territories; clearing one enrages then despawns its owner

Status: accepted (not yet implemented)

## Context

The maze's 4 dot quadrants carry a colour that, today, only drives the music mix and the HUD track meters. Mute the music and the colour — and the whole quadrant structure — is mechanically meaningless. Separately, ghost AI is already region-anchored (fixed scatter-corner targets), so quadrants and ghost behaviour share a spatial structure that the game never connects.

## Decision

Each dot quadrant is the **Territory** of the ghost that scatters to its corner — a mapping that falls out of existing geometry, no new config:

- red (top-left) → Pinky
- green (top-right) → Blinky
- blue (bottom-left) → Clyde
- yellow (bottom-right) → Inky

**Enrage (the stick).** As a territory is cleared, its owner escalates in **discrete steps** keyed to that quadrant's clearance %. Escalation is staged: lower steps tighten targeting (ignore scatter, won't retreat to corner — reusing the existing Elroy "targets Pac during scatter" path), higher steps ramp speed too. Enrage is **monotonic** — eaten dots never return, so it only ratchets up. Steps are tuned per `Level` and get steeper as levels rise.

**Pacify (the carrot).** Finishing a territory (its last colour dot eaten) **permanently despawns** its owner for the rest of the level — hooked onto `Pellets#eat`'s existing `track_cleared` event, alongside the G1 bonus. The risk-reward arc per quadrant: intrude → enrage → escalating danger → clear → that ghost is *out*. Four quadrants = four boss gauntlets. An enrage-scaled score bonus stacks on top (deeper enrage at the moment of completion → bigger payout). The level's difficulty is a four-toothed sawtooth, not a monotonic ramp.

**Enrage replaces Cruise Elroy.** Per-quadrant enrage is the generalisation of Elroy ("Blinky escalates as the maze depletes") to all four ghosts, region-scoped. `CruiseElroy` is deleted; Blinky becomes the green-territory case of the general mechanic. This supersedes the Elroy data shape shipped in [ADR-0009](0009-pac-man-speed-stays-beat-locked.md)'s `LevelConfig` — the Elroy dots/speed columns are re-scoped from maze-wide dot counts to per-quadrant clearance thresholds.

**Shooting stays purely tactical.** Projectiles ([ADR-0007](0007-finite-ammo-manual-fire.md)) remain a temporary removal (ghost → house → respawn) and never touch enrage. A ghost respawning from the house reads its current enrage step fresh from its territory's clearance. The two tools stay distinct: shoot = tactical pause, clear = strategic, permanent solution.

**Colours follow ownership.** Quadrant dot colours are recoloured to match their owner ghost's identity colour (dot colour *is* the ghost), and the maze floor gets a subtle per-territory tint. The HUD's 4 colour-keyed meters are repurposed from music-progress to **enrage / territory gauges** — making the system fully legible with sound off. `Audio::Manager::DOT_COLORS` simply remaps; which track a ghost-colour drives is arbitrary.

**Lifecycle.** Everything keys off monotonic quadrant clearance, so edge cases resolve without special-casing: enrage and despawns **persist through player death** (clearance isn't reset); `ReleaseSchedule` skips despawned ghosts (a ghost still in the house when its quadrant clears despawns from inside); `apply_phase` no-ops on despawned ghosts. `inky_target` already falls back to direct Pac-targeting when Blinky is absent, so despawning Blinky needs no extra handling.

## Consequences

- Every level now ends with a ghost-free victory lap (all dots eaten = all ghosts pacified). Embraced as the earned exhale; the last-cleared quadrant gets a steeper final-stand enrage curve so the level peaks before it fizzles.
- The 4 uncolored power pellets stay fully outside the territory system (ammo only, as today).
- `LevelConfig` rows need revisiting — Elroy columns re-scoped to per-quadrant enrage thresholds.
- **Accessibility caveat:** colour-coding is load-bearing for this mechanic. Needs a non-colour channel — distinct dot *shape* per territory, and a ghost-identity icon on each HUD enrage gauge. Track under settings/accessibility (UI2).

## Rejected

- **Clearing weakens the owner passively (no enrage gauntlet):** difficulty curves the wrong way — the game just decays toward safe.
- **Enrage as a continuous ramp:** unreadable and un-tunable; discrete steps give clear per-level knobs and a threshold the player can feel trip.
- **Score-only carrot:** a flat bonus doesn't feel proportional to finishing a quadrant under an enraged owner; pacify is the visible, mute-proof payoff.
- **Recolour the ghosts instead of the dots:** breaks OG ghost identity hard.
- **Enrage coexisting with / stacking on Cruise Elroy:** two overlapping escalation systems fighting over Blinky's speed; messy to tune.
