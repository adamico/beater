require 'app/game.rb'

def test_ghost_spawn_and_first_tick args, assert
  game = Game.new
  projection = game.instance_variable_get(:@projection)
  maze = game.instance_variable_get(:@maze)
  ghosts = game.instance_variable_get(:@ghosts)
  
  ghost = ghosts.first
  
  # Log spawn state
  puts "=== Ghost Spawn Diagnostic ==="
  puts "Ghost: #{ghost.identity}"
  puts "Spawn pos: (#{ghost.x}, #{ghost.y})"
  puts "Direction: #{ghost.direction}"
  puts "Speed: #{ghost.speed}"
  puts "State: #{ghost.state}"
  
  # Check if at spawn cell center
  cs = projection.cell_size.to_f
  dx_err, dy_err = ghost.cell_center_error(projection)
  puts "Cell center error: dx=#{dx_err.round(4)}, dy=#{dy_err.round(4)}"
  puts "at_cell_center?(eps)? #{ghost.at_cell_center?(projection)}"
  
  # Check decision point (speed-based tolerance)
  speed_tol = ghost.speed.to_f
  at_decision = ghost.at_cell_center?(projection, tolerance: speed_tol + 0.0001)
  puts "at_decision_point?(speed)? #{at_decision}"
  puts "Decision tolerance: #{speed_tol + 0.0001}"
  
  # Get controller next direction
  world = World.new(
    inputs: nil,
    maze: maze,
    projection: projection,
    player: game.instance_variable_get(:@player),
    pellets: game.instance_variable_get(:@pellets),
    ghosts: ghosts
  )
  intent = ghost.controller.next_direction(world, ghost)
  puts "Controller intent: #{intent}"
  
  # Try turn
  gx, gy = ghost.grid_cell(projection)
  puts "Grid cell: (#{gx}, #{gy})"
  
  can_turn_probed = { x: ghost.x + intent.dx, y: ghost.y + intent.dy, w: ghost.w, h: ghost.h }
  cells_probed = projection.cells_touched(can_turn_probed)
  cells_walkable = cells_probed.all? { |(cx, cy)| maze.walkable?(cx, cy, role: ghost.role) }
  puts "Probe cells for turn: #{cells_probed.inspect}, all walkable? #{cells_walkable}"
  
  turn_ok = ghost.try_turn(intent, maze, projection)
  puts "try_turn result: #{turn_ok}"
  puts "Direction after turn: #{ghost.direction}"
  
  # Now advance
  old_x, old_y = ghost.x, ghost.y
  ghost.advance(maze, projection)
  puts "Position before advance: (#{old_x}, #{old_y})"
  puts "Position after advance: (#{ghost.x}, #{ghost.y})"
  puts "Distance moved: #{((ghost.x - old_x)**2 + (ghost.y - old_y)**2)**0.5}"
  
  assert.true! turn_ok, "First turn should succeed from spawn"
  assert.not_equal! [ghost.x, ghost.y], [old_x, old_y], "Ghost should move after first tick"
end
