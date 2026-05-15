# =============================================================================
# progression_tester.rb
# DJ Maze Game — Stem Gain Progression Dev Tool
#
# A standalone DragonRuby scene that lets you scrub each track's dot-collection
# completion % in real time and hear the stem gain progression respond immediately.
# Run this instead of main.rb during audio tuning.
#
# HOW TO USE
# ----------
# 1. Drop this file alongside audio_manager.rb in your app/ folder.
# 2. In main.rb, swap your tick to:
#      require 'app/audio/manager.rb'   # plus the rest of app/audio/*.rb
#      require 'app/progression_tester.rb'
#      def tick(args) = ProgressionTester.tick(args)
# 3. Use mouse to drag channel sliders or click the shortcut buttons.
# 4. Edit TRACK_CONFIGS in track_config.rb, hot-reload fires instantly.
#
# CONTROLS
# --------
#   Drag slider        — set that track's completion %
#   [0] key            — all tracks → 0%
#   [F] key            — all tracks → 100% (full/finale)
#   [Space]            — randomise all sliders
#   [1][2][3][4]       — solo that track (mute others)
#   [S]                — clear solo (all tracks audible)
#   [R]                — reset AudioManager
#   [Q] / Escape       — quit tester (return to main game if integrated)
# =============================================================================

require 'app/audio/music_theory.rb'
require 'app/audio/wave_generator.rb'
require 'app/audio/track_config.rb'
require 'app/audio/beat_clock.rb'
require 'app/audio/track_library.rb'
require 'app/audio/track_player.rb'
require 'app/audio/sfx_player.rb'
require 'app/audio/manager.rb'

module ProgressionTester

  # ---------------------------------------------------------------------------
  # Layout constants — hardware mixer aesthetic
  # ---------------------------------------------------------------------------

  # Colour palette: dark studio console with amber LED accents
  PAL = {
    bg:           { r:  14, g:  14, b:  18, a: 255 },   # near-black console body
    panel:        { r:  22, g:  22, b:  28, a: 255 },   # slightly lighter panels
    rail:         { r:  35, g:  35, b:  42, a: 255 },   # slider rail
    rail_active:  { r:  55, g:  55, b:  65, a: 255 },   # active part of rail
    thumb:        { r: 210, g: 210, b: 220, a: 255 },   # slider thumb (white-ish)
    thumb_hot:    { r: 255, g: 255, b: 255, a: 255 },   # hovered thumb
    led_off:      { r:  30, g:  25, b:  10, a: 255 },   # unlit LED segment
    led_green:    { r:  60, g: 220, b:  80, a: 255 },   # low segment
    led_amber:    { r: 230, g: 160, b:  20, a: 255 },   # mid segment
    led_red:      { r: 220, g:  50, b:  40, a: 255 },   # peak segment
    label:        { r: 160, g: 155, b: 145, a: 255 },   # dim label text
    label_bright: { r: 220, g: 215, b: 200, a: 255 },   # active label text
    accent:       { r: 230, g: 160, b:  20, a: 255 },   # amber accent (same as led_amber)
    solo_active:  { r: 230, g: 160, b:  20, a: 255 },   # solo button lit
    solo_idle:    { r:  50, g:  48, b:  42, a: 255 },   # solo button dark
    btn_idle:     { r:  40, g:  40, b:  48, a: 255 },
    btn_hot:      { r:  60, g:  58, b:  70, a: 255 },
    separator:    { r:  45, g:  44, b:  52, a: 255 },
    scope_bg:     { r:  10, g:  18, b:  12, a: 255 },   # oscilloscope bg (green phosphor)
    scope_line:   { r:  60, g: 220, b:  80, a: 200 },
  }.freeze

  SCREEN_W = 1280
  SCREEN_H = 720

  # Channel strip geometry
  STRIP_COUNT  = 4
  STRIP_W      = 180
  STRIP_GAP    = 24
  STRIPS_TOTAL = STRIP_COUNT * STRIP_W + (STRIP_COUNT - 1) * STRIP_GAP
  STRIP_X0     = (SCREEN_W - STRIPS_TOTAL) / 2   # left edge of first strip
  STRIP_Y0     = 80                               # top of strip area
  STRIP_H      = 540

  # Slider geometry (vertical fader inside each strip)
  FADER_X_OFF  = STRIP_W / 2 - 10   # centre offset
  FADER_W      = 20
  FADER_H      = 300
  FADER_Y0     = STRIP_Y0 + 160     # top of fader travel
  FADER_THUMB_H = 28

  # LED meter geometry
  METER_SEGS   = 16
  METER_SEG_H  = 10
  METER_SEG_GAP = 2
  METER_W      = 14
  METER_X_OFF  = STRIP_W / 2 + 18

  TRACK_NAMES  = { drums: 'DRUMS', bass: 'BASS', lead: 'LEAD', chords: 'CHORDS/LEAD' }.freeze
  TRACK_ORDER  = [:drums, :bass, :lead, :chords].freeze
  TRACK_COLORS = {
    drums: { r: 220, g:  80, b:  60, a: 255 },   # red
    bass:  { r:  60, g: 200, b: 100, a: 255 },   # green
    lead: { r:  80, g: 140, b: 220, a: 255 },   # blue
    chords:    { r: 220, g: 190, b:  50, a: 255 },   # yellow
  }.freeze

  # ---------------------------------------------------------------------------
  # Entry point
  # ---------------------------------------------------------------------------
  # SFX side panel — clickable list to audition every SFX_DEFINITIONS entry.
  # Reachable from the title via the :jukebox scene; also runs standalone via
  # ./run_progression_tester (tools mode).
  SFX_PANEL_X = 1060
  SFX_PANEL_Y_TOP = 620
  SFX_ROW_H = 30
  SFX_PANEL_W = 200
  SFX_ROW_GAP = 4

  def self.tick(args)
    # Re-init whenever audio is missing — happens on jukebox scene re-entry
    # (apply_scene_swap nils args.state.audio).
    init(args) if args.state.pt_version != TOOL_VERSION || args.state.audio.nil?
    handle_input(args)
    handle_sfx_panel(args)
    handle_exit_input(args)
    update_audio(args)
    render(args)
  end

  def self.sfx_names
    Audio::SFXPlayer::SFX_DEFINITIONS.keys
  end

  def self.sfx_row_rect(index)
    {
      x: SFX_PANEL_X,
      y: SFX_PANEL_Y_TOP - (index + 1) * SFX_ROW_H - index * SFX_ROW_GAP,
      w: SFX_PANEL_W,
      h: SFX_ROW_H
    }
  end

  def self.handle_sfx_panel(args)
    mouse = args.inputs.mouse
    return unless mouse.button_left && mouse.click

    sfx_names.each_with_index do |name, i|
      next unless point_in_rect?(mouse.x, mouse.y, sfx_row_rect(i))

      Audio::SFXPlayer.play(args, name)
      post_message(args, "SFX: #{name.to_s.upcase}")
      return
    end
  end

  def self.handle_exit_input(args)
    kb = args.inputs.keyboard.key_down
    return unless kb.escape || kb.q

    # mruby parses `defined?` as a method call, not a keyword, so use
    # const_defined? to probe whether the main app stack is loaded.
    if Object.const_defined?(:SceneDirector)
      SceneDirector.request(:title)
    else
      $gtk.request_quit
    end
  end

  TOOL_VERSION = 3   # bump to force re-init on hot reload

  # ---------------------------------------------------------------------------
  # Init
  # ---------------------------------------------------------------------------
  def self.init(args)
    args.state.pt_version    = TOOL_VERSION
    # Jukebox UX: start at full progression so unmuting/soloing instantly
    # reveals the evolved mix. Pull sliders down to audition the closed-
    # filter / low-gain starting state.
    args.state.pt_completion = { drums: 1.0, bass: 1.0, lead: 1.0, chords: 1.0 }
    args.state.pt_solo       = nil          # nil = no solo, else track symbol
    # TT3: tracks start muted so the jukebox opens silent — unmute or solo
    # to audition each stem on demand.
    args.state.pt_muted      = { drums: true, bass: true, lead: true, chords: true }
    args.state.pt_gain_override = { drums: 1.0, bass: 1.0, lead: 1.0, chords: 1.0 }
    args.state.pt_dragging   = nil          # track being dragged
    args.state.pt_drag_start = nil          # [mouse_y, completion_at_start]
    args.state.pt_meter      = { drums: 0.0, bass: 0.0, lead: 0.0, chords: 0.0 }
    args.state.pt_scope_buf  = []           # last N completion values for mini scope
    args.state.pt_msg        = nil          # status message text
    args.state.pt_msg_ttl    = 0            # message time-to-live in ticks
    args.state.pt_btn_hot    = nil          # which global button is hovered

    # Fresh AudioManager — same one the real game would use
    args.state.audio         = Audio::Manager.new(args)
    args.state.audio.set_dot_totals(drums: 20, bass: 20, lead: 20, chords: 20)

    post_message(args, 'PROGRESSION TESTER READY')
  end

  # ---------------------------------------------------------------------------
  # Input
  # ---------------------------------------------------------------------------
  def self.handle_input(args)
    kb = args.inputs.keyboard
    mx = args.inputs.mouse.x
    my = args.inputs.mouse.y

    # --- Keyboard shortcuts ---
    if kb.key_down.zero
      set_all(args, 0.0)
      post_message(args, 'ALL → 0%')
    end

    if kb.key_down.f
      set_all(args, 1.0)
      post_message(args, 'ALL → 100%')
    end

    if kb.key_down.space
      TRACK_ORDER.each { |t| set_track(args, t, rand) }
      post_message(args, 'RANDOMISED')
    end

    if kb.key_down.s
      args.state.pt_solo = nil
      post_message(args, 'SOLO CLEARED')
    end

    if kb.key_down.r
      init(args)
      return
    end

    # Solo keys 1-4 (DragonRuby key names: one/two/three/four)
    solo_keys = [:one, :two, :three, :four]
    TRACK_ORDER.each_with_index do |track, i|
      key = solo_keys[i]
      if key && kb.key_down.respond_to?(key) && kb.key_down.send(key)
        args.state.pt_solo = (args.state.pt_solo == track ? nil : track)
        msg = args.state.pt_solo ? "SOLO: #{TRACK_NAMES[track]}" : 'SOLO CLEARED'
        post_message(args, msg)
      end
    end

    # --- Mouse: fader drag ---
    mouse = args.inputs.mouse

    # TT1 / TT2: mute and solo buttons need edge-triggered clicks. The old
    # `button_left && mouse.down` is true every frame the button is held,
    # so the toggle flipped up to 60x per click → random final state.
    # mouse.click is set only on the frame the click is registered.
    if mouse.click
      TRACK_ORDER.each_with_index do |track, i|
        mute_rect = mute_btn_rect(i)
        if point_in_rect?(mx, my, mute_rect)
          args.state.pt_muted[track] = !args.state.pt_muted[track]
          state = args.state.pt_muted[track] ? 'MUTED' : 'UNMUTED'
          post_message(args, "#{TRACK_NAMES[track]} #{state}")
          return
        end

        solo_rect = solo_btn_rect(i)
        next unless point_in_rect?(mx, my, solo_rect)

        args.state.pt_solo = (args.state.pt_solo == track ? nil : track)
        msg = args.state.pt_solo ? "SOLO: #{TRACK_NAMES[track]}" : 'SOLO CLEARED'
        post_message(args, msg)
        return
      end
    end

    if mouse.button_left && mouse.down
      # Check if clicking on a fader thumb
      TRACK_ORDER.each_with_index do |track, i|
        thumb_rect = fader_thumb_rect(args, track, i)
        if point_in_rect?(mx, my, thumb_rect)
          args.state.pt_dragging   = track
          args.state.pt_drag_start = [my, args.state.pt_completion[track]]
          break
        end
        # Also check clicking anywhere on the fader rail to jump
        rail_rect = fader_rail_rect(i)
        if point_in_rect?(mx, my, rail_rect)
          t = ((my - FADER_Y0).to_f / FADER_H).clamp(0.0, 1.0)
          set_track(args, track, t)
          args.state.pt_dragging   = track
          args.state.pt_drag_start = [my, t]
          break
        end
      end
    end

    if mouse.button_left && args.state.pt_dragging
      start_y, start_val = args.state.pt_drag_start
      delta = (my - start_y).to_f / FADER_H
      new_val = (start_val + delta).clamp(0.0, 1.0)
      set_track(args, args.state.pt_dragging, new_val)
    end

    if !mouse.button_left
      args.state.pt_dragging = nil
    end

    # --- Mouse: global buttons ---
    # Edge-triggered too — RESET in particular re-creates Audio::Manager
    # so firing it every frame would be catastrophic if a user lingered.
    args.state.pt_btn_hot = nil
    global_buttons(args).each do |btn|
      next unless point_in_rect?(mx, my, btn[:rect])

      args.state.pt_btn_hot = btn[:id]
      btn[:action].call if mouse.click
    end
  end

  def self.set_all(args, val)
    TRACK_ORDER.each { |t| set_track(args, t, val) }
  end

  def self.set_track(args, track, val)
    args.state.pt_completion[track] = val.clamp(0.0, 1.0)
  end

  def self.post_message(args, text)
    args.state.pt_msg     = text
    args.state.pt_msg_ttl = 180   # 3 seconds at 60fps
  end

  # ---------------------------------------------------------------------------
  # Audio update — push completion values into AudioManager each frame
  # ---------------------------------------------------------------------------
  def self.update_audio(args)
    audio = args.state.audio
    return unless audio

    solo = args.state.pt_solo
    muted = args.state.pt_muted

    # Write slider ratios straight into the progression's completion hash so
    # the next sync_gains call inside audio.tick computes track gain/cutoff
    # against them. Bypasses on_dot_collected (counter-based) for 1:1 mapping.
    TRACK_ORDER.each do |track|
      audio.completion[track] = args.state.pt_completion[track]
    end

    audio.tick(args)

    # Apply mute/solo via the `paused` flag, not by zeroing gain. With the
    # native audio backend (audio_stem_fx.dylib) the gain we'd write into
    # args.audio[key].gain is ignored — gain is pushed through
    # NativeBridge.push_track_params from sync_gains every tick. Pausing
    # is engine-level and respected by both legacy and native backends.
    TRACK_ORDER.each do |track|
      key = :"track_#{track}"
      next unless args.audio[key]

      # DAW convention: solo overrides mute on the soloed track. While
      # any track is soloed, only that one plays — mute state on the
      # soloed track is ignored. Otherwise per-track mute decides.
      silenced = solo ? (solo != track) : muted[track]
      args.audio[key].paused = silenced
    end

    # Decay meter values toward current completion (VU meter feel)
    TRACK_ORDER.each do |track|
      target = args.state.pt_completion[track]
      cur    = args.state.pt_meter[track]
      # Attack fast, decay slow — classic VU behaviour
      args.state.pt_meter[track] = if target > cur
                                      cur + (target - cur) * 0.25
                                    else
                                      cur + (target - cur) * 0.04
                                    end
    end

    # Tick down status message
    args.state.pt_msg_ttl = [args.state.pt_msg_ttl - 1, 0].max
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------
  def self.render(args)
    out = args.outputs

    # Background
    out.solids << bg_rect(0, 0, SCREEN_W, SCREEN_H, PAL[:bg])

    # Top header bar
    render_header(args, out)

    # Channel strips
    TRACK_ORDER.each_with_index do |track, i|
      render_strip(args, out, track, i)
    end

    # Global buttons row
    render_global_buttons(args, out)

    # Status bar
    render_status_bar(args, out)

    # Scope (mini waveform visualiser bottom-right)
    render_scope(args, out)

    # SFX panel (right-hand column)
    render_sfx_panel(args, out)
  end

  def self.render_header(args, out)
    # Header panel
    out.solids << bg_rect(0, SCREEN_H - 60, SCREEN_W, 60, PAL[:panel])
    out.lines  << { x: 0, y: SCREEN_H - 61, x2: SCREEN_W, y2: SCREEN_H - 61,
                    **PAL[:separator] }

    out.labels << label(SCREEN_W / 2, SCREEN_H - 20,
                        'DJ MAZE  ·  PROGRESSION TESTER',
                        size: 4, align: 1, **PAL[:accent])

    out.labels << label(SCREEN_W / 2, SCREEN_H - 42,
                        'DRAG FADERS  ·  [0] ZERO  [F] FULL  [SPACE] RANDOM  ' \
                        '[1-4] SOLO  [S] UNSOLO  [R] RESET',
                        size: -3, align: 1, **PAL[:label])

    backend_text = args.state.audio&.respond_to?(:backend_mode) ? args.state.audio.backend_mode.to_s.upcase : 'UNKNOWN'
    out.labels << label(SCREEN_W - 20, SCREEN_H - 20,
              "BACKEND: #{backend_text}",
              size: -3, align: 2, **PAL[:label_bright])
  end

  def self.render_strip(args, out, track, idx)
    sx   = strip_x(idx)
    comp = args.state.pt_completion[track]
    cfg  = Audio::TRACK_CONFIGS[track]
    col  = TRACK_COLORS[track]
    solo = args.state.pt_solo

    # Strip panel background
    out.solids << bg_rect(sx, STRIP_Y0, STRIP_W, STRIP_H, PAL[:panel])

    # Solo highlight border
    if solo == track
      out.borders << { x: sx, y: STRIP_Y0, w: STRIP_W, h: STRIP_H,
                       **PAL[:solo_active], primitive_marker: :border }
    end

    # ── Track name label ──
    out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + STRIP_H - 20,
                        TRACK_NAMES[track], size: 2, align: 1,
                        **( solo == track ? PAL[:accent] : PAL[:label_bright] ))

    # ── Colour dot (track identifier) ──
    out.solids << {
      x: sx + STRIP_W / 2 - 6, y: STRIP_Y0 + STRIP_H - 50,
      w: 12, h: 12, **col
    }

    # ── Completion % readout (LED-style display) ──
    pct_text = "#{(comp * 100).round.to_s.rjust(3)}%"
    out.solids << bg_rect(sx + 20, STRIP_Y0 + STRIP_H - 80, STRIP_W - 40, 24, PAL[:scope_bg])
    out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + STRIP_H - 62,
                        pct_text, size: 3, align: 1, **PAL[:led_green])

    # ── Stem / filter readout ──
    out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + STRIP_H - 100,
                        'LOOPING STEM', size: -2, align: 1, **PAL[:label])

    stem_path = Audio::TrackLibrary::STEM_PATHS[track]
    stem_name = stem_path.split('/').last.to_s.upcase
    out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + STRIP_H - 114,
                        stem_name, size: -2, align: 1, **PAL[:label_bright])

    # ── Filter parameter (cutoff only) ──
    cutoff_hz = interpolated_cutoff_hz_for(cfg, comp)

    if cutoff_hz
      cutoff_text = cutoff_hz > 1000 ? "#{"%.1f" % (cutoff_hz / 1000)}kHz" : "#{"%.0f" % cutoff_hz}Hz"
      out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + STRIP_H - 128,
                          "FC #{cutoff_text}", size: -2, align: 1, **PAL[:label])
    end

    # ── Fader rail ──
    rail = fader_rail_rect(idx)
    out.solids << bg_rect(rail.x, rail.y, rail.w, rail.h, PAL[:rail])

    # Active (filled) portion of rail
    filled_h = (comp * FADER_H).round
    if filled_h > 0
      out.solids << bg_rect(rail.x, rail.y, rail.w, filled_h, PAL[:rail_active])
    end

    # Fader thumb
    thumb = fader_thumb_rect(args, track, idx)
    is_dragging = args.state.pt_dragging == track
    thumb_col = is_dragging ? PAL[:thumb_hot] : PAL[:thumb]
    out.solids << bg_rect(thumb.x, thumb.y, thumb.w, thumb.h, thumb_col)
    # Thumb centre line
    mid_y = thumb.y + thumb.h / 2
    out.lines << { x: thumb.x + 3, y: mid_y, x2: thumb.x + thumb.w - 3, y2: mid_y,
                   **PAL[:rail] }

    # Fader scale marks (0%, 25%, 50%, 75%, 100%)
    [0.0, 0.25, 0.5, 0.75, 1.0].each do |mark|
      mark_y = FADER_Y0 + (FADER_H * mark).round
      out.lines << { x: rail.x - 6, y: mark_y, x2: rail.x, y2: mark_y, **PAL[:label] }
      if [0.0, 0.5, 1.0].include?(mark)
        out.labels << label(rail.x - 8, mark_y + 4,
                            "#{(mark * 100).to_i}", size: -4, align: 2, **PAL[:label])
      end
    end

    # ── LED meter (VU-style, right of fader) ──
    render_led_meter(out, idx, args.state.pt_meter[track])

    # ── Solo button ──
    solo_btn = solo_btn_rect(idx)
    solo_lit  = solo == track
    out.solids  << bg_rect(solo_btn.x, solo_btn.y, solo_btn.w, solo_btn.h,
                           solo_lit ? PAL[:solo_active] : PAL[:solo_idle])
    out.labels  << label(solo_btn.x + solo_btn.w / 2,
                         solo_btn.y + solo_btn.h / 2 + 4,
                         'S', size: -1, align: 1,
                         **( solo_lit ? PAL[:bg] : PAL[:label] ))

              # ── Mute button ──
              mute_btn = mute_btn_rect(idx)
              muted = args.state.pt_muted[track]
              out.solids  << bg_rect(mute_btn.x, mute_btn.y, mute_btn.w, mute_btn.h,
                           muted ? PAL[:led_red] : PAL[:solo_idle])
              out.labels  << label(mute_btn.x + mute_btn.w / 2,
                         mute_btn.y + mute_btn.h / 2 + 4,
                         'M', size: -1, align: 1,
                         **( muted ? PAL[:bg] : PAL[:label] ))

    # ── Progression badge ──
    out.labels << label(sx + STRIP_W / 2, STRIP_Y0 + 12,
              progression_badge(comp), size: -3, align: 1, **PAL[:label])
  end

  def self.render_led_meter(out, idx, level)
    sx = strip_x(idx)
    mx = sx + METER_X_OFF

    METER_SEGS.times do |seg|
      seg_y     = FADER_Y0 + seg * (METER_SEG_H + METER_SEG_GAP)
      # seg 0 = bottom (quiet), seg 15 = top (loud)
      seg_frac  = seg.to_f / METER_SEGS
      lit       = level >= ((seg + 1).to_f / METER_SEGS)

      color = if !lit
                PAL[:led_off]
              elsif seg_frac > 0.87
                PAL[:led_red]
              elsif seg_frac > 0.62
                PAL[:led_amber]
              else
                PAL[:led_green]
              end

      out.solids << bg_rect(mx, seg_y, METER_W, METER_SEG_H, color)
    end
  end

  def self.render_global_buttons(args, out)
    global_buttons(args).each do |btn|
      hot = args.state.pt_btn_hot == btn[:id]
      col = hot ? PAL[:btn_hot] : PAL[:btn_idle]
      out.solids << bg_rect(btn[:rect].x, btn[:rect].y,
                            btn[:rect].w, btn[:rect].h, col)
      out.borders << { x: btn[:rect].x, y: btn[:rect].y,
                       w: btn[:rect].w, h: btn[:rect].h,
                       **PAL[:separator], primitive_marker: :border }
      out.labels << label(btn[:rect].x + btn[:rect].w / 2,
                          btn[:rect].y + btn[:rect].h / 2 + 5,
                          btn[:label], size: -2, align: 1,
                          **( hot ? PAL[:accent] : PAL[:label_bright] ))
      out.labels << label(btn[:rect].x + btn[:rect].w / 2,
                          btn[:rect].y + btn[:rect].h / 2 - 8,
                          btn[:key], size: -4, align: 1, **PAL[:label])
    end
  end

  def self.global_buttons(args)
    btn_w  = 110
    btn_h  = 50
    btn_y  = 18
    gap    = 14
    total  = 4 * btn_w + 3 * gap
    start_x = (SCREEN_W - total) / 2

    [
      { id: :zero,   label: 'ALL ZERO',   key: '[0]',
        rect: { x: start_x,                    y: btn_y, w: btn_w, h: btn_h },
        action: -> { set_all(args, 0.0); post_message(args, 'ALL → 0%') } },
      { id: :full,   label: 'ALL FULL',   key: '[F]',
        rect: { x: start_x + (btn_w + gap),    y: btn_y, w: btn_w, h: btn_h },
        action: -> { set_all(args, 1.0); post_message(args, 'ALL → 100%') } },
      { id: :random, label: 'RANDOMISE',  key: '[SPACE]',
        rect: { x: start_x + (btn_w + gap) * 2, y: btn_y, w: btn_w, h: btn_h },
        action: -> { TRACK_ORDER.each { |t| set_track(args, t, rand) }; post_message(args, 'RANDOMISED') } },
      { id: :reset,  label: 'RESET',      key: '[R]',
        rect: { x: start_x + (btn_w + gap) * 3, y: btn_y, w: btn_w, h: btn_h },
        action: -> { init(args); post_message(args, 'RESET') } },
    ]
  end

  def self.render_sfx_panel(args, out)
    mx = args.inputs.mouse.x
    my = args.inputs.mouse.y

    # Header
    out.labels << label(SFX_PANEL_X + SFX_PANEL_W / 2, SFX_PANEL_Y_TOP - 4,
                        'SFX', size: 2, align: 1, **PAL[:label_bright])

    sfx_names.each_with_index do |name, i|
      rect = sfx_row_rect(i)
      hot = point_in_rect?(mx, my, rect)
      fill = hot ? PAL[:btn_hot] : PAL[:btn_idle]
      out.solids << bg_rect(rect[:x], rect[:y], rect[:w], rect[:h], fill)
      out.borders << { x: rect[:x], y: rect[:y], w: rect[:w], h: rect[:h], **PAL[:separator] }
      out.labels << label(rect[:x] + 10, rect[:y] + rect[:h] - 8,
                          name.to_s.upcase, size: -2,
                          **(hot ? PAL[:label_bright] : PAL[:label]))
    end
  end

  def self.render_status_bar(args, out)
    bar_h = 28
    out.solids << bg_rect(0, 0, SCREEN_W, bar_h, PAL[:panel])
    out.lines  << { x: 0, y: bar_h, x2: SCREEN_W, y2: bar_h, **PAL[:separator] }

    # Overall completion
    overall = args.state.pt_completion.values.sum / 4.0
    out.labels << label(20, bar_h - 8, "OVERALL: #{(overall * 100).round}%",
                        size: -2, **PAL[:label_bright])

    # Status message (fades out)
    if args.state.pt_msg_ttl > 0
      alpha = [(args.state.pt_msg_ttl * 4).clamp(0, 255), 255].min
      out.labels << label(SCREEN_W / 2, bar_h - 8, args.state.pt_msg.to_s,
                          size: -2, align: 1,
                          r: PAL[:accent][:r], g: PAL[:accent][:g],
                          b: PAL[:accent][:b], a: alpha)
    end

    # Tick counter (for debugging hot-reload)
    out.labels << label(SCREEN_W - 20, bar_h - 8,
                        "tick #{args.tick_count}", size: -4, align: 2, **PAL[:label])
  end

  def self.render_scope(args, out)
    # Mini completion history scope — bottom right
    scope_w = 160
    scope_h = 60
    scope_x = SCREEN_W - scope_w - 20
    scope_y = 36

    out.solids << bg_rect(scope_x, scope_y, scope_w, scope_h, PAL[:scope_bg])
    out.borders << { x: scope_x, y: scope_y, w: scope_w, h: scope_h,
                     **PAL[:separator], primitive_marker: :border }
    out.labels << label(scope_x + 4, scope_y + scope_h - 2,
                        'OVERALL', size: -5, **PAL[:label])

    # Push current overall into buffer
    overall = args.state.pt_completion.values.sum / 4.0
    buf = args.state.pt_scope_buf
    buf << overall
    buf.shift while buf.length > scope_w

    # Draw scope line
    buf.each_with_index do |val, i|
      next if i == 0
      x1 = scope_x + i - 1
      x2 = scope_x + i
      y1 = scope_y + (buf[i - 1] * (scope_h - 4)).round + 2
      y2 = scope_y + (val         * (scope_h - 4)).round + 2
      out.lines << { x: x1, y: y1, x2: x2, y2: y2, **PAL[:scope_line] }
    end
  end

  # ---------------------------------------------------------------------------
  # Geometry helpers
  # ---------------------------------------------------------------------------

  def self.strip_x(idx)
    STRIP_X0 + idx * (STRIP_W + STRIP_GAP)
  end

  def self.fader_rail_rect(idx)
    sx = strip_x(idx)
    { x: sx + FADER_X_OFF, y: FADER_Y0, w: FADER_W, h: FADER_H }
  end

  def self.fader_thumb_rect(args, track, idx)
    comp  = args.state.pt_completion[track]
    sx    = strip_x(idx)
    thumb_y = FADER_Y0 + (comp * (FADER_H - FADER_THUMB_H)).round
    { x: sx + FADER_X_OFF - 8, y: thumb_y, w: FADER_W + 16, h: FADER_THUMB_H }
  end

  def self.solo_btn_rect(idx)
    sx = strip_x(idx)
    { x: sx + STRIP_W / 2 - 14, y: STRIP_Y0 + 28, w: 28, h: 20 }
  end

  def self.mute_btn_rect(idx)
    sx = strip_x(idx)
    { x: sx + STRIP_W / 2 - 14, y: STRIP_Y0 + 52, w: 28, h: 20 }
  end

  def self.point_in_rect?(x, y, rect)
    x >= rect[:x] && x <= rect[:x] + rect[:w] &&
      y >= rect[:y] && y <= rect[:y] + rect[:h]
  end

  def self.bg_rect(x, y, w, h, color)
    { x: x, y: y, w: w, h: h, **color, primitive_marker: :solid }
  end

  def self.label(x, y, text, size: 0, align: 0, r: 255, g: 255, b: 255, a: 255)
    { x: x, y: y, text: text, size_enum: size,
      alignment_enum: align, r: r, g: g, b: b, a: a }
  end

  # ---------------------------------------------------------------------------
  # Audio / config helpers (mirrors AudioManager private logic for display)
  # ---------------------------------------------------------------------------

  def self.interpolated_cutoff_hz_for(cfg, t)
    return nil unless cfg.start_cutoff.is_a?(Numeric)

    end_cutoff = cfg.end_cutoff == :bypass ? cfg.start_cutoff : cfg.end_cutoff
    return nil unless end_cutoff.is_a?(Numeric)

    t = t.clamp(0.0, 1.0)
    start_hz = cfg.start_cutoff.to_f.clamp(20.0, 20_000.0)
    end_hz = end_cutoff.to_f.clamp(20.0, 20_000.0)
    return start_hz if start_hz == end_hz

    start_ln = Math.log(start_hz)
    end_ln = Math.log(end_hz)
    Math.exp(start_ln + t * (end_ln - start_ln))
  end

  def self.progression_badge(completion)
    case completion
    when 0.0...0.25 then 'INTRO  ·  DARK LP'
    when 0.25...0.50 then 'BUILD  ·  OPENING LP'
    when 0.50...0.75 then 'LIFT   ·  WIDER LP'
    else                  'FULL   ·  OPEN LP'
    end
  end
end