require 'app/direction.rb'
require 'app/tiles.rb'
require 'app/ghost_controllers.rb'

class GhostStateMachine
  def initialize(projection:, above_door_cell:, current_mode_fn:)
    @projection = projection
    @above_door_cell = above_door_cell
    @current_mode_fn = current_mode_fn
    @transition_log_last = {}
  end

  def start_leaving(ghost)
    ghost.state = :leaving_house
    ghost.role = Tiles::ROLE_GHOST_LEAVING
    ghost.controller = GhostControllers::LeavingHouse.new(@above_door_cell)
    ghost.face(Direction::UP)
  end

  def enter_frightened(ghost, frightened_speed, remaining_ticks)
    return unless ghost.state == :scatter || ghost.state == :chase
    ghost.state = :frightened
    ghost.controller = GhostControllers::Frightened.new
    ghost.speed = frightened_speed
    ghost.frightened_remaining_ticks = remaining_ticks
    ghost.face(ghost.direction.opposite) unless ghost.direction.none?
  end

  def restore_from_frightened(ghost)
    return unless ghost.state == :frightened
    ghost.state = @current_mode_fn.call
    ghost.controller = GhostControllers.for(ghost.identity)
    ghost.speed = ghost.base_speed
    snap_to_cell(ghost)
    GhostControllers::Targeting.clear_latch(ghost.identity)
  end

  def enter_eaten(ghost)
    ghost.state = :eaten
    ghost.role = Tiles::ROLE_GHOST_EATEN
    ghost.controller = GhostControllers::Eaten.new
    ghost.speed = ghost.base_speed
    snap_to_cell(ghost)
  end

  def apply_phase(ghost, mode)
    return unless ghost.state == :scatter || ghost.state == :chase
    ghost.state = mode
    ghost.face(ghost.direction.opposite) unless ghost.direction.none?
  end

  def tick_transitions(ghost, debug: false)
    case ghost.state
    when :eaten
      log_transition_attempt(ghost, ghost.spawn_cell, :eaten_to_leaving) if debug
      transition_at_cell_center(ghost, ghost.spawn_cell) { start_leaving(ghost) }
    when :leaving_house
      log_transition_attempt(ghost, @above_door_cell, :leaving_to_chase) if debug
      transition_at_cell_center(ghost, @above_door_cell) do
        ghost.state = @current_mode_fn.call
        ghost.role = Tiles::ROLE_DEFAULT
        ghost.controller = GhostControllers.for(ghost.identity)
        ghost.speed = ghost.base_speed
        GhostControllers::Targeting.clear_latch(ghost.identity)
      end
    end
  end

  # Frightened ghosts run at odd speed (1) so pixel position can fall off the
  # integer-cell-aligned grid. When transitioning to a state whose speed is
  # even, that drift would prevent at_cell_center? from ever firing again,
  # freezing turning decisions. Snap on entry to fix.
  def snap_to_cell(ghost)
    cs = @projection.cell_size
    ghost.x = ((ghost.x - @projection.offset_x) / cs).round * cs + @projection.offset_x
    ghost.y = ((ghost.y - @projection.offset_y) / cs).round * cs + @projection.offset_y
  end

  private

  def transition_at_cell_center(ghost, target_cell)
    return unless ghost.grid_cell(@projection) == target_cell
    tol = ghost.speed.to_f + GhostControllers::DECISION_EPSILON
    return unless ghost.at_cell_center?(@projection, tolerance: tol)
    ghost.snap_to_cell_center!(@projection)
    yield
  end

  def log_transition_attempt(ghost, target_cell, label)
    cur = ghost.grid_cell(@projection)
    tol = ghost.speed.to_f + GhostControllers::DECISION_EPSILON
    centered = ghost.at_cell_center?(@projection, tolerance: tol)
    cs = @projection.cell_size.to_f
    x_cells = (ghost.x - @projection.offset_x).to_f / cs
    y_cells = (ghost.y - @projection.offset_y).to_f / cs
    round_cell = [x_cells.round, y_cells.round]
    err = [(x_cells - x_cells.round).abs * cs, (y_cells - y_cells.round).abs * cs]
    return if cur == target_cell && centered

    puts "[GHOST TRANSIT] tick=#{Kernel.tick_count} id=#{ghost.identity} #{label} " \
         "pos=(#{ghost.x.round(2)},#{ghost.y.round(2)}) " \
         "cell_floor=#{cur.inspect} cell_round=#{round_cell.inspect} target=#{target_cell.inspect} " \
         "centered=#{centered} err=(#{err[0].round(2)},#{err[1].round(2)}) tol=#{tol.round(2)} " \
         "dir=#{ghost.direction.name} role=#{ghost.role.inspect}"
  end
end
