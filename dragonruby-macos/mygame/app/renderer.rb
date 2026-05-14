# app/renderer.rb
#
# Owns all drawing concerns. Game hands it the world objects + camera each tick;
# Renderer pushes primitives into DR's outputs.
#
# Coordinate model (ADR-0008): maze/pellets/actors/popup live in WORLD space and
# are mapped to SCREEN space by the Camera. Walls are baked once into the static
# `world_target` render target; everything dynamic is a camera-transformed
# primitive. HUD lives directly in SCREEN space, untouched by the camera.

class Renderer
  BACKGROUND      = [30, 30, 30].freeze
  WALL_COLOR      = { r: 255, g: 255, b: 255 }.freeze
  PELLET_COLOR_BY_KEY = {
    red:    { r: 255, g: 90,  b: 90  },
    green:  { r: 90,  g: 230, b: 120 },
    blue:   { r: 90,  g: 160, b: 255 },
    yellow: { r: 255, g: 225, b: 90  },
  }.freeze
  PELLET_COLOR_FALLBACK = { r: 255, g: 200, b: 150 }.freeze
  POWER_PELLET_COLOR = { r: 255, g: 255, b: 255 }.freeze
  POPUP_COLOR     = { r: 100, g: 220, b: 255 }.freeze
  CLIP_BACKGROUND = [0, 0, 0, 0].freeze

  # Pellet sizes as a fraction of the cell, so they never drift when CELL_SIZE
  # changes (ADR-0008). Preserves the original 4/20 and 16/20 ratios.
  PELLET_SIZE_RATIO       = 0.2
  POWER_PELLET_SIZE_RATIO = 0.8

  HUD_AMMO_ICON_SIZE = 24
  HUD_AMMO_ICON_GAP  = 4
  HUD_AMMO_ICON_MAX_VISIBLE = 5
  HUD_AMMO_PATH = "sprites/bullet.png"
  HUD_AMMO_PLUS_COLOR = { r: 255, g: 220, b: 110 }.freeze
  # Fixed screen-space anchor (bottom-left corner), unaffected by the camera.
  HUD_AMMO_MARGIN_X = 20
  HUD_AMMO_MARGIN_Y = 20

  def initialize(projection)
    @projection = projection
    @world_target_built = false
  end

  def draw(outputs, maze, pellets, player, ghosts = [], camera:, projectiles: [], popup: nil, level_complete: false)
    @camera = camera
    outputs.background_color = BACKGROUND
    draw_world(outputs, maze)
    draw_pellets(outputs, pellets)
    draw_actors(outputs, player, ghosts, projectiles)
    draw_hud_ammo(outputs, player) if player
    draw_popup(outputs, popup) if popup
    level_complete
  end

  # World point -> the 1-2 screen-space copies of a world-space primitive
  # (anything with :x/:y/:w). The second copy appears when the primitive
  # straddles the toroidal X seam. The single camera-transform choke point.
  def project(prim)
    _, sy = @camera.to_screen(prim[:x], prim[:y])
    @camera.screen_xs(prim[:x], prim[:w]).map { |sx| prim.merge(x: sx, y: sy) }
  end

  # Bake the static wall geometry into `world_target` once. Walls never change
  # within a level; on level reset Game re-news Renderer, resetting the flag.
  def ensure_world_target(outputs, maze)
    return if @world_target_built
    rt = outputs[:world_target]
    rt.w = @projection.playfield_w
    rt.h = @projection.playfield_h
    rt.background_color = CLIP_BACKGROUND
    rt.lines << maze.wall_segments(@projection).map { |seg| { **seg, **WALL_COLOR } }
    @world_target_built = true
  end

  # Blit the world_target at its camera-projected screen position, plus the
  # +/- world-width copies needed to cover the toroidal X seam. DR culls the
  # offscreen parts; Y is camera-clamped/centred so no vertical wrap.
  def draw_world(outputs, maze)
    ensure_world_target(outputs, maze)
    ww = @projection.playfield_w
    wh = @projection.playfield_h
    zoom = @camera.zoom
    ox, oy = @camera.to_screen(0, 0)
    [-1, 0, 1].each do |k|
      x = ox + k * ww * zoom
      next if x + ww * zoom <= 0 || x >= Camera::SCREEN_W
      outputs.sprites << {
        x: x, y: oy, w: ww * zoom, h: wh * zoom,
        path: :world_target
      }
    end
  end

  def draw_pellets(outputs, pellets)
    solids = []
    cell = @projection.cell_size
    pellet_size = (cell * PELLET_SIZE_RATIO).round
    power_size = (cell * POWER_PELLET_SIZE_RATIO).round
    pellets.each_with_color do |(gx, gy), kind, color|
      rect = @projection.cell_rect(gx, gy)
      size = kind == :power ? power_size : pellet_size
      pad = (cell - size) / 2
      rgb = if kind == :power
              POWER_PELLET_COLOR
            else
              PELLET_COLOR_BY_KEY[color] || PELLET_COLOR_FALLBACK
            end
      solids.concat(project(
        x: rect[:x] + pad, y: rect[:y] + pad,
        w: size, h: size, **rgb
      ))
    end
    outputs.solids << solids
  end

  # Player + ghosts + projectiles, each camera-transformed. Off-screen seam
  # copies simply fall outside the viewport — no clipping needed.
  def draw_actors(outputs, player, ghosts, projectiles = [])
    sprites = []
    sprites.concat(project(player.to_sprite)) if player
    ghosts.each { |g| sprites.concat(project(g.to_sprite)) }
    projectiles.each { |p| sprites.concat(project(p.to_sprite)) }
    outputs.sprites << sprites
  end

  def draw_hud_ammo(outputs, player)
    return unless player.respond_to?(:ammo)
    ammo = player.ammo
    visible = [ammo, HUD_AMMO_ICON_MAX_VISIBLE].min
    base_x = HUD_AMMO_MARGIN_X
    base_y = HUD_AMMO_MARGIN_Y

    sprites = []
    visible.times do |i|
      sprites << {
        x: base_x + i * (HUD_AMMO_ICON_SIZE + HUD_AMMO_ICON_GAP),
        y: base_y,
        w: HUD_AMMO_ICON_SIZE, h: HUD_AMMO_ICON_SIZE,
        path: HUD_AMMO_PATH
      }
    end
    outputs.sprites << sprites

    if ammo > HUD_AMMO_ICON_MAX_VISIBLE
      plus_x = base_x + visible * (HUD_AMMO_ICON_SIZE + HUD_AMMO_ICON_GAP)
      outputs.labels << {
        x: plus_x, y: base_y + HUD_AMMO_ICON_SIZE,
        text: "+", size_enum: 4,
        **HUD_AMMO_PLUS_COLOR
      }
    end
  end

  # Popup is world-anchored (spawned at a ghost centre) -> camera-transformed.
  def draw_popup(outputs, popup)
    project(x: popup[:x], y: popup[:y], w: 0).each do |p|
      outputs.labels << {
        x: p[:x], y: p[:y],
        text: popup[:text],
        size_enum: 4,
        alignment_enum: 1,
        vertical_alignment_enum: 1,
        **POPUP_COLOR,
        a: popup[:alpha] || 255
      }
    end
  end
end
