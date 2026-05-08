require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/maze.rb'
require 'app/pellets.rb'

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
    @player = {
      x: spawn[:x], y: spawn[:y],
      w: CELL_SIZE, h: CELL_SIZE,
      dx: 1, dy: 0,
      path: :solid,
      r: 128, g: 255, b: 128
    }
  end

  def tick
    handle_input
    move_player
    eat_pellets
    render
  end

  def handle_input
    if inputs.up_down != 0
      probe = { **@player, y: @player.y + inputs.up_down }
      if can_turn_to?(probe)
        @player.dy = inputs.up_down
        @player.dx = 0
      end
    elsif inputs.left_right != 0
      probe = { **@player, x: @player.x + inputs.left_right }
      if can_turn_to?(probe)
        @player.dy = 0
        @player.dx = inputs.left_right
      end
    end
  end

  def can_turn_to?(rect)
    cells = @projection.cells_touched(rect)
    return false unless cells.length == 2
    cells.all? { |gx, gy| @maze.walkable?(gx, gy) }
  end

  def move_player
    @player.x += @player.dx * PLAYER_SPEED
    @player.x -= @player.dx * PLAYER_SPEED if blocked?(@player)
    @player.y += @player.dy * PLAYER_SPEED
    @player.y -= @player.dy * PLAYER_SPEED if blocked?(@player)
  end

  def blocked?(rect)
    @projection.cells_touched(rect).any? { |gx, gy| !@maze.walkable?(gx, gy) }
  end

  def eat_pellets
    @projection.cells_touched(@player).each do |gx, gy|
      @pellets.eat(gx, gy) if @pellets.at(gx, gy)
    end
  end

  def render
    outputs.background_color = [30, 30, 30]
    outputs.lines << @maze.wall_segments(@projection).map { |seg| { **seg, **WALL_COLOR } }
    outputs.solids << pellet_solids
    outputs.primitives << @player
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
