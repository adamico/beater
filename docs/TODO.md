# First vertical slice MVP

## Bugs & Tweaks

## Visuals

## Audio

## Gameplay

- G5: bonus score collectables
- G6: quadrant territory + enrage/pacify system — see [ADR-0010](adr/0010-quadrant-territory-enrage.md).
  Ties dot quadrants to ghost behaviour so the structure is meaningful with music muted:
  clearing a `Territory` enrages its owner (stick), finishing it despawns the owner (carrot).
  Replaces `CruiseElroy`; re-scopes `LevelConfig` Elroy columns to per-quadrant thresholds.
  Includes: dot recolour to owner colour, per-territory floor tint, HUD meters → enrage gauges.

## UI

- UI1: Title screen (with title, background, credits, social, play button)
- UI2: Settings screen (graphics, accessibility, audio, controls)
  - accessibility: G6 territory system is colour-load-bearing — add a non-colour channel:
    distinct dot *shape* per territory + ghost-identity icon on each HUD enrage gauge.
- UI4: Pause menu (resume, settings, exit to title)
- UI5: Improve Game Over screen with highscore table & time taken

# Polish after MVP

## Visual

- rhythm hint in player sprite (pulse, glow)
- rhythm hint in ghost sprites (pulse, glow)
- proper sprites in place of placeholders
- animated sprites (idle, move, frightened, eaten)
- proper level graphics in place of bland white walls
- slow down effect when player dies
- ghost state change visual feedback (color change, animation, etc)
- proper dot sprites in place of simple squares (musical theme related, still 4 colors)
- Palette (look in lospec.com) for a low color count palette (4 colors + black and white) with neon tones
- shaders
- particles

## Audio

- rethink to introduce complexification of music tracks with dot track completion. this would need at least 3 variations of each track (base, mid, full) and a way to transition between them smoothly, the beat must be synced.
- better waka waka sound effect which should probably like a 5th stem

## Gameplay

# Future ideas

## Gameplay

- different tracks
- level-complete feedback:
  - allow DJing a bit (mute, solo, filters, beat repeat)
- mini daw to build tracks
- G6 prison cell: instead of plain despawn on `Pacify`, a maze-layout prison cell
  that visibly traps the pacified ghost — much stronger read than vanishing.
- G6 random 5th threat: once all quadrants are cleared, spawn something new for the
  ghost-free victory-lap tail (roaming hazard, timer) so the level doesn't fizzle.

## Visuals

- different skins/palettes
