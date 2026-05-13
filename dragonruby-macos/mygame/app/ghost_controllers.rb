# app/ghost_controllers.rb
#
# Per-personality ghost controllers + frightened + eaten. Decisions are taken
# near intersections (within one movement step of cell center) so ghosts are
# not constrained by exact center hits.

require 'app/direction.rb'

module GhostControllers
  DECISION_EPSILON = 0.0001

  # Clyde flips to scatter when within this radius of Pac (OG arcade rule).
  CLYDE_SHY_RADIUS_TILES = 8

  def self.at_decision_point?(ghost, projection)
    speed_tol = ghost.respond_to?(:speed) ? ghost.speed.to_f : 0.0
    ghost.at_cell_center?(projection, tolerance: speed_tol + DECISION_EPSILON)
  end

  module Targeting
    # OG arcade tie-break preference: UP > LEFT > DOWN > RIGHT.
    TIE_BREAK_ORDER = [Direction::UP, Direction::LEFT, Direction::DOWN, Direction::RIGHT].freeze

    @last_log_tick = {}
    @cell_trails = Hash.new { |h, k| h[k] = [] }
    # One-decision-per-cell latch. at_decision_point? fires every tick within
    # speed-tolerance of cell center, and the greedy + reverse-exclusion picker
    # can flip its choice frame-to-frame at a corner (picks LEFT on tick N
    # because DOWN was the reverse, then DOWN on tick N+1 because LEFT became
    # the new reverse) — that produced scatter corner-loop oscillation. Lives
    # in Targeting only: Frightened (random) and BFS-based controllers don't
    # have the same hazard and aren't gated.
    @last_decision_cell = {}

    def self.clear_latch(identity)
      @last_decision_cell.delete(identity)
    end

    def self.next_direction(ghost, world, target_tile)
      return Direction::NONE unless GhostControllers.at_decision_point?(ghost, world.projection)

      gx, gy = ghost.grid_cell(world.projection)
      return Direction::NONE if @last_decision_cell[ghost.identity] == [gx, gy]

      candidates = TIE_BREAK_ORDER.reject { |d| d == ghost.direction.opposite }

      best = nil
      best_dist = nil
      walk_map = {}
      dist_map = {}
      candidates.each do |d|
        nx, ny = gx + d.dx, gy + d.dy
        walkable = world.maze.walkable?(nx, ny, role: ghost.role)
        walk_map[d.name] = walkable
        next unless walkable
        dist = (nx - target_tile[0])**2 + (ny - target_tile[1])**2
        dist_map[d.name] = dist
        if best_dist.nil? || dist < best_dist
          best = d
          best_dist = dist
        end
      end

      if best.nil?
        log_phantom_reverse(ghost, world, gx, gy, walk_map)
        @last_decision_cell[ghost.identity] = [gx, gy]
        return ghost.direction.opposite
      end

      log_scatter_decision(ghost, gx, gy, target_tile, walk_map, dist_map, best)
      @last_decision_cell[ghost.identity] = [gx, gy]
      best
    end

    def self.log_scatter_decision(ghost, gx, gy, target_tile, walk_map, dist_map, chosen)
      return unless ghost.state == :scatter
      return unless ghost.identity == :blinky || ghost.identity == :pinky

      trail = @cell_trails[ghost.identity]
      trail << [gx, gy]
      trail.shift while trail.size > 8

      reverse = ghost.direction.opposite
      cand = TIE_BREAK_ORDER.map { |d|
        if d == reverse
          [d.name, "rev"]
        else
          w = walk_map[d.name]
          [d.name, w ? "w:#{dist_map[d.name]}" : "x"]
        end
      }.to_h

      puts "[GHOST SCATTER] tick=#{Kernel.tick_count} id=#{ghost.identity} " \
           "cell=(#{gx},#{gy}) dir=#{ghost.direction.name} target=#{target_tile.inspect} " \
           "cand=#{cand.inspect} chose=#{chosen.name} trail=#{trail.inspect}" if GHOST_DEBUG_LOGS
    end

    def self.log_phantom_reverse(ghost, world, gx, gy, walk_map)
      tick = Kernel.tick_count
      key = ghost.identity
      last = @last_log_tick[key] || -1000
      return if tick - last < 30

      @last_log_tick[key] = tick

      cs = world.projection.cell_size.to_f
      ox = world.projection.offset_x
      oy = world.projection.offset_y
      x_cells = (ghost.x - ox).to_f / cs
      y_cells = (ghost.y - oy).to_f / cs
      cell_floor = [(x_cells).floor, (y_cells).floor]
      cell_round = [(x_cells).round, (y_cells).round]
      err = [(x_cells - x_cells.round).abs * cs, (y_cells - y_cells.round).abs * cs]
      tol = ghost.speed.to_f + DECISION_EPSILON

      puts "[GHOST 180°] tick=#{tick} id=#{key} state=#{ghost.state} role=#{ghost.role.inspect} " \
           "pos=(#{ghost.x.round(2)}, #{ghost.y.round(2)}) " \
           "cell_floor=#{cell_floor.inspect} cell_round=#{cell_round.inspect} " \
           "decision_cell=(#{gx},#{gy}) center_err=(#{err[0].round(3)},#{err[1].round(3)}) tol=#{tol.round(3)} " \
           "dir=#{ghost.direction.name} walkable=#{walk_map.inspect} -> reversed to #{ghost.direction.opposite.name}" if GHOST_DEBUG_LOGS
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
      scatter_target_fn: ->(world, ghost) {
        # Cruise Elroy: when active, Blinky targets Pac during scatter too.
        ghost.elroy_state != :off ? world.player.grid_cell(world.projection) : ghost.scatter_target
      },
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
    if dist2 >= CLYDE_SHY_RADIUS_TILES**2
      [px, py]
    else
      ghost.scatter_target
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
