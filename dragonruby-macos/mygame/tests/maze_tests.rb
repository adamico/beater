require 'app/maze.rb'
require 'data/maps/pacman_layout.rb'

# 5x5 layout with horizontal tunnel on middle row (row index 2 in layout, also
# gy=2 after y-flip because the layout is symmetric). `t` marks the explicit
# tunnel-slowdown tiles; `.` interior is walkable but not tunnel.
#   wwwww
#   w...w
#   t..t
#   w...w
#   wwwww
TUNNEL_LAYOUT_5X5 = [
  %w(wwwww),
  %w(w...w),
  %w(t...t),
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

def test_tunnel_marked_cells args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  # Only the two `t` cells on the middle row are tunnel.
  assert.true!  maze.tunnel?(0, 2)
  assert.true!  maze.tunnel?(4, 2)
end

def test_non_tunnel_walkable_cells args, assert
  maze = Maze.from_layout(TUNNEL_LAYOUT_5X5)
  # Walkable interior of the tunnel row is NOT tunnel (pellet floor).
  assert.true!  maze.walkable?(2, 2)
  assert.false! maze.tunnel?(2, 2)
  # Non-tunnel-row walkable cells are not tunnel either.
  assert.false! maze.tunnel?(2, 1)
end

# Regression: previous heuristic walked walkable runs from wrap edges and
# over-included the pellet at col 7 (and the `_` cells past it) on the
# pacman tunnel row. Explicit `t` marker confines tunnel to the 7 `t`
# tiles per side.
def test_pacman_tunnel_precision args, assert
  maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
  # Tunnel row is layout index 15 (top-down) of a 33-row layout ->
  # after y-flip: gy = 33 - 1 - 15 = 17. The row is:
  #   `tttttt.___vLippcRv___.tttttt`
  # so cols 0..5 are tunnel, col 6 is a pellet, cols 7..9 are empty floor,
  # col 10 is the wall column `v`.
  gy = 17
  (0..5).each { |gx| assert.true! maze.tunnel?(gx, gy) }
  # Col 6 is `.` (pellet) — walkable, not tunnel.
  assert.true!  maze.walkable?(6, gy)
  assert.false! maze.tunnel?(6, gy)
  # Cols 7..9 are `_` empty floor — also walkable, not tunnel.
  (7..9).each do |gx|
    assert.true!  maze.walkable?(gx, gy)
    assert.false! maze.tunnel?(gx, gy)
  end
end
