# app/camera.rb
#
# Render-only world->screen transform (ADR-0008). Follows the player: X follows
# freely and the world wraps modulo world-width; Y clamps to maze bounds so the
# view never shows void above/below the maze. Never feeds back into physics.

class Camera
  SCREEN_W = 1280
  SCREEN_H = 720

  attr_reader :zoom

  def initialize(world_w:, world_h:, zoom: 1.0)
    @world_w = world_w
    @world_h = world_h
    @zoom = zoom
    @cx = world_w / 2.0
    @cy = world_h / 2.0
  end

  # Point the camera at a world-space centre. Called by Game after player
  # movement, before render.
  def follow(world_cx, world_cy)
    @cx = world_cx
    half_h = view_h / 2.0
    @cy = if @world_h <= view_h
            @world_h / 2.0
          else
            world_cy.clamp(half_h, @world_h - half_h)
          end
  end

  # World view origin (bottom-left corner) in world coords.
  def left
    @cx - view_w / 2.0
  end

  def bottom
    @cy - view_h / 2.0
  end

  def view_w
    SCREEN_W / @zoom
  end

  def view_h
    SCREEN_H / @zoom
  end

  # World point -> screen point. X is not seam-folded here; primitive callers
  # use #screen_xs, the world_target blit folds via #view_rect.
  def to_screen(wx, wy)
    [(wx - left) * @zoom, (wy - bottom) * @zoom]
  end

  # Screen x positions at which a world-space object of width `w_obj` should be
  # drawn: the base position plus, when it straddles the toroidal seam, the
  # +/- world-width copy that lands on screen. The seam choke point.
  def screen_xs(wx, w_obj)
    base = (wx - left) * @zoom
    xs = [base]
    xs << base - @world_w * @zoom if base + w_obj * @zoom > SCREEN_W
    xs << base + @world_w * @zoom if base < 0
    xs
  end

  # Camera sub-rect in world coords, for blitting the world_target.
  def view_rect
    { x: left, y: bottom, w: view_w, h: view_h }
  end
end
