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

  def initialize(identity:, x:, y:, w:, h:, speed:, scatter_target:, spawn_cell:, controller:, direction: Direction::LEFT)
    init_grid_mover(x: x, y: y, w: w, h: h, speed: speed, direction: direction)
    @identity = identity
    @scatter_target = scatter_target
    @spawn_cell = spawn_cell
    @controller = controller
    @state = :scatter
    @base_speed = speed
  end

  def base_speed
    @base_speed
  end

  # Sprite is 2 tiles wide and tall (arcade-faithful 2x2 quad). The actor's
  # logical rect (collision/movement) stays 1 cell; only the sprite is doubled.
  # Anchor = bottom-left of the 2x2 quad in world coords (screen Y-up).
  def to_sprite
    path = case @state
           when :frightened then SPRITES[:frightened]
           when :eaten      then SPRITES[:eaten]
           else SPRITES[@identity]
           end
    { x: @x, y: @y, w: @w * 2, h: @h * 2, path: path }
  end
end
