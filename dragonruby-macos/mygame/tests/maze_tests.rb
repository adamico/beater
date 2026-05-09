require 'app/maze.rb'

# 5x5 layout with horizontal tunnel on middle row (row index 2 in layout, also
# gy=2 after y-flip because the layout is symmetric).
#   wwwww
#   w...w
#   _..._
#   w...w
#   wwwww
TUNNEL_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(_..._),
  %w(w...w),
  %w(wwwww)
]

def test_walkable_wraps_horizontally args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  # Tunnel row: edge cells walkable, and out-of-bounds gx wraps to opposite edge.
  assert.true! maze.walkable?(0, 2)
  assert.true! maze.walkable?(4, 2)
  assert.true! maze.walkable?(-1, 2)   # wraps to gx=4
  assert.true! maze.walkable?(5, 2)    # wraps to gx=0
end

def test_walkable_wraps_into_wall args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  # Top row is solid wall; wrap still resolves to a wall char -> false.
  assert.false! maze.walkable?(-1, 0)
  assert.false! maze.walkable?(5, 0)
end

def test_walkable_y_does_not_wrap args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  assert.false! maze.walkable?(2, -1)
  assert.false! maze.walkable?(2, 5)
end

def test_wrap_normalizes_gx args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  assert.equal! maze.wrap(-1, 2), [4, 2]
  assert.equal! maze.wrap(5, 2),  [0, 2]
  assert.equal! maze.wrap(2, 2),  [2, 2]
end
