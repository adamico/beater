require 'app/audio/native_bridge.rb'
require 'app/audio/beat_clock.rb'
require 'app/audio/duck_controller.rb'
require 'app/audio/track_progression.rb'
require 'app/audio/sfx_player.rb'
require 'app/game_settings.rb'

module Audio
  class Manager
    TRACKS     = [:drums, :bass, :lead, :chords].freeze
    DOT_COLORS = { red: :drums, green: :bass, blue: :lead, yellow: :chords }.freeze

    # Retained only for on_level_complete_duck_clear (defensive duck reset).
    EAT_DUCK_GAIN_SCALE  = 0.4
    EAT_DUCK_RAMP_IN     = 1
    EAT_DUCK_RAMP_OUT    = 2

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

      NativeBridge.load_stems(@definitions) if @backend_mode == :native

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args, backend: @backend_mode)
      end
    end

    def tick(args)
      prune_sfx(args)
      @duck.tick
      sync_gains(args)
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
      SFXPlayer.play(args, :dot_tick)
    end

    def on_power_pellet(args)
      SFXPlayer.play(args, :power_pellet)
    end

    # G1: a Track reached 100% completion — milestone stinger.
    def on_track_complete(args)
      SFXPlayer.play(args, :track_complete)
    end

    def on_enemy_eaten(args, sequence: 1)
      SFXPlayer.play(args, :enemy_eaten)
    end

    # ADR-0011: bullet partially absorbed by an :enrage1 ghost.
    def on_bullet_absorbed(args)
      SFXPlayer.play(args, :bullet_absorbed)
    end

    # ADR-0011: bullet hit an immune (:enrage2) ghost — never kills.
    def on_bullet_immune(args)
      SFXPlayer.play(args, :bullet_immune)
    end

    # Music ducks out on player death (Dying phase 1). Eased via ramp_in.
    DEATH_DUCK_GAIN_SCALE = 0.12
    DEATH_DUCK_RAMP_IN    = 18

    def on_player_death(args)
      set_duck(args, active: true,
                     gain_scale: DEATH_DUCK_GAIN_SCALE,
                     ramp_in: DEATH_DUCK_RAMP_IN,
                     ramp_out: 8)
    end

    # Music eases back in to the current mix while the camera returns
    # (Dying phase 2). `ramp_out` matches the camera ease duration.
    def on_respawn(args, ramp_out: 30)
      set_duck(args, active: false,
                     gain_scale: DEATH_DUCK_GAIN_SCALE,
                     ramp_in: DEATH_DUCK_RAMP_IN,
                     ramp_out: ramp_out)
    end

    # One metronome click per beat of the Ready-state count-in.
    def on_count_in_beat(args)
      SFXPlayer.play(args, :dot_tick)
    end

    def on_game_over(args)
      TRACKS.each { |n| args.audio[@players[n].track_key]&.tap { |a| a.paused = true } }
      SFXPlayer.play(args, :game_over)
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

    # New level started: track filters re-close to their configured initial
    # values (undoing on_level_complete's unlock_all).
    def on_level_start(args)
      @progression.reset_progress
      sync_gains(args)
    end

    def set_track_config(track, **overrides)
      raise ArgumentError, "Unknown track '#{track}'" unless TRACKS.include?(track)
      @progression.set_config(track, **overrides)
    end

    private

    def resolve_track(color_or_track)
      TRACKS.include?(color_or_track) ? color_or_track : DOT_COLORS[color_or_track]
    end

    def sync_gains(args)
      music_bus = GameSettings.music_gain
      TRACKS.each do |n|
        cutoff_hz, gain = @progression.params(n)
        @players[n].apply_mix_settings(
          args,
          gain: gain * music_bus,
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
  end
end