require 'app/hud.rb'

ZERO_COMPLETION = { red: 0.0, green: 0.0, blue: 0.0, yellow: 0.0 }.freeze
ALL_OFF         = { red: :off, green: :off, blue: :off, yellow: :off }.freeze
NONE_PACIFIED   = { red: false, green: false, blue: false, yellow: false }.freeze

def base_state(overrides = {})
  {
    score: 1234,
    lives: 3,
    ammo: 0,
    completion: ZERO_COMPLETION,
    meter_flash: {},
    enrage_step: ALL_OFF,
    pacified: NONE_PACIFIED,
    beat_phase: 0.5
  }.merge(overrides)
end

def icon_for(out, color)
  out[:sprites].find { |s| s[:path] == Hud::GAUGE_ICON_PATHS[color] }
end

def test_hud_build_returns_solids_sprites_labels args, assert
  out = Hud.build(base_state)
  assert.true! out.key?(:solids)
  assert.true! out.key?(:sprites)
  assert.true! out.key?(:labels)
end

def test_hud_score_label_centered_on_hud_centerline args, assert
  out = Hud.build(base_state(score: 4242))
  label = out[:labels].find { |l| l[:text].to_s.include?('4242') }
  assert.equal! label[:y], Hud::CENTER_Y
end

def test_hud_life_icons_bottom_aligned_on_centerline args, assert
  out = Hud.build(base_state(lives: 2))
  life = out[:sprites].find { |s| s[:path] == Player::PLAYER_SPRITE_PATH }
  assert.equal! life[:y], Hud::CENTER_Y - Hud::LIFE_ICON_H / 2
  assert.equal! life[:h], Hud::LIFE_ICON_H
end

def test_hud_renders_one_icon_per_ghost_identity args, assert
  out = Hud.build(base_state)
  Hud::METER_COLORS.each do |color|
    assert.true!(!icon_for(out, color).nil?, "missing icon for #{color}")
  end
end

def test_hud_pacified_icon_uses_pacify_alpha args, assert
  state = base_state(pacified: NONE_PACIFIED.merge(red: true))
  out = Hud.build(state)
  assert.equal! icon_for(out, :red)[:a], Hud::PACIFY_ALPHA
  # Untouched colors stay opaque.
  assert.equal! icon_for(out, :green)[:a], 255
end

def test_hud_enrage1_adds_red_tint_solid_over_icon args, assert
  state = base_state(enrage_step: ALL_OFF.merge(red: :enrage1))
  out = Hud.build(state)
  icon = icon_for(out, :red)
  tint = out[:solids].find { |s| s[:x] == icon[:x] && s[:y] == icon[:y] && s[:w] == Hud::GAUGE_ICON_SIZE }
  assert.equal! tint[:r], Hud::ENRAGE1_TINT[:r]
  assert.equal! tint[:a], Hud::ENRAGE1_TINT[:a]
end

def test_hud_enrage2_tint_pulses_with_beat_phase args, assert
  state = base_state(enrage_step: ALL_OFF.merge(red: :enrage2), beat_phase: 0.0)
  out_loud = Hud.build(state)
  out_quiet = Hud.build(state.merge(beat_phase: 1.0))
  icon = icon_for(out_loud, :red)
  loud = out_loud[:solids].find { |s| s[:x] == icon[:x] && s[:w] == Hud::GAUGE_ICON_SIZE && s[:r] == Hud::ENRAGE2_TINT[:r] }
  quiet = out_quiet[:solids].find { |s| s[:x] == icon[:x] && s[:w] == Hud::GAUGE_ICON_SIZE && s[:r] == Hud::ENRAGE2_TINT[:r] }
  assert.true! loud[:a] > quiet[:a]
end

def test_hud_pacified_skips_enrage_tint args, assert
  state = base_state(
    enrage_step: ALL_OFF.merge(red: :enrage2),
    pacified:    NONE_PACIFIED.merge(red: true)
  )
  out = Hud.build(state)
  icon = icon_for(out, :red)
  tint = out[:solids].find { |s| s[:x] == icon[:x] && s[:w] == Hud::GAUGE_ICON_SIZE && s[:r] == Hud::ENRAGE2_TINT[:r] }
  assert.nil! tint
end

def test_hud_meter_fill_width_matches_completion_ratio args, assert
  state = base_state(completion: ZERO_COMPLETION.merge(red: 0.5))
  out = Hud.build(state)
  # Find the red filled bar: width = METER_W * 0.5, color matches red pellet.
  red = Hud::PELLET_COLOR_BY_KEY[:red]
  fill = out[:solids].find { |s| s[:w] == (Hud::METER_W * 0.5).round && s[:r] == red[:r] }
  assert.true!(!fill.nil?, 'expected red half-fill bar')
  assert.equal! fill[:h], Hud::METER_H
end

def test_hud_meters_split_around_beat_pulse args, assert
  out = Hud.build(base_state)
  bar_y = Hud::CENTER_Y - Hud::METER_H / 2
  bars = out[:solids].select { |s| s[:y] == bar_y && s[:w] == Hud::METER_W }
  bar_xs = bars.map { |b| b[:x] }.sort
  # 4 background bars; 2 to the left of the pulse, 2 to the right.
  left  = bar_xs.select { |x| x + Hud::METER_W <= Hud::BEAT_X }
  right = bar_xs.select { |x| x >= Hud::BEAT_X }
  assert.equal! left.length, 2
  assert.equal! right.length, 2
end

def test_hud_ammo_renders_up_to_max_with_plus_overflow args, assert
  out_under = Hud.build(base_state(ammo: 3))
  bullets_under = out_under[:sprites].select { |s| s[:path] == Hud::AMMO_PATH }
  assert.equal! bullets_under.length, 3
  assert.true!(out_under[:labels].none? { |l| l[:text] == '+' })

  out_over = Hud.build(base_state(ammo: 9))
  bullets_over = out_over[:sprites].select { |s| s[:path] == Hud::AMMO_PATH }
  assert.equal! bullets_over.length, Hud::AMMO_ICON_MAX
  assert.true!(out_over[:labels].any? { |l| l[:text] == '+' })
end
