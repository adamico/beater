# app/maze.rb
require 'app/tiles.rb'

class Maze
  def self.from_layout(layout)
    grid_w = layout[0][0].length
    grid_h = layout.length

    chars = Array.new(grid_h) { Array.new(grid_w) }
    grid_h.times do |gy|
      src_y = grid_h - 1 - gy
      grid_w.times do |gx|
        chars[gy][gx] = layout[src_y][0][gx]
      end
    end

    new(chars, grid_w, grid_h)
  end

  attr_reader :width, :height

  def initialize(chars, width, height)
    @chars = chars
    @width = width
    @height = height
  end

  def walkable?(gx, gy)
    return false if gx < 0 || gy < 0 || gx >= @width || gy >= @height
    Tiles.walkable?(@chars[gy][gx])
  end

  def char_at(gx, gy)
    return nil if gx < 0 || gy < 0 || gx >= @width || gy >= @height
    @chars[gy][gx]
  end

  def each_cell
    @height.times do |gy|
      @width.times do |gx|
        yield gx, gy, @chars[gy][gx]
      end
    end
  end

  def wall_segments(projection)
    segments = []
    @height.times do |gy|
      @width.times do |gx|
        ch = @chars[gy][gx]
        next if Tiles.walkable?(ch)
        rect = projection.cell_rect(gx, gy)
        cx = rect[:x] + rect[:w] / 2
        cy = rect[:y] + rect[:h] / 2
        top_y = rect[:y] + rect[:h]
        bottom_y = rect[:y]
        left_x = rect[:x]
        right_x = rect[:x] + rect[:w]

        case ch
        when Tiles::CORNER_BR
          segments << { x: cx, y: bottom_y, x2: cx, y2: cy }
          segments << { x: cx, y: cy, x2: right_x, y2: cy }
        when Tiles::CORNER_BL
          segments << { x: cx, y: bottom_y, x2: cx, y2: cy }
          segments << { x: cx, y: cy, x2: left_x, y2: cy }
        when Tiles::CORNER_TR
          segments << { x: cx, y: top_y, x2: cx, y2: cy }
          segments << { x: cx, y: cy, x2: right_x, y2: cy }
        when Tiles::CORNER_TL
          segments << { x: cx, y: top_y, x2: cx, y2: cy }
          segments << { x: cx, y: cy, x2: left_x, y2: cy }
        when Tiles::WALL_V
          segments << { x: cx, y: top_y, x2: cx, y2: bottom_y }
        when Tiles::WALL_H
          segments << { x: left_x, y: cy, x2: right_x, y2: cy }
        end
      end
    end
    segments
  end
end
