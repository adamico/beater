# app/ghost_controllers.rb
#
# Per-personality ghost controllers + frightened + eaten. Decisions are taken
# near intersections (within one movement step of cell center) so ghosts are
# not constrained by exact center hits.

require 'app/direction.rb'

module GhostControllers
  DECISION_EPSILON = 0.0001

  def self.at_decision_point?(ghost, projection)
    speed_tol = ghost.respond_to?(:speed) ? ghost.speed.to_f : 0.0
    ghost.at_cell_center?(projection, tolerance: speed_tol + DECISION_EPSILON)
  end

  module Targeting
    def self.next_direction(ghost, world, target_tile)
      return Direction::NONE unless GhostControllers.at_decision_point?(ghost, world.projection)

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
      return Direction::NONE unless GhostControllers.at_decision_point?(ghost, world.projection)
      gx, gy = ghost.grid_cell(world.projection)
      # Prefer non-reverse walkable directions
      candidates = Direction::ALL_MOVING.reject { |d| d == ghost.direction.opposite }
      walkable = candidates.select { |d| world.maze.walkable?(gx + d.dx, gy + d.dy, role: ghost.role) }
      if !walkable.empty?
        return walkable.sample
      end
      # If no non-reverse walkable, try reverse if it's walkable
      reverse = ghost.direction.opposite
      if world.maze.walkable?(gx + reverse.dx, gy + reverse.dy, role: ghost.role)
        return reverse
      end
      # As a last resort, try any walkable direction (including reverse)
      all_walkable = Direction::ALL_MOVING.select { |d| world.maze.walkable?(gx + d.dx, gy + d.dy, role: ghost.role) }
      return all_walkable.sample unless all_walkable.empty?
      # Truly stuck: surrounded by walls
      Direction::NONE
    end
  end

  # BFS-based shortest-path targeting. Used by Eaten + LeavingHouse where
  # correctness matters (greedy Euclidean breaks across tunnel wrap and dead-
  # end corridors). Chase/scatter stay greedy on purpose — that's the arcade
  # behavior and what gives each ghost its character.
  module BFSTargeting
    def self.next_direction(ghost, world, target_cell)
      return Direction::NONE unless GhostControllers.at_decision_point?(ghost, world.projection)
      start = ghost.grid_cell(world.projection)
      return Direction::NONE if start == target_cell

      visited = { start => nil }
      queue = [start]
      until queue.empty?
        cell = queue.shift
        Direction::ALL_MOVING.each do |d|
          nx, ny = world.maze.wrap(cell[0] + d.dx, cell[1] + d.dy)
          next_cell = [nx, ny]
          next if visited.key?(next_cell)
          next unless world.maze.walkable?(nx, ny, role: ghost.role)
          visited[next_cell] = [cell, d]
          if next_cell == target_cell
            current = next_cell
            current = visited[current][0] while visited[current][0] != start
            return visited[current][1]
          end
          queue << next_cell
        end
      end
      Direction::NONE
    end
  end

  class Eaten
    def next_direction(world, ghost)
      BFSTargeting.next_direction(ghost, world, ghost.spawn_cell)
    end
  end

  # Targets a fixed exit cell with the ghost's current role (:ghost_leaving).
  # Path through the door + pen corridor is opened by the role's passability.
  class LeavingHouse
    def initialize(target_cell)
      @target = target_cell
    end

    def next_direction(world, ghost)
      BFSTargeting.next_direction(ghost, world, @target)
    end
  end
end
