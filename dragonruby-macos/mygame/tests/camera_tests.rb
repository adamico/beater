require 'app/camera.rb'

# World big enough that Y clamps and X has room to wrap.
def fresh_camera
  Camera.new(world_w: 2880, world_h: 3264)
end

def test_to_screen_translates_centre args, assert
  cam = fresh_camera
  cam.follow(1440, 1632) # world centre
  sx, sy = cam.to_screen(1440, 1632)
  assert.equal! sx, 640.0
  assert.equal! sy, 360.0
end

def test_x_never_clamps args, assert
  cam = fresh_camera
  # Far past the right edge: player centre still maps to screen-centre X.
  cam.follow(10_000, 1632)
  sx, _ = cam.to_screen(10_000, 1632)
  assert.equal! sx, 640.0

  cam.follow(-5000, 1632)
  sx, _ = cam.to_screen(-5000, 1632)
  assert.equal! sx, 640.0
end

def test_y_clamps_low args, assert
  cam = fresh_camera
  cam.follow(1440, 0)
  assert.equal! cam.bottom, 0.0
end

def test_y_clamps_high args, assert
  cam = fresh_camera
  cam.follow(1440, 3264)
  assert.equal! cam.bottom, 3264 - 720.0
end

def test_screen_xs_seam args, assert
  cam = fresh_camera
  cam.follow(2870, 1632) # near the right seam
  # An object at world x just past the seam wrap point should draw twice.
  xs = cam.screen_xs(10, 96)
  assert.equal! xs.length, 2
  # An object dead-centre draws once.
  centre = cam.screen_xs(2870, 96)
  assert.equal! centre.length, 1
end

def test_view_rect_dimensions args, assert
  cam = fresh_camera
  cam.follow(1440, 1632)
  v = cam.view_rect
  assert.equal! v[:w], 1280.0
  assert.equal! v[:h], 720.0
  assert.equal! v[:x], 1440 - 640.0
end

def test_y_centres_when_world_shorter_than_screen args, assert
  cam = Camera.new(world_w: 480, world_h: 480)
  cam.follow(240, 100)
  assert.equal! cam.bottom, 240 - 360.0 # world_h/2 - view_h/2
end
