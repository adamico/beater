require 'app/tiles.rb'
require 'app/grid_projection.rb'
require 'app/maze.rb'
require 'app/pellets.rb'
require 'app/direction.rb'
require 'app/grid_mover.rb'
require 'app/keyboard_controller.rb'
require 'app/player.rb'
require 'app/ghost.rb'
require 'app/ghost_controllers.rb'
require 'app/world.rb'
require 'app/renderer.rb'
require 'data/maps/pacman_layout.rb'

class Game
  attr_dr

  CELL_SIZE = 20
  OFFSET_X = CELL_SIZE * 16
  OFFSET_Y = CELL_SIZE * 2
  PLAYER_SPAWN = [4, 8].freeze
  PLAYER_SPEED = 2

  GHOST_SPEED            = 2
  GHOST_FRIGHTENED_SPEED = 1
  FRIGHTENED_DURATION_TICKS = 600 # 10s @ 60fps

  # Arcade-style scatter/chase phase table (level 1), in ticks @ 60fps.
  # Last phase :chase has nil duration = stay in chase forever.
  PHASE_TABLE = [
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   nil]
  ].freeze

  # Per-ghost dot threshold to leave the house (level 1).
  RELEASE_DOT_THRESHOLD = {
    blinky: 0,
    pinky:  0,
    inky:   30,
    clyde:  60
  }.freeze
  RELEASE_STALL_TICKS = 4 * 60

  EAT_POINTS = [200, 400, 800, 1600].freeze

  def initialize
    @maze = Maze.from_layout(MapLayouts::PACMAN_LAYOUT)
    @projection = GridProjection.new(
      cell_size: CELL_SIZE, offset_x: OFFSET_X, offset_y: OFFSET_Y,
      grid_w: @maze.width, grid_h: @maze.height
    )
    @pellets = Pellets.from_maze(@maze)
    @renderer = Renderer.new(@projection)
    @dot_count = 0
    @ticks_since_release = 0
    @phase_index = 0
    @phase_ticks = 0
    @frightened_ticks = 0
    @eat_chain = 0
    @score = 0
    initialize_player
    initialize_ghosts
  end

  def initialize_player
    spawn = @projection.cell_rect(*PLAYER_SPAWN)
    @player = Player.new(
      x: spawn[:x], y: spawn[:y],
      w: CELL_SIZE, h: CELL_SIZE,
      speed: PLAYER_SPEED,
      controller: KeyboardController.new,
      direction: Direction::RIGHT
    )
  end

  def initialize_ghosts
    spawns = ghost_spawn_cells
    bounds = @maze.visible_cell_bounds
    scatter_targets = {
      blinky: [bounds[:gx1], bounds[:gy1]],
      pinky:  [bounds[:gx0], bounds[:gy1]],
      inky:   [bounds[:gx1], bounds[:gy0]],
      clyde:  [bounds[:gx0], bounds[:gy0]]
    }

    @ghosts = Ghost::IDENTITIES.each_with_index.map do |id, i|
      cell = spawns[i] || spawns.last
      rect = @projection.cell_rect(*cell)
      Ghost.new(
        identity: id,
        x: rect[:x], y: rect[:y],
        w: CELL_SIZE, h: CELL_SIZE,
        speed: GHOST_SPEED,
        scatter_target: scatter_targets[id],
        spawn_cell: cell,
        controller: GhostControllers.for(id),
        direction: Direction::LEFT
      )
    end
    @released = { blinky: true, pinky: false, inky: false, clyde: false }
  end

  # Pick 4 spawn cells: prefer EMPTY (`_`) cells far from the player; fall back
  # to any walkable cell if too few. Single anchor cell `G` is not yet emitted
  # by the layout, so we scan instead. TODO: switch to G-anchored offsets.
  def ghost_spawn_cells
    empties = []
    walkables = []
    @maze.each_cell do |gx, gy, ch|
      empties << [gx, gy] if ch == Tiles::EMPTY
      walkables << [gx, gy] if Tiles.walkable?(ch)
    end
    cells = empties.size >= 4 ? empties : walkables

    px, py = PLAYER_SPAWN
    cells.sort_by { |(gx, gy)| -((gx - px)**2 + (gy - py)**2) }.first(4)
  end

  def tick
    tick_phase
    tick_frightened
    tick_releases

    world = World.new(
      inputs: inputs,
      maze: @maze,
      projection: @projection,
      player: @player,
      pellets: @pellets,
      ghosts: @ghosts
    )

    tick_player(world)
    tick_ghosts(world)
    tick_collisions
    @renderer.draw(outputs, @maze, @pellets, @player, @ghosts)
  end

  def tick_phase
    return if any_frightened?
    _, dur = PHASE_TABLE[@phase_index]
    return if dur.nil?
    @phase_ticks += 1
    return if @phase_ticks < dur
    @phase_index += 1
    @phase_ticks = 0
    apply_phase_to_ghosts
  end

  def current_phase_mode
    PHASE_TABLE[@phase_index][0]
  end

  def apply_phase_to_ghosts
    mode = current_phase_mode
    @ghosts.each do |g|
      next if g.state == :frightened || g.state == :eaten
      next unless @released[g.identity]
      g.state = mode
      g.face(g.direction.opposite) unless g.direction.none?
    end
  end

  def tick_frightened
    return if @frightened_ticks <= 0
    @frightened_ticks -= 1
    return if @frightened_ticks > 0
    # Frightened expired: restore active ghosts to current phase mode.
    mode = current_phase_mode
    @ghosts.each do |g|
      if g.state == :frightened
        g.state = mode
        g.controller = GhostControllers.for(g.identity)
        g.speed = g.base_speed
      end
    end
    @eat_chain = 0
  end

  def tick_releases
    @ticks_since_release += 1
    Ghost::IDENTITIES.each do |id|
      next if @released[id]
      threshold = RELEASE_DOT_THRESHOLD[id]
      if @dot_count >= threshold || @ticks_since_release >= RELEASE_STALL_TICKS
        @released[id] = true
        @ticks_since_release = 0
        ghost = @ghosts.find { |g| g.identity == id }
        ghost.state = current_phase_mode if ghost && ghost.state != :frightened && ghost.state != :eaten
        break
      end
    end
  end

  def tick_player(world)
    intent = @player.controller.next_direction(world)
    @player.try_turn(intent, @maze, @projection)
    @player.advance(@maze, @projection)
    player_eat_pellets
  end

  def player_eat_pellets
    @projection.cells_touched(@player.rect).each do |gx, gy|
      kind = @pellets.at(gx, gy)
      next unless kind
      @pellets.eat(gx, gy)
      @dot_count += 1
      @ticks_since_release = 0
      @score += (kind == :power ? 50 : 10)
      trigger_frightened if kind == :power
    end
  end

  def trigger_frightened
    @frightened_ticks = FRIGHTENED_DURATION_TICKS
    @eat_chain = 0
    @ghosts.each do |g|
      next if g.state == :eaten
      next unless @released[g.identity]
      g.state = :frightened
      g.controller = GhostControllers::Frightened.new
      g.speed = GHOST_FRIGHTENED_SPEED
      g.face(g.direction.opposite) unless g.direction.none?
    end
  end

  def tick_ghosts(world)
    @ghosts.each do |g|
      next unless @released[g.identity]
      if g.state == :eaten && reached_spawn?(g)
        respawn_eaten(g)
      end
      intent = g.controller.next_direction(world, g)
      g.try_turn(intent, @maze, @projection) unless intent.none?
      g.advance(@maze, @projection)
    end
  end

  def reached_spawn?(ghost)
    return false unless ghost.at_cell_center?(@projection)
    ghost.grid_cell(@projection) == ghost.spawn_cell
  end

  def respawn_eaten(ghost)
    ghost.state = current_phase_mode
    ghost.controller = GhostControllers.for(ghost.identity)
    ghost.speed = ghost.base_speed
  end

  def tick_collisions
    @ghosts.each do |g|
      next unless rects_overlap?(@player.rect, g.rect)
      case g.state
      when :frightened
        eat_ghost(g)
      when :eaten
        # eyes — no interaction
      else
        player_dies
        return
      end
    end
  end

  def eat_ghost(ghost)
    @score += EAT_POINTS[[@eat_chain, EAT_POINTS.size - 1].min]
    @eat_chain += 1
    ghost.state = :eaten
    ghost.controller = GhostControllers::Eaten.new
    ghost.speed = ghost.base_speed
  end

  def player_dies
    spawn = @projection.cell_rect(*PLAYER_SPAWN)
    @player.x = spawn[:x]
    @player.y = spawn[:y]
    @player.face(Direction::RIGHT)

    spawns = ghost_spawn_cells
    @ghosts.each_with_index do |g, i|
      cell = spawns[i] || spawns.last
      rect = @projection.cell_rect(*cell)
      g.x = rect[:x]
      g.y = rect[:y]
      g.face(Direction::LEFT)
      g.state = :scatter
      g.controller = GhostControllers.for(g.identity)
      g.speed = g.base_speed
    end
    @released = { blinky: true, pinky: false, inky: false, clyde: false }
    @phase_index = 0
    @phase_ticks = 0
    @frightened_ticks = 0
    @eat_chain = 0
    @ticks_since_release = 0
  end

  def any_frightened?
    @frightened_ticks > 0
  end

  def rects_overlap?(a, b)
    a[:x] < b[:x] + b[:w] && a[:x] + a[:w] > b[:x] &&
      a[:y] < b[:y] + b[:h] && a[:y] + a[:h] > b[:y]
  end
end
