require 'app/ghost_controllers.rb'
require 'app/direction.rb'
require 'app/maze.rb'
require 'app/grid_projection.rb'

# Minimal ghost double
class DummyGhost
  attr_accessor :direction, :role
  def initialize(x, y, dir, role = :default, centered: true)
    @x, @y, @direction, @role = x, y, dir, role
    @centered = centered
  end
  def at_cell_center?(projection, tolerance: nil); @centered; end
  def grid_cell(projection); [@x, @y]; end
end

def make_world(layout)
  maze = Maze.from_layout(layout)
  projection = GridProjection.new(cell_size: 1, offset_x: 0, offset_y: 0, grid_w: layout[0].size, grid_h: layout.size)
  Struct.new(:maze, :projection).new(maze, projection)
end

def test_frightened_one_exit args, assert
  # Only LEFT open from center.
  layout = [
    %w(www),
    %w(..w),
    %w(www)
  ]
  world = make_world(layout)
  ghost = DummyGhost.new(1, 1, Direction::UP)
  ctrl = GhostControllers::Frightened.new
  dir = ctrl.next_direction(world, ghost)
  assert.equal! dir, Direction::LEFT
end

def test_frightened_two_exits args, assert
  # LEFT and RIGHT open, reverse (DOWN) excluded while alternatives exist.
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  world = make_world(layout)
  ghost = DummyGhost.new(1, 1, Direction::UP)
  ctrl = GhostControllers::Frightened.new
  10.times do
    dir = ctrl.next_direction(world, ghost)
    assert.true!([Direction::LEFT, Direction::RIGHT].include?(dir))
    assert.not_equal! dir, Direction::DOWN
  end
end

def test_frightened_vertical_corridor_has_legal_move args, assert
  # In a vertical corridor, frightened ghost should keep moving (never NONE).
  layout = [
    %w(w.w),
    %w(w.w),
    %w(w.w)
  ]
  world = make_world(layout)
  ghost = DummyGhost.new(1, 1, Direction::RIGHT)
  ctrl = GhostControllers::Frightened.new
  dir = ctrl.next_direction(world, ghost)
  assert.true!([Direction::UP, Direction::DOWN].include?(dir))
end

def test_frightened_fully_blocked args, assert
  # Surrounded by walls
  layout = [
    %w(www),
    %w(w.w),
    %w(www)
  ]
  world = make_world(layout)
  ghost = DummyGhost.new(1, 1, Direction::UP)
  ctrl = GhostControllers::Frightened.new
  dir = ctrl.next_direction(world, ghost)
  assert.equal! dir, Direction::NONE
end

def test_frightened_not_at_center_returns_none args, assert
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  world = make_world(layout)
  ghost = DummyGhost.new(1, 1, Direction::UP, :default, centered: false)
  ctrl = GhostControllers::Frightened.new
  dir = ctrl.next_direction(world, ghost)
  assert.equal! dir, Direction::NONE
end
