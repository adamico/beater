require 'app/player.rb'
require 'app/maze.rb'
require 'app/grid_projection.rb'

RHYTHM_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(w...w),
  %w(w...w),
  %w(wwwww)
]

RHYTHM_CORRIDOR_LAYOUT_5X5 = [
  %w(wwwww),
  %w(wwwww),
  %w(w...w),
  %w(wwwww),
  %w(wwwww)
]

class RhythmControllerStub
  def next_direction(_world)
    Direction::NONE
  end
end

def rhythm_world
  maze = Maze.from_layout(RHYTHM_LAYOUT_5X5)
  projection = GridProjection.new(cell_size: 20, grid_w: 5, grid_h: 5)
  [maze, projection]
end

def corridor_world
  maze = Maze.from_layout(RHYTHM_CORRIDOR_LAYOUT_5X5)
  projection = GridProjection.new(cell_size: 20, grid_w: 5, grid_h: 5)
  [maze, projection]
end

def rhythm_player(direction: Direction::RIGHT)
  Player.new(
    x: 40,
    y: 40,
    w: 20,
    h: 20,
    speed: 2,
    controller: RhythmControllerStub.new,
    direction: direction
  )
end

def test_player_commit_defers_turn_until_scheduled_step args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::NONE)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  # tick=1 is outside grace window, so turn is scheduled for step index 2 (tick ~15).
  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)
  assert.equal! player.move_state, :committing
  assert.equal! player.direction, Direction::NONE

  player.update_with_rhythm(tick_count: 14, intent: Direction::NONE, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::NONE

  player.update_with_rhythm(tick_count: 15, intent: Direction::NONE, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::UP
  assert.equal! player.move_state, :moving
end

def test_player_commit_can_be_overridden_by_valid_input args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::UP
  assert.equal! player.move_state, :moving

  player.update_with_rhythm(tick_count: 2, intent: Direction::DOWN, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::DOWN
  assert.equal! player.move_state, :moving
end

def test_player_reverse_direction_turns_immediately args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  player.update_with_rhythm(tick_count: 1, intent: Direction::LEFT, maze: maze, projection: projection)

  assert.equal! player.direction, Direction::LEFT
  assert.equal! player.move_state, :moving
end

def test_player_orthogonal_turn_applies_immediately_when_legal args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)

  assert.equal! player.direction, Direction::UP
  assert.equal! player.move_state, :moving
end

def test_player_held_orthogonal_intent_retries_until_legal args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  # Misalign x so upward turn is illegal initially; moving right reaches alignment.
  player.x = 36

  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)
  assert.equal! player.move_state, :moving
  assert.equal! player.direction, Direction::RIGHT

  player.update_with_rhythm(tick_count: 2, intent: Direction::UP, maze: maze, projection: projection)
  assert.true! [Direction::RIGHT, Direction::UP].include?(player.direction)

  player.update_with_rhythm(tick_count: 3, intent: Direction::UP, maze: maze, projection: projection)
  player.update_with_rhythm(tick_count: 4, intent: Direction::UP, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::UP
  assert.equal! player.move_state, :moving
end

def test_player_holding_orthogonal_in_corridor_keeps_forward_movement args, assert
  maze, projection = corridor_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: true, bpm: 120, grace_ticks: 3)

  x0 = player.x
  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)
  x1 = player.x
  player.update_with_rhythm(tick_count: 2, intent: Direction::UP, maze: maze, projection: projection)
  x2 = player.x

  assert.equal! player.direction, Direction::RIGHT
  assert.true! x1 > x0
  assert.true! x2 > x1
end

def test_player_immediate_mode_still_turns_without_rhythm args, assert
  maze, projection = rhythm_world
  player = rhythm_player(direction: Direction::RIGHT)
  player.configure_rhythm(enabled: false, bpm: 120, grace_ticks: 3)

  player.update_with_rhythm(tick_count: 1, intent: Direction::UP, maze: maze, projection: projection)
  assert.equal! player.direction, Direction::UP
end
