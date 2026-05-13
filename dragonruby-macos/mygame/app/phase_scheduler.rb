class PhaseScheduler
  PHASE_TABLE = [
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  7 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   20 * 60],
    [:scatter,  5 * 60],
    [:chase,   nil]
  ].freeze

  def initialize(&on_phase_change)
    @on_phase_change = on_phase_change
    reset
  end

  def current_mode
    PHASE_TABLE[@phase_index][0]
  end

  def tick
    _, dur = PHASE_TABLE[@phase_index]
    return if dur.nil?
    @phase_ticks += 1
    return if @phase_ticks < dur
    @phase_index += 1
    @phase_ticks = 0
    @on_phase_change&.call(current_mode)
  end

  def reset
    @phase_index = 0
    @phase_ticks = 0
  end
end
