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
    @totals_by_color = Hash.new(0)
    @remaining_by_color = Hash.new(0)
    state.each_value do |entry|
      next unless entry[:kind] == :pellet && entry[:color]
      @totals_by_color[entry[:color]] += 1
      @remaining_by_color[entry[:color]] += 1
    end
  end

  attr_reader :totals_by_color, :remaining_by_color

  # Per-color progress ratio (dots eaten / total) — drives the HUD track meters.
  def completion_by_color
    COLORS.to_h do |c|
      total = @totals_by_color[c]
      [c, total > 0 ? (total - @remaining_by_color[c]).to_f / total : 0.0]
    end
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

  # Returns the eaten entry. When this eat empties a colour (last dot of that
  # colour), the entry carries `track_cleared: <color>` so Game can fire the
  # G1 track-completion bonus.
  def eat(gx, gy)
    entry = @state.delete([gx, gy])
    if entry && entry[:kind] == :pellet && entry[:color]
      color = entry[:color]
      @remaining_by_color[color] -= 1
      entry = entry.merge(track_cleared: color) if @remaining_by_color[color] <= 0
    end
    entry
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
