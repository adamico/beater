# app/maze.rb
require 'app/tiles.rb'
require 'app/wall_shape.rb'

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
    gx, gy = wrap(gx, gy)
    return false if gy < 0 || gy >= @height
    Tiles.walkable?(@chars[gy][gx])
  end

  # Toroidal coord normalization on the X axis. Y is not wrapped: maps with
  # vertical tunnels would need the same treatment, but current layouts cap
  # top/bottom rows with solid wall.
  def wrap(gx, gy)
    [gx % @width, gy]
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
    each_cell do |gx, gy, ch|
      next if Tiles.walkable?(ch)
      shape = WallShape.from_char(ch)
      next unless shape
      segments.concat(shape.segments(projection.cell_rect(gx, gy)))
    end
    segments
  end
end
