# app/grid_mover.rb
require 'app/direction.rb'

# Mixin providing grid-aligned movement on a Maze.
#
# State (held on the including instance):
#   x, y, w, h          — pixel-space rect
#   dx, dy              — current per-tick velocity (set from @direction)
#   direction           — Direction value
#   speed               — pixels per advance() step
#
# Including classes call init_grid_mover(...) from their own initialize, then
# drive movement with try_turn(direction, maze, projection) and
# advance(maze, projection) per tick.

module GridMover
  attr_accessor :x, :y, :w, :h, :dx, :dy, :speed, :direction

  def init_grid_mover(x:, y:, w:, h:, speed:, direction: Direction::NONE)
    @x = x
    @y = y
    @w = w
    @h = h
    @speed = speed
    @direction = direction
    @dx = direction.dx
    @dy = direction.dy
  end

  # Attempt to face `direction`. Returns true if applied.
  #
  # Rules:
  #   - NONE              → no-op, returns false (no intent this tick).
  #   - same as current   → no-op success.
  #   - opposite of current → always allowed (instant reverse).
  #   - perpendicular     → allowed only if (a) the rect is grid-aligned on
  #     the perpendicular axis (probe touches exactly two cells) and (b) both
  #     touched cells are walkable.
  def try_turn(direction, maze, projection)
    return false if direction.none?
    return true  if direction == @direction

    if direction != @direction.opposite
      probe = { x: @x + direction.dx, y: @y + direction.dy, w: @w, h: @h }
      cells = projection.cells_touched(probe)
      return false unless cells.length == 2
      return false unless cells.all? { |(gx, gy)| maze.walkable?(gx, gy) }
    end

    face direction
    true
  end

  # Step in current direction by `speed`. If the new position overlaps a wall,
  # rollback that axis. Axes evaluated independently so corner-clipping isn't
  # double-blocked.
  def advance(maze, projection)
    return if @direction.none?

    @x += @dx * @speed
    @x -= @dx * @speed if blocked_by_wall?(maze, projection)
    @y += @dy * @speed
    @y -= @dy * @speed if blocked_by_wall?(maze, projection)

    wrap_pixel_position(projection)
  end

  # Tunnel teleport: once the rect has fully exited the playfield horizontally,
  # snap to the opposite edge. Maze#walkable? wraps grid coords already, so the
  # actor walks across the seam without rollback; this only repositions pixels.
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
    projection.cells_touched(rect).any? { |(gx, gy)| !maze.walkable?(gx, gy) }
  end
end
