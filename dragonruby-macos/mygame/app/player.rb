# app/player.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'

class Player
  include GridMover

  attr_accessor :controller

  def initialize(x:, y:, w:, h:, speed:, controller:, direction: Direction::NONE)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @controller = controller
    @sprite_scale = 1.5
    @sprite_offset = (w * @sprite_scale - w) / 2.0
  end

  def to_sprite
    { 
      x: @x - @sprite_offset, y: @y - @sprite_offset,
      w: @w * @sprite_scale, h: @h * @sprite_scale,
      path: "sprites/circle/yellow.png"
    }
  end
end
