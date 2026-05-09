require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/maze.rb'
require 'app/pellets.rb'
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/keyboard_controller.rb'
require 'app/player.rb'
require 'app/world.rb'

class Game
  attr_dr

  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  PLAYER_SPAWN = [3, 7].freeze
  PLAYER_SPEED = 2

  WALL_COLOR   = { r: 255, g: 255, b: 255 }.freeze
  PELLET_COLOR = { r: 255, g: 200, b: 150 }.freeze

  def initialize
    @projection = GridProjection.new(cell_size: CELL_SIZE, offset_x: OFFSET_X, offset_y: OFFSET_Y)
    @maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
    @pellets = Pellets.from_maze(@maze)

    spawn = @projection.cell_rect(*PLAYER_SPAWN)
    @player = Player.new(
      x: spawn[:x], y: spawn[:y],
      w: CELL_SIZE, h: CELL_SIZE,
      speed: PLAYER_SPEED,
      controller: KeyboardController.new,
      direction: Direction::RIGHT
    )
  end

  def tick
    world = World.new(inputs: inputs, maze: @maze, projection: @projection, player: @player, pellets: @pellets)
    intent = @player.controller.next_direction(world)
    @player.try_turn(intent, @maze, @projection)
    @player.advance(@maze, @projection)
    eat_pellets
    render
  end

  def eat_pellets
    @projection.cells_touched(@player.rect).each do |gx, gy|
      @pellets.eat(gx, gy) if @pellets.at(gx, gy)
    end
  end

  def render
    outputs.background_color = [30, 30, 30]
    outputs.lines << @maze.wall_segments(@projection).map { |seg| { **seg, **WALL_COLOR } }
    outputs.solids << pellet_solids
    outputs.solids << @player.to_solid
  end

  def pellet_solids
    solids = []
    @pellets.each do |coords, kind|
      gx, gy = coords
      r = @projection.cell_rect(gx, gy)
      size = kind == :power ? 8 : 4
      pad = (CELL_SIZE - size) / 2
      solids << { x: r[:x] + pad, y: r[:y] + pad, w: size, h: size, **PELLET_COLOR }
    end
    solids
  end
end
