# app/grid_projection.rb

class GridProjection
  attr_reader :cell_size, :offset_x, :offset_y, :grid_w, :grid_h

  def initialize(cell_size:, offset_x:, offset_y:, grid_w:, grid_h:)
    @cell_size = cell_size
    @offset_x = offset_x
    @offset_y = offset_y
    @grid_w = grid_w
    @grid_h = grid_h
  end

  def cell_rect(gx, gy)
    {
      x: gx * @cell_size + @offset_x,
      y: gy * @cell_size + @offset_y,
      w: @cell_size,
      h: @cell_size
    }
  end

  def cells_touched(rect)
    min_gx = ((rect[:x] - @offset_x).to_f / @cell_size).floor
    max_gx = ((rect[:x] + rect[:w] - @offset_x - 1).to_f / @cell_size).floor
    min_gy = ((rect[:y] - @offset_y).to_f / @cell_size).floor
    max_gy = ((rect[:y] + rect[:h] - @offset_y - 1).to_f / @cell_size).floor

    result = []
    (min_gx..max_gx).each do |gx|
      (min_gy..max_gy).each do |gy|
        result << [gx, gy]
      end
    end
    result
  end

  def aligned?(rect)
    cells_touched(rect).length == 2
  end

  def playfield_w
    @cell_size * @grid_w
  end

  def playfield_h
    @cell_size * @grid_h
  end

  def playfield_rect
    { x: @offset_x, y: @offset_y, w: playfield_w, h: playfield_h }
  end

  def rect_for_cell_bounds(b)
    {
      x: b[:gx0] * @cell_size + @offset_x,
      y: b[:gy0] * @cell_size + @offset_y,
      w: (b[:gx1] - b[:gx0] + 1) * @cell_size,
      h: (b[:gy1] - b[:gy0] + 1) * @cell_size
    }
  end
end
