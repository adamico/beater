module Audio
  module WaveGenerator
    SR = MusicTheory::SAMPLE_RATE.to_f

    def self.sine_period(freq)
      n = (SR / freq).ceil
      n.map_with_index { |i| Math.sin(2.0 * Math::PI * i / n) }
    end

    def self.sawtooth_period(freq)
      n = (SR / freq).ceil
      n.map_with_index { |i| 2.0 * i.to_f / n - 1.0 }
    end

    def self.square_period(freq, duty: 0.5)
      n = (SR / freq).ceil
      n.map_with_index { |i| i.to_f / n < duty ? 1.0 : -1.0 }
    end

    def self.kick(duration_frames: 6, frequency: 80)
      total = (SR * duration_frames / 60.0).ceil
      n     = (SR / frequency).ceil
      total.map_with_index do |i|
        Math.exp(-5.0 * i / total) * Math.sin(2.0 * Math::PI * i / n)
      end
    end

    def self.snare(duration_frames: 4)
      total = (SR * duration_frames / 60.0).ceil
      rng   = Random.new(42)
      total.map_with_index { |i| (rng.rand * 2.0 - 1.0) * Math.exp(-8.0 * i / total) }
    end

    def self.hihat(duration_frames: 2)
      total = (SR * duration_frames / 60.0).ceil
      rng   = Random.new(99)
      total.map_with_index { |i| (rng.rand * 2.0 - 1.0) * Math.exp(-20.0 * i / total) * 0.4 }
    end

    def self.tile_to_frame(period)
      frame_size = (SR / 60.0).ceil
      copies     = (frame_size.to_f / period.length).ceil + 1
      (period * copies).first(frame_size)
    end

    SILENCE_FRAME = Array.new((SR / 60.0).ceil, 0.0).freeze
  end
end
