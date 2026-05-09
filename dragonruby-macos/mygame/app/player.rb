# app/player.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'

class Player
  include GridMover

  attr_accessor :controller, :r, :g, :b, :a

  def initialize(x:, y:, w:, h:, speed:, controller:, direction: Direction::NONE, color: { r: 128, g: 255, b: 128 })
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @controller = controller
    @r = color[:r]
    @g = color[:g]
    @b = color[:b]
    @a = 255
  end

  def to_solid
    { x: @x, y: @y, w: @w, h: @h, r: @r, g: @g, b: @b, a: @a }
  end
end
