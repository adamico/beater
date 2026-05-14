require 'app/camera.rb'
require 'app/direction.rb'

# World big enough that Y clamps and X has room to wrap. 60x68 cells of 48px.
def fresh_camera
  Camera.new(world_w: 2880, world_h: 3264, cell_size: 48)
end

# Drive `follow` enough times for the eased look-ahead offset to converge to
# within sub-pixel of its target (LOOK_AHEAD_EASE is small).
def settle(cam, cx, cy, direction)
  400.times { cam.follow(cx, cy, direction) }
end

def test_to_screen_translates_centre args, assert
  cam = fresh_camera
  cam.follow(1440, 1632, Direction::NONE) # world centre, no lead
  sx, sy = cam.to_screen(1440, 1632)
  assert.equal! sx, 640.0
  assert.equal! sy, 360.0
end

def test_x_never_clamps args, assert
  cam = fresh_camera
  # Far past the right edge: player centre still maps to screen-centre X.
  cam.follow(10_000, 1632, Direction::NONE)
  sx, _ = cam.to_screen(10_000, 1632)
  assert.equal! sx, 640.0

  cam.follow(-5000, 1632, Direction::NONE)
  sx, _ = cam.to_screen(-5000, 1632)
  assert.equal! sx, 640.0
end

def test_y_clamps_low args, assert
  cam = fresh_camera
  cam.follow(1440, 0, Direction::NONE)
  assert.equal! cam.bottom, 0.0
end

def test_y_clamps_high args, assert
  cam = fresh_camera
  cam.follow(1440, 3264, Direction::NONE)
  assert.equal! cam.bottom, 3264 - 720.0
end

def test_screen_xs_seam args, assert
  cam = fresh_camera
  cam.follow(2870, 1632, Direction::NONE) # near the right seam
  # An object at world x just past the seam wrap point should draw twice.
  xs = cam.screen_xs(10, 96)
  assert.equal! xs.length, 2
  # An object dead-centre draws once.
  centre = cam.screen_xs(2870, 96)
  assert.equal! centre.length, 1
end

def test_view_rect_dimensions args, assert
  cam = fresh_camera
  cam.follow(1440, 1632, Direction::NONE)
  v = cam.view_rect
  assert.equal! v[:w], 1280.0
  assert.equal! v[:h], 720.0
  assert.equal! v[:x], 1440 - 640.0
end

def test_y_centres_when_world_shorter_than_screen args, assert
  cam = Camera.new(world_w: 480, world_h: 480, cell_size: 48)
  cam.follow(240, 100, Direction::NONE)
  assert.equal! cam.bottom, 240 - 360.0 # world_h/2 - view_h/2
end

def test_look_ahead_leads_travel_direction args, assert
  cam = fresh_camera
  # One frame moving RIGHT: camera has eased a little ahead, so the player
  # sits left of screen centre.
  cam.follow(1440, 1632, Direction::RIGHT)
  sx, _ = cam.to_screen(1440, 1632)
  assert.true! sx < 640.0
end

def test_look_ahead_converges_to_lead_cells args, assert
  cam = fresh_camera
  settle(cam, 1440, 1632, Direction::RIGHT)
  sx, _ = cam.to_screen(1440, 1632)
  # Lead converges to LOOK_AHEAD_CELLS_X (3) * cell_size (48) = 144px.
  assert.equal! sx.round, (640 - 144)
end

def test_look_ahead_decays_to_zero_when_stopped args, assert
  cam = fresh_camera
  settle(cam, 1440, 1632, Direction::RIGHT) # build up a lead
  settle(cam, 1440, 1632, Direction::NONE)  # then stop
  sx, _ = cam.to_screen(1440, 1632)
  assert.equal! sx.round, 640
end

def test_look_ahead_y_still_clamps args, assert
  cam = fresh_camera
  # Moving DOWN at the maze bottom: look-ahead would push the view below the
  # maze, but the Y-clamp wins.
  settle(cam, 1440, 0, Direction::DOWN)
  assert.equal! cam.bottom, 0.0
end
