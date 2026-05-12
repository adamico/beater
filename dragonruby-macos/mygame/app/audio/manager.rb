require 'app/audio/native_bridge.rb'
require 'app/audio/beat_clock.rb'
require 'app/audio/duck_controller.rb'
require 'app/audio/track_progression.rb'

module Audio
  class Manager
    TRACKS     = [:drums, :bass, :lead, :chords].freeze
    DOT_COLORS = { red: :drums, green: :bass, blue: :lead, yellow: :chords }.freeze

    EAT_DUCK_GAIN_SCALE  = 0.4
    EAT_DUCK_RAMP_IN     = 1
    EAT_DUCK_RAMP_OUT    = 2
    EAT_FREEZE_HOLD_TICKS = 45 # 0.75 * 60-tick freeze

    attr_reader :backend_mode

    def completion = @progression.completion
    def overall_completion = @progression.overall_completion
    def duck_active = @duck.active?
    def duck_amount = @duck.amount
    def duck_gain_scale = @duck.gain_scale
    def duck_gain_multiplier = @duck.gain_multiplier

    def initialize(args)
      @definitions  = TrackLibrary.build_all
      @players      = {}
      @progression  = TrackProgression.new(
        tracks:  TRACKS,
        configs: TRACK_CONFIGS.transform_values(&:dup)
      )

      @duck            = DuckController.new
      @backend_mode    = NativeBridge.backend_mode
      @rhythm_bpm      = BeatClock::DEFAULT_BPM
      @rhythm_sfx_bpm  = @rhythm_bpm / 2.0
      @pending_dot_tick = false
      @pending_power_pellet = false
      @eat_freeze_hold_remaining = 0
      @eat_freeze_releasing = false

      NativeBridge.load_stems(@definitions) if @backend_mode == :native

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args, backend: @backend_mode)
      end
    end

    def tick(args)
      prune_sfx(args)
      @duck.tick
      sync_gains(args)
      flush_rhythmic_sfx(args)
    end

    def set_rhythm_bpm(bpm)
      @rhythm_bpm = bpm.to_f
      @rhythm_sfx_bpm = @rhythm_bpm / 2.0
    end

    def set_duck(_args, **kwargs)
      @duck.set(**kwargs)
    end

    def using_native_backend?
      @backend_mode == :native
    end

    def set_dot_totals(totals)
      @progression.set_totals(totals)
    end

    def on_dot_collected(args, color_or_track)
      track = resolve_track(color_or_track)
      return unless track

      @progression.record_dot(track)
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

    def on_ghost_eat_imminent(args, imminent:)
      set_duck(args, active: imminent,
                     gain_scale: EAT_DUCK_GAIN_SCALE,
                     ramp_in: EAT_DUCK_RAMP_IN,
                     ramp_out: EAT_DUCK_RAMP_OUT)
    end

    def on_ghost_eat_freeze_begin(args)
      set_duck(args, active: true,
                     gain_scale: EAT_DUCK_GAIN_SCALE,
                     ramp_in: EAT_DUCK_RAMP_IN,
                     ramp_out: EAT_DUCK_RAMP_OUT,
                     immediate: true)
      @eat_freeze_hold_remaining = EAT_FREEZE_HOLD_TICKS
      @eat_freeze_releasing = false
    end

    def on_ghost_eat_freeze_tick(args)
      if !@eat_freeze_releasing
        set_duck(args, active: true,
                       gain_scale: EAT_DUCK_GAIN_SCALE,
                       ramp_in: EAT_DUCK_RAMP_IN,
                       ramp_out: EAT_DUCK_RAMP_OUT)
        @eat_freeze_hold_remaining -= 1
        @eat_freeze_releasing = true if @eat_freeze_hold_remaining <= 0
        :holding
      else
        set_duck(args, active: false,
                       gain_scale: EAT_DUCK_GAIN_SCALE,
                       ramp_in: EAT_DUCK_RAMP_IN,
                       ramp_out: EAT_DUCK_RAMP_OUT)
        @duck.amount <= 0.001 ? :done : :releasing
      end
    end

    def on_level_complete_duck_clear(args)
      set_duck(args, active: false,
                     gain_scale: EAT_DUCK_GAIN_SCALE,
                     ramp_in: EAT_DUCK_RAMP_IN,
                     ramp_out: EAT_DUCK_RAMP_OUT)
    end

    def on_level_complete(args)
      @progression.unlock_all
      sync_gains(args)
    end

    def set_filter(track, type, **opts)
      raise ArgumentError, "Unknown track '#{track}'. Valid: #{TRACKS.join(', ')}" unless TRACKS.include?(track)
      raise ArgumentError, "Unknown filter '#{type}'."                              unless FilterFactory.valid?(type)

      @players[track].swap_filter(type, **opts)
    end

    def set_track_config(track, **overrides)
      raise ArgumentError, "Unknown track '#{track}'" unless TRACKS.include?(track)
      @progression.set_config(track, **overrides)
    end

    def filter_type(track) = @players[track]&.filter_type

    private

    def resolve_track(color_or_track)
      TRACKS.include?(color_or_track) ? color_or_track : DOT_COLORS[color_or_track]
    end

    def sync_gains(args)
      TRACKS.each do |n|
        cutoff_hz, gain = @progression.params(n)
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

    def prune_sfx(args)
      args.audio
        .select { |k, v| k.to_s.start_with?("sfx_") && v[:stop_at] && args.tick_count >= v[:stop_at] }
        .each_key { |k| args.audio.delete(k) }
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