# app/ghost_controllers.rb
#
# Per-personality ghost controllers + frightened + eaten. All decisions taken
# at intersections (cell-center + ≥2 non-reverse walkable exits); else NONE so
# GridMover keeps current direction. Reverse excluded from candidates.

require 'app/direction.rb'

module GhostControllers
  module Targeting
    def self.next_direction(ghost, world, target_tile)
      return Direction::NONE unless ghost.at_cell_center?(world.projection)

      gx, gy = ghost.grid_cell(world.projection)
      candidates = Direction::ALL_MOVING.reject { |d| d == ghost.direction.opposite }

      best = nil
      best_dist = nil
      candidates.each do |d|
        nx, ny = gx + d.dx, gy + d.dy
        next unless world.maze.walkable?(nx, ny, role: ghost.role)
        dist = (nx - target_tile[0])**2 + (ny - target_tile[1])**2
        if best_dist.nil? || dist < best_dist
          best = d
          best_dist = dist
        end
      end

      best || ghost.direction.opposite
    end
  end

  class BaseChase
    def initialize(scatter_target_fn:, chase_target_fn:)
      @scatter_target_fn = scatter_target_fn
      @chase_target_fn = chase_target_fn
    end

    def next_direction(world, ghost)
      target = (ghost.state == :scatter ? @scatter_target_fn : @chase_target_fn).call(world, ghost)
      Targeting.next_direction(ghost, world, target)
    end
  end

  def self.for(identity)
    case identity
    when :blinky then blinky
    when :pinky  then pinky
    when :inky   then inky
    when :clyde  then clyde
    end
  end

  def self.blinky
    BaseChase.new(
      scatter_target_fn: ->(_w, ghost) { ghost.scatter_target },
      chase_target_fn:   ->(world, _g) { world.player.grid_cell(world.projection) }
    )
  end

  def self.pinky
    BaseChase.new(
      scatter_target_fn: ->(_w, ghost) { ghost.scatter_target },
      chase_target_fn:   ->(world, _g) { pinky_target(world) }
    )
  end

  # 4 tiles ahead of player. Replicates the arcade up-direction overflow bug
  # (4 up + 4 left) intentionally. See docs/adr/0003-pinky-overflow-bug-replicated.md
  def self.pinky_target(world)
    px, py = world.player.grid_cell(world.projection)
    d = world.player.direction
    tx = px + d.dx * 4
    ty = py + d.dy * 4
    tx -= 4 if d == Direction::UP
    [tx, ty]
  end

  def self.inky
    BaseChase.new(
      scatter_target_fn: ->(_w, ghost) { ghost.scatter_target },
      chase_target_fn:   ->(world, _g) { inky_target(world) }
    )
  end

  def self.inky_target(world)
    blinky = world.ghosts.find { |g| g.identity == :blinky }
    return world.player.grid_cell(world.projection) unless blinky

    px, py = world.player.grid_cell(world.projection)
    d = world.player.direction
    pivot_x = px + d.dx * 2
    pivot_y = py + d.dy * 2
    pivot_x -= 2 if d == Direction::UP # mirror Pinky-style overflow at the 2-ahead step

    bx, by = blinky.grid_cell(world.projection)
    [pivot_x + (pivot_x - bx), pivot_y + (pivot_y - by)]
  end

  def self.clyde
    BaseChase.new(
      scatter_target_fn: ->(_w, ghost) { ghost.scatter_target },
      chase_target_fn:   ->(world, ghost) { clyde_target(world, ghost) }
    )
  end

  def self.clyde_target(world, ghost)
    px, py = world.player.grid_cell(world.projection)
    gx, gy = ghost.grid_cell(world.projection)
    dist2 = (px - gx)**2 + (py - gy)**2
    if dist2 >= 64 # >= 8 tiles
      [px, py]
    else
      ghost.scatter_target
    end
  end

  class Frightened
    def next_direction(world, ghost)
      return Direction::NONE unless ghost.at_cell_center?(world.projection)
      gx, gy = ghost.grid_cell(world.projection)
      candidates = Direction::ALL_MOVING.reject { |d| d == ghost.direction.opposite }
      walkable = candidates.select { |d| world.maze.walkable?(gx + d.dx, gy + d.dy, role: ghost.role) }
      walkable.empty? ? ghost.direction.opposite : walkable.sample
    end
  end

  class Eaten
    def next_direction(world, ghost)
      Targeting.next_direction(ghost, world, ghost.spawn_cell)
    end
  end
end
