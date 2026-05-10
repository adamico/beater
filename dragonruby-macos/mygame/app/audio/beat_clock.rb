module Audio
  module BeatClock
    TICKS_PER_STEP = 8
    STEPS_PER_LOOP = 64

    def self.current_step(tick_count) = (tick_count / TICKS_PER_STEP) % STEPS_PER_LOOP
    def self.step_changed?(tick_count) = tick_count % TICKS_PER_STEP == 0
  end
end
