# app/player.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/audio/beat_clock.rb'

class Player
  include GridMover

  attr_accessor :controller
  attr_reader :move_state, :commit_direction, :rhythm_fallback

  def initialize(x:, y:, w:, h:, speed:, controller:, direction: Direction::NONE)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @controller = controller
    @base_speed = speed.to_f
    @sprite_scale = 1.5
    @sprite_offset = (w * @sprite_scale - w) / 2.0

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
    advance(maze, projection)
  end

  def to_sprite
    { 
      x: @x - @sprite_offset, y: @y - @sprite_offset,
      w: @w * @sprite_scale, h: @h * @sprite_scale,
      path: "sprites/circle/yellow.png"
    }
  end

  private

  def update_immediate(intent:, maze:, projection:)
    @speed = @base_speed
    try_turn(intent, maze, projection)
    advance(maze, projection)
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
