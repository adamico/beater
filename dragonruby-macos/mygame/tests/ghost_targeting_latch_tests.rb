require 'app/ghost_controllers.rb'
require 'app/direction.rb'
require 'app/maze.rb'
require 'app/grid_projection.rb'
require 'app/ghost.rb'

# Minimal ghost double for Targeting (needs identity for the latch hash).
class LatchDummyGhost
  attr_accessor :direction, :role, :identity
  def initialize(x, y, dir, identity:, role: :default, centered: true)
    @x, @y, @direction, @role, @identity = x, y, dir, role, identity
    @centered = centered
  end
  def at_cell_center?(projection, tolerance: nil); @centered; end
  def grid_cell(projection); [@x, @y]; end
  def speed; 1.0; end
  def state; :scatter; end
  def elroy_state; :off; end
end

def make_latch_world(layout)
  maze = Maze.from_layout(layout)
  projection = GridProjection.new(cell_size: 1, offset_x: 0, offset_y: 0, grid_w: layout[0].size, grid_h: layout.size)
  Struct.new(:maze, :projection).new(maze, projection)
end

# Regression for ebe4b05: at a corner, greedy + reverse-exclusion can flip its
# choice frame-to-frame within the same cell, producing scatter corner-loop
# oscillation. Targeting must commit one decision per cell visit.
def test_targeting_latches_one_decision_per_cell args, assert
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  world = make_latch_world(layout)
  GhostControllers::Targeting.clear_latch(:test_latch)
  ghost = LatchDummyGhost.new(1, 1, Direction::UP, identity: :test_latch)
  target = [0, 1]

  first = GhostControllers::Targeting.next_direction(ghost, world, target)
  assert.not_equal! first, Direction::NONE

  # Same cell, same tick context — latch must suppress a second decision so the
  # ghost cannot flip direction within one cell visit.
  second = GhostControllers::Targeting.next_direction(ghost, world, target)
  assert.equal! second, Direction::NONE
end

# After clear_latch (controller swap-back point), Targeting must be allowed to
# decide again in the same cell — otherwise a ghost that exits frightened next
# to a corner could skip a turn.
def test_clear_latch_reenables_decision args, assert
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  world = make_latch_world(layout)
  GhostControllers::Targeting.clear_latch(:test_clear)
  ghost = LatchDummyGhost.new(1, 1, Direction::UP, identity: :test_clear)
  target = [0, 1]

  GhostControllers::Targeting.next_direction(ghost, world, target)
  GhostControllers::Targeting.clear_latch(ghost.identity)
  again = GhostControllers::Targeting.next_direction(ghost, world, target)
  assert.not_equal! again, Direction::NONE
end

# Latch is per-identity, so different ghosts decide independently in the same
# cell.
def test_latch_is_per_identity args, assert
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  world = make_latch_world(layout)
  GhostControllers::Targeting.clear_latch(:test_a)
  GhostControllers::Targeting.clear_latch(:test_b)
  ghost_a = LatchDummyGhost.new(1, 1, Direction::UP, identity: :test_a)
  ghost_b = LatchDummyGhost.new(1, 1, Direction::UP, identity: :test_b)
  target = [0, 1]

  GhostControllers::Targeting.next_direction(ghost_a, world, target)
  # Different identity — must still get a decision in the same cell.
  b_first = GhostControllers::Targeting.next_direction(ghost_b, world, target)
  assert.not_equal! b_first, Direction::NONE
end

# Regression for scatter/chase stuck-at-corner: if a Ghost can't advance for a
# tick (forward blocked, rolled back), Ghost#update must clear the Targeting
# latch so the controller can re-decide next tick. Without this, the latch
# pins NONE forever and the ghost freezes in place silently.
def test_update_clears_targeting_latch_on_no_move args, assert
  # Ghost at (1,1) facing UP, with UP blocked by wall. Advance will be rolled
  # back. Rest of the cross is open so the ghost would normally have choices.
  layout = [
    %w(www),
    %w(...),
    %w(www)
  ]
  maze = Maze.from_layout(layout)
  projection = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 3, grid_h: 3)

  # Simulate a prior Targeting decision committed in (1,1).
  GhostControllers::Targeting.instance_variable_get(:@last_decision_cell)[:test_stuck_recover] = [1, 1]

  ghost = Ghost.new(
    identity: :test_stuck_recover,
    x: 20, y: 20, w: 20, h: 20,
    speed: 1.0,
    scatter_target: [10, 1],
    spawn_cell: [1, 1],
    controller: nil,
    direction: Direction::UP
  )
  ghost.state = :scatter

  ghost.update(intent: Direction::NONE, maze: maze, projection: projection)

  latched = GhostControllers::Targeting.instance_variable_get(:@last_decision_cell)[:test_stuck_recover]
  assert.equal! latched, nil
end

