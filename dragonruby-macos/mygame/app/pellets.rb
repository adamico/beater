# app/pellets.rb
require 'app/tiles.rb'

class Pellets
  COLORS = [:red, :green, :blue, :yellow].freeze

  def self.from_maze(maze)
    mid_x = maze.width  / 2
    mid_y = maze.height / 2
    state = {}
    maze.each_cell do |gx, gy, ch|
      case ch
      when Tiles::PELLET
        state[[gx, gy]] = { kind: :pellet, color: quadrant_color(gx, gy, mid_x, mid_y) }
      when Tiles::POWER_PELLET
        state[[gx, gy]] = { kind: :power }
      end
    end
    new(state)
  end

  # TL=red, TR=green, BL=blue, BR=yellow.
  # Stable per (gx,gy); independent of dot count balance per quadrant.
  def self.quadrant_color(gx, gy, mid_x, mid_y)
    left = gx < mid_x
    top  = gy >= mid_y
    return :red    if  left &&  top
    return :green  if !left &&  top
    return :blue   if  left && !top
    :yellow
  end

  def initialize(state)
    @state = state
  end

  def at(gx, gy)
    entry = @state[[gx, gy]]
    entry && entry[:kind]
  end

  def color_at(gx, gy)
    entry = @state[[gx, gy]]
    entry && entry[:color]
  end

  def entry_at(gx, gy)
    @state[[gx, gy]]
  end

  def eat(gx, gy)
    @state.delete([gx, gy])
  end

  def remaining
    @state.size
  end

  def each(&blk)
    @state.each { |key, entry| blk.call(key, entry[:kind]) }
  end

  def each_with_color(&blk)
    @state.each { |key, entry| blk.call(key, entry[:kind], entry[:color]) }
  end
end
