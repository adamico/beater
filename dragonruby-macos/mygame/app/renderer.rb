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
    red: { r: 255, g: 90, b: 90 },
    green: { r: 90, g: 230, b: 120 },
    blue: { r: 90, g: 160, b: 255 },
    yellow: { r: 255, g: 225, b: 90 }
  }.freeze
  PELLET_COLOR_FALLBACK = { r: 255, g: 200, b: 150 }.freeze
  POPUP_COLOR = { r: 100, g: 220, b: 255 }.freeze
  # G1: track-completion popup + meter-flash tint.
  TRACK_POPUP_COLOR = { r: 255, g: 225, b: 90 }.freeze
  METER_FLASH_COLOR = { r: 255, g: 255, b: 255 }.freeze
  METER_FLASH_TICKS = 24
  CLIP_BACKGROUND = [0, 0, 0, 0].freeze

  # Pellet sizes as a fraction of the cell, so they never drift when CELL_SIZE
  # changes (ADR-0008). Territory dots upsized from 0.2 so the per-territory
  # shape (UI3a) is legible; power pellets keep the original 16/20 ratio.
  PELLET_SIZE_RATIO       = 1.0
  POWER_PELLET_SIZE_RATIO = 1.2

  # UI3a: distinct musical-accidental shape per territory (♭ ♯ ♮ 𝄪) as the
  # non-colour identity channel for ADR-0010. Frame order matches the sheet.
  PELLET_SPRITE_PATH  = 'sprites/dots.png'.freeze
  PELLET_SPRITE_TILE  = 48
  PELLET_SPRITE_FRAME = { red: 0, green: 1, blue: 2, yellow: 3 }.freeze
  POWER_PELLET_SPRITE_FRAME = 4

  HUD_AMMO_ICON_SIZE = 32
  HUD_AMMO_ICON_GAP  = 4
  HUD_AMMO_ICON_MAX_VISIBLE = 5
  HUD_AMMO_PATH = 'sprites/bullet.png'
  HUD_AMMO_PLUS_COLOR = { r: 255, g: 220, b: 110 }.freeze
  # Fixed screen-space anchor (bottom-left corner), unaffected by the camera.
  HUD_AMMO_MARGIN_X = 20
  HUD_AMMO_MARGIN_Y = 20

  HUD_TEXT_COLOR   = { r: 255, g: 255, b: 255 }.freeze
  HUD_DIM_COLOR    = { r: 200, g: 200, b: 200 }.freeze
  # Lives: row of small player-sprite icons, top-right.
  HUD_LIFE_ICON_W  = 32
  HUD_LIFE_ICON_H  = 48
  HUD_LIFE_GAP     = 6
  HUD_LIFE_Y       = 660
  # Track completion: 4 colored meters across the top centre.
  HUD_METER_W      = 110
  HUD_METER_H      = 12
  HUD_METER_GAP    = 12
  HUD_METER_Y      = 698
  HUD_METER_BG     = { r: 55, g: 55, b: 55 }.freeze
  HUD_METER_COLORS = %i[red green blue yellow].freeze

  def initialize(projection)
    @projection = projection
    @world_target_built = false
  end

  def draw(outputs, maze, pellets, player, ghosts = [], camera:, projectiles: [], popup: nil, track_popups: [],
           hud: nil, state: :playing)
    @camera = camera
    outputs.background_color = BACKGROUND
    draw_world(outputs, maze)
    draw_pellets(outputs, pellets)
    draw_actors(outputs, player, ghosts, projectiles)
    draw_hud(outputs, player, hud) if hud && state != :game_over
    draw_popup(outputs, popup) if popup
    track_popups.each { |p| draw_popup(outputs, p, color: TRACK_POPUP_COLOR) }
    draw_state_banner(outputs, state)
    state
  end

  # Screen-space HUD: ammo row, score, life icons, 4 track-completion meters.
  def draw_hud(outputs, player, hud)
    draw_hud_ammo(outputs, player) if player
    outputs.labels << {
      x: HUD_AMMO_MARGIN_X, y: 706,
      text: "SCORE #{hud[:score]}", size_enum: 4, **HUD_TEXT_COLOR
    }
    draw_hud_lives(outputs, hud[:lives])
    draw_hud_meters(outputs, hud[:completion], hud[:meter_flash])
  end

  def draw_hud_lives(outputs, lives)
    return unless lives

    sprites = []
    lives.times do |i|
      sprites << {
        x: Camera::SCREEN_W - HUD_AMMO_MARGIN_X - (i + 1) * (HUD_LIFE_ICON_W + HUD_LIFE_GAP),
        y: HUD_LIFE_Y, w: HUD_LIFE_ICON_W, h: HUD_LIFE_ICON_H,
        path: Player::PLAYER_SPRITE_PATH,
        tile_x: Player::WALK_FRAME_START * Player::PLAYER_SPRITE_WIDTH, tile_y: 0,
        tile_w: Player::PLAYER_SPRITE_WIDTH, tile_h: Player::PLAYER_SPRITE_HEIGHT
      }
    end
    outputs.sprites << sprites
  end

  def draw_hud_meters(outputs, completion, meter_flash = nil)
    return unless completion

    meter_flash ||= {}
    total_w = HUD_METER_COLORS.size * HUD_METER_W +
              (HUD_METER_COLORS.size - 1) * HUD_METER_GAP
    start_x = (Camera::SCREEN_W - total_w) / 2
    solids = []
    HUD_METER_COLORS.each_with_index do |color, i|
      x = start_x + i * (HUD_METER_W + HUD_METER_GAP)
      ratio = (completion[color] || 0.0).clamp(0.0, 1.0)
      solids << { x: x, y: HUD_METER_Y, w: HUD_METER_W, h: HUD_METER_H, **HUD_METER_BG }
      solids << {
        x: x, y: HUD_METER_Y, w: (HUD_METER_W * ratio).round, h: HUD_METER_H,
        **(PELLET_COLOR_BY_KEY[color] || PELLET_COLOR_FALLBACK)
      }
      # G1: white overlay over the full bar, fading out over the flash window.
      flash = meter_flash[color].to_i
      next if flash <= 0

      solids << {
        x: x, y: HUD_METER_Y, w: HUD_METER_W, h: HUD_METER_H,
        **METER_FLASH_COLOR,
        a: (flash.to_f / METER_FLASH_TICKS * 255).to_i
      }
    end
    outputs.solids << solids
  end

  # Centred banner for the non-playing states.
  def draw_state_banner(outputs, state)
    text = case state
           when :ready          then 'READY?'
           when :level_complete then 'LEVEL COMPLETE'
           when :game_over      then 'GAME OVER'
           end
    return unless text

    cx = Camera::SCREEN_W / 2
    cy = Camera::SCREEN_H / 2
    outputs.labels << {
      x: cx, y: cy + 24, text: text, size_enum: 12,
      alignment_enum: 1, vertical_alignment_enum: 1, **HUD_TEXT_COLOR
    }
    return if state == :ready

    outputs.labels << {
      x: cx, y: cy - 28, text: 'press any key', size_enum: 2,
      alignment_enum: 1, vertical_alignment_enum: 1, **HUD_DIM_COLOR
    }
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
    power_size = (cell * POWER_PELLET_SIZE_RATIO).round
    pellets.each_with_color do |(gx, gy), kind, color|
      rect = @projection.cell_rect(gx, gy)
      if kind == :power
        pad = (cell - power_size) / 2
        sprites.concat(project(
                         x: rect[:x] + pad, y: rect[:y] + pad,
                         w: power_size, h: power_size,
                         path: PELLET_SPRITE_PATH,
                         tile_x: POWER_PELLET_SPRITE_FRAME * PELLET_SPRITE_TILE, tile_y: 0,
                         tile_w: PELLET_SPRITE_TILE, tile_h: PELLET_SPRITE_TILE
                       ))
      else
        pad = (cell - pellet_size) / 2
        frame = PELLET_SPRITE_FRAME[color] || 0
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

    return unless ammo > HUD_AMMO_ICON_MAX_VISIBLE

    plus_x = base_x + visible * (HUD_AMMO_ICON_SIZE + HUD_AMMO_ICON_GAP)
    outputs.labels << {
      x: plus_x, y: base_y + HUD_AMMO_ICON_SIZE,
      text: '+', size_enum: 4,
      **HUD_AMMO_PLUS_COLOR
    }
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
