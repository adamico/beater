module Audio
  module MusicTheory
    SAMPLE_RATE = 48_000
    SEMITONES_FROM_A = {
      c: -9,
      cs: -8, db: -8,
      d: -7,
      ds: -6, eb: -6,
      e: -5,
      f: -4,
      fs: -3, gb: -3,
      g: -2,
      gs: -1, ab: -1,
      a: 0,
      as: 1,  bb: 1,
      b: 2,
    }.freeze
    SUPPORTED_OCTAVES = (0..8).freeze

    def self.semitone(offset)
      440.0 * (2.0 ** (offset / 12.0))
    end

    NOTE_FREQUENCIES = SUPPORTED_OCTAVES.each_with_object({}) do |octave, acc|
      SEMITONES_FROM_A.each do |name, offset_from_a4|
        acc["#{name}#{octave}".to_sym] = semitone(offset_from_a4 + (octave - 4) * 12)
      end
    end.freeze
  end
end
