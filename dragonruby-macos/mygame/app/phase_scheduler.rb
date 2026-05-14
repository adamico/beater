require 'app/level_config.rb'

# Drives ghost scatter/chase mode changes. The phase table is per-Level data
# owned by LevelConfig and injected via load_table — see CONTEXT.md "Level".
class PhaseScheduler
  def initialize(table: LevelConfig::PHASE_TIER1, &on_phase_change)
    @on_phase_change = on_phase_change
    @table = table
    reset
  end

  # Swap in a new level's phase table and restart from phase 0.
  def load_table(table)
    @table = table
    reset
  end

  def current_mode
    @table[@phase_index][0]
  end

  def tick
    _, dur = @table[@phase_index]
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
