module Audio
  class DuckController
    attr_reader :gain_scale, :amount

    def initialize
      @active = false
      @amount = 0.0
      @gain_scale = 1.0
      @ramp_in_ticks = 8
      @ramp_out_ticks = 8
    end

    def active?
      @active
    end

    def set(active:, gain_scale: 0.55, ramp_in: 8, ramp_out: 8, immediate: false)
      was_active = @active
      @active = active
      @gain_scale = gain_scale
      @ramp_in_ticks = [ramp_in.to_i, 1].max
      @ramp_out_ticks = [ramp_out.to_i, 1].max

      if immediate && active && !was_active
        @amount = 1.0
      end
    end

    def tick
      if @active
        step = 1.0 / @ramp_in_ticks
        @amount = [@amount + step, 1.0].min
      else
        step = 1.0 / @ramp_out_ticks
        @amount = [@amount - step, 0.0].max
      end
    end

    def gain_multiplier
      (1.0 - @amount * (1.0 - @gain_scale)).clamp(0.0, 1.0)
    end
  end
end
