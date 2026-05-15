module Audio
  module WaveGenerator
    SR = MusicTheory::SAMPLE_RATE.to_f
    TWO_PI = 2.0 * Math::PI

    # Per-sample oscillator used by SFX_DEFINITIONS lambdas. Swap the symbol
    # to change waveform without rewriting the rest of the lambda.
    #
    #   s = WaveGenerator.osc(:sine,   freq, i)
    #   s = WaveGenerator.osc(:tri,    freq, i)
    #   s = WaveGenerator.osc(:saw,    freq, i)
    #   s = WaveGenerator.osc(:square, freq, i, duty: 0.3)  # 0..1 pulse width
    #   s = WaveGenerator.osc(:noise,  freq, i)             # freq/i ignored
    #
    # `duty` is read every call, so passing a time-varying value gives PWM.
    # Saw/square/tri are naive (no anti-aliasing) — fine up to a few kHz,
    # aliases above. Arcade flavour, not synth-perfect.
    def self.osc(kind, freq, i, duty: 0.5)
      case kind
      when :sine
        Math.sin(TWO_PI * freq * i / SR)
      when :tri
        p = freq * i / SR
        p -= p.floor
        p < 0.5 ? 4.0 * p - 1.0 : 3.0 - 4.0 * p
      when :saw
        p = freq * i / SR
        p -= p.floor
        2.0 * p - 1.0
      when :square
        p = freq * i / SR
        p -= p.floor
        p < duty ? 1.0 : -1.0
      when :noise
        rand * 2.0 - 1.0
      end
    end

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
