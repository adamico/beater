# app/ghost.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/tiles.rb'
require 'app/ghost_controllers.rb'

class Ghost
  include GridMover

  IDENTITIES = [:blinky, :pinky, :inky, :clyde].freeze

  SPRITES = {
    blinky: "sprites/square/red.png",
    pinky: "sprites/square/violet.png",
    inky:  "sprites/square/blue.png",
    clyde: "sprites/square/orange.png",
    frightened: "sprites/square/black.png",
    frightened_flash: "sprites/square/white.png",
    eaten: "sprites/hexagon/white.png"
  }.freeze

  FRIGHTENED_FLASH_WINDOW = 150 # last 2.5s @ 60fps (5 on-flashes window)
  FRIGHTENED_FLASH_PERIOD = 15  # alternate every 0.25s

  attr_accessor :controller, :frightened_remaining_ticks, :elroy_state
  attr_reader :state, :identity, :scatter_target, :spawn_cell

  def state=(new_state)
    if @state != new_state
      caller_line = caller(1, 1).first.to_s.split('/').last
      puts "[GHOST STATE] tick=#{Kernel.tick_count} id=#{@identity} #{@state.inspect} -> #{new_state.inspect} " \
           "dir=#{@direction&.name} role=#{@role.inspect} from=#{caller_line}"
    end
    @state = new_state
  end

  def initialize(identity:, x:, y:, w:, h:, speed:, scatter_target:, spawn_cell:, controller:, direction: Direction::LEFT, sprite_scale: 2.0, sprite_offset_x: nil, sprite_offset_y: nil)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @identity = identity
    @scatter_target = scatter_target
    @spawn_cell = spawn_cell
    @controller = controller
    @state = :scatter
    @base_speed = speed
    @sprite_scale = sprite_scale
    # Default: center the scaled sprite over the 1-cell logical rect.
    @sprite_offset_x = sprite_offset_x || (w * @sprite_scale - w) / 2.0
    @sprite_offset_y = sprite_offset_y || (h * @sprite_scale - h) / 2.0
    @frightened_remaining_ticks = 0
    @elroy_state = :off
    @stuck_ticks = 0
    @stuck_logged = false
  end

  STUCK_LOG_THRESHOLD = 120 # 2s @ 60fps

  def base_speed
    @base_speed
  end

  # Sprite is rendered at sprite_scale times the logical 1-cell rect (default
  # 2x = arcade 2x2 quad), centered via sprite_offset_x/y. Tweak via init args.
  def to_sprite
    path = case @state
           when :frightened then frightened_sprite
           when :eaten      then SPRITES[:eaten]
           else SPRITES[@identity]
           end
    {
      x: @x - @sprite_offset_x, y: @y - @sprite_offset_y,
      w: @w * @sprite_scale, h: @h * @sprite_scale,
      path: path
    }
  end

  def frightened_sprite
    return SPRITES[:frightened] if @frightened_remaining_ticks > FRIGHTENED_FLASH_WINDOW
    # Inside warning window: alternate every FRIGHTENED_FLASH_PERIOD ticks.
    flash_on = (@frightened_remaining_ticks.to_i / FRIGHTENED_FLASH_PERIOD) % 2 > 1
    flash_on ? SPRITES[:frightened_flash] : SPRITES[:frightened]
  end

  def update(intent:, maze:, projection:)
    speed_tol = speed.to_f + GhostControllers::DECISION_EPSILON

    old_x = @x
    old_y = @y

    # Controller is responsible for emitting NONE when no new decision is
    # warranted (e.g. Targeting's one-decision-per-cell latch). Here we just
    # honor whatever intent the controller produced.
    try_turn(intent, maze, projection) unless intent.none?

    advance(maze, projection)

    moved = (@x - old_x).abs > GhostControllers::DECISION_EPSILON ||
            (@y - old_y).abs > GhostControllers::DECISION_EPSILON

    # If movement was rolled back by collision and we're near a cell center,
    # snap to the center so transition/turn logic can progress on next tick.
    if !moved && at_cell_center?(projection, tolerance: speed_tol)
      snap_to_cell_center!(projection)
    end

    # Ghost couldn't move this tick — release the Targeting one-decision-per-
    # cell latch so the controller can re-decide next tick. Corner-loop
    # oscillation (which the latch exists to prevent) requires the ghost to
    # actually move between cells each tick, so this clear path doesn't
    # re-open that case.
    GhostControllers::Targeting.clear_latch(@identity) unless moved

    detect_stuck(moved, maze, projection, speed_tol)
  end

  def detect_stuck(moved, maze, projection, speed_tol)
    if moved
      @stuck_ticks = 0
      @stuck_logged = false
      return
    end
    @stuck_ticks += 1
    # :in_house ghosts are intentionally stationary (cosmetic oscillation not
    # yet implemented) and will log noise here; accept until that lands.
    return if @stuck_logged || @stuck_ticks < STUCK_LOG_THRESHOLD

    @stuck_logged = true
    gx, gy = grid_cell(projection)
    cs = projection.cell_size.to_f
    x_cells = (@x - projection.offset_x).to_f / cs
    y_cells = (@y - projection.offset_y).to_f / cs
    err = [(x_cells - x_cells.round).abs * cs, (y_cells - y_cells.round).abs * cs]
    decision = at_cell_center?(projection, tolerance: speed_tol)
    walk = Direction::ALL_MOVING.map { |d|
      [d.name, maze.walkable?(gx + d.dx, gy + d.dy, role: @role)]
    }.to_h
    puts "[GHOST STUCK] tick=#{Kernel.tick_count} id=#{@identity} state=#{@state} " \
         "stuck_ticks=#{@stuck_ticks} pos=(#{@x.round(2)},#{@y.round(2)}) " \
         "cell=(#{gx},#{gy}) center_err=(#{err[0].round(3)},#{err[1].round(3)}) " \
         "tol=#{speed_tol.round(3)} at_decision=#{decision} dir=#{@direction.name} " \
         "speed=#{@speed} role=#{@role.inspect} walk=#{walk.inspect}"
  end
end
