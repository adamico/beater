require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/maze.rb'
require 'app/grid_projection.rb'

# 5x5 layout: outer ring of walls, 3x3 walkable interior.
#   wwwww
#   w...w
#   w...w
#   w...w
#   wwwww
TEST_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(w...w),
  %w(w...w),
  %w(wwwww)
]

class TestActor
  include GridMover

  def initialize(x:, y:, w:, h:, speed:, direction: Direction::NONE)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
  end
end

def fresh_world
  maze = Maze.from_layout(TEST_LAYOUT_5X5)
  projection = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  [maze, projection]
end

def actor_at_center(direction: Direction::NONE, speed: 2)
  TestActor.new(x: 40, y: 40, w: 20, h: 20, speed: speed, direction: direction)
end

def test_try_turn_none_is_no_op args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::UP)
  result = actor.try_turn(Direction::NONE, maze, projection)
  assert.false! result
  assert.equal! actor.direction, Direction::UP
end

def test_try_turn_same_direction_succeeds args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::UP)
  result = actor.try_turn(Direction::UP, maze, projection)
  assert.true! result
  assert.equal! actor.direction, Direction::UP
end

def test_try_turn_opposite_always_allowed args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::UP)
  result = actor.try_turn(Direction::DOWN, maze, projection)
  assert.true! result
  assert.equal! actor.direction, Direction::DOWN
  assert.equal! actor.dy, -1
end

def test_try_turn_perpendicular_aligned_walkable_succeeds args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::UP)
  # Center (gx=2, gy=2) is walkable; cell to the left (gx=1, gy=2) also walkable.
  result = actor.try_turn(Direction::LEFT, maze, projection)
  assert.true! result
  assert.equal! actor.direction, Direction::LEFT
  assert.equal! actor.dx, -1
end

def test_try_turn_perpendicular_misaligned_fails args, assert
  maze, projection = fresh_world
  # Misaligned on x by 1 pixel: probe spans 4 cells, alignment check fails.
  actor = TestActor.new(x: 41, y: 40, w: 20, h: 20, speed: 2, direction: Direction::UP)
  result = actor.try_turn(Direction::LEFT, maze, projection)
  assert.false! result
  assert.equal! actor.direction, Direction::UP
end

def test_try_turn_perpendicular_into_wall_fails args, assert
  maze, projection = fresh_world
  # Aligned at left edge of walkable region (gx=1). Turning LEFT probes into
  # cell gx=0, which is a wall.
  actor = TestActor.new(x: 20, y: 40, w: 20, h: 20, speed: 2, direction: Direction::UP)
  result = actor.try_turn(Direction::LEFT, maze, projection)
  assert.false! result
  assert.equal! actor.direction, Direction::UP
end

def test_try_turn_perpendicular_snaps_near_center_with_fractional_speed args, assert
  maze, projection = fresh_world
  # Horizontal travel with fractional speed can miss exact center by sub-pixel drift.
  # When close enough to the centerline, turning should snap and succeed.
  actor = TestActor.new(x: 58.8, y: 40, w: 20, h: 20, speed: (4.0 / 3.0), direction: Direction::RIGHT)
  result = actor.try_turn(Direction::UP, maze, projection)

  assert.true! result
  assert.equal! actor.direction, Direction::UP
  assert.equal! actor.x, 60
end

def test_advance_none_does_not_move args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::NONE)
  actor.advance(maze, projection)
  assert.equal! actor.x, 40
  assert.equal! actor.y, 40
end

def test_advance_in_open_corridor args, assert
  maze, projection = fresh_world
  actor = actor_at_center(direction: Direction::UP, speed: 2)
  actor.advance(maze, projection)
  assert.equal! actor.x, 40
  assert.equal! actor.y, 42
end

TUNNEL_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(_..._),
  %w(w...w),
  %w(wwwww)
]

def tunnel_world
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  projection = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  [maze, projection]
end

def test_advance_into_tunnel_does_not_rollback args, assert
  maze, projection = tunnel_world
  # Tunnel row is gy=2. Aligned at left edge (gx=0). Step LEFT by 2 leaves rect
  # at x=-2 (still mostly inside playfield); walkable? wraps so no rollback.
  actor = TestActor.new(x: 0, y: 40, w: 20, h: 20, speed: 2, direction: Direction::LEFT)
  actor.advance(maze, projection)
  assert.equal! actor.x, -2
end

def test_advance_wraps_after_fully_exiting args, assert
  maze, projection = tunnel_world
  # Actor is one step away from being fully off-screen on the left.
  # x=-18 + step LEFT by 2 -> x=-20, x+w=0 -> teleport to x = -20 + 100 = 80.
  actor = TestActor.new(x: -18, y: 40, w: 20, h: 20, speed: 2, direction: Direction::LEFT)
  actor.advance(maze, projection)
  assert.equal! actor.x, 80
end

def test_advance_wraps_after_exiting_right args, assert
  maze, projection = tunnel_world
  # playfield_w = 100. Actor at x=98 + step RIGHT by 2 -> x=100 -> teleport to 0.
  actor = TestActor.new(x: 98, y: 40, w: 20, h: 20, speed: 2, direction: Direction::RIGHT)
  actor.advance(maze, projection)
  assert.equal! actor.x, 0
end

def test_advance_into_wall_rolls_back args, assert
  maze, projection = fresh_world
  # Position the actor flush against the top walkable row (gy=3). Stepping UP
  # by speed=2 puts the rect into gy=4 which is wall; rollback expected.
  actor = TestActor.new(x: 40, y: 60, w: 20, h: 20, speed: 2, direction: Direction::UP)
  actor.advance(maze, projection)
  assert.equal! actor.y, 60
end

def test_at_cell_center_tolerance_and_snap_with_fractional_speed args, assert
  maze, projection = fresh_world
  actor = TestActor.new(x: 59.99995, y: 40.00002, w: 20, h: 20, speed: (2.0 / 3.0), direction: Direction::RIGHT)

  assert.true! actor.at_cell_center?(projection)
  actor.snap_to_cell_center!(projection)
  assert.equal! actor.x, 60
  assert.equal! actor.y, 40
end
