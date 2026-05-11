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
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  LEVEL_BPM = 120
  CELLS_PER_BEAT = 2.0

  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  FRAMES_PER_BEAT = (Audio::BeatClock::FPS * 60.0) / LEVEL_BPM
  FRAMES_PER_CELL = FRAMES_PER_BEAT / CELLS_PER_BEAT
  PLAYER_SPEED = CELL_SIZE / FRAMES_PER_CELL

  GHOST_SPEED_RATIO = 0.75
  GHOST_FRIGHTENED_RATIO = 0.5

  GHOST_SPEED            = PLAYER_SPEED * GHOST_SPEED_RATIO
  GHOST_FRIGHTENED_SPEED = PLAYER_SPEED * GHOST_FRIGHTENED_RATIO
  FRIGHTENED_DURATION_TICKS = 600 # 10s @ 60fps

  PHASE_TABLE = [
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   nil]
  ].freeze

  RELEASE_DOT_THRESHOLD = {
    blinky: 0,
    pinky:  0,
    inky:   30,
    clyde:  60
  }.freeze
  RELEASE_STALL_TICKS = 4 * 60

  EAT_POINTS = [200, 400, 800, 1600].freeze
  EAT_PAUSE_TICKS = 60 # 1s arcade-style freeze on eat
  EAT_DUCK_HOLD_RATIO = 0.75
  PRE_EAT_DUCK_LOOKAHEAD_CELLS = 1.5
  PRE_EAT_DUCK_LATERAL_TOL_CELLS = 0.8
  DUCK_GAIN_SCALE = 0.4
  DUCK_RAMP_IN_TICKS = 1
  DUCK_RAMP_OUT_TICKS = 2

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
    @dot_count = 0
    @ticks_since_release = 0
    @phase_index = 0
    @phase_ticks = 0
    @frightened_ticks = 0
    @eat_chain = 0
    @score = 0
    @eat_pause_ticks = 0
    @eat_duck_hold_ticks = 0
    @eat_duck_releasing = false
    @eat_popup = nil
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
  # Use the leftmost (smallest gx) for ghosts with multiple markers — that
  # is the anchor of the 2-tile-wide sprite quad.
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
    @released = { blinky: true, pinky: false, inky: false, clyde: false }
    @ghosts.each do |g|
      if g.identity == :blinky
        g.state = current_phase_mode
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
      args.state.audio.set_duck(args, active: false,
                                      gain_scale: DUCK_GAIN_SCALE,
                                      ramp_in: DUCK_RAMP_IN_TICKS,
                                      ramp_out: DUCK_RAMP_OUT_TICKS)
      request_reset_if_any_key
      @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_popup, level_complete: true)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end

    if @eat_pause_ticks > 0
      process_eat_freeze_duck
      visible_ghosts = @ghosts.reject { |g| g.state == :eaten }
      @renderer.draw(outputs, @maze, @pellets, nil, visible_ghosts, popup: @eat_popup, level_complete: false)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end

    args.state.audio.set_duck(args, active: false,
                                    gain_scale: DUCK_GAIN_SCALE,
                                    ramp_in: DUCK_RAMP_IN_TICKS,
                                    ramp_out: DUCK_RAMP_OUT_TICKS)

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
    maybe_preduck_ghost_eat
    if check_level_complete
      @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_popup, level_complete: true)
      draw_audio_debug_watch if args.state.debug_audio
      return
    end
    tick_ghosts(world)
    tick_collisions
    @renderer.draw(outputs, @maze, @pellets, @player, @ghosts, popup: @eat_popup, level_complete: false)
    draw_audio_debug_watch if args.state.debug_audio
  end

  def tick_phase
    return if any_frightened?
    _, dur = PHASE_TABLE[@phase_index]
    return if dur.nil?
    @phase_ticks += 1
    return if @phase_ticks < dur
    @phase_index += 1
    @phase_ticks = 0
    apply_phase_to_ghosts
  end

  def current_phase_mode
    PHASE_TABLE[@phase_index][0]
  end

  def apply_phase_to_ghosts
    mode = current_phase_mode
    @ghosts.each do |g|
      next unless g.state == :scatter || g.state == :chase
      g.state = mode
      g.face(g.direction.opposite) unless g.direction.none?
    end
  end

  def tick_frightened
    return if @frightened_ticks <= 0
    @frightened_ticks -= 1
    @ghosts.each { |g| g.frightened_remaining_ticks = @frightened_ticks if g.state == :frightened }
    return if @frightened_ticks > 0
    mode = current_phase_mode
    @ghosts.each do |g|
      if g.state == :frightened
        g.state = mode
        g.controller = GhostControllers.for(g.identity)
        g.speed = g.base_speed
        snap_to_cell(g)
      end
    end
    @eat_chain = 0
  end

  def tick_releases
    @ticks_since_release += 1
    Ghost::IDENTITIES.each do |id|
      next if @released[id]
      threshold = RELEASE_DOT_THRESHOLD[id]
      if @dot_count >= threshold || @ticks_since_release >= RELEASE_STALL_TICKS
        @released[id] = true
        @ticks_since_release = 0
        ghost = @ghosts.find { |g| g.identity == id }
        start_leaving_house(ghost) if ghost && ghost.state == :in_house
        break
      end
    end
  end

  def start_leaving_house(ghost)
    ghost.state = :leaving_house
    ghost.role = Tiles::ROLE_GHOST_LEAVING
    ghost.controller = GhostControllers::LeavingHouse.new(@above_door_cell)
    ghost.face(Direction::UP)
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
      @dot_count += 1
      @ticks_since_release = 0
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
    @frightened_ticks = FRIGHTENED_DURATION_TICKS
    @eat_chain = 0
    @ghosts.each do |g|
      next unless g.state == :scatter || g.state == :chase
      g.state = :frightened
      g.controller = GhostControllers::Frightened.new
      g.speed = GHOST_FRIGHTENED_SPEED
      g.frightened_remaining_ticks = FRIGHTENED_DURATION_TICKS
      g.face(g.direction.opposite) unless g.direction.none?
    end
  end

  def tick_ghosts(world)
    @ghosts.each do |g|
      next if g.state == :in_house

      handle_ghost_state_transitions(g)
      next unless g.controller

      intent = g.controller.next_direction(world, g)
      g.try_turn(intent, @maze, @projection) unless intent.none?
      g.advance(@maze, @projection)
    end
  end

  def handle_ghost_state_transitions(ghost)
    return unless ghost.at_cell_center?(@projection)
    cell = ghost.grid_cell(@projection)

    case ghost.state
    when :eaten
      if cell == ghost.spawn_cell
        # Reached home — flip to leaving so it walks back out the door.
        start_leaving_house(ghost)
      end
    when :leaving_house
      if cell == @above_door_cell
        ghost.state = current_phase_mode
        ghost.role = Tiles::ROLE_DEFAULT
        ghost.controller = GhostControllers.for(ghost.identity)
        ghost.speed = ghost.base_speed
      end
    end
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
    points = EAT_POINTS[[@eat_chain, EAT_POINTS.size - 1].min]
    @score += points
    args.state.audio.set_duck(args, active: true,
                                    gain_scale: DUCK_GAIN_SCALE,
                                    ramp_in: DUCK_RAMP_IN_TICKS,
                                    ramp_out: DUCK_RAMP_OUT_TICKS,
                                    immediate: true)
    # Audio tick normally runs at frame start; push updated duck now so hit is immediate.
    args.state.audio.tick(args)
    args.state.audio.on_enemy_eaten(args, sequence: @eat_chain + 1)
    @eat_chain += 1
    ghost.state = :eaten
    ghost.role = Tiles::ROLE_GHOST_EATEN
    ghost.controller = GhostControllers::Eaten.new
    ghost.speed = ghost.base_speed
    snap_to_cell(ghost)
    @eat_pause_ticks = EAT_PAUSE_TICKS
    @eat_duck_hold_ticks = (EAT_PAUSE_TICKS * EAT_DUCK_HOLD_RATIO).to_i
    @eat_duck_releasing = false
    @eat_popup = { x: ghost.x + ghost.w / 2, y: ghost.y + ghost.h / 2, text: points.to_s }
  end

  def process_eat_freeze_duck
    if !@eat_duck_releasing
      args.state.audio.set_duck(args, active: true,
                                      gain_scale: DUCK_GAIN_SCALE,
                                      ramp_in: DUCK_RAMP_IN_TICKS,
                                      ramp_out: DUCK_RAMP_OUT_TICKS)
      @eat_duck_hold_ticks -= 1
      @eat_duck_releasing = true if @eat_duck_hold_ticks <= 0
    else
      args.state.audio.set_duck(args, active: false,
                                      gain_scale: DUCK_GAIN_SCALE,
                                      ramp_in: DUCK_RAMP_IN_TICKS,
                                      ramp_out: DUCK_RAMP_OUT_TICKS)
    end

    @eat_pause_ticks -= 1 if @eat_pause_ticks > 0

    # Freeze ends only after both base freeze budget and duck release complete.
    if @eat_pause_ticks <= 0 && args.state.audio.duck_amount <= 0.001
      @eat_pause_ticks = 0
      @eat_duck_releasing = false
      @eat_popup = nil
    end
  end

  def maybe_preduck_ghost_eat
    imminent = ghost_eat_imminent?
    args.state.audio.set_duck(args, active: imminent,
                                    gain_scale: DUCK_GAIN_SCALE,
                                    ramp_in: DUCK_RAMP_IN_TICKS,
                                    ramp_out: DUCK_RAMP_OUT_TICKS)
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
    reset_ghost_states
    @phase_index = 0
    @phase_ticks = 0
    @frightened_ticks = 0
    @eat_chain = 0
    @ticks_since_release = 0
  end

  # Frightened ghosts run at odd speed (1) so their pixel position can fall
  # off the integer-cell-aligned grid. When transitioning to a state whose
  # speed is even, that drift would prevent at_cell_center? from ever firing
  # again, freezing all turning decisions. Snap on entry to fix.
  def snap_to_cell(ghost)
    cs = @projection.cell_size
    ghost.x = ((ghost.x - @projection.offset_x) / cs).round * cs + @projection.offset_x
    ghost.y = ((ghost.y - @projection.offset_y) / cs).round * cs + @projection.offset_y
  end

  def any_frightened?
    @frightened_ticks > 0
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
    args.state.audio.set_duck(args, active: false,
                                    gain_scale: DUCK_GAIN_SCALE,
                                    ramp_in: DUCK_RAMP_IN_TICKS,
                                    ramp_out: DUCK_RAMP_OUT_TICKS)
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
