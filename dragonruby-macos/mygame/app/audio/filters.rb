module Audio
  module FilterMath
    SR     = MusicTheory::SAMPLE_RATE.to_f
    TWO_PI = 2.0 * Math::PI

    def lp_alpha(cutoff_hz)
      1.0 - Math.exp(-TWO_PI * cutoff_hz.to_f / SR)
    end

    def hp_alpha(cutoff_hz)
      w = TWO_PI * cutoff_hz.to_f / SR
      1.0 / (1.0 + w)
    end
  end

  module Filters
    class Null
      def self.initial_state; {}; end
      def process(samples, _state) = samples
    end

    class LowPass
      include FilterMath

      def self.initial_state
        { lp_prev: 0.0 }
      end

      def initialize(cutoff: 800.0)
        @alpha = lp_alpha(cutoff)
      end

      def process(samples, state)
        prev = state[:lp_prev]
        out  = samples.map { |x| prev = prev + @alpha * (x - prev) }
        state[:lp_prev] = prev
        out
      end
    end

    class HighPass
      include FilterMath

      def self.initial_state
        { hp_prev_out: 0.0, hp_prev_in: 0.0 }
      end

      def initialize(cutoff: 500.0)
        @alpha = hp_alpha(cutoff)
      end

      def process(samples, state)
        prev_out = state[:hp_prev_out]
        prev_in  = state[:hp_prev_in]

        out = samples.map do |x|
          y        = @alpha * (prev_out + x - prev_in)
          prev_in  = x
          prev_out = y
          y
        end

        state[:hp_prev_out] = prev_out
        state[:hp_prev_in]  = prev_in
        out
      end
    end

    class BandPass
      include FilterMath

      def self.initial_state
        LowPass.initial_state.merge(HighPass.initial_state)
      end

      def initialize(cutoff: 1000.0, bandwidth: 400.0)
        half      = bandwidth.to_f / 2.0
        @lp_alpha = lp_alpha((cutoff + half).clamp(20.0, 20_000.0))
        @hp_alpha = hp_alpha((cutoff - half).clamp(20.0, 20_000.0))
      end

      def process(samples, state)
        prev   = state[:lp_prev]
        lp_out = samples.map { |x| prev = prev + @lp_alpha * (x - prev) }
        state[:lp_prev] = prev

        prev_out = state[:hp_prev_out]
        prev_in  = state[:hp_prev_in]
        out = lp_out.map do |x|
          y        = @hp_alpha * (prev_out + x - prev_in)
          prev_in  = x
          prev_out = y
          y
        end

        state[:hp_prev_out] = prev_out
        state[:hp_prev_in]  = prev_in
        out
      end
    end

    class DJ
      def self.initial_state
        { dj_low: 0.0, dj_band: 0.0 }
      end

      def initialize(cutoff: 200.0, resonance: 2.0)
        safe_cutoff = cutoff.to_f.clamp(20.0, 20_000.0)
        @f = 2.0 * Math.sin(Math::PI * safe_cutoff / MusicTheory::SAMPLE_RATE)
        @q = 1.0 / resonance.to_f.clamp(0.1, 8.0)
      end

      def process(samples, state)
        low  = state[:dj_low]
        band = state[:dj_band]

        out = samples.map do |x|
          low  = low  + @f * band
          high = x    - low - @q * band
          band = @f   * high + band
          low.clamp(-1.0, 1.0)
        end

        state[:dj_low]  = low
        state[:dj_band] = band
        out
      end
    end
  end

  module FilterFactory
    REGISTRY = {
      none:     Filters::Null,
      lowpass:  Filters::LowPass,
      highpass: Filters::HighPass,
      bandpass: Filters::BandPass,
      dj:       Filters::DJ,
    }.freeze

    def self.build(type, **opts)
      klass = REGISTRY.fetch(type) do
        raise ArgumentError, "Unknown filter '#{type}'. Valid: #{REGISTRY.keys.join(', ')}"
      end
      filter = klass == Filters::Null ? Filters::Null.new : klass.new(**opts)
      [filter, klass.initial_state]
    end

    def self.valid?(type) = REGISTRY.key?(type)
  end
end
