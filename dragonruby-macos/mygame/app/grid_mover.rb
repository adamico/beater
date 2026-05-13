# app/grid_mover.rb
require 'app/direction.rb'
require 'app/tiles.rb'

# Mixin providing grid-aligned movement on a Maze.
#
# State (held on the including instance):
#   x, y, w, h          — pixel-space rect
#   dx, dy              — current per-tick velocity (set from @direction)
#   direction           — Direction value
#   speed               — pixels per advance() step
#   role                — passability role (Tiles::ROLE_*); defaults to :default
#
# Including classes call init_grid_mover(...) from their own initialize, then
# drive movement with try_turn(direction, maze, projection) and
# advance(maze, projection) per tick.

module GridMover
  attr_accessor :x, :y, :w, :h, :dx, :dy, :speed, :direction, :role
  AXIS_SNAP_EPSILON = 0.0001

  def init_grid_mover(x:, y:, w:, h:, speed:, direction: Direction::NONE, role: Tiles::ROLE_DEFAULT)
    @x = x
    @y = y
    @w = w
    @h = h
    @speed = speed
    @direction = direction
    @dx = direction.dx
    @dy = direction.dy
    @role = role
  end

  def try_turn(direction, maze, projection)
    return false if direction.none?
    return true  if direction == @direction

    if turn_possible?(direction, maze, projection)
      # Snap the abandoned axis so non-integer speeds don't accumulate
      # perpendicular drift across successive turns. Without this, drift can
      # exceed at_cell_center? tolerance and strand the actor at walls.
      if perpendicular_to_current?(direction)
        snapped = snapped_position_for(direction, projection)
        if snapped
          @x = snapped[:x]
          @y = snapped[:y]
        end
      end
      face direction
      return true
    end

    return false unless perpendicular_to_current?(direction)

    snapped = snapped_position_for(direction, projection)
    return false unless snapped

    original_x = @x
    original_y = @y
    @x = snapped[:x]
    @y = snapped[:y]

    if turn_possible?(direction, maze, projection)
      face direction
      true
    else
      @x = original_x
      @y = original_y
      false
    end
  end

  def turn_possible?(direction, maze, projection)
    return false if direction.none?
    return true  if direction == @direction
    return true  if direction == @direction.opposite

    probe = { x: @x + direction.dx, y: @y + direction.dy, w: @w, h: @h }
    cells = projection.cells_touched(probe)
    return false unless cells.length == 2

    cells.all? { |(gx, gy)| maze.walkable?(gx, gy, role: @role) }
  end

  def advance(maze, projection)
    return if @direction.none?

    @x += @dx * @speed
    @x -= @dx * @speed if blocked_by_wall?(maze, projection)
    @y += @dy * @speed
    @y -= @dy * @speed if blocked_by_wall?(maze, projection)

    wrap_pixel_position(projection)
  end

  def wrap_pixel_position(projection)
    pf = projection.playfield_w
    left = projection.offset_x
    right = left + pf
    @x += pf if @x + @w <= left
    @x -= pf if @x >= right
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def face(direction)
    @direction = direction
    @dx = direction.dx
    @dy = direction.dy
  end

  def blocked_by_wall?(maze, projection)
    projection.cells_touched(rect).any? { |(gx, gy)| !maze.walkable?(gx, gy, role: @role) }
  end

  def perpendicular_to_current?(direction)
    return false if @direction.none?
    return false if direction == @direction || direction == @direction.opposite

    (direction.vertical? && @direction.horizontal?) ||
      (direction.horizontal? && @direction.vertical?)
  end

  def snapped_position_for(direction, projection)
    return nil unless perpendicular_to_current?(direction)

    snap_tolerance = @speed.to_f + AXIS_SNAP_EPSILON
    cs = projection.cell_size

    if direction.vertical?
      target_x = (((@x - projection.offset_x).to_f / cs).round * cs) + projection.offset_x
      return nil unless (@x - target_x).abs <= snap_tolerance

      { x: target_x, y: @y }
    else
      target_y = (((@y - projection.offset_y).to_f / cs).round * cs) + projection.offset_y
      return nil unless (@y - target_y).abs <= snap_tolerance

      { x: @x, y: target_y }
    end
  end

  # True when the rect is exactly aligned to a single grid cell.
  # Ghost controllers use this to take decisions only at intersections.
  def at_cell_center?(projection, tolerance: nil)
    tol = tolerance.nil? ? AXIS_SNAP_EPSILON : tolerance.to_f
    dx_err, dy_err = cell_center_error(projection)
    dx_err <= tol && dy_err <= tol
  end

  def snap_to_cell_center!(projection)
    cs = projection.cell_size
    @x = ((@x - projection.offset_x) / cs).round * cs + projection.offset_x
    @y = ((@y - projection.offset_y) / cs).round * cs + projection.offset_y
  end

  # Grid coords of the cell the rect's anchor is closest to.
  # Must match at_cell_center? (which uses .round) so decision-point logic and
  # transition checks agree about which cell the actor is "on".
  def grid_cell(projection)
    cs = projection.cell_size
    [((@x - projection.offset_x) / cs).round, ((@y - projection.offset_y) / cs).round]
  end

  def cell_center_error(projection)
    cs = projection.cell_size.to_f
    x_cells = (@x - projection.offset_x).to_f / cs
    y_cells = (@y - projection.offset_y).to_f / cs
    [
      (x_cells - x_cells.round).abs * cs,
      (y_cells - y_cells.round).abs * cs
    ]
  end
end
