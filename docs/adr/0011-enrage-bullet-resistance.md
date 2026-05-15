# Enraged ghosts resist bullets; `:enrage2` is immune

Status: accepted (not yet implemented)

## Context

[ADR-0007](0007-finite-ammo-manual-fire.md) made shooting a universally-available, edge-triggered tool: any active ghost dies in one hit, regardless of state. [ADR-0010](0010-quadrant-territory-enrage.md) then added the territory `Enrage`/`Pacify` system and asserted "shooting stays purely tactical" — meaning shoot and clear were two paths to the same outcome. In practice that left them redundant: the player could antagonise a quadrant with impunity and bullet their way out of any consequence. The `Enrage` speed bump alone (≤ 0.95·PLAYER_SPEED at L1) was easily outpaced and cancelled by a single shot, so the territory framing carried no actual pressure once ammo was on hand.

## Decision

A ghost's `Enrage` step now gates its bullet resistance:

- `:off` — 1 hit (current behaviour, unchanged).
- `:enrage1` — 2 hits required to send the ghost to `:eaten`.
- `:enrage2` — **immune** to projectiles for the rest of the level (can only be removed via `Pacify`).

Partial damage (a hit count below the kill threshold) is tracked per-ghost and **clears on every enrage step-up**: a ghost at `:enrage1` with 1/2 absorbed hits, when escalating to `:enrage2`, resets to 0 absorbed and becomes immune. The "scarring" model — the ghost gets madder, partial damage doesn't accumulate across thresholds, and step-up can never make a ghost *easier* to kill in absolute terms.

Every projectile contact still **consumes the bullet** regardless of whether the hit kills, partially damages, or is absorbed by an immune ghost. Bullets never penetrate. On a non-killing hit the ghost replays a **shorter "armor flash"** (the existing `eaten_flash_ticks` animation, rescaled) and a distinct **metallic SFX** is played in place of the kill SFX. Immune `:enrage2` hits use the same flash + a third distinct SFX so "you really can't kill this one" reads differently from "you damaged but didn't kill."

The `EatSequencer` chain (200→400→800→1600) stays exclusively shoot-driven and only counts **kills**: partial hits don't escalate the chain, don't reset its timer, and don't extend it. `Pacify` (territory cleared, owner despawned) remains a separate event with its own scoring path (the ADR-0010 enrage-scaled bonus on the existing `Pellets#track_cleared` hook), and does not contribute to the chain — pacify is a strategic outcome, the chain is a tactical one.

`Enrage` speed values are **left at the ADR-0010 modest curve** for now (L1 enrage1 = 0.85·PLAYER_SPEED, enrage2 = 0.95). Bullet resistance is the dominant threat; the speed bump is now meaningful only because it can no longer be cancelled by a single shot. The ghost-controller targeting personalities (Pinky's ambush, Inky's vector trick) are likewise untouched — only scatter-suppression remains. Revisit speed/targeting amplification after playtesting B alone proves whether enraged ghosts can simply be outrun.

## Consequences

- **Supersedes the "shooting stays purely tactical" framing in [ADR-0010](0010-quadrant-territory-enrage.md).** Shoot and clear are now genuinely complementary tools, not redundant paths to the same outcome:
  - Shoot = tactical removal of *calm* ghosts (and a costly partial measure against `:enrage1`).
  - Clear = strategic, the *only* way to remove a `:enrage2` ghost.
- The final stretch of every territory (where the owner sits at `:enrage2`) becomes a forced commitment — no bailing out with ammo, the player either finishes the quadrant or flees and lets it sit at `:enrage2` indefinitely.
- Ammo economy shifts: power pellets remain valuable (5 ammo per pickup, [ADR-0007](0007-finite-ammo-manual-fire.md)) but the marginal value of the *Nth* bullet drops as more ghosts approach `:enrage2` immunity. This is intentional — ammo's relative value is highest early in the level, when most ghosts are calm.
- Three audio cues now needed where there was one: kill (existing `enemy_eaten`), partial-hit metallic, and immune metallic (the latter two distinct from each other).
- New per-`Ghost` field for absorbed hit count, reset on enrage step-up.

## Rejected

- **Stepped armor without `:enrage2` immunity** (`:off`=1, `:enrage1`=2, `:enrage2`=3): keeps shooting as a universal escape valve, just at higher ammo cost. Doesn't create the hard line that makes `Pacify` the *only* solution to a deeply-antagonised quadrant. The "boss fight" framing collapses to ammo arithmetic.
- **Binary immunity** (any non-`:off` step → bullets bounce): collapses the choice instantly. The `:enrage1` "spend 2 bullets to send it home, or commit to clearing" tactical decision disappears — you either committed before the first hit, or you didn't.
- **Bullet pass-through on immune `:enrage2` hits** (no flash, no consume): reads as a bug. Player thinks projectile collision is broken. Consistent flash + bullet consumption across all enrage steps preserves the mechanical model "every bullet hits something."
- **Partial-hit stun or knockback**: would make partial hits *strictly better* than full hits in some scenarios (free crowd-control). Partial hits should be pure ammo expenditure.
- **Partial damage carrying across step-up**: lets the player effectively bypass `:enrage2` immunity by half-damaging at `:enrage1` then waiting for the step-up. Clear-on-step-up keeps the immunity rule absolute.
- **Pacify routed through `EatSequencer.on_ghost_eaten`** (counts toward the chain): mixes the strategic and tactical reward verbs, and lies about causality — pacify is triggered by eating a *dot*, not a ghost.
- **Scaling up the Enrage *speed* curve in this slice** (option A from the grill): one big mechanical change at a time. Crank speed only if playtest shows enraged ghosts can be perpetually outrun.
