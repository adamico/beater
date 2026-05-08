# app/pellets.rb
require 'app/tiles.rb'

class Pellets
  def self.from_maze(maze)
    state = {}
    maze.each_cell do |gx, gy, ch|
      case ch
      when Tiles::PELLET       then state[[gx, gy]] = :pellet
      when Tiles::POWER_PELLET then state[[gx, gy]] = :power
      end
    end
    new(state)
  end

  def initialize(state)
    @state = state
  end

  def at(gx, gy)
    @state[[gx, gy]]
  end

  def eat(gx, gy)
    @state.delete([gx, gy])
  end

  def remaining
    @state.size
  end

  def each(&blk)
    @state.each(&blk)
  end
end
