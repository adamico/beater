# Music themed Pac-Man clone GDD: Vertical Slice MVP

## Game Overview

**Working Title**: Beat-Eater or Beat-Masher or Beat-Muncher or Beat2R

**Core Concept**: A single-level Pac-Man game where collecting colored dots progressively builds a multi-track electronic music composition. The more dots you collect from each track, the fuller that track sounds.

**Scope**: One playable level. Arcade-like 2D top-down view. Win by collecting all dots. Classic Pac-Man rules with audio/visual twists.

**Target Duration**: 2–5 minutes per playthrough

**Platform**: Browser-based 2D arcade game (no isometric complexity for MVP)

**Target Resolution**: 320×360 or similar (classic arcade aspect ratio)

---

## Core Gameplay Loop

1. **Navigate the maze** (Pac-Man-identical movement + collision)
2. **Collect colored dots** (each color = one track in the song)
3. **Hear the track build in real-time** as you collect dots from each color
4. **Avoid four enemies** with distinct behaviors (Pac-Man AI)
5. **Eat power pellets** for temporary invincibility (eat enemies for points)
6. **Collect all dots** to win and hear the complete track

---

## The Dots: Progressive Track System

### Design Philosophy

- **4 colored dot types** = 4 different tracks (drums, bass, lead, vocals)
- Each color spawns ~16–20 dots across the maze (total ~64–80 dots per level)
- Dots are thematically simple; all complexity is in audio response

### Collection Mechanic

When you collect a dot of color X:

1. **Play audio immediately**: The corresponding note/sample from that track plays
2. **Track completion % is calculated**: `collected_dots_of_color / total_dots_of_color`
3. **Playback intensity increases** based on completion:

| Completion % | Behavior                                                      |
| ------------ | ------------------------------------------------------------- |
| 0–25%        | Only 1st note of the track plays (every 2 beats, very sparse) |
| 25–50%       | More notes unlock; more notes play each beat                  |
| 50–75%       | Most notes play, but with a muffling/low-pass filter effect   |
| 75–100%      | All notes play at full clarity and volume                     |

### Audio Implementation Details

- **Track structure**: Each of the 4 tracks is a 64-step loop (at 16th-note resolution)
  - At 120 BPM, this is ~4 bars, ~16 seconds per loop
- **Muting logic**: Don't mute individual notes; instead, mute _steps_ in the sequence
  - Example: Drums track has 64 steps. At 50% collection, only steps [0, 2, 4, 6, ...] play; others are silent
- **Filtering**: At 50–75%, apply a low-pass filter to the track (reduce high frequencies, make it sound "muffled")
- **All tracks play continuously** during gameplay, but are muted/filtered based on collection %

### Why This Works

- **Minimal scope**: Just track collection % and apply audio muting/filtering
- **Immediate feedback**: Player hears result of every dot collected
- **Progression feeling**: Hears the track "come alive" as they play better
- **No branching complexity**: All dots are generic; color is metadata

---

## Enemies: Pac-Man AI + DJ Theme

### Design: Reuse Pac-Man's Four Ghosts

Keep Pac-Man's AI _exactly_; change only visuals and thematic names.

| Ghost      | Color  | Pac-Man AI             | DJ Theme             | Behavior                                                                |
| ---------- | ------ | ---------------------- | -------------------- | ----------------------------------------------------------------------- |
| **Blinky** | Red    | Direct pursuit         | Feedback Loop        | Beeline toward player at all times                                      |
| **Pinky**  | Pink   | Ambush ahead           | Sidechain Compressor | Intercepts ahead of player's path                                       |
| **Inky**   | Blue   | Unpredictable flanking | Reverb Decay         | Moves toward player's position from 2 moves ago (delayed/echo behavior) |
| **Clyde**  | Orange | Erratic mode-switching | Silence/Dropout      | Chases when close; wanders randomly when far away                       |

### Implementation

- **Copy Pac-Man's ghost AI exactly** (don't invent new behavior)
- **Change only the visual**: Wavy lines, distortion artifacts, sound-wave shapes—whatever fits "audio feedback" theme
- **Keep behavior identical**: This is proven fun and keeps scope tight

### Why

- Players already understand Pac-Man enemy behavior; familiar = faster learning
- Frees bandwidth to focus on audio design
- Provably fun mechanic; don't risk unknowns in MVP

---

## Power Pellets

### Mechanics (Pac-Man-Identical)

- **Count**: 4 power pellets per level (standard Pac-Man)
- **Effect**: Eating one grants **10 seconds of invincibility**
- **During invincibility**: Player can eat enemies for escalating points
- **Enemy state**: Enemies flash/change color when vulnerable
- **Escape behavior**: Enemies may flee or move more erratically when frightened (optional, tune based on playtesting)

### Points for Eating Enemies (During Invincibility)

| Enemy Eaten (in sequence) | Points |
| ------------------------- | ------ |
| 1st enemy                 | 200    |
| 2nd enemy                 | 400    |
| 3rd enemy                 | 800    |
| 4th enemy                 | 1600   |

_Reset counter when invincibility expires or next power pellet is eaten._

### Audio/Visual Twist (Non-Mechanical)

- **Visual effect**: Screen flashes, waveform visualization, enemies glow/distort
- **Audio cue**: Power-up triggers a musical effect (bass drop, filter sweep, or reverb swell)
  - Keep it under 1 second so it doesn't interrupt gameplay
  - Make it repeatable so it doesn't get annoying
  - Must be musically coherent with the main track (same key/tempo)

### Why This Approach

- **No new mechanics**, just flavor (keeps scope tight)
- **1–2 audio effects total for MVP** (pick bass drop or filter sweep, not both)
- **Use existing track audio** (don't require new assets)

---

## Win Condition

### Goal

**Collect all dots** (Pac-Man-identical)

### Feedback

- **Progress display**: `Dots Collected / Total Dots` shown on screen (e.g., "64/64")
- **Completion**: When all dots collected, trigger **Level Complete** screen
  - Display final score
  - **Play the complete track at full clarity** (all 4 colors at 100% unmuted/unfiltered)
  - Option to restart or replay

### Why

- Players immediately hear the payoff: the finished composition they built
- Thematic payoff (audio is the reward, not just points)
- Motivates replaying to get higher scores

---

## Level Design: The Maze

### Layout Rules

- **Use a classic Pac-Man maze layout** (or a simplified version)
  - Rectangular corridors, open spaces, strategic bottlenecks
  - Minimum ~20×20 grid cells (big enough for interesting routing)
  - Maximum ~28×36 (classic Pac-Man size)
- **Symmetry**: Encourage but don't require (makes enemy behavior more predictable, which is good for learning)

### Dot Placement

- **Total dots**: 64–80 across all 4 colors (~16–20 per color)
- **Distribution**: Spread evenly through the maze; don't cluster one color in one area
  - Forces player to explore all paths
  - Ensures all four tracks are progressively heard
- **Color balance**: Roughly equal number of each color dot (±2 dots OK)

### Power Pellet Placement

- **Quantity**: 4 power pellets (standard Pac-Man)
- **Location**: One in each corner, away from center enemy spawn (classic Pac-Man)
- **Spacing**: At least 5 grid cells from any wall edge (not too trivial to grab)

### Enemy Spawn

- **Location**: Center of maze or one corner (standard Pac-Man)
- **Initial position**: All ghosts start in the spawn, scatter outward when level begins

### Art Scope (Minimal)

| Asset          | Scope                                                    | Notes                                                           |
| -------------- | -------------------------------------------------------- | --------------------------------------------------------------- |
| Walls          | Simple lines (black/dark on light background)            | No texture, no detail                                           |
| Dots (regular) | Solid circles, 4 colors (red, green, blue, yellow)       | ~2–3 pixels diameter                                            |
| Power pellets  | Larger circles, blinking or different color              | ~4–5 pixels diameter                                            |
| Player         | Simple sprite (circle, square, or small character shape) | ~4×4 or 8×8 pixels                                              |
| Ghosts         | 4 colored sprites (one per color)                        | ~8×8 pixels, simple shapes (wavy blobs or distortion artifacts) |
| Background     | Plain (no parallax, no decoration)                       | Solid color                                                     |

**Total visual assets**: ~10 unique sprites. Minimalist is intentional.

---

## Score System

### Points Breakdown

| Action                        | Points |
| ----------------------------- | ------ |
| Dot eaten                     | 10     |
| Power pellet eaten            | 50     |
| Enemy eaten (1st in sequence) | 200    |
| Enemy eaten (2nd in sequence) | 400    |
| Enemy eaten (3rd in sequence) | 800    |
| Enemy eaten (4th in sequence) | 1600   |
| Level complete (bonus)        | 5000   |

### Display

- **Score**: Top-left or top-center of screen (always visible)
- **Lives**: Top-right or top-center (e.g., "Lives: 3")
- **Dots collected**: Center or top (e.g., "64/64 Dots")

---

## Audio Design

### Track Composition

**One complete song** (the "victory composition"):

- **Structure**: 4 independent looping stem files
  - Track 1: Drums stem
  - Track 2: Bass stem
  - Track 3: Lead stem
  - Track 4: Chords stem
- **Format**: `.wav`
- **Looping**: All tracks loop continuously during gameplay
- **Synchronization**: All four stems must be exported at the same length so they stay aligned

### Progressive Gain Logic

**Pseudo-code for each track:**

```
completion_percent = collected_dots_of_color / total_dots_of_color
gain = start_gain + completion_percent * (end_gain - start_gain)
```

**Implementation detail**: Dot collection still maps by color to one track, but progression now changes track gain only. Music stems are pre-rendered; they are not generated note-by-note at runtime.

### Sound Effects (SFX)

| Event                  | Sound                                 | Duration  | Notes                                          |
| ---------------------- | ------------------------------------- | --------- | ---------------------------------------------- |
| Dot collected          | Quick beep/note                       | ~100ms    | Use a sample from the main track (not generic) |
| Power pellet collected | Musical stab                          | ~500ms    | In-key, one beat, satisfying                   |
| Enemy eaten            | Descending glissando or "error" sound | ~300ms    | Cheap, satisfying feedback                     |
| Game over              | Sad trombone or filter-swept downward | ~1s       | Negative reinforcement                         |
| Level complete         | (Main track plays at full clarity)    | Full loop | Positive reinforcement                         |

SFX remain procedurally generated for now. The music simplification only removes runtime note generation for the background tracks.

### Audio Implementation

- **Runtime**: DragonRuby `args.audio`
- **Format**: Load the 4 music tracks from `.wav` files
- **Playback**: Register all 4 stems as looping audio sources at startup
- **Progression**: Update `gain` on each registered music source as dots are collected
- **SFX**: Procedural generation remains valid for gameplay feedback sounds

### Audio Sync Considerations

- **Tight sync required**: All 4 tracks must stay locked together (no drift)
- **Solution**: Start the 4 looping stems together and keep them running; only gain changes during play
- **Test**: Listen for any drift after 1–2 minutes of play; adjust if necessary

---

## Difficulty Tuning (Single Level MVP)

Since this is one level, tune for a **moderately challenging but playable** experience.

### Tunable Parameters

| Parameter             | Default         | Range        | Notes                                             |
| --------------------- | --------------- | ------------ | ------------------------------------------------- |
| Ghost speed           | 0.7 cells/frame | 0.5–1.2      | Higher = harder; 0.7 is manageable                |
| Ghost AI update rate  | Every 8 frames  | 4–16 frames  | How often ghosts recalculate path; lower = harder |
| Power pellet duration | 10 seconds      | 6–15 seconds | Shorter = harder                                  |
| Dot density           | 64–80 total     | 48–100       | More dots = longer game, more "building" feel     |

### Playtesting Will Reveal

- Whether enemies are too fast or too slow
- Whether power pellets are too generous or too scarce
- Whether the maze layout is fair or frustrating
- Whether the audio progression feels rewarding

**Don't over-tune for MVP; ship and iterate based on feedback.**

---

## Technical Architecture

### Platform & Tech Stack

- **Platform**: Browser-based (HTML5 Canvas, WebGL, or Pico-8 if you prefer Lua)
- **Resolution**: 320×360 (or 336×384 for classic Pac-Man grid scaling)
- **Frame rate**: 60 FPS (standard arcade cadence)

### Code Structure (Suggested OOP Approach)

```
Game (main loop, update/render cycle)
├── Maze
│   ├── grid (wall collision)
│   ├── pathfinding (for ghost AI)
│   └── rendering
├── Player
│   ├── position, direction
│   ├── collision detection
│   └── input handling
├── Enemies (managed as array)
│   ├── Enemy (base class)
│   │   ├── position, direction
│   │   ├── state machine (Pursue, Wander, Frightened, Eaten)
│   │   ├── AI logic (Blinky, Pinky, Inky, Clyde specific)
│   │   └── update/render
├── Dots (managed as spatial grid or quadtree)
│   ├── position, color
│   ├── collection state
│   └── render
├── PowerPellets (simple array)
│   ├── position
│   ├── collection state
│   └── render
├── AudioManager
│   ├── load tracks
│   ├── play SFX
│   ├── manage muting/filtering based on collection %
│   └── synchronization logic
└── UI
    ├── score display
    ├── lives display
    ├── dots collected / total
    └── game state screens (title, game over, level complete)
```

### Key Design Patterns (From Your Knowledge)

1. **State Machine** (Gang of Four)
   - Use for Enemy AI: `Pursue` → `Wander` → `Frightened` → `Eaten` states
   - Keeps ghost logic clean and testable
   - Easy to add new enemy types later

2. **Observer Pattern** (Optional)
   - Use for audio events: When a dot is collected, notify AudioManager
   - Decouples game logic from audio
   - Makes testing easier

3. **Spatial Partitioning** (Optional but recommended)
   - Use quadtree or simple grid for dot lookup (faster collision detection)
   - Especially helpful if you have 80 dots

4. **Clock/Timer Pattern**
   - Centralized game clock for beat synchronization
   - All audio events scheduled from this clock
   - Avoids drift in multi-track audio

---

## Success Criteria for MVP

### Must Have (Blocking)

- [ ] Player can move in all 4 directions; collision with walls works
- [ ] Dots spawn and can be collected
- [ ] When a dot is collected, audio plays (the corresponding track sample)
- [ ] Collection % for each color is calculated correctly
- [ ] Dots are progressively unmuted/filtered based on collection %
- [ ] Four enemies with distinct AI behaviors (Blinky, Pinky, Inky, Clyde) chase the player
- [ ] Power pellets work: invincibility for 10 seconds, eat enemies for points
- [ ] Enemies flash/change color when vulnerable
- [ ] Collecting all dots triggers level complete; full track plays at full clarity
- [ ] Score, lives, and progress are displayed
- [ ] Game-over state when lives reach 0
- [ ] No major bugs blocking play

### Should Have (Polish)

- [ ] Audio/visual effect when power pellet is eaten
- [ ] Sound effects for dot collection, enemy eaten, game over
- [ ] Smooth sprite animation (optional; can be static for MVP)
- [ ] Start/menu screen (basic text OK)

### Nice to Have (Deferred)

- [ ] High score persistence
- [ ] Difficulty tuning based on playtesting
- [ ] Visual effects (screen shake, color flash)
- [ ] Multiple difficulty levels

### Out of Scope for MVP

- [ ] Multiple levels
- [ ] Procedural maze generation
- [ ] Advanced enemy AI tuning
- [ ] Leaderboards
- [ ] Sound mixing/volume controls (optional; good for accessibility, but not critical)

---

## Development Roadmap

### Phase 1: Foundation (Day 1–2)

- [ ] Set up project structure and build pipeline
- [ ] Implement maze grid and collision detection
- [ ] Implement player movement and wall collision
- [ ] Render maze, player, enemies (static visuals OK)

### Phase 2: Dots & Scoring (Day 2–3)

- [ ] Implement dot spawning and placement
- [ ] Implement dot collection and removal
- [ ] Implement score system
- [ ] Implement progress display (X/Y dots)

### Phase 3: Enemies (Day 3–4)

- [ ] Implement basic enemy movement
- [ ] Implement Blinky (direct pursuit) AI
- [ ] Implement Pinky, Inky, Clyde AI
- [ ] Enemy rendering and debug visualization (optional)

### Phase 4: Power Pellets (Day 4–5)

- [ ] Implement power pellet spawning
- [ ] Implement invincibility state
- [ ] Implement eating enemies and point escalation
- [ ] Enemy vulnerable state and rendering

### Phase 5: Audio Integration (Day 5–7)

- [ ] Set up audio system (Web Audio API or Tone.js)
- [ ] Load 4-track composition
- [ ] Implement muting/filtering logic based on collection %
- [ ] Implement SFX (dot collected, power pellet, enemy eaten, game over)
- [ ] Test sync between tracks (listen for drift)

### Phase 6: Polish & Tuning (Day 7–8)

- [ ] Difficulty tuning (ghost speed, power pellet duration, etc.)
- [ ] Visual polish (animations, effects, UI)
- [ ] Playtesting with friends/colleagues
- [ ] Bug fixes

### Phase 7: Ship (Day 8–9)

- [ ] Final QA
- [ ] Build and deploy to itch.io
- [ ] Gather feedback

---

## Questions for You (Before Starting)

1. **Tech stack**: Web (Canvas/WebGL), Pico-8 Lua, or something else?
2. **Audio**: Can you compose/record the 64-step 4-track loop? If not, should we scope down to simpler synthesized tracks (sine waves, etc.)?
3. **Art**: Confirm OK with minimal sprite art (circles, simple shapes)?
4. **Timeline**: When do you want to ship? (Affects code priority.)
5. **Playtest plan**: Do you have friends/colleagues to get feedback from after MVP?

---

## Appendix: Reference Materials

### Pac-Man Resources

- Classic Pac-Man behavior: https://www.gamasutra.com/view/feature/3938/the_pacman_dossier.php
- Ghost AI breakdown: https://www.youtube.com/watch?v=ataGotQ7ir8

### Web Audio Resources

- Web Audio API docs: https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API
- Tone.js docs: https://tonejs.org/ (recommended for easier scheduling)

### Jam Rules Compliance

- Keep theme (dots = music, tracks build progressively)
- Keep core Pac-Man mechanics (maze, enemies, power pellets)
- Avoid copying Pac-Man assets directly (make our own sprites, even if minimal)
- Audio is original (compose/record your own tracks)
- Keep it SFW and itch.io compliant
- Ensure playable in browser (no downloads required)

---

**Document Version**: 1.0  
**Last Updated**: [Today's date]  
**Status**: Ready for development
