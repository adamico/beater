require 'app/tiles'
require 'app/grid_projection'
require 'app/camera'
require 'app/maze'
require 'app/pellets'
require 'app/direction'
require 'app/grid_mover'
require 'app/keyboard_controller'
require 'app/player'
require 'app/ghost'
require 'app/ghost_controllers'
require 'app/world'
require 'app/renderer'
require 'app/audio/beat_clock'
require 'app/level_config'
require 'app/phase_scheduler'
require 'app/release_schedule'
require 'app/ghost_state_machine'
require 'app/territory'
require 'app/enrage'
require 'app/eat_sequencer'
require 'app/projectile'
require 'data/maps/pacman_layout'
require 'app/scenes/scene_director'
require 'app/scenes/scene_layout'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/highscores'

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

  # Ghost speeds, tunnel slowdown and Cruise Elroy thresholds are per-Level
  # data — see LevelConfig and CONTEXT.md "Level".

  PROJECTILE_SPEED       = PLAYER_SPEED * 2.0

  STEP_INPUT_GRACE_TICKS = 3

  STARTING_LIVES = 3
  # Ready-state count-in length: one bar.
  READY_TICKS = (FRAMES_PER_BEAT * CELLS_PER_BEAT).round
  # Grace before game-over accepts a restart key (lets the stinger breathe).
  GAME_OVER_INPUT_GRACE_TICKS = 45

  # G1: track-completion bonus — awarded when a colour's last dot is eaten.
  TRACK_COMPLETE_BONUS    = 1000
  TRACK_POPUP_TICKS       = EatSequencer::POPUP_TICKS
  TRACK_POPUP_FLOAT       = EatSequencer::POPUP_FLOAT_PER_TICK
  METER_FLASH_TICKS       = 24

  SPAWN_MARKER_TO_IDENTITY = {
    Tiles::SPAWN_BLINKY => :blinky,
    Tiles::SPAWN_PINKY => :pinky,
    Tiles::SPAWN_INKY => :inky,
    Tiles::SPAWN_CLYDE => :clyde
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
    @prison_cells = scan_prison_cells
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
    @level = 1
    @play_ticks = 0 # ADR-0013: only advances during tick_playing
    @audio_state_for = nil
    @projectiles = []
    @track_popups = []      # G1: Game-owned score popups for track completion
    @meter_flash = {}       # G1: color => ticks remaining for HUD meter flash
    apply_level_config
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

      cells[id] = [gx, gy] if cells[id].nil? || gx < cells[id][0]
    end
    cells
  end

  # G6: locate the four prison cells (k/l/m/n) — one per ghost identity.
  def scan_prison_cells
    cells = {}
    @maze.each_cell do |gx, gy, ch|
      id = Tiles::PRISON_TO_IDENTITY[ch]
      cells[id] = [gx, gy] if id
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
      blinky: [bounds[:gx1], bounds[:gy1] + 3],
      pinky: [bounds[:gx0], bounds[:gy1] + 3],
      inky: [bounds[:gx1], bounds[:gy0] - 3],
      clyde: [bounds[:gx0], bounds[:gy0] - 3]
    }

    @ghosts = Ghost::IDENTITIES.map do |id|
      cell = @spawn_cells[id]
      rect = @projection.cell_rect(*cell)
      Ghost.new(
        identity: id,
        x: rect[:x], y: rect[:y],
        w: CELL_SIZE, h: CELL_SIZE,
        speed: PLAYER_SPEED * @level_config[:ghost_speed_ratio],
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
    # Pre-mark imprisoned ghosts as already released so the schedule never
    # tries to spawn them out of the house (G6 Pacify persists through death).
    @ghosts.each { |g| @release_schedule.mark_released(g.identity) if g.imprisoned? }
    @ghosts.each do |g|
      next if g.imprisoned? # G6: pacified ghosts stay imprisoned across death

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
    when :paused         then tick_paused
    when :dying          then tick_dying
    when :level_complete then tick_level_complete
    when :game_over      then tick_game_over
    end
  end

  PAUSE_ITEMS = %i[resume settings exit_to_title].freeze
  PAUSE_LABELS = {
    resume: 'RESUME',
    settings: 'SETTINGS',
    exit_to_title: 'EXIT TO TITLE'
  }.freeze
  PAUSE_ITEM_W = 320
  PAUSE_ITEM_H = 52
  PAUSE_ITEM_GAP = 14
  PAUSE_ITEMS_TOP_Y = SceneDirector::SCREEN_H - 320

  def enter_paused
    @state = :paused
    @pause_selected = 0
    args.state.audio.on_pause(args)
  end

  def exit_paused
    @state = :playing
    args.state.audio.on_resume(args)
  end

  def tick_paused
    handle_pause_input
    draw_frame
    draw_pause_overlay
  end

  def handle_pause_input
    return if SceneDirector.transitioning?

    if Scenes::MenuInput.pause?(args)
      exit_paused
      return
    end

    result = Scenes::MenuController.update(
      args,
      selected: @pause_selected,
      count: PAUSE_ITEMS.length,
      item_rects: pause_item_rects
    )
    @pause_selected = result[:selected]
    activate_pause_item if result[:action] == :activate
  end

  def pause_item_rects
    Scenes::MenuRenderer.item_rects(
      PAUSE_ITEMS.length,
      screen_w: SceneDirector::SCREEN_W,
      top_y: PAUSE_ITEMS_TOP_Y,
      item_w: PAUSE_ITEM_W,
      item_h: PAUSE_ITEM_H,
      gap: PAUSE_ITEM_GAP
    )
  end

  def activate_pause_item
    case PAUSE_ITEMS[@pause_selected]
    when :resume        then exit_paused
    when :settings      then SceneDirector.request(:settings, return_to: :playing)
    when :exit_to_title then SceneDirector.request(:title)
    end
  end

  def draw_pause_overlay
    Scenes::MenuRenderer.draw_dim(
      outputs,
      w: SceneDirector::SCREEN_W,
      h: SceneDirector::SCREEN_H
    )
    Scenes::MenuRenderer.draw_heading(
      outputs, 'PAUSED',
      x: SceneDirector::SCREEN_W / 2,
      y: SceneDirector::SCREEN_H - 120
    )
    Scenes::MenuRenderer.draw_items(
      outputs,
      pause_item_rects,
      PAUSE_ITEMS.map { |k| PAUSE_LABELS[k] },
      @pause_selected,
      label_size: 5
    )
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
    @play_ticks += 1 # ADR-0013: exactly once per tick_playing call
    if pause_pressed?
      enter_paused
      draw_frame
      draw_pause_overlay
      return
    end
    @eat_sequencer.tick(args)
    tick_track_fx
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

  GAME_OVER_ITEMS = %i[retry back_to_title].freeze
  GAME_OVER_LABELS = { retry: 'RETRY', back_to_title: 'BACK TO TITLE' }.freeze
  GAME_OVER_ITEM_W = 320
  GAME_OVER_ITEM_H = 52
  GAME_OVER_ITEM_GAP = 14
  GAME_OVER_MENU_TOP_Y = 200

  def tick_game_over
    @game_over_ticks += 1
    case @game_over_phase
    when :initials then handle_initials_input
    when :menu     then handle_game_over_menu
    end
    draw_game_over_screen
  end

  def handle_initials_input
    return if SceneDirector.transitioning?

    if Scenes::MenuInput.cancel?(args)
      # Skip initials entry — score is not recorded.
      @game_over_phase = :menu
      return
    end
    if Scenes::MenuInput.confirm?(args)
      Audio::SFXPlayer.play(args, :ui_activate)
      commit_initials
      return
    end

    v = Scenes::MenuInput.navigate_delta(args)
    if v != 0
      # Up (-1) advances the letter (A→B); Down (+1) goes back.
      @initials[@initials_slot] = (@initials[@initials_slot] - v) % 26
      Audio::SFXPlayer.play(args, :ui_navigate)
    end

    h = Scenes::MenuInput.horizontal_delta(args)
    if h != 0
      @initials_slot = (@initials_slot + h) % 3
      Audio::SFXPlayer.play(args, :ui_navigate)
    end
  end

  def commit_initials
    letters = @initials.map { |i| ('A'.ord + i).chr }.join
    date = (Time.now.strftime('%Y-%m-%d') rescue '----')
    @final_rank = Highscores.insert(
      score: @score, level_reached: @level,
      time_seconds: @play_ticks / 60, initials: letters, date: date
    )
    @game_over_phase = :menu
  end

  def handle_game_over_menu
    return if SceneDirector.transitioning?
    return if @game_over_ticks < GAME_OVER_INPUT_GRACE_TICKS

    result = Scenes::MenuController.update(
      args,
      selected: @game_over_selected,
      count: GAME_OVER_ITEMS.length,
      item_rects: game_over_item_rects
    )
    @game_over_selected = result[:selected]
    case result[:action]
    when :activate then activate_game_over_item
    when :cancel   then args.state.request_game_reset = true
    end
  end

  def activate_game_over_item
    case GAME_OVER_ITEMS[@game_over_selected]
    when :retry         then args.state.request_replay = true
    when :back_to_title then args.state.request_game_reset = true
    end
  end

  def game_over_item_rects
    Scenes::MenuRenderer.item_rects(
      GAME_OVER_ITEMS.length,
      screen_w: Scenes::SceneLayout::SCREEN_W,
      top_y: GAME_OVER_MENU_TOP_Y,
      item_w: GAME_OVER_ITEM_W,
      item_h: GAME_OVER_ITEM_H,
      gap: GAME_OVER_ITEM_GAP
    )
  end

  def draw_game_over_screen
    outputs.background_color = [12, 8, 24]
    draw_game_over_header
    draw_game_over_stats
    draw_highscore_table
    if @game_over_phase == :initials
      draw_initials_rotor
    else
      draw_game_over_menu
    end
  end

  def draw_game_over_header
    Scenes::MenuRenderer.draw_heading(
      outputs, 'GAME OVER',
      x: Scenes::SceneLayout::SCREEN_W / 2,
      y: Scenes::SceneLayout.header_center_y,
      size: 14
    )
  end

  def draw_game_over_stats
    time = Highscores.format_time(@play_ticks / 60)
    outputs.primitives << {
      x: Scenes::SceneLayout::SCREEN_W / 2, y: 590,
      text: "SCORE #{@score}    LEVEL #{@level}    TIME #{time}",
      size_enum: 5, alignment_enum: 1, vertical_alignment_enum: 1,
      r: 220, g: 220, b: 220
    }.label!
  end

  def draw_highscore_table
    cx = Scenes::SceneLayout::SCREEN_W / 2
    outputs.primitives << {
      x: cx, y: 530, text: 'HIGHSCORES',
      size_enum: 4, alignment_enum: 1, vertical_alignment_enum: 1,
      r: 255, g: 230, b: 100
    }.label!

    row_top = 490
    row_h = 28
    Highscores.entries.each_with_index do |e, i|
      rank = i + 1
      is_new = (@final_rank == rank)
      color = is_new ? { r: 255, g: 230, b: 100 } : { r: 220, g: 220, b: 220 }
      line = "#{rank}.  #{e[:initials]}   #{e[:score]}   L#{e[:level_reached]}   #{Highscores.format_time(e[:time_seconds])}"
      outputs.primitives << {
        x: cx, y: row_top - i * row_h,
        text: line, size_enum: 2,
        alignment_enum: 1, vertical_alignment_enum: 1,
        **color
      }.label!
    end
  end

  def draw_initials_rotor
    cx = Scenes::SceneLayout::SCREEN_W / 2
    outputs.primitives << {
      x: cx, y: 210,
      text: 'NEW HIGHSCORE — ENTER INITIALS',
      size_enum: 3, alignment_enum: 1, vertical_alignment_enum: 1,
      r: 255, g: 230, b: 100
    }.label!

    slot_w = 60
    slot_gap = 30
    total_w = 3 * slot_w + 2 * slot_gap
    start_x = cx - total_w / 2
    box_y = 110
    box_h = 80
    3.times do |i|
      is_sel = (i == @initials_slot)
      char = ('A'.ord + @initials[i]).chr
      box = { x: start_x + i * (slot_w + slot_gap), y: box_y, w: slot_w, h: box_h }
      fill = is_sel ? Scenes::MenuRenderer::SELECTED_FILL : Scenes::MenuRenderer::UNSELECTED_FILL
      border = is_sel ? Scenes::MenuRenderer::SELECTED_BORDER : Scenes::MenuRenderer::UNSELECTED_BORDER
      outputs.primitives << box.merge(fill).solid!
      outputs.primitives << box.merge(border).border!
      outputs.primitives << {
        x: box[:x] + box[:w] / 2, y: box[:y] + box[:h] / 2,
        text: char, size_enum: 8,
        alignment_enum: 1, vertical_alignment_enum: 1,
        r: 255, g: 255, b: 255
      }.label!
    end

    outputs.primitives << {
      x: cx, y: 70,
      text: 'Up/Down change letter  —  Left/Right move slot  —  Enter confirm  —  Esc skip',
      size_enum: 0, alignment_enum: 1, vertical_alignment_enum: 1,
      r: 160, g: 160, b: 180
    }.label!
  end

  def draw_game_over_menu
    Scenes::MenuRenderer.draw_items(
      outputs, game_over_item_rects,
      GAME_OVER_ITEMS.map { |k| GAME_OVER_LABELS[k] },
      @game_over_selected,
      label_size: 4
    )
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
    @game_over_selected = 0
    @final_rank = nil
    @initials = [0, 0, 0]
    @initials_slot = 0
    @game_over_phase = Highscores.qualifies?(@score) ? :initials : :menu
    args.state.audio.on_game_over(args)
  end

  # Single seam for per-Level difficulty data (see CONTEXT.md "Level").
  # Called from initialize (level 1) and start_next_level. Seeds the phase
  # scheduler; ghost speeds and Elroy thresholds are read live from
  # @level_config by initialize_ghosts / apply_dynamic_speeds.
  def apply_level_config
    @level_config = LevelConfig.for(@level)
    @phase_scheduler.load_table(@level_config[:phase_table])
  end

  # In-place reset for the level loop: keep score and lives, rebuild pellets
  # and actors, return to the ready count-in.
  def start_next_level
    @level += 1
    apply_level_config
    @pellets = Pellets.from_maze(@maze)
    @projectiles.clear
    reset_player_to_spawn
    @player.reset_ammo!
    initialize_ghosts
    @phase_scheduler.reset
    @eat_sequencer.reset
    @track_popups.clear
    @meter_flash.clear
    @audio_state_for = nil # forces set_dot_totals refresh for the new pellets
    args.state.audio.on_level_start(args) # re-close track filters to initial values
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
      next if g.imprisoned? # G6: pacified ghosts stay locked in their prison cell

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
      track_popups: @track_popups,
      hud: hud_data,
      state: @state
    )
    draw_audio_debug_watch if args.state.debug_audio
  end

  def hud_data
    beats = args.tick_count.to_f / FRAMES_PER_BEAT
    {
      score: @score,
      lives: @lives,
      completion: @pellets.completion_by_color,
      meter_flash: @meter_flash,
      beat_phase: beats - beats.floor
    }
  end

  def pause_pressed?
    Scenes::MenuInput.pause?(args)
  end

  def any_key_pressed?
    !args.inputs.keyboard.key_down.truthy_keys.empty? ||
      !args.inputs.controller_one.key_down.truthy_keys.empty?
  end

  def tick_phase
    @phase_scheduler.tick
  end

  def apply_phase_to_ghosts(mode)
    @ghosts.each { |g| @ghost_fsm.apply_phase(g, mode) unless g.imprisoned? }
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

  # G4a: dot is eaten only when the player's center enters its cell, not when
  # the player rect bleeds 1px into the cell. Matches OG Pac feel and removes
  # the duplicate-eat edge case where rect overlap touched two cells at once.
  def player_eat_pellets
    cs = @projection.cell_size
    cx = @player.x + @player.w / 2.0
    cy = @player.y + @player.h / 2.0
    gx = (cx / cs).floor
    gy = (cy / cs).floor
    entry = @pellets.eat(gx, gy)
    return unless entry

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

    on_track_cleared(gx, gy, entry[:track_cleared]) if entry[:track_cleared]
  end

  # G1: a colour's last dot was just eaten. Flat bonus + popup at the dot's
  # cell + HUD meter flash + audio stinger. No world freeze (unlike eat-freeze).
  def on_track_cleared(gx, gy, color)
    @score += TRACK_COMPLETE_BONUS
    rect = @projection.cell_rect(gx, gy)
    @track_popups << {
      x: rect[:x] + rect[:w] / 2, y: rect[:y] + rect[:h] / 2,
      text: TRACK_COMPLETE_BONUS.to_s, alpha: 255, ticks: TRACK_POPUP_TICKS
    }
    @meter_flash[color] = METER_FLASH_TICKS
    args.state.audio.on_track_complete(args)
    pacify_owner_of(color)
  end

  # G6 Pacify: clearing a Territory teleports its owner ghost into that
  # ghost's prison cell and locks it there (:imprisoned). Marks released so
  # the schedule never re-spawns it, drops the controller. Persists across
  # player death — clearance is monotonic.
  def pacify_owner_of(color)
    id = Territory.owner_of(color)
    return unless id

    ghost = @ghosts.find { |g| g.identity == id }
    return unless ghost && !ghost.imprisoned?

    cell = @prison_cells[id]
    if cell
      rect = @projection.cell_rect(*cell)
      ghost.x = rect[:x]
      ghost.y = rect[:y]
    end
    ghost.state = :imprisoned
    ghost.controller = nil
    @release_schedule.mark_released(id)
  end

  # Advance Game-owned G1 timers: track popups (float + fade) and meter flash.
  # Ticked every playing frame regardless of eat-freeze, like EatSequencer.
  def tick_track_fx
    @track_popups.each do |p|
      p[:ticks] -= 1
      p[:y] += TRACK_POPUP_FLOAT
      p[:alpha] = ((p[:ticks].to_f / TRACK_POPUP_TICKS).clamp(0.0, 1.0) * 255).to_i
    end
    @track_popups.reject! { |p| p[:ticks] <= 0 }
    @meter_flash.each_key { |c| @meter_flash[c] -= 1 }
    @meter_flash.reject! { |_c, t| t <= 0 }
  end

  def tick_fire_input(world)
    return unless @player.controller.respond_to?(:fire_pressed?)
    return unless @player.controller.fire_pressed?(world)
    return if @player.direction.none?
    return unless @player.consume_ammo!

    Audio::SFXPlayer.play(args, :shoot)
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
        next if g.imprisoned? || g.state == :in_house || g.state == :eaten
        next unless rects_overlap?(p.collision_rect, g.rect)

        apply_bullet_to(g)
        p.kill! # ADR-0011: bullets are always consumed on contact
        break
      end
    end
  end

  # ADR-0011: bullet resistance gated by Enrage step. :off needs 1 hit (kill),
  # :enrage1 needs 2 (1st partial → flash + metallic clank, 2nd kills),
  # :enrage2 is immune (every hit flashes + plays the heavier metallic SFX,
  # never kills). Bullet always consumed by the caller.
  def apply_bullet_to(g)
    if g.enrage_step == :enrage2
      g.armor_flash!
      args.state.audio.on_bullet_immune(args)
      return
    end

    g.absorb_bullet!
    if g.absorbed_hits >= Enrage.hits_required(g.enrage_step)
      g.reset_absorbed!
      eat_ghost(g)
    else
      args.state.audio.on_bullet_absorbed(args)
    end
  end

  def tick_ghosts(world)
    debug = args&.state&.debug_ghost
    apply_dynamic_speeds
    @ghosts.each do |g|
      next if g.imprisoned? || g.state == :in_house

      @ghost_fsm.tick_transitions(g, debug: debug)
      next unless g.controller

      intent = g.controller.next_direction(world, g)
      g.update(intent: intent, maze: @maze, projection: @projection)
    end
  end

  # G6: per-Territory Enrage applied to every ghost. Replaces global
  # Cruise Elroy. Each ghost's enrage_step is derived from how many dots
  # remain in *its* Territory (the quadrant it owns by scatter corner).
  def apply_dynamic_speeds
    @ghosts.each do |g|
      next if g.imprisoned? || g.state == :in_house || g.state == :leaving_house

      g.enrage_step = enrage_for(g)

      next if g.state == :eaten # eaten ghosts ignore tunnel slowdown

      g.speed = effective_ghost_speed(g)
    end
  end

  def enrage_for(g)
    color = Territory.color_of(g.identity)
    remaining = @pellets.remaining_by_color[color]
    Enrage.step(
      remaining,
      enrage1_dots: @level_config[:enrage1_dots],
      enrage2_dots: @level_config[:enrage2_dots]
    )
  end

  def effective_ghost_speed(g)
    gx, gy = g.grid_cell(@projection)
    return PLAYER_SPEED * @level_config[:ghost_tunnel_ratio] if @maze.tunnel?(gx, gy)

    case g.enrage_step
    when :enrage2 then return PLAYER_SPEED * @level_config[:enrage2_ratio]
    when :enrage1 then return PLAYER_SPEED * @level_config[:enrage1_ratio]
    end
    g.base_speed
  end

  def tick_collisions
    @ghosts.each do |g|
      next if g.imprisoned? || g.state == :in_house || g.state == :eaten
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
