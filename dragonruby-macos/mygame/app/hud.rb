# app/hud.rb
#
# Screen-space HUD. Pure-function build: takes a state hash, returns
# { solids:, sprites:, labels: } primitive arrays. Renderer is the only
# caller; Game owns the state shape. No DragonRuby outputs are touched here,
# which is the whole point — keeps the layout + state-mapping logic
# directly assertable in specs.

module Hud
  SCREEN_W = Camera::SCREEN_W

  # All HUD rows share a single centerline (score, enrage gauge bars, ghost
  # icons, life icons). Each element computes its own y as CENTER_Y - h/2.
  CENTER_Y = 684

  TEXT_COLOR = { r: 255, g: 255, b: 255 }.freeze

  # Ammo row — anchored bottom-left, not on the centerline.
  AMMO_ICON_SIZE  = 32
  AMMO_ICON_GAP   = 4
  AMMO_ICON_MAX   = 5
  AMMO_PATH       = 'sprites/bullet.png'
  AMMO_PLUS_COLOR = { r: 255, g: 220, b: 110 }.freeze
  AMMO_MARGIN_X   = 20
  AMMO_MARGIN_Y   = 20

  # Lives — row of player-sprite icons, top-right.
  LIFE_ICON_W = 48
  LIFE_ICON_H = 48
  LIFE_GAP    = 6

  # Enrage gauges — 4 colored meters split 2-left / beat pulse / 2-right.
  METER_W       = 110
  METER_H       = 12
  METER_GAP     = 12
  METER_BG      = { r: 55, g: 55, b: 55 }.freeze
  METER_COLORS  = %i[red green blue yellow].freeze
  METER_FLASH_COLOR = { r: 255, g: 255, b: 255 }.freeze
  METER_FLASH_TICKS = 24
  PELLET_COLOR_BY_KEY = {
    red: { r: 255, g: 90, b: 90 },
    green: { r: 90, g: 230, b: 120 },
    blue: { r: 90, g: 160, b: 255 },
    yellow: { r: 255, g: 225, b: 90 }
  }.freeze

  GAUGE_ICON_SIZE = 32
  GAUGE_ICON_GAP  = 6
  GAUGE_ICON_PATHS = {
    red: 'sprites/bass_blinky_icon.png',
    green: 'sprites/drums_pinky_icon.png',
    blue: 'sprites/chords_clyde_icon.png',
    yellow: 'sprites/lead_inky_icon.png'
  }.freeze
  ENRAGE1_TINT    = { r: 255, g: 80, b: 80, a: 60  }.freeze
  ENRAGE2_TINT    = { r: 255, g: 30, b: 30, a: 120 }.freeze
  ENRAGE2_PULSE_A = 30
  PACIFY_ALPHA    = 60

  # Beat pulse — square that pops bright+large on the downbeat.
  BEAT_X         = SCREEN_W / 2
  BEAT_Y         = CENTER_Y
  BEAT_R_MIN     = 8
  BEAT_R_MAX     = 24
  BEAT_SIDE_GAP  = 60
  BEAT_COLOR     = { r: 255, g: 230, b: 100 }.freeze
  BEAT_ALPHA_MIN = 80
  BEAT_ALPHA_MAX = 255

  # state keys: :score, :lives, :ammo, :completion, :meter_flash,
  #             :enrage_step, :pacified, :beat_phase
  def self.build(state)
    out = { solids: [], sprites: [], labels: [] }
    build_ammo(out, state[:ammo])
    build_score(out, state[:score])
    build_lives(out, state[:lives])
    build_meters(out, state[:completion], state[:meter_flash],
                 state[:enrage_step], state[:pacified], state[:beat_phase])
    build_beat_pulse(out, state[:beat_phase]) if state[:beat_phase]
    out
  end

  def self.build_score(out, score)
    out[:labels] << {
      x: AMMO_MARGIN_X, y: CENTER_Y,
      text: "SCORE #{score}", size_enum: 4, **TEXT_COLOR,
      alignment_enum: 0, vertical_alignment_enum: 1
    }
  end

  def self.build_lives(out, lives)
    return unless lives

    lives.times do |i|
      out[:sprites] << {
        x: SCREEN_W - AMMO_MARGIN_X - (i + 1) * (LIFE_ICON_W + LIFE_GAP),
        y: CENTER_Y - LIFE_ICON_H / 2,
        w: LIFE_ICON_W, h: LIFE_ICON_H,
        path: Player::PLAYER_SPRITE_PATH,
        tile_x: Player::WALK_FRAME_START * Player::PLAYER_SPRITE_WIDTH, tile_y: 0,
        tile_w: Player::PLAYER_SPRITE_WIDTH, tile_h: Player::PLAYER_SPRITE_HEIGHT
      }
    end
  end

  def self.build_ammo(out, ammo)
    return unless ammo

    visible = [ammo, AMMO_ICON_MAX].min
    visible.times do |i|
      out[:sprites] << {
        x: AMMO_MARGIN_X + i * (AMMO_ICON_SIZE + AMMO_ICON_GAP),
        y: AMMO_MARGIN_Y,
        w: AMMO_ICON_SIZE, h: AMMO_ICON_SIZE,
        path: AMMO_PATH
      }
    end
    return unless ammo > AMMO_ICON_MAX

    plus_x = AMMO_MARGIN_X + visible * (AMMO_ICON_SIZE + AMMO_ICON_GAP)
    out[:labels] << {
      x: plus_x, y: AMMO_MARGIN_Y + AMMO_ICON_SIZE,
      text: '+', size_enum: 4, **AMMO_PLUS_COLOR
    }
  end

  def self.build_meters(out, completion, meter_flash, enrage_step, pacified, beat_phase)
    return unless completion

    meter_flash ||= {}
    enrage_step ||= {}
    pacified    ||= {}
    slot_w = GAUGE_ICON_SIZE + GAUGE_ICON_GAP + METER_W
    half_w = 2 * slot_w + METER_GAP
    left_start  = BEAT_X - BEAT_SIDE_GAP - half_w
    right_start = BEAT_X + BEAT_SIDE_GAP
    bar_y = CENTER_Y - METER_H / 2

    METER_COLORS.each_with_index do |color, i|
      half_start = i < 2 ? left_start : right_start
      slot_x = half_start + (i % 2) * (slot_w + METER_GAP)
      icon_x = slot_x
      bar_x  = slot_x + GAUGE_ICON_SIZE + GAUGE_ICON_GAP
      ratio  = (completion[color] || 0.0).clamp(0.0, 1.0)

      out[:solids] << { x: bar_x, y: bar_y, w: METER_W, h: METER_H, **METER_BG }
      out[:solids] << {
        x: bar_x, y: bar_y, w: (METER_W * ratio).round, h: METER_H,
        **PELLET_COLOR_BY_KEY[color]
      }
      flash = meter_flash[color].to_i
      if flash > 0
        out[:solids] << {
          x: bar_x, y: bar_y, w: METER_W, h: METER_H,
          **METER_FLASH_COLOR,
          a: (flash.to_f / METER_FLASH_TICKS * 255).to_i
        }
      end

      build_gauge_icon(out, color, icon_x, enrage_step[color], pacified[color], beat_phase)
    end
  end

  def self.build_gauge_icon(out, color, x, step, is_pacified, beat_phase)
    path = GAUGE_ICON_PATHS[color]
    return unless path

    y = CENTER_Y - GAUGE_ICON_SIZE / 2
    out[:sprites] << {
      x: x, y: y, w: GAUGE_ICON_SIZE, h: GAUGE_ICON_SIZE,
      path: path, a: is_pacified ? PACIFY_ALPHA : 255
    }
    return if is_pacified

    case step
    when :enrage1
      out[:solids] << {
        x: x, y: y, w: GAUGE_ICON_SIZE, h: GAUGE_ICON_SIZE, **ENRAGE1_TINT
      }
    when :enrage2
      pulse = beat_phase ? ((1.0 - beat_phase.clamp(0.0, 1.0)) * ENRAGE2_PULSE_A).to_i : 0
      out[:solids] << {
        x: x, y: y, w: GAUGE_ICON_SIZE, h: GAUGE_ICON_SIZE,
        r: ENRAGE2_TINT[:r], g: ENRAGE2_TINT[:g], b: ENRAGE2_TINT[:b],
        a: ENRAGE2_TINT[:a] + pulse
      }
    end
  end

  def self.build_beat_pulse(out, phase)
    intensity = 1.0 - phase.clamp(0.0, 1.0)
    r = BEAT_R_MIN + (BEAT_R_MAX - BEAT_R_MIN) * intensity
    alpha = (BEAT_ALPHA_MIN + (BEAT_ALPHA_MAX - BEAT_ALPHA_MIN) * intensity).to_i
    out[:solids] << {
      x: BEAT_X - r, y: BEAT_Y - r, w: 2 * r, h: 2 * r,
      **BEAT_COLOR, a: alpha
    }
  end
end
