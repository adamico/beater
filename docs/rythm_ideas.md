# Rhythm ideas

## Player pellet eating sound should be synced to the music

Great design instinct. This is actually a constraint propagation problem — BPM drives everything else, and you need to work backwards from it to derive movement speed, not the other way around.

## The Dependency Chain

```
BPM → beat duration (ms) → step duration (frames) → grid cell traversal time → player speed (cells/frame)
```

Every value in that chain is derived. The only free variables are BPM and grid cell size. Once you fix those, player speed is not a design choice — it's a calculation.

## Working The Math

At 120 BPM, 60 fps:

```
frames_per_beat = 60 / (BPM / 60) = 60 / 2 = 30 frames
frames_per_step = frames_per_beat / 4 = 7.5  ← 16th note
```

Now the question is: **how many grid cells should the player cross per beat?** One cell per beat feels sluggish. Four cells per beat (one per 16th note step) feels frantic. Two cells per beat is the natural sweet spot — it means the player eats a dot roughly every half-beat, which sits musically.

```
cells_per_beat    = 2
frames_per_cell   = frames_per_beat / cells_per_beat = 15 frames
player_speed      = 1.0 / frames_per_cell = 0.0667 cells/frame
```

For a dot-eat sound to feel synced it doesn't need to land exactly on a 16th note step — it needs to land within about ±1 frame of a beat subdivision. At this speed, with normal maze navigation, dot collections will cluster naturally near beat positions without any quantisation needed.

## The Quantisation Question

You could go further and **snap dot-eat sounds to the nearest 16th note grid**. The sound plays on the next step boundary rather than the exact frame of collision. This is what rhythm games do. The tradeoff:

- **Pro**: Perfectly rhythmic, even if the player moves slightly off-beat
- **Con**: Up to 7-8 frames of perceived latency on the feedback sound, which may feel disconnected from the visual collection event

For a Pac-Man-style game I'd skip quantisation. The player's movement rhythm naturally emerges from the maze structure — corridors force consistent traversal patterns. The dot sound playing immediately on collision will feel more responsive and the rhythmic sync will be approximate but satisfying.

## The Level Properties Struct

This is the important part for your question about multiple mazes. BPM should live on the level, and everything else should derive from it at load time:

```ruby
LevelConfig = Struct.new(
  # Identity
  :name,
  :maze_file,

  # Music
  :bpm,
  :track_configs,      # per-track TrackConfig overrides (or nil = use defaults)
  :key,                # :a_minor, :c_major etc — for future use

  # Derived (computed in initialize, not set manually)
  :frames_per_beat,
  :frames_per_step,
  :frames_per_cell,
  :player_speed,

  keyword_init: true
) do
  CELLS_PER_BEAT = 2   # design constant — feels right, change if needed

  def self.build(name:, maze_file:, bpm:, track_configs: nil, key: :a_minor)
    fpb  = 60.0 * 60 / bpm          # frames per beat
    fps  = fpb / 4.0                 # frames per 16th-note step
    fpc  = fpb / CELLS_PER_BEAT      # frames per grid cell
    spd  = 1.0 / fpc                 # player speed in cells/frame

    new(
      name:           name,
      maze_file:      maze_file,
      bpm:            bpm,
      track_configs:  track_configs,
      key:            key,
      frames_per_beat: fpb.round,
      frames_per_step: fps.round,    # feed this into BeatClock
      frames_per_cell: fpc.round,    # feed this into Player
      player_speed:    spd,
    )
  end
end
```

Usage:

```ruby
LEVELS = [
  LevelConfig.build(
    name:      'Warehouse',
    maze_file: 'maze_01',
    bpm:       120,
    key:       :a_minor
  ),
  LevelConfig.build(
    name:      'Rooftop',
    maze_file: 'maze_02',
    bpm:       140,           # faster BPM → faster player automatically
    track_configs: {
      drums: TrackConfig.new(filter_type: :dj, start_cutoff: 600, ...)
    }
  ),
]
```

## The Two Places That Consume LevelConfig

**`BeatClock`** needs to stop using the hardcoded `TICKS_PER_STEP = 8` constant and instead read from the level:

```ruby
module BeatClock
  def self.current_step(tick_count, frames_per_step)
    (tick_count / frames_per_step) % STEPS_PER_LOOP
  end
end
```

**`Player`** reads `frames_per_cell` for movement:

```ruby
class Player
  def initialize(level_config)
    @frames_per_cell = level_config.frames_per_cell
  end

  def update
    # Move 1 full cell over frames_per_cell ticks
    # (grid-locked movement fits maze collision naturally)
  end
end
```

## One Gotcha: Non-Integer Frame Counts

At 140 BPM:

```
frames_per_beat = 60 * 60 / 140 = 25.7 frames  ← not an integer
```

Rounding to 26 introduces drift over a long session. For the jam this is fine — the perceptual error is under 2ms per beat. If you want it exact, track a floating-point beat accumulator instead of comparing tick counts:

```ruby
@beat_acc += 1.0 / frames_per_beat_float
current_beat = @beat_acc.floor
```

Same pattern `BeatClock` already uses conceptually, just with floats instead of integer division. Worth doing for the audio sync — the game loop can keep integer ticks.

Want me to update `BeatClock` in `audio_manager.rb` to accept `frames_per_step` as a parameter, and add the `LevelConfig` struct as a third artifact?

## Rythm driven movement

The player presses a direction. Instead of moving immediately, the character **accelerates into the next 16th-note grid slot** and the dot-eat sound fires exactly on that step boundary. The delay window is your acceleration ramp — 0 to 7-8 frames at 120 BPM.

This is essentially **rhythmic quantisation with visible commitment**. The player sees the acceleration, understands they're "locked in" to that direction, and the payoff is a perfectly synced sound.

## The Interesting Emergent Mechanics

**Direction changes during the ramp.** If the player inputs a new direction during the 7-frame acceleration window, do you honour it or ignore it? This is the crux. Two options:

- **Honour last input** — buffer the new direction, apply it after the current ramp completes. Feels forgiving, classic Pac-Man buffering.
- **Cancel and re-ramp** — new input interrupts, starts a new ramp in the new direction. Riskier, more skill-expressive.

The cancel-and-re-ramp option is where it gets musically interesting — a player who keeps changing direction never actually moves, which is a natural punishment for being off-rhythm.

**Wall collision during the ramp.** If the player commits to a direction but there's a wall, do you ramp them into the wall and stop, or detect early and cancel? Early detection is more readable — the player shouldn't feel tricked by acceleration into a dead end.

**Ghost interaction.** A ghost that touches the player during the ramp — are they vulnerable? I'd say yes, the ramp doesn't grant any special state. But the reduced speed during ramp-up makes the player briefly more vulnerable, which is a genuine risk/reward tension.

## My Honest Take On The Mechanic

It's good, but it has one significant risk: **it may feel like input lag to players who don't understand the system**. The first few deaths will feel unfair. You need strong visual communication — the acceleration needs to be readable immediately, not discovered through frustration.

Two things that would make it land:

**A anticipation squash on the player sprite.** Frame 0 of input: player squashes slightly backward (wind-up). Frames 1-7: stretch forward into the direction. This is classic animation principle — anticipation makes commitment readable before it happens.

**A rhythmic UI element.** A subtle pulse on the screen border or a beat indicator that shows the player where the next 16th-note lands. Players will naturally try to time their inputs to it. This transforms "input lag" into "rhythm game."

Without those two things it's a frustrating mystery. With them it's a distinctive mechanic.

## The State Machine

The player needs a new state between `Idle` and `Moving`:

```
Idle → [input received] → Committing → [step boundary hit] → Moving → [wall collision] → Idle
                              ↑                                            |
                         [new input                                   [new input]
                          during ramp]                                     |
                              └──────────────────────────────────────────┘
```

`Committing` is the new state. It holds:
- `direction` — committed direction
- `ramp_frame` — how many frames into the ramp (0 → frames_per_step)
- `speed` — lerped from 0 to `player_speed` over the ramp duration
- `next_step_at` — the exact tick when the step boundary fires

```ruby
module PlayerState
  IDLE       = :idle        # waiting for input, stopped at cell boundary
  COMMITTING = :committing  # accelerating toward next step boundary
  MOVING     = :moving      # full speed, wall-locked movement
end

class Player
  def update(args, level_config, beat_clock)
    case @state
    when :idle
      dir = read_input(args)
      if dir && !wall_in_direction?(dir)
        @state          = :committing
        @commit_dir     = dir
        @commit_start   = args.tick_count
        @next_step_at   = beat_clock.next_step_tick(args.tick_count)
        @ramp_duration  = @next_step_at - args.tick_count
      end

    when :committing
      t = (args.tick_count - @commit_start).to_f / @ramp_duration
      # Ease-in curve: slow start, fast finish
      @speed = level_config.player_speed * ease_in(t)

      # Check for direction change input
      new_dir = read_input(args)
      if new_dir && new_dir != @commit_dir && !wall_in_direction?(new_dir)
        # Cancel and re-ramp in new direction
        @commit_dir    = new_dir
        @commit_start  = args.tick_count
        @next_step_at  = beat_clock.next_step_tick(args.tick_count)
        @ramp_duration = @next_step_at - args.tick_count
      end

      move_by(@speed, @commit_dir)

      if args.tick_count >= @next_step_at
        @speed = level_config.player_speed
        @state = :moving
        # Fire dot-eat sound here — guaranteed on step boundary
        args.state.audio.on_dot_collected(args, dot_at_position) if dot_here?
      end

    when :moving
      move_by(level_config.player_speed, @direction)
      if wall_ahead?
        snap_to_cell_boundary
        @state = :idle
      end
    end
  end

  def ease_in(t)
    t = t.clamp(0.0, 1.0)
    t * t   # quadratic ease-in — slow start, accelerates into the beat
  end
end
```

The `beat_clock.next_step_tick` method is the key addition to `BeatClock` — it answers "given the current tick, how many ticks until the next 16th-note boundary?"

```ruby
module BeatClock
  def self.next_step_tick(tick_count, frames_per_step)
    ticks_into_step = tick_count % frames_per_step
    tick_count + (frames_per_step - ticks_into_step)
  end
end
```

## The Tweaking Variables

Three knobs that control how punishing it feels:

**Easing curve** — `t * t` (quadratic) versus `t * t * t` (cubic, slower start) versus `Math.sqrt(t)` (square root, faster start, less dramatic). Square root will feel most forgiving because the player reaches near-full speed quickly and only the last few frames are at full pace. Cubic will feel most rhythmically demanding.

**Grace window** — inputs received within N frames of a step boundary could snap to the *current* step rather than the *next* one. A 2-3 frame grace window makes early inputs feel responsive without breaking the sync. This is how rhythm games handle it — there's always a hit window, not a hard boundary.

**Ramp on re-input** — whether cancelling and re-ramping resets to the *next* step or the *current* step's remaining time. The latter is more forgiving but players can exploit it by tapping rapidly to stay almost-stationary while enemies approach.

## My Recommendation For The Jam

Implement it, but ship with the square-root ease and a 3-frame grace window by default. Put all three knobs in `LevelConfig` so you can tune per-maze. The first maze should have a slow BPM (100–110) specifically to give players a longer ramp window to learn the mechanic before you push the tempo up in later levels.

Should I add `PlayerState`, the updated `BeatClock`, and the ramp variables to `LevelConfig` as a dedicated artifact?