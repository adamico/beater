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

  # Dying-state eased return (ADR-0008 amendment): the camera leaves hard-lock
  # and eases from its current position to the reset player. Duration is
  # proportional to distance travelled, clamped to this frame range.
  DYING_EASE_PX_PER_FRAME = 14.0
  DYING_EASE_MIN_FRAMES   = 24.0
  DYING_EASE_MAX_FRAMES   = 90.0

  attr_reader :zoom, :dying_ease_duration

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
    @cy = clamp_cy(world_cy + @offset_y)
  end

  def clamp_cy(cy)
    return @world_h / 2.0 if @world_h <= view_h
    half_h = view_h / 2.0
    cy.clamp(half_h, @world_h - half_h)
  end

  # Begin the Dying-state eased return to `target_cx/target_cy` (the reset
  # player centre). Clears the look-ahead offset so the resumed hard-lock
  # picks up cleanly. X takes the short toroidal path; Y is clamped to bounds.
  def begin_dying_ease(target_cx, target_cy)
    @offset_x = 0.0
    @offset_y = 0.0
    @ease_from_x = @cx
    @ease_from_y = @cy

    dx = (target_cx % @world_w) - (@cx % @world_w)
    dx -= @world_w if dx > @world_w / 2.0
    dx += @world_w if dx < -@world_w / 2.0
    @ease_dx = dx
    @ease_dy = clamp_cy(target_cy) - @cy

    dist = Math.sqrt(@ease_dx * @ease_dx + @ease_dy * @ease_dy)
    @dying_ease_duration =
      (dist / DYING_EASE_PX_PER_FRAME).clamp(DYING_EASE_MIN_FRAMES, DYING_EASE_MAX_FRAMES)
    @ease_elapsed = 0.0
  end

  # Advance the dying ease one frame. Returns true once the ease has arrived.
  def tick_dying_ease
    @ease_elapsed += 1.0
    raw = (@ease_elapsed / @dying_ease_duration).clamp(0.0, 1.0)
    t = raw < 0.5 ? 2.0 * raw * raw : 1.0 - ((-2.0 * raw + 2.0)**2) / 2.0
    @cx = (@ease_from_x + @ease_dx * t) % @world_w
    @cy = @ease_from_y + @ease_dy * t
    raw >= 1.0
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
