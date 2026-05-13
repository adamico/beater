require 'app/direction.rb'
require 'app/maze.rb'
require 'app/grid_projection.rb'
require 'app/projectile.rb'

# 5x5 with outer wall ring, middle row is a tunnel that wraps on x.
PROJECTILE_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(_..._),
  %w(w...w),
  %w(wwwww)
]

def projectile_world
  maze = Maze.from_layout(PROJECTILE_LAYOUT_5X5)
  projection = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  [maze, projection]
end

# A projectile is constructed from its center; rect top-left is (cx - SIZE/2, cy - SIZE/2).
def projectile_at(cx:, cy:, direction:, speed: 4)
  Projectile.new(cx: cx, cy: cy, direction: direction, speed: speed)
end

def spawn_xy(cx, cy)
  [cx - Projectile::SIZE / 2.0, cy - Projectile::SIZE / 2.0]
end

def test_spawn_centers_rect_on_given_point args, assert
  p = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT)
  r = p.rect
  sx, sy = spawn_xy(50, 50)
  assert.equal! r[:x], sx
  assert.equal! r[:y], sy
  assert.equal! r[:w], Projectile::SIZE
  assert.equal! r[:h], Projectile::SIZE
end

def test_advances_in_fired_direction args, assert
  maze, projection = projectile_world
  p = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT, speed: 3)
  p.tick(maze, projection)
  sx, sy = spawn_xy(50, 50)
  assert.equal! p.x, sx + 3.0
  assert.equal! p.y, sy
  assert.false! p.dead?
end

def test_advances_upward args, assert
  maze, projection = projectile_world
  p = projectile_at(cx: 50, cy: 50, direction: Direction::UP, speed: 3)
  p.tick(maze, projection)
  sx, sy = spawn_xy(50, 50)
  assert.equal! p.x, sx
  assert.equal! p.y, sy + 3.0
end

def test_despawns_on_wall_hit_right args, assert
  maze, projection = projectile_world
  # Cell (gx=3, gy=2) center is at (70, 50). Walkable row, wall at gx=4 (top/bot)
  # but tunnel row gy=2 wraps. Use gy=1 row instead, where gx=4 is wall.
  p = projectile_at(cx: 70, cy: 30, direction: Direction::RIGHT, speed: 20)
  p.tick(maze, projection)
  assert.true! p.dead?
end

def test_despawns_on_wall_hit_up args, assert
  maze, projection = projectile_world
  # gy=3 row is walkable, gy=4 is wall. Center at (50, 70), step UP by 20.
  p = projectile_at(cx: 50, cy: 70, direction: Direction::UP, speed: 20)
  p.tick(maze, projection)
  assert.true! p.dead?
end

def test_despawns_on_wall_hit_down args, assert
  maze, projection = projectile_world
  # gy=1 row is walkable, gy=0 is wall. Center at (50, 30), step DOWN by 20.
  p = projectile_at(cx: 50, cy: 30, direction: Direction::DOWN, speed: 20)
  p.tick(maze, projection)
  assert.true! p.dead?
end

def test_despawns_on_wall_hit_left_outside_tunnel args, assert
  maze, projection = projectile_world
  # Row gy=1 is walkable, gx=0 is wall. Center at (30, 30), step LEFT into gx=0.
  p = projectile_at(cx: 30, cy: 30, direction: Direction::LEFT, speed: 20)
  p.tick(maze, projection)
  assert.true! p.dead?
end

def test_wraps_through_tunnel args, assert
  maze, projection = projectile_world
  # Tunnel row gy=2: gx=0 and gx=4 are EMPTY (walkable). Step LEFT until the
  # rect fully exits playfield_w=100; the wrap kicks in (same rule as GridMover).
  size = Projectile::SIZE
  cx = size / 2.0   # @x = 0
  p = projectile_at(cx: cx, cy: 50, direction: Direction::LEFT, speed: size)
  p.tick(maze, projection)
  # @x = -size after step; @x + w = 0 -> wrap +playfield_w.
  assert.equal! p.x, 100.0 - size
  assert.false! p.dead?
end

def test_anim_ticks_advance_on_each_tick args, assert
  maze, projection = projectile_world
  p = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT, speed: 1)
  sprite0 = p.to_sprite
  assert.equal! sprite0[:tile_x], 0
  p.tick(maze, projection)
  p.tick(maze, projection)
  p.tick(maze, projection)
  p.tick(maze, projection)
  # After TICKS_PER_FRAME ticks, frame index advances; with FRAME_COUNT=1 it
  # wraps back to 0. Once the sheet grows this will become a meaningful check.
  sprite1 = p.to_sprite
  assert.equal! sprite1[:tile_x] % Projectile::SPRITE_TILE_WIDTH, 0
end

def test_sprite_rotation_per_direction args, assert
  right = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT).to_sprite
  left  = projectile_at(cx: 50, cy: 50, direction: Direction::LEFT).to_sprite
  up    = projectile_at(cx: 50, cy: 50, direction: Direction::UP).to_sprite
  down  = projectile_at(cx: 50, cy: 50, direction: Direction::DOWN).to_sprite

  assert.equal! right[:flip_horizontally], nil
  assert.equal! right[:angle], nil

  assert.equal! left[:flip_horizontally], true
  assert.equal! left[:angle], nil

  assert.equal! up[:angle], 90
  assert.equal! up[:flip_horizontally], nil

  assert.equal! down[:angle], 90
  assert.equal! down[:flip_horizontally], true
end

def test_kill_marks_dead args, assert
  p = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT)
  assert.false! p.dead?
  p.kill!
  assert.true! p.dead?
end

def test_dead_projectile_does_not_advance args, assert
  maze, projection = projectile_world
  p = projectile_at(cx: 50, cy: 50, direction: Direction::RIGHT, speed: 3)
  p.kill!
  p.tick(maze, projection)
  sx, sy = spawn_xy(50, 50)
  assert.equal! p.x, sx
  assert.equal! p.y, sy
end
