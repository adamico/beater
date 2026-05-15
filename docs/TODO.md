# First vertical slice MVP

## Bugs & Tweaks

## Visuals

## Audio

## Gameplay
- G5: bonus score collectables

## UI

- UI1: Title screen (with title, background, credits, social, play button)
- UI2: Settings screen (graphics, accessibility, audio, controls)
- UI3b add ghost-identity icon on each HUD enrage gauge.
- UI4: Pause menu (resume, settings, exit to title)
- UI5: Improve Game Over screen with highscore table & time taken

# Polish after MVP

## Visual
- add player trail
- improve hit feedback (ghosts, player, dots)
- rhythm hint in ghost sprites (pulse, glow)
- ghosts animated sprites (idle, move, frightened, eaten)
- proper level graphics in place of bland white walls
- proper dot sprites in place of simple squares (musical theme related, still 4 colors)
- shaders
- particles

## Audio

- rethink to introduce complexification of music tracks with dot track completion. this would need at least 3 variations of each track (base, mid, full) and a way to transition between them smoothly, the beat must be synced.
- better eating sound effect which should probably like a 5th stem

## Gameplay
- G6 prison cell: instead of plain despawn on `Pacify`, a maze-layout prison cell
  that visibly traps the pacified ghost — much stronger read than vanishing.

# Future ideas

## Gameplay
- different enemy behavior per type
- level-complete feedback:
  - allow DJing a bit (mute, solo, filters, beat repeat)
- mini daw to build tracks
- G6 random 5th threat: once all quadrants are cleared, spawn something new for the
  ghost-free victory-lap tail (roaming hazard, timer) so the level doesn't fizzle. Similar to Wizard of Wor spawning new monsters in the empty maze after the player clears all the dots.

## Visuals

- different skins/palettes

## Audio

- different tracks