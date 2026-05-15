require 'app/direction.rb'

def test_direction_vectors args, assert
  assert.equal! Direction::UP.dx, 0
  assert.equal! Direction::UP.dy, 1
  assert.equal! Direction::DOWN.dx, 0
  assert.equal! Direction::DOWN.dy, -1
  assert.equal! Direction::LEFT.dx, -1
  assert.equal! Direction::LEFT.dy, 0
  assert.equal! Direction::RIGHT.dx, 1
  assert.equal! Direction::RIGHT.dy, 0
  assert.equal! Direction::NONE.dx, 0
  assert.equal! Direction::NONE.dy, 0
end

def test_direction_opposite args, assert
  assert.equal! Direction::UP.opposite,    Direction::DOWN
  assert.equal! Direction::DOWN.opposite,  Direction::UP
  assert.equal! Direction::LEFT.opposite,  Direction::RIGHT
  assert.equal! Direction::RIGHT.opposite, Direction::LEFT
  assert.equal! Direction::NONE.opposite,  Direction::NONE
end

def test_direction_none_predicate args, assert
  assert.true!  Direction::NONE.none?
  assert.false! Direction::UP.none?
end

def test_direction_axis_predicates args, assert
  assert.true!  Direction::LEFT.horizontal?
  assert.true!  Direction::RIGHT.horizontal?
  assert.false! Direction::UP.horizontal?
  assert.false! Direction::DOWN.horizontal?

  assert.true!  Direction::UP.vertical?
  assert.true!  Direction::DOWN.vertical?
  assert.false! Direction::LEFT.vertical?
  assert.false! Direction::RIGHT.vertical?

  assert.false! Direction::NONE.horizontal?
  assert.false! Direction::NONE.vertical?
end

def test_direction_all_collections args, assert
  assert.equal! Direction::ALL_MOVING.length, 4
  assert.equal! Direction::ALL.length, 5
  assert.true! Direction::ALL.include?(Direction::NONE)
  assert.false! Direction::ALL_MOVING.include?(Direction::NONE)
end
