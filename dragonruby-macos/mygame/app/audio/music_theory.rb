module Audio
  module MusicTheory
    SAMPLE_RATE = 48_000

    def self.semitone(offset)
      440.0 * (2.0 ** (offset / 12.0))
    end

    NOTE_FREQUENCIES = {
      c4: semitone(-9),  d4: semitone(-7),  e4: semitone(-5),
      f4: semitone(-4),  g4: semitone(-2),  a4: semitone(0),
      b4: semitone(2),   c5: semitone(3),   d5: semitone(5),
      e5: semitone(7),   g5: semitone(10),  a5: semitone(12),
      c3: semitone(-21), g3: semitone(-14), a3: semitone(-12),
      f3: semitone(-16),
    }.freeze
  end
end
