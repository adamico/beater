module Audio
  class Manager
    TRACKS     = [:drums, :bass, :lead, :chords].freeze
    DOT_COLORS = { red: :drums, green: :bass, blue: :lead, yellow: :chords }.freeze

    attr_reader :completion, :duck_active, :duck_amount, :duck_gain_scale

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

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args)
      end
    end

    def tick(args)
      prune_sfx(args)
      sync_gains(args)
    end

    def set_duck(_args, active:, gain_scale: 0.55, ramp_in: 8, ramp_out: 8)
      @duck_active     = active
      @duck_gain_scale = gain_scale
      @duck_amount     = active ? 1.0 : 0.0
    end

    def duck_gain_multiplier
      1.0
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
      SFXPlayer.play(args, :dot_tick)
    end

    def on_power_pellet(args)
      SFXPlayer.play(args, :power_pellet)
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

      gain = cfg.start_gain + t * (cfg.end_gain - cfg.start_gain)
      [nil, nil, gain]
    end

    def sync_gains(args)
      TRACKS.each do |n|
        _cutoff, _res, gain = interpolated_params(n, @completion[n])
        args.audio[@players[n].track_key]&.tap { |a| a.gain = gain }
      end
    end

    def prune_sfx(args)
      args.audio
        .select { |k, v| k.to_s.start_with?("sfx_") && v[:stop_at] && args.tick_count >= v[:stop_at] }
        .each_key { |k| args.audio.delete(k) }
    end
  end
end