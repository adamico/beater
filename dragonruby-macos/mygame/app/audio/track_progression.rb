module Audio
  class TrackProgression
    MIN_CUTOFF_HZ = 20.0
    MAX_CUTOFF_HZ = 20_000.0

    def initialize(tracks:, configs:)
      @tracks     = tracks
      @configs    = configs
      @dot_totals = tracks.to_h { |t| [t, 20] }
      @dot_counts = tracks.to_h { |t| [t, 0] }
      @completion = tracks.to_h { |t| [t, 0.0] }
    end

    def set_totals(totals)
      @dot_totals.merge!(totals)
    end

    def record_dot(track)
      return nil unless @dot_counts.key?(track)
      @dot_counts[track] += 1
      ratio = (@dot_counts[track].to_f / @dot_totals[track]).clamp(0.0, 1.0)
      @completion[track] = ratio
      ratio
    end

    def unlock_all
      @tracks.each { |t| @completion[t] = 1.0 }
    end

    # New-level reset: dot counts and completion return to their initial
    # zero state so the filters re-close to each track's start_cutoff/gain.
    def reset_progress
      @tracks.each do |t|
        @dot_counts[t] = 0
        @completion[t] = 0.0
      end
    end

    def completion
      @completion
    end

    def overall_completion
      @completion.values.sum / @tracks.length.to_f
    end

    def params(track)
      cfg = @configs[track]
      t   = @completion[track].clamp(0.0, 1.0)

      cutoff_hz = interpolated_cutoff_hz(cfg, t)
      gain = cfg.start_gain + t * (cfg.end_gain - cfg.start_gain)
      [cutoff_hz, gain]
    end

    def config(track)
      @configs[track]
    end

    def set_config(track, **overrides)
      cfg = @configs[track]
      overrides.each do |key, value|
        raise ArgumentError, "Unknown TrackConfig field '#{key}'" unless cfg.respond_to?(:"#{key}=")
        cfg.send(:"#{key}=", value)
      end
    end

    private

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
  end
end
