class FrightenedTimer
  DURATION_TICKS = 360 # 6s @ 60fps (OG Lvl 1)

  attr_reader :remaining

  def initialize(&on_expire)
    @on_expire = on_expire
    @remaining = 0
  end

  def active?
    @remaining > 0
  end

  def trigger
    @remaining = DURATION_TICKS
  end

  def tick(&on_active_tick)
    return if @remaining <= 0
    @remaining -= 1
    on_active_tick&.call(@remaining)
    @on_expire&.call if @remaining == 0
  end

  def reset
    @remaining = 0
  end
end
