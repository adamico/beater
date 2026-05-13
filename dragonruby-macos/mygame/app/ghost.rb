# app/ghost.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/tiles.rb'
require 'app/ghost_controllers.rb'

GHOST_DEBUG_LOGS = true

class Ghost
  include GridMover

  IDENTITIES = [:blinky, :pinky, :inky, :clyde].freeze

  SPRITES = {
    blinky: "sprites/square/red.png",
    pinky: "sprites/square/violet.png",
    inky:  "sprites/square/blue.png",
    clyde: "sprites/square/orange.png",
    eaten: "sprites/hexagon/white.png"
  }.freeze

  attr_accessor :controller, :elroy_state, :eaten_flash_ticks
  attr_reader :state, :identity, :scatter_target, :spawn_cell

  def state=(new_state)
    if @state != new_state
      caller_line = caller(1, 1).first.to_s.split('/').last
      puts "[GHOST STATE] tick=#{Kernel.tick_count} id=#{@identity} #{@state.inspect} -> #{new_state.inspect} " \
           "dir=#{@direction&.name} role=#{@role.inspect} from=#{caller_line}" if GHOST_DEBUG_LOGS
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
    @elroy_state = :off
    @stuck_ticks = 0
    @stuck_logged = false
    @eaten_flash_ticks = 0
  end

  # TG2 eaten-hit animation: identity sprite scales up to peak, then down to a
  # tiny size; on completion sprite swaps to :eaten and ghost resumes movement
  # (boosted) back to the house. Movement is frozen for the duration.
  EATEN_FLASH_TICKS      = 24  # total animation length (~0.4s @ 60fps)
  EATEN_GROW_TICKS       = 8   # ticks spent scaling up to peak
  EATEN_FLASH_PEAK_SCALE = 1.6 # scale at peak (end of grow phase)
  EATEN_FLASH_END_SCALE  = 0.1 # scale at end of shrink phase
  EATEN_SPEED_MULTIPLIER = 2.2 # post-anim speed boost on return-to-house

  STUCK_LOG_THRESHOLD = 120 # 2s @ 60fps

  def base_speed
    @base_speed
  end

  # Sprite is rendered at sprite_scale times the logical 1-cell rect (default
  # 2x = arcade 2x2 quad), centered via sprite_offset_x/y. Tweak via init args.
  def flashing?
    @eaten_flash_ticks && @eaten_flash_ticks > 0
  end

  def to_sprite
    if flashing?
      age = EATEN_FLASH_TICKS - @eaten_flash_ticks # 0..EATEN_FLASH_TICKS-1
      @eaten_flash_ticks -= 1                      # render-time tick (advances during sim hitstop)
      if age < EATEN_GROW_TICKS
        # Phase A: identity sprite, ease scale 1.0 -> PEAK (ease-out).
        t = age.to_f / EATEN_GROW_TICKS
        eased = 1.0 - (1.0 - t) * (1.0 - t)
        scale = @sprite_scale * (1.0 + (EATEN_FLASH_PEAK_SCALE - 1.0) * eased)
      else
        # Phase B: identity sprite, ease scale PEAK -> END_SCALE (ease-in).
        shrink_age = age - EATEN_GROW_TICKS
        shrink_total = EATEN_FLASH_TICKS - EATEN_GROW_TICKS
        t = (shrink_age.to_f / shrink_total).clamp(0.0, 1.0)
        eased = t * t
        scale = @sprite_scale * (EATEN_FLASH_PEAK_SCALE +
                                 (EATEN_FLASH_END_SCALE - EATEN_FLASH_PEAK_SCALE) * eased)
      end
      path = SPRITES[@identity]
    else
      path = @state == :eaten ? SPRITES[:eaten] : SPRITES[@identity]
      scale = @sprite_scale
    end
    off_x = (@w * scale - @w) / 2.0
    off_y = (@h * scale - @h) / 2.0
    {
      x: @x - off_x, y: @y - off_y,
      w: @w * scale, h: @h * scale,
      path: path
    }
  end

  def update(intent:, maze:, projection:)
    return if flashing? # frozen during eaten-hit animation; resumes when anim ends
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
         "speed=#{@speed} role=#{@role.inspect} walk=#{walk.inspect}" if GHOST_DEBUG_LOGS
  end
end
