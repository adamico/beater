# Bugs & Tweaks

# To grill

- TG1: rework the "eat" score bonus: instead of the OG 200/400/800/1600 chain tied to a single frightened window, turn it into a time-windowed combo bonus (kill another ghost within T ticks of the last kill to escalate; resets if timer lapses).
  
- TG3: ✅ grilled + implemented — camera directional look-ahead (leads 20% of viewport along travel axis, eased, decays to zero when stopped); minimap dropped. See [ADR-0008](adr/0008-follow-camera-world-screen-split.md).

# First vertical slice MVP

## Visuals


## Audio

## Gameplay

## UI

- Title screen (with title, background, credits, social, play button)
- Settings screen (graphics, accessibility, audio, controls)
- Game HUD (current score, lives, 4 track completion % display)
- Pause menu (resume, settings, exit to title)
- Game Over (Win & loss screens with highscore table & time taken)

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
- 
## Audio
- longer music tracks, still loop based but more variation
- better waka waka sound effect which should probably like a 5th stem

# Future ideas

## Gameplay


- bonus score collectables
- different maps
- different tracks
- mechanics:
  - button to toggle dot eating for chain reaction scoring
  - jump/sink to avoid eating
- level-complete feedback:
  - allow DJing a bit (mute, solo, filters, beat repeat)
- mini daw to build tracks

## Visuals

- real toroid rendering instead of player teleporting from one side to the other
- different skins/palettes
