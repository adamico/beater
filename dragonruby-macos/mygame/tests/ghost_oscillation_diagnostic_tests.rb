require 'app/game.rb'

def build_world_for_oscillation(game)
  World.new(
    inputs: nil,
    maze: game.instance_variable_get(:@maze),
    projection: game.instance_variable_get(:@projection),
    player: game.instance_variable_get(:@player),
    pellets: game.instance_variable_get(:@pellets),
    ghosts: game.instance_variable_get(:@ghosts)
  )
end

def tick_ghost_system(game)
  game.tick_phase
  game.tick_releases
  game.tick_frightened
  game.tick_ghosts(build_world_for_oscillation(game))
end

def test_detect_two_tile_ghost_oscillation args, assert
  game = Game.new
  projection = game.instance_variable_get(:@projection)
  ghosts = game.instance_variable_get(:@ghosts)

  history = {}
  oscillation = nil
  stalls = {}

  1200.times do |tick|
    tick_ghost_system(game)

    ghosts.each do |g|
      next if g.state == :in_house || g.state == :frightened

      gx, gy = g.grid_cell(projection)
      key = g.object_id
      history[key] ||= []
      stalls[key] ||= 0

      prev = history[key].last
      history[key] << {
        tick: tick,
        state: g.state,
        dir: g.direction,
        cell: [gx, gy],
        pos: [g.x, g.y],
        err: g.cell_center_error(projection)
      }
      history[key] = history[key].last(12)

      if !prev.nil? &&
         (g.x - prev[:pos][0]).abs <= GhostControllers::DECISION_EPSILON &&
         (g.y - prev[:pos][1]).abs <= GhostControllers::DECISION_EPSILON
        stalls[key] += 1
      else
        stalls[key] = 0
      end

      if stalls[key] >= 8
        oscillation = { ghost: g, events: h = history[key].last(10), mode: :stalled }
        break
      end

      h = history[key]
      next unless h.length >= 8

      a = h[-8][:cell]
      b = h[-7][:cell]
      pattern = (
        h[-6][:cell] == a &&
        h[-5][:cell] == b &&
        h[-4][:cell] == a &&
        h[-3][:cell] == b &&
        h[-2][:cell] == a &&
        h[-1][:cell] == b
      )

      if pattern && a != b
        oscillation = { ghost: g, events: h.last(8), mode: :abab }
        break
      end
    end

    break if oscillation
  end

  if oscillation
    g = oscillation[:ghost]
    puts "=== Ghost Oscillation Detected ==="
    puts "mode=#{oscillation[:mode]} ghost=#{g.identity} final_state=#{g.state} final_dir=#{g.direction}"
    oscillation[:events].each do |e|
      puts "tick=#{e[:tick]} state=#{e[:state]} dir=#{e[:dir]} cell=#{e[:cell].inspect} pos=(#{e[:pos][0].round(3)},#{e[:pos][1].round(3)}) err=(#{e[:err][0].round(3)},#{e[:err][1].round(3)})"
    end
  else
    puts 'No 2-tile oscillation detected over 1200 ticks (non-frightened ghosts).'
  end

  assert.nil! oscillation, 'Detected non-frightened ghost oscillation between two tiles'
end