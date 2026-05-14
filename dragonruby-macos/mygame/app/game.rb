require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/camera.rb'
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
require 'app/release_schedule.rb'
require 'app/ghost_state_machine.rb'
require 'app/cruise_elroy.rb'
require 'app/eat_sequencer.rb'
require 'app/projectile.rb'
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  LEVEL_BPM = 128
  CELLS_PER_BEAT = 4.0

  # Half the player sprite height (ADR-0008): a 2-cell-wide tunnel then spans
  # exactly one sprite height, so the player fits the tunnel cleanly. Camera
  # still runs at zoom 1.0; the sprite renders native across a 2x2 cell span.
  CELL_SIZE = Player::PLAYER_SPRITE_HEIGHT / 2
  PROJECTILE_SIZE = CELL_SIZE * 2
  FRAMES_PER_BEAT = (Audio::BeatClock::FPS * 60.0) / LEVEL_BPM
  FRAMES_PER_CELL = FRAMES_PER_BEAT / CELLS_PER_BEAT
  PLAYER_SPEED = CELL_SIZE / FRAMES_PER_CELL

  GHOST_SPEED_RATIO      = 0.75 # OG Lvl 1
  GHOST_TUNNEL_RATIO     = 0.4  # OG Lvl 1 (in tunnel row)
  GHOST_ELROY1_RATIO     = 0.85
  GHOST_ELROY2_RATIO     = 0.95

  GHOST_SPEED            = PLAYER_SPEED * GHOST_SPEED_RATIO
  GHOST_TUNNEL_SPEED     = PLAYER_SPEED * GHOST_TUNNEL_RATIO
  GHOST_ELROY1_SPEED     = PLAYER_SPEED * GHOST_ELROY1_RATIO
  GHOST_ELROY2_SPEED     = PLAYER_SPEED * GHOST_ELROY2_RATIO

  PROJECTILE_SPEED       = PLAYER_SPEED * 2.0

  STEP_INPUT_GRACE_TICKS = 3

  STARTING_LIVES = 3
  # Ready-state count-in length: one bar.
  READY_TICKS = (FRAMES_PER_BEAT * CELLS_PER_BEAT).round
  # Grace before game-over accepts a restart key (lets the stinger breathe).
  GAME_OVER_INPUT_GRACE_TICKS = 45

  SPAWN_MARKER_TO_IDENTITY = {
    Tiles::SPAWN_BLINKY => :blinky,
    Tiles::SPAWN_PINKY  => :pinky,
    Tiles::SPAWN_INKY   => :inky,
    Tiles::SPAWN_CLYDE  => :clyde
  }.freeze

  def initialize
    @maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
    @projection = GridProjection.new(
      cell_size: CELL_SIZE,
      grid_w: @maze.width, grid_h: @maze.height
    )
    @pellets = Pellets.from_maze(@maze)
    @renderer = Renderer.new(@projection)
    @camera = Camera.new(
      world_w: CELL_SIZE * @maze.width,
      world_h: CELL_SIZE * @maze.height,
      cell_size: CELL_SIZE
    )
    @spawn_cells = scan_spawn_cells
    @player_spawn = scan_player_spawn
    @above_door_cell = @spawn_cells[:blinky]

    @phase_scheduler = PhaseScheduler.new { |mode| apply_phase_to_ghosts(mode) }
    @release_schedule = ReleaseSchedule.new
    @ghost_fsm = GhostStateMachine.new(
      projection: @projection,
      above_door_cell: @above_door_cell,
      current_mode_fn: -> { @phase_scheduler.current_mode }
    )
    @eat_sequencer = EatSequencer.new(state_machine: @ghost_fsm)

    @score = 0
    @lives = STARTING_LIVES
    @audio_state_for = nil
    @projectiles = []
    initialize_player
    initialize_ghosts
    enter_ready
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
    # OG-style off-map scatter targets: unreachable points beyond each
    # corner so ghosts orbit the corner rather than settling on it. With
    # on-map targets they oscillate between the two corridor intersections
    # adjacent to the corner cell instead of taking the vertical path.
    scatter_targets = {
      blinky: [bounds[:gx1],     bounds[:gy1] + 3],
      pinky:  [bounds[:gx0],     bounds[:gy1] + 3],
      inky:   [bounds[:gx1],     bounds[:gy0] - 3],
      clyde:  [bounds[:gx0],     bounds[:gy0] - 3]
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
      GhostControllers::Targeting.clear_latch(g.identity)
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

  # Point the camera at the player centre. Render-only; called before each draw.
  def update_camera
    @camera.follow(
      @player.x + @player.w / 2.0,
      @player.y + @player.h / 2.0,
      @player.direction
    )
  end

  def tick
    ensure_audio_state
    args.state.audio.tick(args)
    toggle_audio_debug_watch

    case @state
    when :ready          then tick_ready
    when :playing        then tick_playing
    when :dying          then tick_dying
    when :level_complete then tick_level_complete
    when :game_over      then tick_game_over
    end
  end

  # --- Game state machine (see CONTEXT.md "Game state") --------------------

  def enter_ready
    @state = :ready
    @ready_elapsed = 0
    @ready_last_beat = -1
  end

  def tick_ready
    beat = (@ready_elapsed / FRAMES_PER_BEAT).floor
    if beat != @ready_last_beat
      @ready_last_beat = beat
      args.state.audio.on_count_in_beat(args)
    end
    @ready_elapsed += 1
    @state = :playing if @ready_elapsed >= READY_TICKS

    update_camera
    draw_frame
  end

  def tick_playing
    @eat_sequencer.tick(args)
    if @eat_sequencer.frozen?
      visible_ghosts = @ghosts.reject { |g| g.state == :eaten && !g.flashing? }
      update_camera
      draw_frame(ghosts: visible_ghosts)
      return
    end

    tick_phase
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
    update_camera
    if check_level_complete
      draw_frame
      return
    end
    tick_ghosts(world)
    tick_fire_input(world)
    tick_projectiles
    tick_collisions
    draw_frame
  end

  # Phase 1: fixed-frame death animation, world frozen, music ducked out.
  # Phase 2: actors reset, then the camera eases back to the player while
  # music eases in. Routes to game_over when no lives remain.
  def tick_dying
    if @dying_phase == :anim
      @player.tick_death
      if @player.death_anim_done?
        respawn_actors
        if @lives <= 0
          enter_game_over
          return
        end
        start_camera_return
        @dying_phase = :camera
      end
      draw_frame
    else # :camera
      arrived = @camera.tick_dying_ease
      draw_frame
      @state = :playing if arrived
    end
  end

  def tick_level_complete
    args.state.audio.on_level_complete_duck_clear(args)
    if any_key_pressed?
      start_next_level
      return
    end
    update_camera
    draw_frame
  end

  def tick_game_over
    @game_over_ticks += 1
    request_reset_if_any_key if @game_over_ticks > GAME_OVER_INPUT_GRACE_TICKS
    update_camera
    draw_frame
  end

  def enter_dying
    @lives -= 1
    @state = :dying
    @dying_phase = :anim
    @player.begin_death
    @projectiles.clear
    args.state.audio.on_player_death(args)
  end

  def enter_game_over
    @state = :game_over
    @game_over_ticks = 0
    args.state.audio.on_game_over(args)
  end

  # In-place reset for the level loop: keep score and lives, rebuild pellets
  # and actors, return to the ready count-in.
  def start_next_level
    @pellets = Pellets.from_maze(@maze)
    @projectiles.clear
    reset_player_to_spawn
    @player.reset_ammo!
    initialize_ghosts
    @phase_scheduler.reset
    @eat_sequencer.reset
    @audio_state_for = nil # forces set_dot_totals refresh for the new pellets
    enter_ready
  end

  def reset_player_to_spawn
    spawn = @projection.cell_rect(*@player_spawn)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.face(Direction::RIGHT)
    @player.clear_death
  end

  # Teleport player + ghosts to spawn, reset schedulers. The dying-phase
  # boundary — runs once the death animation completes.
  def respawn_actors
    reset_player_to_spawn
    @ghosts.each do |g|
      cell = @spawn_cells[g.identity]
      rect = @projection.cell_rect(*cell)
      g.x = rect[:x]
      g.y = rect[:y]
    end
    @phase_scheduler.reset
    @eat_sequencer.reset
    reset_ghost_states
  end

  def start_camera_return
    cx = @player.x + @player.w / 2.0
    cy = @player.y + @player.h / 2.0
    @camera.begin_dying_ease(cx, cy)
    args.state.audio.on_respawn(args, ramp_out: @camera.dying_ease_duration)
  end

  def draw_frame(ghosts: @ghosts)
    @renderer.draw(
      outputs, @maze, @pellets, @player, ghosts,
      camera: @camera,
      projectiles: @projectiles,
      popup: @eat_sequencer.popup,
      hud: hud_data,
      state: @state
    )
    draw_audio_debug_watch if args.state.debug_audio
  end

  def hud_data
    {
      score: @score,
      lives: @lives,
      completion: @pellets.completion_by_color
    }
  end

  def any_key_pressed?
    !args.inputs.keyboard.key_down.truthy_keys.empty? ||
      !args.inputs.controller_one.key_down.truthy_keys.empty?
  end

  def tick_phase
    @phase_scheduler.tick
  end

  def apply_phase_to_ghosts(mode)
    @ghosts.each { |g| @ghost_fsm.apply_phase(g, mode) }
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
        @player.gain_ammo
      else
        args.state.audio.on_dot_collected(args, entry[:color])
      end
    end
  end

  def tick_fire_input(world)
    return unless @player.controller.respond_to?(:fire_pressed?)
    return unless @player.controller.fire_pressed?(world)
    return if @player.direction.none?
    return unless @player.consume_ammo!
    fire_projectile
  end

  def tick_projectiles
    @projectiles.each { |p| p.tick(@maze, @projection) }
    resolve_projectile_hits
    @projectiles.reject!(&:dead?)
  end

  def fire_projectile
    cx = @player.x + @player.w / 2.0
    cy = @player.y + @player.h / 2.0
    @projectiles << Projectile.new(
      cx: cx, cy: cy, direction: @player.direction,
      speed: PROJECTILE_SPEED, size: PROJECTILE_SIZE
    )
  end

  def resolve_projectile_hits
    @projectiles.each do |p|
      next if p.dead?
      @ghosts.each do |g|
        next if g.state == :in_house || g.state == :eaten
        next unless rects_overlap?(p.rect, g.rect)
        eat_ghost(g)
        p.kill!
        break
      end
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
      enter_dying
      return
    end
  end

  def eat_ghost(ghost)
    @score += @eat_sequencer.on_ghost_eaten(args, ghost)
  end

  def ensure_audio_state
    args.state.audio ||= Audio::Manager.new(args)
    audio_id = args.state.audio.object_id
    return if @audio_state_for == audio_id

    args.state.audio.set_dot_totals(dot_totals_by_track)
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
    return false if @state == :level_complete || @pellets.remaining != 0

    @state = :level_complete
    @projectiles.clear
    @player.reset_ammo!
    args.state.audio.on_level_complete_duck_clear(args)
    args.state.audio.on_level_complete(args)
    true
  end

  def request_reset_if_any_key
    args.state.request_game_reset = true if any_key_pressed?
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
