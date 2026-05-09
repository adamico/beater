require 'app/grid_projection.rb'

def test_cell_rect_with_offset args, assert
  proj = GridProjection.new(cell_size: 20, offset_x: 100, offset_y: 50, grid_w: 5, grid_h: 5)
  rect = proj.cell_rect(2, 3)
  assert.equal! rect[:x], 140  # 2*20 + 100
  assert.equal! rect[:y], 110  # 3*20 + 50
  assert.equal! rect[:w], 20
  assert.equal! rect[:h], 20
end

def test_cells_touched_aligned args, assert
  proj = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  cells = proj.cells_touched(x: 40, y: 40, w: 20, h: 20)
  assert.equal! cells.length, 1
  assert.equal! cells.first, [2, 2]
end

def test_cells_touched_x_offset_by_one args, assert
  proj = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  cells = proj.cells_touched(x: 41, y: 40, w: 20, h: 20)
  assert.equal! cells.length, 2
  assert.true! cells.include?([2, 2])
  assert.true! cells.include?([3, 2])
end

def test_cells_touched_both_axes_offset args, assert
  proj = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  cells = proj.cells_touched(x: 41, y: 41, w: 20, h: 20)
  assert.equal! cells.length, 4
end

def test_aligned_predicate args, assert
  proj = GridProjection.new(cell_size: 20, offset_x: 0, offset_y: 0, grid_w: 5, grid_h: 5)
  # 1px probe from aligned position into next row → 2 cells → "aligned"
  assert.true!  proj.aligned?(x: 40, y: 41, w: 20, h: 20)
  # Misaligned on both axes → 4 cells → not aligned
  assert.false! proj.aligned?(x: 41, y: 41, w: 20, h: 20)
  # Fully aligned → 1 cell → not "aligned" by the 2-cell rule
  assert.false! proj.aligned?(x: 40, y: 40, w: 20, h: 20)
end
