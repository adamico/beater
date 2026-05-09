require 'app/direction.rb'
require 'app/keyboard_controller.rb'

class FakeInputs
  attr_accessor :up_down, :left_right
  def initialize(up_down: 0, left_right: 0)
    @up_down = up_down
    @left_right = left_right
  end
end

class FakeWorld
  attr_reader :inputs
  def initialize(inputs)
    @inputs = inputs
  end
end

def world_with(up_down: 0, left_right: 0)
  FakeWorld.new(FakeInputs.new(up_down: up_down, left_right: left_right))
end

def test_keyboard_controller_emits_up args, assert
  ctrl = KeyboardController.new
  assert.equal! ctrl.next_direction(world_with(up_down: 1)), Direction::UP
end

def test_keyboard_controller_emits_down args, assert
  ctrl = KeyboardController.new
  assert.equal! ctrl.next_direction(world_with(up_down: -1)), Direction::DOWN
end

def test_keyboard_controller_emits_left args, assert
  ctrl = KeyboardController.new
  assert.equal! ctrl.next_direction(world_with(left_right: -1)), Direction::LEFT
end

def test_keyboard_controller_emits_right args, assert
  ctrl = KeyboardController.new
  assert.equal! ctrl.next_direction(world_with(left_right: 1)), Direction::RIGHT
end

def test_keyboard_controller_emits_none_when_idle args, assert
  ctrl = KeyboardController.new
  assert.equal! ctrl.next_direction(world_with), Direction::NONE
end

def test_keyboard_controller_vertical_priority args, assert
  ctrl = KeyboardController.new
  # Both vertical and horizontal pressed: vertical wins (legacy behavior).
  result = ctrl.next_direction(world_with(up_down: 1, left_right: 1))
  assert.equal! result, Direction::UP
end
