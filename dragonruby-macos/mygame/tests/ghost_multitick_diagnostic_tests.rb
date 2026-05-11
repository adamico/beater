require 'app/game.rb'

def test_ghost_multiple_ticks_with_turns args, assert
  game = Game.new
  projection = game.instance_variable_get(:@projection)
  maze = game.instance_variable_get(:@maze)
  ghosts = game.instance_variable_get(:@ghosts)
  world = World.new(
    inputs: nil,
    maze: maze,
    projection: projection,
    player: game.instance_variable_get(:@player),
    pellets: game.instance_variable_get(:@pellets),
    ghosts: ghosts
  )
  
  ghost = ghosts.first
  
  puts "=== Multi-Tick Ghost Trace ==="
  puts "Starting: #{ghost.identity} at (#{ghost.x}, #{ghost.y}), dir=#{ghost.direction}"
  
  10.times do |tick|
    old_x, old_y = ghost.x, ghost.y
    
    # Replicate tick_ghosts step-by-step
    game.handle_ghost_state_transitions(ghost)
    return unless ghost.controller
    
    # Pre-turn state
    cs = projection.cell_size.to_f
    dx_err, dy_err = ghost.cell_center_error(projection)
    speed_tol = ghost.speed.to_f + 0.0001
    at_decision = ghost.at_cell_center?(projection, tolerance: speed_tol)
    
    puts "\nTick #{tick}:"
    puts "  Pos: (#{ghost.x.round(2)}, #{ghost.y.round(2)})"
    puts "  Center err: dx=#{dx_err.round(4)}, dy=#{dy_err.round(4)}"
    puts "  At decision? #{at_decision}"
    
    # Get intent
    intent = ghost.controller.next_direction(world, ghost)
    puts "  Intent: #{intent}"
    
    # Try turn
    turn_ok = ghost.try_turn(intent, maze, projection)
    puts "  Try turn result: #{turn_ok}, new dir=#{ghost.direction}"
    puts "  Pos after turn: (#{ghost.x.round(2)}, #{ghost.y.round(2)})"
    
    # Advance
    ghost.advance(maze, projection)
    dist = ((ghost.x - old_x)**2 + (ghost.y - old_y)**2)**0.5
    puts "  Pos after advance: (#{ghost.x.round(2)}, #{ghost.y.round(2)})"
    puts "  Distance moved: #{dist.round(4)}"
    
    if dist < 0.001
      puts "  *** STUCK! No movement this tick ***"
      break
    end
  end
end
