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

      @manual_filter = { drums: false, bass: false, lead: false, chords: false }

      @configs = TRACK_CONFIGS.transform_values(&:dup)

      @last_params = { drums: nil, bass: nil, lead: nil, chords: nil }

      @duck_active     = false
      @duck_amount     = 0.0
      @duck_gain_scale = 0.55
      @duck_ramp_in    = 8
      @duck_ramp_out   = 8

      TRACKS.each do |n|
        @players[n] = TrackPlayer.new(n, @definitions[n], args)
        apply_envelope(n, 0.0)
      end
    end

    def tick(args)
      update_duck_amount
      prune_sfx(args)
      sync_gains(args)
      update_auto_envelopes
    end

    def set_duck(_args, active:, gain_scale: 0.55, ramp_in: 8, ramp_out: 8)
      @duck_active     = active
      @duck_gain_scale = gain_scale
      @duck_ramp_in    = [ramp_in, 1].max
      @duck_ramp_out   = [ramp_out, 1].max
    end

    def duck_gain_multiplier
      1.0 - @duck_amount * (1.0 - @duck_gain_scale)
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

    def update_duck_amount
      target = @duck_active ? 1.0 : 0.0
      return if @duck_amount == target

      step = if @duck_active
               1.0 / @duck_ramp_in
             else
               1.0 / @duck_ramp_out
             end

      if @duck_active
        @duck_amount = [@duck_amount + step, 1.0].min
      else
        @duck_amount = [@duck_amount - step, 0.0].max
      end
    end

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
      cutoff, resonance      = envelope_params_for(track, t)

      if @duck_amount <= 0.0 && t >= 1.0 && cfg.bypass_at_full?
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
        _cutoff, _res, gain = interpolated_params(n, @completion[n])
        gain *= duck_gain_multiplier
        args.audio[@players[n].track_key]&.tap { |a| a.gain = gain }
      end
    end

    def update_auto_envelopes
      TRACKS.each do |n|
        next if @manual_filter[n]

        t                 = @completion[n]
        cutoff, resonance = envelope_params_for(n, t)
        new_params            = [cutoff, resonance]

        next if @last_params[n] == new_params

        @last_params[n] = new_params
        cfg             = @configs[n]

        if @duck_amount <= 0.0 && t >= 1.0 && cfg.bypass_at_full?
          @players[n].swap_filter(:none)
        else
          opts = { cutoff: cutoff }
          opts[:resonance] = resonance if resonance
          @players[n].swap_filter(cfg.filter_type, **opts)
        end
      end
    end

    def envelope_params_for(track, t)
      cfg                    = @configs[track]
      base_cutoff, base_res, = interpolated_params(track, t)
      return [base_cutoff, base_res] if @duck_amount <= 0.0

      duck_cutoff = cfg.start_cutoff.to_f
      cutoff      = (base_cutoff + @duck_amount * (duck_cutoff - base_cutoff)).round

      resonance = if base_res || cfg.start_resonance
                    start_res = base_res.nil? ? cfg.start_resonance : base_res
                    target_res = cfg.start_resonance.nil? ? start_res : cfg.start_resonance
                    start_res + @duck_amount * (target_res - start_res)
                  end

      [cutoff, resonance]
    end

    def prune_sfx(args)
      args.audio
        .select { |k, v| k.to_s.start_with?("sfx_") && v[:stop_at] && args.tick_count >= v[:stop_at] }
        .each_key { |k| args.audio.delete(k) }
    end
  end
end