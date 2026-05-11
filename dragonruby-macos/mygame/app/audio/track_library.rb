module Audio
  class TrackDefinition
    attr_accessor :input_path

    def initialize(input_path:)
      @input_path = input_path
    end
  end

  module TrackLibrary
    STEM_PATHS = {
      drums: "sounds/music/drums.wav",
      bass: "sounds/music/bass.wav",
      lead: "sounds/music/lead.wav",
      chords: "sounds/music/chords.wav",
    }.freeze

    def self.build_all
      STEM_PATHS.transform_values { |path| TrackDefinition.new(input_path: path) }
    end
  end
end
