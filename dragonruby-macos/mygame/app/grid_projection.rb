# app/grid_projection.rb
#
# Maps grid ordinals to world-space pixel rects. World origin == grid origin:
# there is no screen offset here — the Camera owns all world→screen translation.

class GridProjection
  attr_reader :cell_size, :grid_w, :grid_h

  def initialize(cell_size:, grid_w:, grid_h:)
    @cell_size = cell_size
    @grid_w = grid_w
    @grid_h = grid_h
  end

  # Zero-returning shims: world origin == grid origin. Kept so grid_mover,
  # ghost_state_machine, projectile and ghost_controllers need no edits; the
  # dead `- 0` arithmetic gets scrubbed in a later cleanup commit.
  def offset_x
    0
  end

  def offset_y
    0
  end

  def cell_rect(gx, gy)
    {
      x: gx * @cell_size,
      y: gy * @cell_size,
      w: @cell_size,
      h: @cell_size
    }
  end

  def cells_touched(rect)
    min_gx = (rect[:x].to_f / @cell_size).floor
    max_gx = ((rect[:x] + rect[:w] - 1).to_f / @cell_size).floor
    min_gy = (rect[:y].to_f / @cell_size).floor
    max_gy = ((rect[:y] + rect[:h] - 1).to_f / @cell_size).floor

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
end
