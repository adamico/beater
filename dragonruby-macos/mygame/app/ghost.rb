# app/ghost.rb
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/tiles.rb'

class Ghost
  include GridMover

  IDENTITIES = [:blinky, :pinky, :inky, :clyde].freeze

  SPRITES = {
    blinky: "sprites/square/red.png",
    pinky:  "sprites/square/violet.png",
    inky:   "sprites/square/blue.png",
    clyde:  "sprites/square/orange.png",
    frightened: "sprites/square/white.png",
    eaten:      "sprites/square/empty.png"
  }.freeze

  attr_accessor :state, :controller
  attr_reader :identity, :scatter_target, :spawn_cell

  def initialize(identity:, x:, y:, w:, h:, speed:, scatter_target:, spawn_cell:, controller:, direction: Direction::LEFT, sprite_scale: 2.0, sprite_offset_x: nil, sprite_offset_y: nil)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @identity = identity
    @scatter_target = scatter_target
    @spawn_cell = spawn_cell
    @controller = controller
    @state = :scatter
    @base_speed = speed
    @sprite_scale = sprite_scale
    # Default: center the scaled sprite over the 1-cell logical rect.
    @sprite_offset_x = sprite_offset_x || (w * @sprite_scale - w) / 2.0
    @sprite_offset_y = sprite_offset_y || (h * @sprite_scale - h) / 2.0
  end

  def base_speed
    @base_speed
  end

  # Sprite is rendered at sprite_scale times the logical 1-cell rect (default
  # 2x = arcade 2x2 quad), centered via sprite_offset_x/y. Tweak via init args.
  def to_sprite
    path = case @state
           when :frightened then SPRITES[:frightened]
           when :eaten      then SPRITES[:eaten]
           else SPRITES[@identity]
           end
    {
      x: @x - @sprite_offset_x, y: @y - @sprite_offset_y,
      w: @w * @sprite_scale, h: @h * @sprite_scale,
      path: path
    }
  end
end
