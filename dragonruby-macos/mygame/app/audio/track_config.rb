module Audio
  class TrackConfig
    attr_accessor :start_cutoff, :end_cutoff,
                  :start_resonance, :end_resonance,
                  :start_gain, :end_gain

    def initialize(start_cutoff:, end_cutoff:,
                   start_gain:, end_gain:,
                   start_resonance: nil, end_resonance: nil)
      @start_cutoff    = start_cutoff
      @end_cutoff      = end_cutoff
      @start_resonance = start_resonance
      @end_resonance   = end_resonance
      @start_gain      = start_gain
      @end_gain        = end_gain
    end

    def bypass_at_full?
      @end_cutoff == :bypass
    end

    def dup
      TrackConfig.new(
        start_cutoff:    @start_cutoff,    end_cutoff:    @end_cutoff,
        start_resonance: @start_resonance, end_resonance: @end_resonance,
        start_gain:      @start_gain,      end_gain:      @end_gain,
      )
    end
  end

  TRACK_CONFIGS = {
    drums: TrackConfig.new(
      start_cutoff:     800,    end_cutoff:     7_000,
      start_resonance:  2.5,    end_resonance:  0.5,
      start_gain:       0.2,    end_gain:       0.6
    ),
    bass: TrackConfig.new(
      start_cutoff:     500,    end_cutoff:     7_000,
      start_resonance:  nil,    end_resonance:  nil,
      start_gain:       0.2,    end_gain:       0.6
    ),
    lead: TrackConfig.new(
      start_cutoff:     600,    end_cutoff:     7_000,
      start_resonance:  2.4,    end_resonance:  0.8,
      start_gain:       0.01,   end_gain:       0.3
    ),
    chords: TrackConfig.new(
      start_cutoff:     300,    end_cutoff:     7_000,
      start_resonance:  nil,    end_resonance:  nil,
      start_gain:       0.1,    end_gain:       0.4
    ),
  }.freeze
end
