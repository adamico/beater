# First vertical slice MVP

## Bugs & Tweaks

- at gameover screen, when choosing to go back to title with the keyboard, the game tries to restart and then goes back to title

## Visuals

## Audio

## Gameplay

## UI

## tests & tools
- reenable DRGTK console shortcuts
- add a jukebox mode to listen to music and sfx without playing, for testing and fun

# Polish after MVP

## Visual
- V1: ghosts animated sprites (idle, move, frightened, eaten)
- add player ghost trail like vampire survivors
- improve hit feedback (ghosts, player, dots)
- rhythm hint in ghost sprites (pulse, glow)
- proper level graphics in place of bland white walls
- shaders
- particles

## UI
- UI3: (depends on V1) add ghost-identity icon on each HUD enrage gauge.

## Audio

- rethink to introduce complexification of music tracks with dot track completion. this would need at least 3 variations of each track (base, mid, full) and a way to transition between them smoothly, the beat must be synced.
- better eating sound effect which should probably like a 5th stem

## Gameplay

- G5: bonus score collectables or other collectables?

## tests & refactor

- improve the maze layout code to be more data-driven and less hardcoded, maybe with a visual editor
- add a level difficulty curve editor to tweak enemy behavior, spawn rates, and other parameters across levels

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