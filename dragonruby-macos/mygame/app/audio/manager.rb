require 'app/audio/native_bridge.rb'
require 'app/audio/beat_clock.rb'

module Audio
  class Manager
    TRACKS     = [:drums, :bass, :lead, :chords].freeze
    DOT_COLORS = { red: :drums, green: :bass, blue: :lead, yellow: :chords }.freeze
    MIN_CUTOFF_HZ = 20.0
    MAX_CUTOFF_HZ = 20_000.0

    attr_reader :completion, :duck_active, :duck_amount, :duck_gain_scale, :backend_mode

    def initialize(args)
      @definitions  = TrackLibrary.build_all
      @players      = {}
      @dot_totals   = { drums: 20, bass: 20, lead: 20, chords: 20 }
      @dot_counts   = { drums: 0,  bass: 0,  lead: 0,  chords: 0  }
      @completion   = { drums: 0.0, bass: 0.0, lead: 0.0, chords: 0.0 }

      @configs = TRACK_CONFIGS.transform_values(&:dup)

      @duck_active     = false
      @duck_amount     = 0.0
      @duck_gain_scale = 1.0
      @duck_ramp_in_ticks = 8
      @duck_ramp_out_ticks = 8
      @backend_mode    = NativeBridge.backend_mode
      @rhythm_bpm      = BeatClock::DEFAULT_BPM
      @rhythm_sfx_bpm  = @rhythm_bpm / 2.0
      @pending_dot_tick = false
      @pending_power_pellet = false

      NativeBridge.load_stems(@definitions) if @backend_mode == :native

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args, backend: @backend_mode)
      end
    end

    def tick(args)
      prune_sfx(args)
      advance_duck_amount
      sync_gains(args)
      flush_rhythmic_sfx(args)
    end

    def set_rhythm_bpm(bpm)
      @rhythm_bpm = bpm.to_f
      @rhythm_sfx_bpm = @rhythm_bpm / 2.0
    end

    def set_duck(_args, active:, gain_scale: 0.55, ramp_in: 8, ramp_out: 8, immediate: false)
      was_active = @duck_active
      @duck_active     = active
      @duck_gain_scale = gain_scale
      @duck_ramp_in_ticks = [ramp_in.to_i, 1].max
      @duck_ramp_out_ticks = [ramp_out.to_i, 1].max

      if immediate && active && !was_active
        @duck_amount = 1.0
      end
    end

    def duck_gain_multiplier
      (1.0 - @duck_amount * (1.0 - @duck_gain_scale)).clamp(0.0, 1.0)
    end

    def using_native_backend?
      @backend_mode == :native
    end

    def set_dot_totals(totals)
      @dot_totals.merge!(totals)
    end

    def on_dot_collected(args, color_or_track)
      track = resolve_track(color_or_track)
      return unless track

      @dot_counts[track] += 1
      ratio              = (@dot_counts[track].to_f / @dot_totals[track]).clamp(0.0, 1.0)
      @completion[track] = ratio
      @players[track].update_completion(ratio)
      @pending_dot_tick = true
    end

    def on_power_pellet(args)
      @pending_power_pellet = true
    end

    def on_enemy_eaten(args, sequence: 1)
      SFXPlayer.play(args, :enemy_eaten)
    end

    def on_game_over(args)
      TRACKS.each { |n| args.audio[@players[n].track_key]&.tap { |a| a.paused = true } }
      SFXPlayer.play(args, :game_over)
    end

    def on_level_complete(args)
      TRACKS.each do |n|
        @completion[n] = 1.0
        @players[n].unlock_fully
      end
      sync_gains(args)
    end

    def set_filter(track, type, **opts)
      raise ArgumentError, "Unknown track '#{track}'. Valid: #{TRACKS.join(', ')}" unless TRACKS.include?(track)
      raise ArgumentError, "Unknown filter '#{type}'."                              unless FilterFactory.valid?(type)

      @players[track].swap_filter(type, **opts)
    end

    def set_track_config(track, **overrides)
      raise ArgumentError, "Unknown track '#{track}'" unless TRACKS.include?(track)

      cfg = @configs[track]
      overrides.each do |key, value|
        raise ArgumentError, "Unknown TrackConfig field '#{key}'" unless cfg.respond_to?(:"#{key}=")
        cfg.send(:"#{key}=", value)
      end
    end

    def filter_type(track) = @players[track]&.filter_type

    def overall_completion
      @completion.values.sum / TRACKS.length.to_f
    end

    private

    def resolve_track(color_or_track)
      TRACKS.include?(color_or_track) ? color_or_track : DOT_COLORS[color_or_track]
    end

    def interpolated_params(track, t)
      cfg = @configs[track]
      t   = t.clamp(0.0, 1.0)

      cutoff_hz = interpolated_cutoff_hz(cfg, t)
      gain = cfg.start_gain + t * (cfg.end_gain - cfg.start_gain)

      [cutoff_hz, gain]
    end

    def sync_gains(args)
      TRACKS.each do |n|
        cutoff_hz, gain = interpolated_params(n, @completion[n])
        @players[n].apply_mix_settings(
          args,
          gain: gain,
          cutoff_hz: cutoff_hz,
          resonance: nil,
          duck_multiplier: duck_gain_multiplier,
          bypass_mix: 1.0
        )
      end
    end

    def interpolated_cutoff_hz(cfg, t)
      return nil unless cfg.start_cutoff.is_a?(Numeric)

      end_cutoff = cfg.end_cutoff == :bypass ? cfg.start_cutoff : cfg.end_cutoff
      return nil unless end_cutoff.is_a?(Numeric)

      start_hz = cfg.start_cutoff.to_f.clamp(MIN_CUTOFF_HZ, MAX_CUTOFF_HZ)
      end_hz = end_cutoff.to_f.clamp(MIN_CUTOFF_HZ, MAX_CUTOFF_HZ)
      return start_hz if start_hz == end_hz

      start_ln = Math.log(start_hz)
      end_ln = Math.log(end_hz)
      Math.exp(start_ln + t * (end_ln - start_ln))
    end

    def prune_sfx(args)
      args.audio
        .select { |k, v| k.to_s.start_with?("sfx_") && v[:stop_at] && args.tick_count >= v[:stop_at] }
        .each_key { |k| args.audio.delete(k) }
    end

    def advance_duck_amount
      if @duck_active
        step = 1.0 / @duck_ramp_in_ticks
        @duck_amount = [@duck_amount + step, 1.0].min
      else
        step = 1.0 / @duck_ramp_out_ticks
        @duck_amount = [@duck_amount - step, 0.0].max
      end
    end

    def flush_rhythmic_sfx(args)
      return unless BeatClock.step_changed?(args.tick_count, bpm: @rhythm_sfx_bpm)

      if @pending_power_pellet
        SFXPlayer.play(args, :power_pellet)
        @pending_power_pellet = false
        @pending_dot_tick = false
      elsif @pending_dot_tick
        SFXPlayer.play(args, :dot_tick)
        @pending_dot_tick = false
      end
    end
  end
end