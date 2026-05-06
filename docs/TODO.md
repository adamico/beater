# First vertical slice MVP

## Visuals

- Top down 2D
- Player sprite (simple circle)
- Ghost sprites (simple circles)
- Dot sprites (simple circles)
- Palette (look in lospec.com) for a low color count palette (4 colors + black and white) with neon tones

## Audio

- Use a js library for synced audio playback like tone.js
- Use littlejs zzsfxr to generate sound effects
- Use littlejs zzsfm to generate music
- Have 3-4 versions of the same track with different levels of completeness
- or have muted notes based on player progress

## Gameplay

- use builtin littlejs world grid
- maze drawn in code using the grid
- Player is a simple shape in yellow/white
- Player movement in a gridlocked 4 axis without stopping (copy pacman)
- Simple AABB collision detection
- Dots and power pellets are code based circles, dots are white, power pellets are larger and white
- Enemies are a different shape than player, in 4 colors (copy pacman)
- Enemies use pacman AI

## UI

- Title screen (with title, background, credits, social, play button)
- Settings screen (graphics, accessibility, audio, controls)
- Game HUD (current score, lives, 4 track completion % display)
- Pause menu (resume, settings, exit to title)
- Game Over (Win & loss screens with highscore table & time taken)

# Future ideas

## Gameplay

- bonus score collectables (not vanilla pacman?)
- different maps
- different tracks
- mechanics:
  - button to toggle dot eating for chain reaction scoring
  - jump

## Visuals

- different skins
- screen shake
- enemy flash
- shaders
- particles
