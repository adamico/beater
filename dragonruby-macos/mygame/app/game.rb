require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/maze.rb'
require 'app/pellets.rb'
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/keyboard_controller.rb'
require 'app/player.rb'
require 'app/world.rb'
require 'app/renderer.rb'
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  PLAYER_SPAWN = [4, 8].freeze
  PLAYER_SPEED = 2

  def initialize
    @maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
    @projection = GridProjection.new(
      cell_size: CELL_SIZE, offset_x: OFFSET_X, offset_y: OFFSET_Y,
      grid_w: @maze.width, grid_h: @maze.height
    )
    @pellets = Pellets.from_maze(@maze)
    @renderer = Renderer.new(@projection)
    initialize_player
  end

  def initialize_player
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
    world = World.new(
      inputs: inputs,
      maze: @maze,
      projection: @projection,
      player: @player,
      pellets: @pellets
    )
    tick_player(world)
    @renderer.draw(outputs, @maze, @pellets, @player)
  end

  def tick_player(world)
    player_moves(world)
    player_eat_pellets
  end

  def player_moves(world)
    intent = @player.controller.next_direction(world)
    @player.try_turn(intent, @maze, @projection)
    @player.advance(@maze, @projection)
  end

  def player_eat_pellets
    @projection.cells_touched(@player.rect).each do |gx, gy|
      @pellets.eat(gx, gy) if @pellets.at(gx, gy)
    end
  end
end
