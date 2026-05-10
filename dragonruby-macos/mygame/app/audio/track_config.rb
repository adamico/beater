module Audio
  class TrackConfig
    attr_accessor :filter_type,
                  :start_cutoff, :end_cutoff,
                  :start_resonance, :end_resonance,
                  :start_gain, :end_gain

    def initialize(filter_type:, start_cutoff:, end_cutoff:,
                   start_gain:, end_gain:,
                   start_resonance: nil, end_resonance: nil)
      @filter_type     = filter_type
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
        filter_type:     @filter_type,
        start_cutoff:    @start_cutoff,    end_cutoff:    @end_cutoff,
        start_resonance: @start_resonance, end_resonance: @end_resonance,
        start_gain:      @start_gain,      end_gain:      @end_gain,
      )
    end
  end

  TRACK_CONFIGS = {
    drums: TrackConfig.new(
      filter_type:      :dj,
      start_cutoff:     900,    end_cutoff:     8_000,
      start_resonance:  2.5,    end_resonance:  0.5,
      start_gain:       0.70,   end_gain:       1.0
    ),
    bass: TrackConfig.new(
      filter_type:      :lowpass,
      start_cutoff:     500,    end_cutoff:     4_000,
      start_resonance:  nil,    end_resonance:  nil,
      start_gain:       0.80,   end_gain:       0.90
    ),
    lead: TrackConfig.new(
      filter_type:      :dj,
      start_cutoff:     600,    end_cutoff:     6_000,
      start_resonance:  3.0,    end_resonance:  0.8,
      start_gain:       0.50,   end_gain:       1.0
    ),
    chords: TrackConfig.new(
      filter_type:      :lowpass,
      start_cutoff:     300,    end_cutoff:     :bypass,
      start_resonance:  nil,    end_resonance:  nil,
      start_gain:       0.30,   end_gain:       1.0
    ),
  }.freeze
end
