require 'app/maze.rb'
require 'app/pellets.rb'

# 6x6 layout. Center at (3,3). Pellets in all 4 quadrants; one power pellet.
QUAD_LAYOUT_6X6 = [
  %w(wwwwww),
  %w(w....w),
  %w(w.oo.w),
  %w(w....w),
  %w(w....w),
  %w(wwwwww),
]

def test_pellets_assigns_color_per_quadrant args, assert
  maze    = Maze.from_layout(QUAD_LAYOUT_6X6)
  pellets = Pellets.from_maze(maze)

  mid_x = maze.width  / 2  # 3
  mid_y = maze.height / 2  # 3

  pellets.each_with_color do |(gx, gy), kind, color|
    next unless kind == :pellet
    expected = if    gx < mid_x && gy >= mid_y then :red
               elsif gx >= mid_x && gy >= mid_y then :green
               elsif gx < mid_x && gy <  mid_y then :blue
               else                                 :yellow
               end
    assert.equal! color, expected
  end
end

def test_pellets_color_assignment_is_stable args, assert
  maze    = Maze.from_layout(QUAD_LAYOUT_6X6)
  a = Pellets.from_maze(maze)
  b = Pellets.from_maze(maze)
  a.each_with_color do |(gx, gy), _kind, color|
    assert.equal! color, b.color_at(gx, gy)
  end
end

def test_pellets_eat_returns_entry args, assert
  maze    = Maze.from_layout(QUAD_LAYOUT_6X6)
  pellets = Pellets.from_maze(maze)

  # Find any pellet position
  target = nil
  pellets.each_with_color { |(gx, gy), kind, _c| target ||= [gx, gy] if kind == :pellet }

  entry = pellets.eat(*target)
  assert.equal! entry[:kind], :pellet
  assert.true! Pellets::COLORS.include?(entry[:color])
  assert.nil! pellets.at(*target)
end

def test_pellets_power_has_no_color args, assert
  maze    = Maze.from_layout(QUAD_LAYOUT_6X6)
  pellets = Pellets.from_maze(maze)
  found_power = false
  maze.each_cell do |gx, gy, _ch|
    next unless pellets.at(gx, gy) == :power
    found_power = true
    assert.nil! pellets.color_at(gx, gy)
  end
  assert.true! found_power
end

def test_pellets_each_back_compat_yields_kind args, assert
  maze    = Maze.from_layout(QUAD_LAYOUT_6X6)
  pellets = Pellets.from_maze(maze)
  kinds = []
  pellets.each { |(_gx, _gy), kind| kinds << kind }
  assert.true! kinds.include?(:pellet)
  assert.true! kinds.include?(:power)
end
