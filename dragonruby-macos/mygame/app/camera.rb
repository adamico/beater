# app/camera.rb
#
# Render-only world->screen transform (ADR-0008). Follows the player: X follows
# freely and the world wraps modulo world-width; Y clamps to maze bounds so the
# view never shows void above/below the maze. Never feeds back into physics.
#
# Look-ahead (TG3): the camera leads the player in the travel direction so more
# of the maze ahead is visible. The lead is an eased 2D offset that decays to
# zero when the player is stopped.

class Camera
  SCREEN_W = 1280
  SCREEN_H = 720

  # How far ahead of the player the camera leads, in cells, per travel axis.
  # Kept per-axis (not a single viewport fraction) because the 16:9 viewport
  # already shows less vertically — leading the same cell count both ways
  # spends more of the budget on the scarce vertical dimension. Eased toward
  # each frame; decays to zero on Direction::NONE.
  LOOK_AHEAD_CELLS_X = 2.0
  LOOK_AHEAD_CELLS_Y = 4.0
  LOOK_AHEAD_EASE = 0.03

  attr_reader :zoom

  def initialize(world_w:, world_h:, cell_size:, zoom: 1.0)
    @world_w = world_w
    @world_h = world_h
    @cell_size = cell_size
    @zoom = zoom
    @cx = world_w / 2.0
    @cy = world_h / 2.0
    @offset_x = 0.0
    @offset_y = 0.0
  end

  # Point the camera at the player. Called by Game after player movement,
  # before render. `direction` is a Direction (dx/dy in -1..1); the camera
  # eases a look-ahead offset toward `direction * lead-cells * cell-size`,
  # then centres on player + offset. Y-clamp is applied last so look-ahead
  # near the maze top/bottom is simply clamped away.
  def follow(world_cx, world_cy, direction)
    target_x = direction.dx * LOOK_AHEAD_CELLS_X * @cell_size
    target_y = direction.dy * LOOK_AHEAD_CELLS_Y * @cell_size
    @offset_x += (target_x - @offset_x) * LOOK_AHEAD_EASE
    @offset_y += (target_y - @offset_y) * LOOK_AHEAD_EASE

    @cx = world_cx + @offset_x
    cy = world_cy + @offset_y
    half_h = view_h / 2.0
    @cy = if @world_h <= view_h
            @world_h / 2.0
          else
            cy.clamp(half_h, @world_h - half_h)
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
