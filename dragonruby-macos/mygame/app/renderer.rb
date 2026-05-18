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
  BACKGROUND        = [30, 30, 30].freeze
  WALL_COLOR        = { r: 255, g: 255, b: 255 }.freeze
  POPUP_COLOR       = { r: 100, g: 220, b: 255 }.freeze
  TRACK_POPUP_COLOR = { r: 255, g: 225, b: 90 }.freeze
  CLIP_BACKGROUND   = [0, 0, 0, 0].freeze

  # Pellet sizes as a fraction of the cell, so they never drift when CELL_SIZE
  # changes (ADR-0008). Territory dots upsized from 0.2 so the per-territory
  # shape (UI3a) is legible; power pellets keep the original 16/20 ratio.
  PELLET_SIZE_RATIO  = 1.0
  POWER_PELLET_RATIO = 1.2

  # UI3a: distinct musical-accidental shape per territory (♭ ♯ ♮ 𝄪) as the
  # non-colour identity channel for ADR-0010. Frame order matches the sheet.
  PELLET_SPRITE_PATH  = 'sprites/dots.png'.freeze
  PELLET_SPRITE_TILE  = 48
  NORMAL_PELLET_FRAME = { red: 0, green: 1, blue: 2, yellow: 3 }.freeze
  POWER_PELLET_FRAME  = 4

  def initialize(projection)
    @projection = projection
    @world_target_built = false
  end

  def draw(outputs, maze, pellets, player, ghosts = [], camera:, projectiles: [], particles: nil,
           popup: nil, track_popups: [], hud: nil, state: :playing)
    @camera = camera
    outputs.background_color = BACKGROUND
    draw_world(outputs, maze)
    draw_pellets(outputs, pellets)
    draw_actors(outputs, player, ghosts, projectiles)
    draw_particles(outputs, particles) if particles # ADR-0018 (above actors, below HUD)
    draw_hud(outputs, hud) if hud && state != :game_over
    draw_popup(outputs, popup) if popup
    track_popups.each { |p| draw_popup(outputs, p, color: TRACK_POPUP_COLOR) }
    outputs.labels << Banner.build(state)[:labels]
    state
  end

  # Render-only confetti (ADR-0018). World-space, camera-transformed via the
  # same `project()` seam as actors (handles toroidal X seam + screen shake).
  def draw_particles(outputs, particles)
    solids = []
    particles.list.each do |p|
      half = p[:size] / 2.0
      alpha = (255.0 * p[:life] / p[:life_total]).to_i
      solids.concat(project(
                      x: p[:x] - half, y: p[:y] - half,
                      w: p[:size], h: p[:size],
                      r: p[:r], g: p[:g], b: p[:b], a: alpha
                    ))
    end
    outputs.solids << solids
  end

  # Hud + Banner modules own all screen-space overlay layout. Renderer just
  # pushes the returned primitives into DR's outputs.
  def draw_hud(outputs, hud)
    result = Hud.build(hud)
    outputs.solids  << result[:solids]
    outputs.sprites << result[:sprites]
    outputs.labels  << result[:labels]
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
    sprites = []
    cell = @projection.cell_size
    pellet_size = (cell * PELLET_SIZE_RATIO).round
    power_size = (cell * POWER_PELLET_RATIO).round
    pellets.each_with_color do |(gx, gy), kind, color|
      rect = @projection.cell_rect(gx, gy)
      if kind == :power
        pad = (cell - power_size) / 2
        sprites.concat(project(
                         x: rect[:x] + pad, y: rect[:y] + pad,
                         w: power_size, h: power_size,
                         path: PELLET_SPRITE_PATH,
                         tile_x: POWER_PELLET_FRAME * PELLET_SPRITE_TILE, tile_y: 0,
                         tile_w: PELLET_SPRITE_TILE, tile_h: PELLET_SPRITE_TILE
                       ))
      else
        pad = (cell - pellet_size) / 2
        frame = NORMAL_PELLET_FRAME[color] || 0
        sprites.concat(project(
                         x: rect[:x] + pad, y: rect[:y] + pad,
                         w: pellet_size, h: pellet_size,
                         path: PELLET_SPRITE_PATH,
                         tile_x: frame * PELLET_SPRITE_TILE, tile_y: 0,
                         tile_w: PELLET_SPRITE_TILE, tile_h: PELLET_SPRITE_TILE
                       ))
      end
    end
    outputs.sprites << sprites
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

  # Popup is world-anchored (spawned at a ghost centre) -> camera-transformed.
  def draw_popup(outputs, popup, color: POPUP_COLOR)
    project(x: popup[:x], y: popup[:y], w: 0).each do |p|
      outputs.labels << {
        x: p[:x], y: p[:y],
        text: popup[:text],
        size_enum: 4,
        alignment_enum: 1,
        vertical_alignment_enum: 1,
        **color,
        a: popup[:alpha] || 255
      }
    end
  end
end
