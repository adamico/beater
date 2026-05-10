module Audio
  class Manager
    TRACKS     = [:drums, :bass, :lead, :chords].freeze
    DOT_COLORS = { red: :drums, green: :bass, blue: :lead, yellow: :chords }.freeze

    attr_reader :completion

    def initialize(args)
      @definitions  = TrackLibrary.build_all
      @players      = {}
      @dot_totals   = { drums: 20, bass: 20, lead: 20, chords: 20 }
      @dot_counts   = { drums: 0,  bass: 0,  lead: 0,  chords: 0  }
      @completion   = { drums: 0.0, bass: 0.0, lead: 0.0, chords: 0.0 }

      @manual_filter = { drums: false, bass: false, lead: false, chords: false }

      @configs = TRACK_CONFIGS.transform_values(&:dup)

      @last_params = { drums: nil, bass: nil, lead: nil, chords: nil }

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args)
        apply_envelope(n, 0.0)
      end
    end

    def tick(args)
      prune_sfx(args)
      sync_gains(args)
      update_auto_envelopes
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
      @players[track].queue_dot_sfx
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
        unless @manual_filter[n]
          cfg = @configs[n]
          cfg.bypass_at_full? ? @players[n].swap_filter(:none) : apply_envelope(n, 1.0)
        end
      end
      sync_gains(args)
    end

    def set_filter(track, type, **opts)
      raise ArgumentError, "Unknown track '#{track}'. Valid: #{TRACKS.join(', ')}" unless TRACKS.include?(track)
      raise ArgumentError, "Unknown filter '#{type}'."                              unless FilterFactory.valid?(type)

      @manual_filter[track] = (type != :none)
      @last_params[track]   = nil
      @players[track].swap_filter(type, **opts)
    end

    def set_track_config(track, **overrides)
      raise ArgumentError, "Unknown track '#{track}'" unless TRACKS.include?(track)

      cfg = @configs[track]
      overrides.each do |key, value|
        raise ArgumentError, "Unknown TrackConfig field '#{key}'" unless cfg.respond_to?(:"#{key}=")
        cfg.send(:"#{key}=", value)
      end
      @last_params[track] = nil
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

      end_cutoff = cfg.bypass_at_full? ? 20_000.0 : cfg.end_cutoff.to_f
      cutoff     = (cfg.start_cutoff + t * (end_cutoff - cfg.start_cutoff)).round

      resonance = if cfg.start_resonance
                    cfg.start_resonance + t * (cfg.end_resonance - cfg.start_resonance)
                  end

      [cutoff, resonance, gain]
    end

    def apply_envelope(track, t)
      cfg                   = @configs[track]
      cutoff, resonance, _gain = interpolated_params(track, t)

      if t >= 1.0 && cfg.bypass_at_full?
        @players[track].swap_filter(:none)
      else
        opts = { cutoff: cutoff }
        opts[:resonance] = resonance if resonance
        @players[track].swap_filter(cfg.filter_type, **opts)
      end

      @last_params[track] = [cutoff, resonance]
    end

    def sync_gains(args)
      TRACKS.each do |n|
        cutoff, _res, gain = interpolated_params(n, @completion[n])
        args.audio[@players[n].track_key]&.tap { |a| a.gain = gain }
      end
    end

    def update_auto_envelopes
      TRACKS.each do |n|
        next if @manual_filter[n]

        t                     = @completion[n]
        cutoff, resonance, _g = interpolated_params(n, t)
        new_params            = [cutoff, resonance]

        next if @last_params[n] == new_params

        @last_params[n] = new_params
        cfg             = @configs[n]

        if t >= 1.0 && cfg.bypass_at_full?
          @players[n].swap_filter(:none)
        else
          opts = { cutoff: cutoff }
          opts[:resonance] = resonance if resonance
          @players[n].swap_filter(cfg.filter_type, **opts)
        end
      end
    end

    def prune_sfx(args)
      args.audio
        .select { |k, v| k.to_s.start_with?("sfx_") && v[:stop_at] && args.tick_count >= v[:stop_at] }
        .each_key { |k| args.audio.delete(k) }
    end
  end
end