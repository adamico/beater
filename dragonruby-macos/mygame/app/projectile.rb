require 'app/direction.rb'
require 'app/tiles.rb'

# Power-pellet projectile. Travels in a straight line at fixed pixel speed,
# obeys maze passability (walls stop it, tunnels wrap it), and despawns on
# wall hit or ghost contact. Spawned at the player's logical center while
# the frightened window is active; see docs/adr/0006-power-pellet-projectiles.md.
class Projectile
  SIZE = 40
  SPRITE_PATH = "sprites/bullet.png"
  SPRITE_TILE_WIDTH = 32
  # = bullet.png width / SPRITE_TILE_WIDTH; bump when the sheet grows beyond one frame.
  FRAME_COUNT = 1
  TICKS_PER_FRAME = 4

  attr_reader :direction, :x, :y, :w, :h

  def initialize(cx:, cy:, direction:, speed:)
    @x = cx - SIZE / 2.0
    @y = cy - SIZE / 2.0
    @w = SIZE
    @h = SIZE
    @direction = direction
    @speed = speed.to_f
    @dead = false
    @anim_ticks = 0
  end

  def rect
    { x: @x, y: @y, w: @w, h: @h }
  end

  def dead?
    @dead
  end

  def kill!
    @dead = true
  end

  def tick(maze, projection)
    return if @dead
    @anim_ticks += 1
    @x += @direction.dx * @speed
    @y += @direction.dy * @speed
    wrap_x(projection)
    @dead = true if blocked_by_wall?(maze, projection)
  end

  def to_sprite
    frame = @anim_ticks.idiv(TICKS_PER_FRAME) % FRAME_COUNT
    base = {
      x: @x, y: @y, w: @w, h: @h,
      path: SPRITE_PATH,
      tile_x: frame * SPRITE_TILE_WIDTH, tile_y: 0,
      tile_w: SPRITE_TILE_WIDTH, tile_h: SPRITE_TILE_WIDTH
    }
    case @direction
    when Direction::LEFT then base.merge(flip_horizontally: true)
    when Direction::UP   then base.merge(angle: 90)
    when Direction::DOWN then base.merge(angle: 90, flip_horizontally: true)
    else base
    end
  end

  private

  def wrap_x(projection)
    pf = projection.playfield_w
    left = projection.offset_x
    right = left + pf
    @x += pf if @x + @w <= left
    @x -= pf if @x >= right
  end

  def blocked_by_wall?(maze, projection)
    cx = @x + @w / 2.0
    cy = @y + @h / 2.0
    gx = ((cx - projection.offset_x) / projection.cell_size).floor
    gy = ((cy - projection.offset_y) / projection.cell_size).floor
    !maze.walkable?(gx, gy, role: Tiles::ROLE_DEFAULT)
  end
end
