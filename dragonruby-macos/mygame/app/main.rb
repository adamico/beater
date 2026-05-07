require 'app/gmm_parser.rb'
require 'app/map_generator.rb'

MapGenerator.generate_if_needed('data/maps/pacman.gmm', 'data/maps/pacman_layout.rb')
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  pacman_layout = MapLayouts::PACMAN_LAYOUT

  GRID_WIDTH = 28
  GRID_HEIGHT = 36
  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  MAP_FILE = 'data/maps/pacman.gmm'

  def initialize
    puts "Game initializing..."
    map = GmmParser.parse(MAP_FILE)
    puts "Map loaded: #{!map.nil?} (W: #{map&.[](:width)}, H: #{map&.[](:height)}, Floors: #{map&.[](:floors)&.length})"
    grid_w = map ? map[:width] : GRID_WIDTH
    grid_h = map ? map[:height] : GRID_HEIGHT

    # generate available spaces that the player can move through
    @cells = grid_w.flat_map do |x_ordinal|
      grid_h.map do |y_ordinal|
        {
          **Geometry.rect(
            x: x_ordinal * CELL_SIZE + OFFSET_X,
            y: y_ordinal * CELL_SIZE + OFFSET_Y,
            w: CELL_SIZE,
            h: CELL_SIZE
          ),
          x_ordinal: x_ordinal,
          y_ordinal: y_ordinal
        }
      end
    end

    # track which spaces have walls in them
    @walls = []
    if map
      @cells.each do |cell|
        gmm_y = grid_h - 1 - cell[:y_ordinal]
        gmm_x = cell[:x_ordinal]
        index = gmm_y * (map[:width] + 1) + gmm_x
        tile = map[:floors][index]
        
        # floors (1) are walkable cells, all other tiles are walls
        @walls << cell if tile != 1
      end
    end

    # player's position, size, and movement direction
    @player = {
      x: (CELL_SIZE / 2)*3 + OFFSET_X,
      y: (CELL_SIZE / 2)*7 + OFFSET_Y,
      w: CELL_SIZE,
      h: CELL_SIZE,
      dx: 1,
      dy: 0,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: :solid,
      r: 128, g: 255, b: 128,
    }
  end

  def tick
    # Render debug info
    outputs.labels << { x: 10, y: 710, text: "Press 'R' to reload map. Walls: #{@walls.length}", r: 255, g: 255, b: 255 }

    if inputs.keyboard.key_down.r
      puts "Reloading Game map..."
      initialize
    end

    # move player based on arrow key input, but only if the player won't collide with a wall
    if inputs.up_down != 0
      # first check cells to see if the player is grid aligned
      collisions = Geometry.find_all_intersect_rect(
        { **@player, y: @player.y + inputs.up_down },
        @cells,
        tolerance: 0
      )

      # if the player is intersecting with exactly 2 cells, then they are grid aligned and we can check for wall collisions
      if collisions.length == 2
        # if neither of the cells the player is intersecting with have walls, then we can move the player
        if collisions.none? { |collision| @walls.include?(collision) }
          # update the player's movement direction based on the input
          @player.dy = inputs.up_down
          @player.dx = 0
        end
      end
    elsif inputs.left_right != 0
      collisions = Geometry.find_all_intersect_rect(
        { **@player, x: @player.x + inputs.left_right },
        @cells,
        tolerance: 0
      )

      if collisions.length == 2
        if collisions.none? { |collision| @walls.include?(collision) }
          @player.dy = 0
          @player.dx = inputs.left_right
        end
      end
    end

    # move the player based on their movement direction, but only if they won't collide with a wall
    @player.x += @player.dx * 2
    if Geometry.find_intersect_rect(@player, @walls)
      @player.x -= @player.dx * 2
    end
    @player.y += @player.dy * 2
    if Geometry.find_intersect_rect(@player, @walls)
      @player.y -= @player.dy * 2
    end

    # render the game
    outputs.background_color = [30, 30, 30]
    outputs.primitives << @walls.map do |cell|
      {
        x: cell[:x] + 2,
        y: cell[:y] + 2,
        w: cell[:w] - 4,
        h: cell[:h] - 4,
        path: :solid, r: 255, g: 255, b: 255, a: 128
      }
    end
    outputs.primitives << @player
  end
end

module Main
  def tick args
    @game ||= Game.new
    @game.args = args
    @game.tick
  end

  def reset args
    @game = nil
  end
end

GTK.reset
