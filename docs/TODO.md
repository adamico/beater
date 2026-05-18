# First vertical slice MVP

## Bugs & Tweaks

## Visuals

## Audio

## Gameplay

## UI

## tests & tools

# Polish after MVP

## Visual
- improve ghosts movement animation (bobbing, eyes looking in movement direction)
- add player ghost trail like vampire survivors
- improve hit feedback (ghosts, player, dots)
- add screen shake on player hit
- add particles for:
  - dot collection
  - ghost hits
  - player shooting
- add light effects for player shooting
- rhythm hint in ghost sprites (pulse, glow)
- proper level graphics in place of bland white walls

## UI

## Audio

- rethink to introduce complexification of music tracks with dot track completion. this would need at least 3 variations of each track (base, mid, full) and a way to transition between them smoothly, the beat must be synced.
- add filter knobs to the jukebox (filter type, cutoff, resonance) for more DJing fun
- add beat repeat and stutter effects to the jukebox for more rhythmic fun
- add quantized beat start/stop when muting/unmuting tracks in the jukebox to keep everything in sync
- add reverse playback option
- add oscilloscope visualizer for the music tracks in the jukebox for extra flair

## Gameplay

- G5: bonus score collectables or other collectables?

## tests & tools & refactor

- TTR1: add cheat shorcuts (no collision with ghosts, infinite lives, infinite ammo, no clip to walls) for easier testing of later levels and mechanics
- TTR2: improve the maze layout code to be more data-driven and less hardcoded, maybe with a visual editor
- TTR3: add a level difficulty curve editor to tweak enemy behavior, spawn rates, and other parameters across levels

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