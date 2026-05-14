# First vertical slice MVP

## Bugs & Tweaks

## Visuals

## Audio

## Gameplay

- G1: score system (points for eating dots, points for eating ghosts with chain reaction bonus, points for completing tracks)
- G2: rework the "eat" score bonus: instead of the OG 200/400/800/1600 chain tied to a single frightened window, turn it into a time-windowed combo bonus (kill another ghost within T ticks of the last kill to escalate; resets if timer lapses).
- G4: add more levels inspired by the OG.
- G5: bonus score collectables

## UI

- UI1: Title screen (with title, background, credits, social, play button)
- UI2: Settings screen (graphics, accessibility, audio, controls)
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

## Visuals

- different skins/palettes
