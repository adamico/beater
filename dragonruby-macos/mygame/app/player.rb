# app/player.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/audio/beat_clock.rb'

class Player
  include GridMover

  PLAYER_SPRITE_PATH = "sprites/player.png"
  PLAYER_SPRITE_WIDTH = 64
  PLAYER_SPRITE_HEIGHT = 96

  attr_accessor :controller
  attr_reader :move_state, :commit_direction, :rhythm_fallback, :ammo

  AMMO_PER_POWER_PELLET = 5

  def initialize(x:, y:, w:, h:, speed:, controller:, direction: Direction::NONE)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @controller = controller
    @base_speed = speed.to_f
    # Sprite renders native (ADR-0008). CELL_SIZE is half the sprite height, so
    # the 64x96 canvas spans a 2x2 cell area; centre it on the logical 1-cell
    # rect (the offsets are negative — the sprite overhangs the cell).
    @sprite_offset_x = (w - PLAYER_SPRITE_WIDTH) / 2.0
    @sprite_offset_y = (h - PLAYER_SPRITE_HEIGHT) / 2.0

    @rhythm_enabled = false
    @rhythm_bpm = Audio::BeatClock::DEFAULT_BPM
    @rhythm_grace_ticks = 3
    @orthogonal_grace_ticks = 1
    @orthogonal_ramp_scale = 0.5
    @move_state = :moving
    @commit_kind = :none
    @commit_direction = Direction::NONE
    @commit_start_tick = 0
    @commit_target_step = nil
    @commit_target_tick = 0.0
    @commit_duration_ticks = 1.0
    @rhythm_fallback = false
    @dot_slow_remaining_ticks = 0
    @visual_offset_x = 0.0
    @visual_offset_y = 0.0
    @walk_ticks = 0
    @ammo = 0
  end

  def gain_ammo(n = AMMO_PER_POWER_PELLET)
    @ammo += n
  end

  def consume_ammo!
    return false if @ammo <= 0
    @ammo -= 1
    true
  end

  def reset_ammo!
    @ammo = 0
  end

  # Fixed-frame death animation (Dying state, phase 1). Not beat-synced — kept
  # snappy for the frantic feel. The sprite spins, shrinks and fades over the
  # window; the logical position is untouched (the world is frozen anyway).
  DEATH_ANIM_TICKS = 36

  def begin_death
    @death_ticks = DEATH_ANIM_TICKS
  end

  def tick_death
    @death_ticks -= 1 if @death_ticks && @death_ticks > 0
  end

  def dying?
    !@death_ticks.nil?
  end

  def death_anim_done?
    !@death_ticks.nil? && @death_ticks <= 0
  end

  def clear_death
    @death_ticks = nil
  end

  WALK_FRAME_START = 3
  WALK_FRAME_COUNT = 8
  TICKS_PER_WALK_FRAME = 4

  # Px per tick the rendered sprite catches up to the logical position
  # after a corner snap. Lower = more visible diagonal slide; higher = closer
  # to instant.
  VISUAL_OFFSET_DECAY_PX = 1.5

  # OG Lvl 1: Pac slows to 0.9× while munching a dot (arcade = 1-frame skip
  # per pellet). Applied as a post-multiplier so it co-exists with the
  # rhythm commit ramp without re-syncing the beat clock.
  DOT_SLOW_TICKS = 4
  DOT_SLOW_FACTOR = 0.9

  # OG-style cornering: Pac may start a turn this far before reaching cell
  # center. Expressed as a multiple of per-tick step so the turn window stays
  # wider than one movement step at any CELL_SIZE/speed (a fixed px value
  # smaller than @speed makes intersections un-turnable on most ticks).
  # Ghosts keep the default (speed + ε), so Pac gains a small distance edge
  # through corners. See docs/OG/ghosts_behav.md "Cornering".
  CORNER_TOLERANCE_SPEED_RATIO = 1.75

  def corner_snap_tolerance
    @base_speed * CORNER_TOLERANCE_SPEED_RATIO
  end

  def snap_perpendicular_on_turn?
    false
  end

  # Wrap GridMover#try_turn so any perpendicular snap (logical jump) gets
  # absorbed as a visual offset that decays over a few frames. The hitbox
  # and dot-collection use the logical position; only rendering trails.
  def try_turn(direction, maze, projection)
    pre_x, pre_y = @x, @y
    result = super
    if result
      @visual_offset_x -= (@x - pre_x)
      @visual_offset_y -= (@y - pre_y)
    end
    result
  end

  def decay_visual_offset
    @visual_offset_x = decay_toward_zero(@visual_offset_x, VISUAL_OFFSET_DECAY_PX)
    @visual_offset_y = decay_toward_zero(@visual_offset_y, VISUAL_OFFSET_DECAY_PX)
  end

  def decay_toward_zero(value, step)
    return 0.0 if value.abs <= step
    value > 0 ? value - step : value + step
  end

  # OG diagonal cornering phase: while moving along one axis with a
  # non-zero offset on the perpendicular axis, nudge the perp axis toward
  # the cell center each tick (capped at @speed) producing a ~45° diagonal
  # path until aligned. Replaces the perpendicular snap that ghosts use.
  def apply_corner_phase(projection)
    return if @direction.none?
    cs = projection.cell_size
    if @direction.vertical?
      target = ((@x - projection.offset_x) / cs).round * cs + projection.offset_x
      delta = target - @x
      return if delta.abs <= AXIS_SNAP_EPSILON
      step = [@speed.to_f, delta.abs].min
      @x += delta.positive? ? step : -step
    elsif @direction.horizontal?
      target = ((@y - projection.offset_y) / cs).round * cs + projection.offset_y
      delta = target - @y
      return if delta.abs <= AXIS_SNAP_EPSILON
      step = [@speed.to_f, delta.abs].min
      @y += delta.positive? ? step : -step
    end
  end

  def on_dot_eaten
    @dot_slow_remaining_ticks = DOT_SLOW_TICKS
  end

  def configure_rhythm(enabled:, bpm:, grace_ticks: 3)
    @rhythm_enabled = enabled
    @rhythm_bpm = bpm.to_f
    @rhythm_grace_ticks = grace_ticks.to_i
    @orthogonal_grace_ticks = [@rhythm_grace_ticks - 2, 1].max
  end

  def enable_rhythm_fallback!
    @rhythm_fallback = true
    cancel_commit
  end

  def update_with_rhythm(tick_count:, intent:, maze:, projection:)
    return update_immediate(intent: intent, maze: maze, projection: projection) if !@rhythm_enabled || @rhythm_fallback

    finalize_commit_if_due(tick_count: tick_count, maze: maze, projection: projection)

    if committing?
      if !intent.none? && intent == @direction.opposite && turn_possible?(intent, maze, projection)
        cancel_commit
        try_turn(intent, maze, projection)
      elsif !@commit_direction.none? && !turn_possible?(@commit_direction, maze, projection)
        cancel_commit
      elsif !intent.none? && intent != @commit_direction && turn_possible?(intent, maze, projection)
        start_commit(direction: intent, tick_count: tick_count, kind: :forward)
      end
    elsif !intent.none? && intent == @direction.opposite && turn_possible?(intent, maze, projection)
      cancel_commit
      try_turn(intent, maze, projection)
    elsif !intent.none? && intent != @direction && orthogonal_to_current?(intent)
      # Buffered cornering: keep moving forward, retry turn every tick while held.
      try_turn(intent, maze, projection)
    elsif !intent.none? && intent != @direction && turn_possible?(intent, maze, projection)
      start_commit(direction: intent, tick_count: tick_count, kind: :forward)
    end

    apply_commit_speed(tick_count)
    apply_dot_slow
    apply_corner_phase(projection)
    advance(maze, projection)
    decay_visual_offset
  end

  def to_sprite
    return death_sprite if dying?

    frame = @walk_ticks.idiv(TICKS_PER_WALK_FRAME) % WALK_FRAME_COUNT
    tile_index = WALK_FRAME_START + frame
    base = {
      x: @x + @sprite_offset_x + @visual_offset_x,
      y: @y + @sprite_offset_y + @visual_offset_y,
      w: PLAYER_SPRITE_WIDTH, h: PLAYER_SPRITE_HEIGHT,
      path: PLAYER_SPRITE_PATH,
      tile_x: tile_index * PLAYER_SPRITE_WIDTH,
      tile_y: 0,
      tile_w: PLAYER_SPRITE_WIDTH,
      tile_h: PLAYER_SPRITE_HEIGHT,
    }
    case @direction
      when Direction::LEFT then base.merge(flip_horizontally: true)
      when Direction::UP   then base.merge(angle: 90)
      when Direction::DOWN then base.merge(angle: 90, flip_horizontally: true)
      else base
    end
  end

  # Spin + shrink + fade about the sprite centre, driven by death-anim progress.
  def death_sprite
    t = (1.0 - @death_ticks.to_f / DEATH_ANIM_TICKS).clamp(0.0, 1.0)
    scale = 1.0 - t
    w = PLAYER_SPRITE_WIDTH * scale
    h = PLAYER_SPRITE_HEIGHT * scale
    cx = @x + @sprite_offset_x + PLAYER_SPRITE_WIDTH / 2.0
    cy = @y + @sprite_offset_y + PLAYER_SPRITE_HEIGHT / 2.0
    {
      x: cx - w / 2.0, y: cy - h / 2.0, w: w, h: h,
      path: PLAYER_SPRITE_PATH,
      tile_x: WALK_FRAME_START * PLAYER_SPRITE_WIDTH, tile_y: 0,
      tile_w: PLAYER_SPRITE_WIDTH, tile_h: PLAYER_SPRITE_HEIGHT,
      angle: t * 540.0,
      a: (255 * (1.0 - t)).to_i
    }
  end

  def advance(maze, projection)
    pre_x, pre_y = @x, @y
    super
    moved = (@x - pre_x).abs > AXIS_SNAP_EPSILON || (@y - pre_y).abs > AXIS_SNAP_EPSILON
    @walk_ticks += 1 if moved
  end

  private

  def update_immediate(intent:, maze:, projection:)
    @speed = @base_speed
    apply_dot_slow
    try_turn(intent, maze, projection)
    advance(maze, projection)
  end

  def apply_dot_slow
    return if @dot_slow_remaining_ticks <= 0
    @speed *= DOT_SLOW_FACTOR
    @dot_slow_remaining_ticks -= 1
  end

  def committing?
    @move_state == :committing
  end

  def start_commit(direction:, tick_count:, kind: :forward)
    step = nil
    target_tick = 0.0
    duration = Audio::BeatClock.frames_per_step(bpm: @rhythm_bpm)

    if kind == :forward
      step = Audio::BeatClock.scheduled_step_for_input(
        tick_count,
        bpm: @rhythm_bpm,
        grace_ticks: @rhythm_grace_ticks
      )
      target_tick = Audio::BeatClock.step_start_tick(step, bpm: @rhythm_bpm)
      duration = [target_tick - tick_count.to_f, 1.0].max
    else
      # Orthogonal turns keep momentum and wait for first legal turn slot.
      duration = [duration * @orthogonal_ramp_scale, 1.0].max
    end

    @move_state = :committing
    @commit_kind = kind
    @commit_direction = direction
    @commit_start_tick = tick_count.to_i
    @commit_target_step = step
    @commit_target_tick = target_tick
    @commit_duration_ticks = duration
  end

  def finalize_commit_if_due(tick_count:, maze:, projection:)
    return unless committing?
    return unless @commit_kind == :forward

    current_step = Audio::BeatClock.current_step(tick_count, bpm: @rhythm_bpm)
    return if current_step < @commit_target_step

    try_turn(@commit_direction, maze, projection) if turn_possible?(@commit_direction, maze, projection)
    cancel_commit
  end

  def cancel_commit
    @move_state = :moving
    @commit_kind = :none
    @commit_direction = Direction::NONE
    @commit_target_step = nil
    @commit_target_tick = 0.0
    @commit_duration_ticks = 1.0
  end

  def apply_commit_speed(tick_count)
    unless committing?
      @speed = @base_speed
      return
    end

    if @commit_kind == :orthogonal
      @speed = @base_speed
      return
    end

    elapsed = tick_count.to_f - @commit_start_tick.to_f
    t = (elapsed / @commit_duration_ticks).clamp(0.0, 1.0)
    @speed = @base_speed * Math.sqrt(t)
  end

  def orthogonal_to_current?(intent)
    return false if intent.none? || @direction.none?

    (@direction.horizontal? && intent.vertical?) ||
      (@direction.vertical? && intent.horizontal?)
  end
end
