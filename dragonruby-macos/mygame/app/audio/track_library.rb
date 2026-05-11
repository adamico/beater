module Audio
  class TrackDefinition
    attr_accessor :pattern, :wave_fn, :sfx_fn

    def initialize(pattern:, wave_fn:, sfx_fn:)
      @pattern = pattern
      @wave_fn = wave_fn
      @sfx_fn  = sfx_fn
    end
  end

  module TrackLibrary
    DENSITY_MASKS = {
      sparse: (0...64).select { |i| i % 16 == 0 },
      medium: (0...64).select { |i| i % 4  == 0 },
      dense:  (0...64).select { |i| i % 2  == 0 },
      full:   (0...64).to_a,
    }.freeze

    def self.build_all
      { drums: build_drums, bass: build_bass, lead: build_lead, chords: build_chords }
    end

    def self.build_drums
      kick_buf  = WaveGenerator.kick
      snare_buf = WaveGenerator.snare
      hihat_buf = WaveGenerator.hihat
      pattern   = Array.new(64, nil)

      64.times do |s|
        pattern[s] = case s % 16
                     when 0, 8          then :kick
                     when 4, 12         then :snare
                     when 2, 6, 10, 14  then :hihat
                     end
      end

      wave_fn = ->(n) { { kick: kick_buf, snare: snare_buf, hihat: hihat_buf }[n] }
      sfx_fn  = -> { WaveGenerator.kick(duration_frames: 4) }
      TrackDefinition.new(pattern: pattern, wave_fn: wave_fn, sfx_fn: sfx_fn)
    end

    BASS_NOTES = [:a2, :c2, :g2, :a2, :f2, :g2, :a2, :g2].freeze

    def self.build_bass
      cache   = {}
      pattern = Array.new(64, nil)
      64.times { |s| pattern[s] = BASS_NOTES[(s / 8) % BASS_NOTES.length] if [0,4,8,12].include?(s % 16) }
      wave_fn = ->(n) { cache[n] ||= WaveGenerator.sawtooth_period(MusicTheory::NOTE_FREQUENCIES[n]) }
      sfx_fn  = -> { WaveGenerator.sawtooth_period(MusicTheory::NOTE_FREQUENCIES[:a3]).first(800) }
      TrackDefinition.new(pattern: pattern, wave_fn: wave_fn, sfx_fn: sfx_fn)
    end

    LEAD_ARP = [:a4, :c5, :e5, :g5, :e5, :c5, :a4, :e5].freeze

    def self.build_lead
      cache   = {}
      pattern = Array.new(64, nil)
      64.times { |s| pattern[s] = LEAD_ARP[s % LEAD_ARP.length] if s.even? }
      wave_fn = ->(n) { cache[n] ||= WaveGenerator.square_period(MusicTheory::NOTE_FREQUENCIES[n], duty: 0.25) }
      sfx_fn  = -> { WaveGenerator.square_period(MusicTheory::NOTE_FREQUENCIES[:a4], duty: 0.25).first(800) }
      TrackDefinition.new(pattern: pattern, wave_fn: wave_fn, sfx_fn: sfx_fn)
    end

    CHORDS_MELODY = [
      :a4, nil, :c5, nil, :e5, nil, :d5, nil, :g5, nil, :e5, nil, :a4, nil, nil, nil,
      :c5, nil, :e5, nil, :g5, nil, :e5, nil, :d5, nil, :c5, nil, :a4, nil, nil, nil,
      :a5, nil, nil, nil, :g5, nil, :e5, nil, :d5, nil, :e5, nil, :g5, nil, nil, nil,
      :a4, nil, :c5, nil, :e5, nil, :g5, nil, :a5, nil, nil, nil, nil, nil, nil, nil,
    ].freeze

    def self.build_chords
      cache   = {}
      wave_fn = ->(n) { cache[n] ||= WaveGenerator.sine_period(MusicTheory::NOTE_FREQUENCIES[n]) }
      sfx_fn  = -> { WaveGenerator.sine_period(MusicTheory::NOTE_FREQUENCIES[:a5]).first(800) }
      TrackDefinition.new(pattern: CHORDS_MELODY.dup, wave_fn: wave_fn, sfx_fn: sfx_fn)
    end
  end
end
