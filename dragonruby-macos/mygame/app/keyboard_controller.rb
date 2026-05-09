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
end
