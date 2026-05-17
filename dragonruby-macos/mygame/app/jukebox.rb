module Jukebox
  VERSION = 1 # bump to force re-init on hot reload

  TRACKS = %i[drums bass lead chords].freeze
  NAMES  = { drums: 'DRUMS', bass: 'BASS', lead: 'LEAD', chords: 'CHORDS' }.freeze

  SCREEN_W = 1280
  SCREEN_H = 720

  STRIP_COUNT = 4
  STRIP_W     = 180
  STRIP_GAP   = 24
  STRIP_Y     = 80
  STRIP_H     = 540
  STRIP_X0    = (SCREEN_W - (STRIP_COUNT * STRIP_W + (STRIP_COUNT - 1) * STRIP_GAP)) / 2

  FADER_W       = 20
  FADER_H       = 300
  FADER_Y       = STRIP_Y + 110
  FADER_THUMB_H = 28

  METER_SEGS    = 16
  METER_SEG_H   = 10
  METER_SEG_GAP = 2
  METER_W       = 14

  WHEEL_STEP = 0.05

  SFX_PANEL_X     = 1060
  SFX_PANEL_Y_TOP = 620
  SFX_PANEL_W     = 200
  SFX_ROW_H       = 30
  SFX_ROW_GAP     = 4

  COL = {
    bg: { r: 14, g: 14, b: 18, a: 255 },
    panel: { r: 22, g: 22, b: 28, a: 255 },
    rail: { r: 35, g: 35, b: 42, a: 255 },
    rail_active: { r: 55, g: 55, b:  65, a: 255 },
    thumb: { r: 210, g: 210, b: 220, a: 255 },
    thumb_hot: { r: 255, g: 255, b: 255, a: 255 },
    led_off: { r: 30, g: 25, b: 10, a: 255 },
    led_green: { r: 60, g: 220, b:  80, a: 255 },
    led_amber: { r: 230, g: 160, b:  20, a: 255 },
    led_red: { r: 220, g: 50, b: 40, a: 255 },
    label: { r: 160, g: 155, b: 145, a: 255 },
    label_bright: { r: 220, g: 215, b: 200, a: 255 },
    accent: { r: 230, g: 160, b: 20, a: 255 },
    solo_idle: { r: 50, g: 48, b: 42, a: 255 },
    btn_idle: { r: 40, g: 40, b: 48, a: 255 },
    btn_hot: { r: 60, g: 58, b: 70, a: 255 },
    separator: { r: 45, g: 44, b: 52, a: 255 }
  }.freeze

  # ---------------------------------------------------------------------------
  # Entry
  # ---------------------------------------------------------------------------

  def self.tick(args)
    init(args) if args.state.jukebox.nil? || args.state.jukebox[:version] != VERSION
    handle_input(args)
    handle_sfx_panel(args)
    handle_exit(args)
    update_audio(args)
    render(args)
  end

  def self.init(args)
    Audio::NativeBridge.load_stems(stem_definitions) if Audio::NativeBridge.backend_mode == :native
    backend = Audio::NativeBridge.backend_mode

    players = TRACKS.each_with_object({}) do |t, h|
      h[t] = Audio::TrackPlayer.new(t, stem_definitions[t], args, backend: backend)
    end

    args.state.jukebox = {
      version: VERSION,
      players: players,
      gain: TRACKS.each_with_object({}) { |t, h| h[t] = 1.0 },
      muted: TRACKS.each_with_object({}) { |t, h| h[t] = false },
      solo_set: [],
      dragging: nil,
      drag_start: nil,
      meter: TRACKS.each_with_object({}) { |t, h| h[t] = 0.0 },
      msg: nil,
      msg_ttl: 0,
      btn_hot: nil
    }

    post_message(args, 'JUKEBOX READY')
  end

  def self.stem_definitions
    @stem_definitions ||= Audio::TrackLibrary.build_all
  end

  def self.handle_exit(args)
    kb = args.inputs.keyboard.key_down
    return unless kb.escape || kb.q

    SceneDirector.request(:title)
  end

  # ---------------------------------------------------------------------------
  # Input
  # ---------------------------------------------------------------------------

  def self.handle_input(args)
    st    = args.state.jukebox
    kb    = args.inputs.keyboard
    mouse = args.inputs.mouse
    mx = mouse.x
    my = mouse.y

    if kb.key_down.zero
      TRACKS.each { |t| set_gain(st, t, 0.0) }
      post_message(args, 'ALL → 0%')
    end

    if kb.key_down.f
      TRACKS.each { |t| set_gain(st, t, 1.0) }
      post_message(args, 'ALL → 100%')
    end

    # Digit keys: 1..4 toggle mute, SHIFT+1..4 toggle solo membership.
    digit_keys = %i[one two three four]
    TRACKS.each_with_index do |track, i|
      key = digit_keys[i]
      next unless kb.key_down.respond_to?(key) && kb.key_down.send(key)

      if kb.key_held.shift
        toggle_solo(args, track)
      else
        toggle_mute(args, track)
      end
    end

    # Strip mouse handling: M/S buttons, fader drag, wheel.
    TRACKS.each_with_index do |track, i|
      if mouse.click
        if point_in?(mx, my, mute_btn_rect(i))
          toggle_mute(args, track)
          return
        end
        if point_in?(mx, my, solo_btn_rect(i))
          toggle_solo(args, track)
          return
        end
      end

      # Wheel adjusts gain while hovering anywhere on the strip column.
      if point_in?(mx, my, strip_rect(i)) && mouse.wheel
        dy = mouse.wheel.y.to_f
        set_gain(st, track, st[:gain][track] + dy * WHEEL_STEP) if dy != 0
      end
    end

    if mouse.button_left && mouse.down
      TRACKS.each_with_index do |track, i|
        if point_in?(mx, my, fader_thumb_rect(st, track, i))
          st[:dragging]   = track
          st[:drag_start] = [my, st[:gain][track]]
          break
        end
        next unless point_in?(mx, my, fader_rail_rect(i))

        t = ((my - FADER_Y).to_f / FADER_H).clamp(0.0, 1.0)
        set_gain(st, track, t)
        st[:dragging]   = track
        st[:drag_start] = [my, t]
        break
      end
    end

    if mouse.button_left && st[:dragging]
      start_y, start_val = st[:drag_start]
      delta = (my - start_y).to_f / FADER_H
      set_gain(st, st[:dragging], start_val + delta)
    end

    st[:dragging] = nil unless mouse.button_left

    # Global buttons (ALL ZERO, ALL FULL).
    st[:btn_hot] = nil
    global_buttons(args).each do |btn|
      next unless point_in?(mx, my, btn[:rect])

      st[:btn_hot] = btn[:id]
      btn[:action].call if mouse.click
    end
  end

  def self.set_gain(st, track, val)
    st[:gain][track] = val.clamp(0.0, 1.0)
  end

  def self.toggle_mute(args, track)
    st = args.state.jukebox
    st[:muted][track] = !st[:muted][track]
    post_message(args, "#{NAMES[track]} #{st[:muted][track] ? 'MUTED' : 'UNMUTED'}")
  end

  def self.toggle_solo(args, track)
    st = args.state.jukebox
    if st[:solo_set].include?(track)
      st[:solo_set].delete(track)
    else
      st[:solo_set] << track
    end
    msg = st[:solo_set].empty? ? 'SOLO CLEARED' : "SOLO: #{st[:solo_set].map { |t| NAMES[t] }.join(' ')}"
    post_message(args, msg)
  end

  def self.post_message(args, text)
    st = args.state.jukebox
    st[:msg]     = text
    st[:msg_ttl] = 180
  end

  # ---------------------------------------------------------------------------
  # Audio update — sliders write straight to stem gain
  # ---------------------------------------------------------------------------

  def self.update_audio(args)
    st = args.state.jukebox
    solo_set = st[:solo_set]

    music_bus = GameSettings.music_gain

    TRACKS.each do |track|
      audible = solo_set.empty? ? !st[:muted][track] : solo_set.include?(track)
      # Slider at 100% = unity stem after settings bus; never adds gain beyond
      # what GameSettings would apply in-game.
      gain    = audible ? st[:gain][track] * music_bus : 0.0

      # cutoff at LP ceiling = inaudible filtering. Native DSP defaults to
      # 1 kHz LP at registration and ignores nil cutoff (-1.0 sentinel means
      # "keep current") — pushing 20 kHz forces a wide-open filter.
      st[:players][track].apply_mix_settings(
        args,
        gain: gain,
        cutoff_hz: 20_000.0,
        resonance: 0.707,
        duck_multiplier: 1.0,
        bypass_mix: 1.0
      )

      # VU meter tracks slider position (pre-bus), so 100% slider = full meter
      # regardless of master/music settings. Mute/solo silences both meter and
      # signal so the LEDs reflect what's actually playing.
      target = audible ? st[:gain][track] : 0.0
      cur    = st[:meter][track]
      st[:meter][track] = target > cur ? cur + (target - cur) * 0.25 : cur + (target - cur) * 0.04
    end

    st[:msg_ttl] = [st[:msg_ttl] - 1, 0].max
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  def self.render(args)
    out = args.outputs
    out.solids << rect(0, 0, SCREEN_W, SCREEN_H, COL[:bg])
    render_header(out)
    TRACKS.each_with_index { |track, i| render_strip(args, out, track, i) }
    render_global_buttons(args, out)
    render_status_bar(args, out)
    render_sfx_panel(args, out)
  end

  def self.render_header(out)
    out.solids << rect(0, SCREEN_H - 60, SCREEN_W, 60, COL[:panel])
    out.lines  << { x: 0, y: SCREEN_H - 61, x2: SCREEN_W, y2: SCREEN_H - 61, **COL[:separator] }
    out.labels << label(SCREEN_W / 2, SCREEN_H - 20, 'BEAT2R JUKEBOX', size: 4, align: 1, **COL[:accent])
    out.labels << label(SCREEN_W / 2, SCREEN_H - 74,
                        'DRAG / WHEEL FADERS  ·  [1-4] MUTE  ·  [SHIFT+1-4] SOLO  ·  [ESC] EXIT',
                        size: -3, align: 1, **COL[:label])
  end

  def self.render_strip(args, out, track, idx)
    st       = args.state.jukebox
    sx       = strip_x(idx)
    gain     = st[:gain][track]
    soloed   = st[:solo_set].include?(track)
    muted    = st[:muted][track]

    out.solids << rect(sx, STRIP_Y, STRIP_W, STRIP_H, COL[:panel])

    out.borders << { x: sx, y: STRIP_Y, w: STRIP_W, h: STRIP_H, **COL[:accent], primitive_marker: :border } if soloed

    out.labels << label(sx + STRIP_W / 2, STRIP_Y + STRIP_H - 20,
                        NAMES[track], size: 2, align: 1,
                                      **(soloed ? COL[:accent] : COL[:label_bright]))

    # Fader rail + filled portion
    rail = fader_rail_rect(idx)
    out.solids << rect(rail[:x], rail[:y], rail[:w], rail[:h], COL[:rail])
    filled_h = (gain * FADER_H).round
    out.solids << rect(rail[:x], rail[:y], rail[:w], filled_h, COL[:rail_active]) if filled_h > 0

    # Fader thumb
    thumb = fader_thumb_rect(st, track, idx)
    thumb_col = st[:dragging] == track ? COL[:thumb_hot] : COL[:thumb]
    out.solids << rect(thumb[:x], thumb[:y], thumb[:w], thumb[:h], thumb_col)
    mid_y = thumb[:y] + thumb[:h] / 2
    out.lines << { x: thumb[:x] + 2, y: mid_y, x2: thumb[:x] + thumb[:w] - 3, y2: mid_y, **COL[:rail] }

    # Scale marks
    [0.0, 0.25, 0.5, 0.75, 1.0].each do |mark|
      mark_y = FADER_Y + (FADER_H * mark).round
      out.lines << { x: rail[:x] - 10, y: mark_y, x2: rail[:x], y2: mark_y, **COL[:label] }
      if [0.0, 0.5, 1.0].include?(mark)
        out.labels << label(rail[:x] - 16, mark_y + 4, "#{(mark * 100).to_i}", size: -4, align: 2, **COL[:label])
      end
    end

    render_led_meter(out, idx, st[:meter][track])

    solo_btn = solo_btn_rect(idx)
    out.solids << rect(solo_btn[:x], solo_btn[:y], solo_btn[:w], solo_btn[:h],
                       soloed ? COL[:accent] : COL[:solo_idle])
    out.labels << label(solo_btn[:x] + solo_btn[:w] / 2, solo_btn[:y] + solo_btn[:h] / 2 + 9,
                        'S', size: -1, align: 1, **(soloed ? COL[:bg] : COL[:label]))

    mute_btn = mute_btn_rect(idx)
    out.solids << rect(mute_btn[:x], mute_btn[:y], mute_btn[:w], mute_btn[:h],
                       muted ? COL[:led_red] : COL[:solo_idle])
    out.labels << label(mute_btn[:x] + mute_btn[:w] / 2, mute_btn[:y] + mute_btn[:h] / 2 + 9,
                        'M', size: -1, align: 1, **(muted ? COL[:bg] : COL[:label]))
  end

  def self.render_led_meter(out, idx, level)
    mx = strip_x(idx) + STRIP_W / 2 + 38

    METER_SEGS.times do |seg|
      seg_y    = FADER_Y + seg * (METER_SEG_H + METER_SEG_GAP)
      seg_frac = seg.to_f / METER_SEGS
      lit      = level >= ((seg + 1).to_f / METER_SEGS)

      color = if !lit                then COL[:led_off]
              elsif seg_frac > 0.87  then COL[:led_red]
              elsif seg_frac > 0.62  then COL[:led_amber]
              else                        COL[:led_green]
              end

      out.solids << rect(mx, seg_y, METER_W, METER_SEG_H, color)
    end
  end

  def self.render_global_buttons(args, out)
    global_buttons(args).each do |btn|
      hot = args.state.jukebox[:btn_hot] == btn[:id]
      out.solids  << rect(btn[:rect][:x], btn[:rect][:y], btn[:rect][:w], btn[:rect][:h],
                          hot ? COL[:btn_hot] : COL[:btn_idle])
      out.borders << { x: btn[:rect][:x], y: btn[:rect][:y], w: btn[:rect][:w], h: btn[:rect][:h],
                       **COL[:separator], primitive_marker: :border }
      out.labels  << label(btn[:rect][:x] + btn[:rect][:w] / 2,
                           btn[:rect][:y] + btn[:rect][:h] / 2 + 15,
                           btn[:label], size: -2, align: 1,
                                        **(hot ? COL[:accent] : COL[:label_bright]))
      out.labels  << label(btn[:rect][:x] + btn[:rect][:w] / 2,
                           btn[:rect][:y] + btn[:rect][:h] / 2 - 4,
                           btn[:key], size: -4, align: 1, **COL[:label])
    end
  end

  def self.global_buttons(args)
    btn_w   = 110
    btn_h   = 40
    btn_y   = 30
    gap     = 14
    total   = 2 * btn_w + gap
    start_x = (SCREEN_W - total) / 2

    [
      { id: :zero, label: 'ALL ZERO', key: '[0]',
        rect: { x: start_x, y: btn_y, w: btn_w, h: btn_h },
        action: lambda {
          TRACKS.each { |t| set_gain(args.state.jukebox, t, 0.0) }
          post_message(args, 'ALL → 0%')
        } },
      { id: :full, label: 'ALL FULL', key: '[F]',
        rect: { x: start_x + btn_w + gap, y: btn_y, w: btn_w, h: btn_h },
        action: lambda {
          TRACKS.each { |t| set_gain(args.state.jukebox, t, 1.0) }
          post_message(args, 'ALL → 100%')
        } }
    ]
  end

  def self.render_status_bar(args, out)
    st = args.state.jukebox
    bar_h = 28
    out.solids << rect(0, 0, SCREEN_W, bar_h, COL[:panel])
    out.lines  << { x: 0, y: bar_h, x2: SCREEN_W, y2: bar_h, **COL[:separator] }

    if st[:msg_ttl] > 0
      alpha = [(st[:msg_ttl] * 4).clamp(0, 255), 255].min
      out.labels << label(SCREEN_W / 2, bar_h - 8, st[:msg].to_s, size: -2, align: 1,
                                                                  r: COL[:accent][:r], g: COL[:accent][:g], b: COL[:accent][:b], a: alpha)
    end

    out.labels << label(SCREEN_W - 20, bar_h - 8, "tick #{args.tick_count}", size: -4, align: 2, **COL[:label])
  end

  # ---------------------------------------------------------------------------
  # SFX side panel
  # ---------------------------------------------------------------------------

  def self.sfx_names
    Audio::SFXPlayer::SFX_DEFINITIONS.keys
  end

  def self.sfx_row_rect(index)
    {
      x: SFX_PANEL_X,
      y: SFX_PANEL_Y_TOP - (index + 2) * SFX_ROW_H - index * SFX_ROW_GAP,
      w: SFX_PANEL_W,
      h: SFX_ROW_H
    }
  end

  def self.handle_sfx_panel(args)
    mouse = args.inputs.mouse
    return unless mouse.button_left && mouse.click

    sfx_names.each_with_index do |name, i|
      next unless point_in?(mouse.x, mouse.y, sfx_row_rect(i))

      Audio::SFXPlayer.play(args, name)
      post_message(args, "SFX: #{name.to_s.upcase}")
      return
    end
  end

  def self.render_sfx_panel(args, out)
    mx = args.inputs.mouse.x
    my = args.inputs.mouse.y
    out.labels << label(SFX_PANEL_X + SFX_PANEL_W / 2, SFX_PANEL_Y_TOP - 4,
                        'SFX', size: 2, align: 1, **COL[:label_bright])

    sfx_names.each_with_index do |name, i|
      r   = sfx_row_rect(i)
      hot = point_in?(mx, my, r)
      out.solids  << rect(r[:x], r[:y], r[:w], r[:h], hot ? COL[:btn_hot] : COL[:btn_idle])
      out.borders << { x: r[:x], y: r[:y], w: r[:w], h: r[:h], **COL[:separator] }
      out.labels  << label(r[:x] + 10, r[:y] + r[:h] - 8, name.to_s.upcase,
                           size: -2, **(hot ? COL[:label_bright] : COL[:label]))
    end
  end

  # ---------------------------------------------------------------------------
  # Geometry
  # ---------------------------------------------------------------------------

  def self.strip_x(idx)    = STRIP_X0 + idx * (STRIP_W + STRIP_GAP)
  def self.strip_rect(idx) = { x: strip_x(idx), y: STRIP_Y, w: STRIP_W, h: STRIP_H }

  def self.fader_rail_rect(idx)
    { x: strip_x(idx) + STRIP_W / 2 - 10, y: FADER_Y, w: FADER_W, h: FADER_H }
  end

  def self.fader_thumb_rect(st, track, idx)
    thumb_y = FADER_Y + (st[:gain][track] * (FADER_H - FADER_THUMB_H)).round
    { x: strip_x(idx) + STRIP_W / 2 - 18, y: thumb_y, w: FADER_W + 16, h: FADER_THUMB_H }
  end

  def self.solo_btn_rect(idx)
    { x: strip_x(idx) + STRIP_W / 2 - 14, y: STRIP_Y + 28, w: 28, h: 20 }
  end

  def self.mute_btn_rect(idx)
    { x: strip_x(idx) + STRIP_W / 2 - 14, y: STRIP_Y + 52, w: 28, h: 20 }
  end

  def self.point_in?(x, y, r)
    x >= r[:x] && x <= r[:x] + r[:w] && y >= r[:y] && y <= r[:y] + r[:h]
  end

  def self.rect(x, y, w, h, color)
    { x: x, y: y, w: w, h: h, **color, primitive_marker: :solid }
  end

  def self.label(x, y, text, size: 0, align: 0, r: 255, g: 255, b: 255, a: 255)
    { x: x, y: y, text: text, size_enum: size, alignment_enum: align, r: r, g: g, b: b, a: a }
  end
end
