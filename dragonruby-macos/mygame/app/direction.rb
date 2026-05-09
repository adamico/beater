# app/direction.rb
#
# Cardinal direction value object. Replaces ad-hoc symbols and (dx, dy) pairs
# in actor and controller code. NONE represents "no movement intent."

class Direction
  attr_reader :dx, :dy, :name

  def initialize(name, dx, dy)
    @name = name
    @dx = dx
    @dy = dy
  end

  UP    = new(:up,    0,  1)
  DOWN  = new(:down,  0, -1)
  LEFT  = new(:left, -1,  0)
  RIGHT = new(:right, 1,  0)
  NONE  = new(:none,  0,  0)

  ALL_MOVING = [UP, DOWN, LEFT, RIGHT].freeze
  ALL        = (ALL_MOVING + [NONE]).freeze

  OPPOSITES = {
    :up    => DOWN,
    :down  => UP,
    :left  => RIGHT,
    :right => LEFT,
    :none  => NONE
  }

  def opposite
    OPPOSITES[@name]
  end

  def none?
    self == NONE
  end

  def horizontal?
    @dx != 0
  end

  def vertical?
    @dy != 0
  end

  def to_s
    @name.to_s
  end
end
