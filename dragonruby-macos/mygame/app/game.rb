require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/maze.rb'
require 'app/pellets.rb'
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/keyboard_controller.rb'
require 'app/player.rb'
require 'app/ghost.rb'
require 'app/ghost_controllers.rb'
require 'app/world.rb'
require 'app/renderer.rb'
require 'app/audio/beat_clock.rb'
require 'app/phase_scheduler.rb'
require 'app/frightened_timer.rb'
require 'app/release_schedule.rb'
require 'app/ghost_state_machine.rb'
require 'app/cruise_elroy.rb'
require 'app/eat_sequencer.rb'
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  LEVEL_BPM = 128
  CELLS_PER_BEAT = 4.0

  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  FRAMES_PER_BEAT = (Audio::BeatClock::FPS * 60.0) / LEVEL_BPM
  FRAMES_PER_CELL = FRAMES_PER_BEAT / CELLS_PER_BEAT
  PLAYER_SPEED = CELL_SIZE / FRAMES_PER_CELL

  GHOST_SPEED_RATIO      = 0.75 # OG Lvl 1
  GHOST_FRIGHTENED_RATIO = 0.5
  GHOST_TUNNEL_RATIO     = 0.4  # OG Lvl 1 (in tunnel row)
  GHOST_ELROY1_RATIO     = 0.85
  GHOST_ELROY2_RATIO     = 0.95

  GHOST_SPEED            = PLAYER_SPEED * GHOST_SPEED_RATIO
  GHOST_FRIGHTENED_SPEED = PLAYER_SPEED * GHOST_FRIGHTENED_RATIO
  GHOST_TUNNEL_SPEED     = PLAYER_SPEED * GHOST_TUNNEL_RATIO
  GHOST_ELROY1_SPEED     = PLAYER_SPEED * GHOST_ELROY1_RATIO
  GHOST_ELROY2_SPEED     = PLAYER_SPEED * GHOST_ELROY2_RATIO

  PRE_EAT_DUCK_LOOKAHEAD_CELLS = 1.5
  PRE_EAT_DUCK_LATERAL_TOL_CELLS = 0.8

  STEP_INPUT_GRACE_TICKS = 3

  SPAWN_MARKER_TO_IDENTITY = {
    Tiles::SPAWN_BLINKY => :blinky,
    Tiles::SPAWN_PINKY  => :pinky,
    Tiles::SPAWN_INKY   => :inky,
    Tiles::SPAWN_CLYDE  => :clyde
  }.freeze

  def initialize
    @maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
    @projection = GridProjection.new(
      cell_size: CELL_SIZE, offset_x: OFFSET_X, offset_y: OFFSET_Y,
      grid_w: @maze.width, grid_h: @maze.height
    )
    @pellets = Pellets.from_maze(@maze)
    @renderer = Renderer.new(@projection)
    @spawn_cells = scan_spawn_cells
    @player_spawn = scan_player_spawn
    @above_door_cell = @spawn_cells[:blinky]

    @phase_scheduler = PhaseScheduler.new { |mode| apply_phase_to_ghosts(mode) }
    @frightened_timer = FrightenedTimer.new { restore_ghosts_from_frightened }
    @release_schedule = ReleaseSchedule.new
    @ghost_fsm = GhostStateMachine.new(
      projection: @projection,
      above_door_cell: @above_door_cell,
      current_mode_fn: -> { @phase_scheduler.current_mode }
    )
    @eat_sequencer = EatSequencer.new(state_machine: @ghost_fsm)

    @score = 0
    @level_complete = false
    @audio_state_for = nil
    initialize_player
    initialize_ghosts
  end

  def scan_player_spawn
    @maze.each_cell do |gx, gy, ch|
      return [gx, gy] if ch == Tiles::SPAWN_PLAYER
    end
    raise "No player spawn (#{Tiles::SPAWN_PLAYER}) in layout"
  end

  def initialize_player
    spawn = @projection.cell_rect(*@player_spawn)
    @player = Player.new(
      x: spawn[:x], y: spawn[:y],
      w: CELL_SIZE, h: CELL_SIZE,
      speed: PLAYER_SPEED,
      controller: KeyboardController.new,
      direction: Direction::RIGHT
    )
    @player.configure_rhythm(
      enabled: true,
      bpm: LEVEL_BPM,
      grace_ticks: STEP_INPUT_GRACE_TICKS
    )
  end

  # Each ghost identity has one or more spawn marker chars in the layout.
  # Use the leftmost (smallest gx) for ghosts with multiple markers — anchor of
  # the 2-tile-wide sprite quad.
  def scan_spawn_cells
    cells = {}
    @maze.each_cell do |gx, gy, ch|
      id = SPAWN_MARKER_TO_IDENTITY[ch]
      next unless id
      if cells[id].nil? || gx < cells[id][0]
        cells[id] = [gx, gy]
      end
    end
    cells
  end

  def initialize_ghosts
    bounds = @maze.visible_cell_bounds
    scatter_targets = {
      blinky: [bounds[:gx1], bounds[:gy1]],
      pinky:  [bounds[:gx0], bounds[:gy1]],
      inky:   [bounds[:gx1], bounds[:gy0]],
      clyde:  [bounds[:gx0], bounds[:gy0]]
    }

    @ghosts = Ghost::IDENTITIES.map do |id|
      cell = @spawn_cells[id]
      rect = @projection.cell_rect(*cell)
      Ghost.new(
        identity: id,
        x: rect[:x], y: rect[:y],
        w: CELL_SIZE, h: CELL_SIZE,
        speed: GHOST_SPEED,
        scatter_target: scatter_targets[id],
        spawn_cell: cell,
        controller: GhostControllers.for(id),
        direction: Direction::LEFT
      )
    end
    reset_ghost_states
  end

  def reset_ghost_states
    @release_schedule.reset
    @ghosts.each do |g|
      if g.identity == :blinky
        g.state = @phase_scheduler.current_mode
        g.role = Tiles::ROLE_DEFAULT
        g.controller = GhostControllers.for(g.identity)
      else
        g.state = :in_house
        g.role = Tiles::ROLE_DEFAULT
        g.controller = nil
      end
      g.face(Direction::LEFT)
      g.speed = g.base_speed
    end
  end

  def tick
    ensure_audio_state
    args.state.audio.tick(args)
    toggle_audio_debug_watch

    if @level_complete
      args.state.audio.on_level_complete_duck_clear(args)
      request_reset_if_any_key
      @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_sequencer.popup, level_complete: true)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end

    if @eat_sequencer.frozen?
      @eat_sequencer.tick_freeze(args)
      visible_ghosts = @ghosts.reject { |g| g.state == :eaten }
      @renderer.draw(outputs, @maze, @pellets, nil, visible_ghosts, popup: @eat_sequencer.popup, level_complete: false)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end

    tick_phase
    tick_frightened
    tick_releases

    world = World.new(
      inputs: inputs,
      maze: @maze,
      projection: @projection,
      player: @player,
      pellets: @pellets,
      ghosts: @ghosts
    )

    tick_player(world)
    args.state.audio.on_ghost_eat_imminent(args, imminent: ghost_eat_imminent?)
    if check_level_complete
      @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_sequencer.popup, level_complete: true)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end
    tick_ghosts(world)
    tick_collisions
    @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_sequencer.popup, level_complete: false)
    draw_audio_debug_watch if args.state.debug_audio
  end

  def tick_phase
    @phase_scheduler.tick(paused: @frightened_timer.active?)
  end

  def apply_phase_to_ghosts(mode)
    @ghosts.each { |g| @ghost_fsm.apply_phase(g, mode) }
  end

  def tick_frightened
    @frightened_timer.tick do |remaining|
      @ghosts.each { |g| g.frightened_remaining_ticks = remaining if g.state == :frightened }
    end
  end

  def restore_ghosts_from_frightened
    @ghosts.each { |g| @ghost_fsm.restore_from_frightened(g) }
    @eat_sequencer.reset_chain
  end

  def tick_releases
    @release_schedule.tick do |id|
      ghost = @ghosts.find { |g| g.identity == id }
      @ghost_fsm.start_leaving(ghost) if ghost && ghost.state == :in_house
    end
  end

  def tick_player(world)
    intent = @player.controller.next_direction(world)
    @player.update_with_rhythm(
      tick_count: args.tick_count,
      intent: intent,
      maze: @maze,
      projection: @projection
    )
    player_eat_pellets
  end

  def player_eat_pellets
    @projection.cells_touched(@player.rect).each do |gx, gy|
      entry = @pellets.eat(gx, gy)
      next unless entry

      kind = entry[:kind]
      @release_schedule.on_dot_eaten
      @player.on_dot_eaten
      @score += (kind == :power ? 50 : 10)
      if kind == :power
        args.state.audio.on_power_pellet(args)
        trigger_frightened
      else
        args.state.audio.on_dot_collected(args, entry[:color])
      end
    end
  end

  def trigger_frightened
    @frightened_timer.trigger
    @eat_sequencer.reset_chain
    @ghosts.each do |g|
      @ghost_fsm.enter_frightened(g, GHOST_FRIGHTENED_SPEED, @frightened_timer.remaining)
    end
  end

  def tick_ghosts(world)
    debug = args&.state&.debug_ghost
    apply_dynamic_speeds
    @ghosts.each do |g|
      next if g.state == :in_house

      @ghost_fsm.tick_transitions(g, debug: debug)
      next unless g.controller

      intent = g.controller.next_direction(world, g)
      g.update(intent: intent, maze: @maze, projection: @projection)
    end
  end

  def apply_dynamic_speeds
    clyde = @ghosts.find { |g| g.identity == :clyde }
    clyde_in_house = clyde && clyde.state == :in_house
    elroy = CruiseElroy.state(@pellets.remaining, clyde_in_house: clyde_in_house)
    @ghosts.each do |g|
      next if g.state == :in_house || g.state == :leaving_house

      g.elroy_state = (g.identity == :blinky ? elroy : :off)

      next if g.state == :eaten # eaten ghosts ignore tunnel slowdown
      g.speed = effective_ghost_speed(g)
    end
  end

  def effective_ghost_speed(g)
    gx, gy = g.grid_cell(@projection)
    return GHOST_TUNNEL_SPEED if @maze.tunnel?(gx, gy)
    return GHOST_FRIGHTENED_SPEED if g.state == :frightened
    if g.identity == :blinky
      case g.elroy_state
      when :elroy2 then return GHOST_ELROY2_SPEED
      when :elroy1 then return GHOST_ELROY1_SPEED
      end
    end
    g.base_speed
  end

  def tick_collisions
    @ghosts.each do |g|
      next if g.state == :in_house || g.state == :eaten
      next unless rects_overlap?(@player.rect, g.rect)
      if g.state == :frightened
        eat_ghost(g)
      else
        player_dies
        return
      end
    end
  end

  def eat_ghost(ghost)
    @score += @eat_sequencer.on_ghost_eaten(args, ghost)
  end

  def ghost_eat_imminent?
    dir = @player.direction
    return false if dir.none?

    lookahead = CELL_SIZE * PRE_EAT_DUCK_LOOKAHEAD_CELLS
    lateral_tol = CELL_SIZE * PRE_EAT_DUCK_LATERAL_TOL_CELLS

    px = @player.x + @player.w / 2.0
    py = @player.y + @player.h / 2.0

    @ghosts.any? do |g|
      next false unless g.state == :frightened

      gx = g.x + g.w / 2.0
      gy = g.y + g.h / 2.0

      rel_x = gx - px
      rel_y = gy - py
      forward = rel_x * dir.dx + rel_y * dir.dy

      next false if forward < 0 || forward > lookahead

      lateral = dir.horizontal? ? rel_y.abs : rel_x.abs
      lateral <= lateral_tol
    end
  end

  def player_dies
    spawn = @projection.cell_rect(*@player_spawn)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.face(Direction::RIGHT)

    @ghosts.each do |g|
      cell = @spawn_cells[g.identity]
      rect = @projection.cell_rect(*cell)
      g.x = rect[:x]
      g.y = rect[:y]
    end
    @phase_scheduler.reset
    @frightened_timer.reset
    @eat_sequencer.reset
    reset_ghost_states
  end

  def ensure_audio_state
    args.state.audio ||= Audio::Manager.new(args)
    audio_id = args.state.audio.object_id
    return if @audio_state_for == audio_id

    args.state.audio.set_dot_totals(dot_totals_by_track)
    args.state.audio.set_rhythm_bpm(LEVEL_BPM) if args.state.audio.respond_to?(:set_rhythm_bpm)
    @audio_state_for = audio_id
  end

  def dot_totals_by_track
    totals = Audio::Manager::TRACKS.to_h { |track| [track, 0] }

    @pellets.each_with_color do |_pos, kind, color|
      next unless kind == :pellet
      track = Audio::Manager::DOT_COLORS[color]
      totals[track] += 1 if track
    end

    totals.transform_values { |count| count > 0 ? count : 1 }
  end

  def check_level_complete
    return false if @level_complete || @pellets.remaining != 0

    @level_complete = true
    args.state.audio.on_level_complete_duck_clear(args)
    args.state.audio.on_level_complete(args)
    true
  end

  def request_reset_if_any_key
    kb_keys = args.inputs.keyboard.key_down.truthy_keys
    c1_keys = args.inputs.controller_one.key_down.truthy_keys
    return if kb_keys.empty? && c1_keys.empty?

    args.state.request_game_reset = true
  end

  def toggle_audio_debug_watch
    return unless args.inputs.keyboard.key_down.f3

    args.state.debug_audio = !args.state.debug_audio
  end

  def draw_audio_debug_watch
    outputs.labels << {
      x: 20,
      y: 700,
      text: "duck active=#{args.state.audio.duck_active} amount=#{args.state.audio.duck_amount.round(2)} gain=#{args.state.audio.duck_gain_multiplier.round(2)}",
      size_enum: 1,
      r: 255,
      g: 255,
      b: 0
    }
  end

  def rects_overlap?(a, b)
    a[:x] < b[:x] + b[:w] && a[:x] + a[:w] > b[:x] &&
      a[:y] < b[:y] + b[:h] && a[:y] + a[:h] > b[:y]
  end
end
