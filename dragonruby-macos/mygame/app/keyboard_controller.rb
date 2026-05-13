# app/keyboard_controller.rb
require 'app/direction.rb'

# Maps DR's per-tick input axes to a Direction. Vertical input takes priority
# over horizontal when both are pressed (matches the legacy behavior in Game).
class KeyboardController
  def next_direction(world)
    inputs = world.inputs
    return Direction::UP    if inputs.up_down > 0
    return Direction::DOWN  if inputs.up_down < 0
    return Direction::RIGHT if inputs.left_right > 0
    return Direction::LEFT  if inputs.left_right < 0
    Direction::NONE
  end

  # Edge-triggered fire input. True on the tick Space or the controller's
  # south button transitions from up to down.
  def fire_pressed?(world)
    inputs = world.inputs
    return false unless inputs
    kb = inputs.keyboard&.key_down
    c1 = inputs.controller_one&.key_down
    return true if kb && kb.respond_to?(:space) && kb.space
    return true if c1 && c1.respond_to?(:a) && c1.a
    return true if c1 && c1.respond_to?(:button_a) && c1.button_a
    false
  end
end
