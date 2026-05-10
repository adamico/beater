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

    if direction != @direction.opposite
      probe = { x: @x + direction.dx, y: @y + direction.dy, w: @w, h: @h }
      cells = projection.cells_touched(probe)
      return false unless cells.length == 2
      return false unless cells.all? { |(gx, gy)| maze.walkable?(gx, gy, role: @role) }
    end

    face direction
    true
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

  # True when the rect is exactly aligned to a single grid cell.
  # Ghost controllers use this to take decisions only at intersections.
  def at_cell_center?(projection)
    cs = projection.cell_size
    ((@x - projection.offset_x) % cs == 0) && ((@y - projection.offset_y) % cs == 0)
  end

  # Grid coords of the cell the rect is anchored to.
  def grid_cell(projection)
    cs = projection.cell_size
    [((@x - projection.offset_x) / cs).floor, ((@y - projection.offset_y) / cs).floor]
  end
end
