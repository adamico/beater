module Audio
  module BeatClock
    STEPS_PER_LOOP = 64
    STEPS_PER_BEAT = 4.0
    FPS = 60.0
    DEFAULT_BPM = 128.0

    def self.frames_per_step(bpm: DEFAULT_BPM)
      (FPS * 60.0) / (bpm.to_f * STEPS_PER_BEAT)
    end

    def self.current_step(tick_count, bpm: DEFAULT_BPM)
      fps = frames_per_step(bpm: bpm)
      (tick_count.to_f / fps).floor % STEPS_PER_LOOP
    end

    def self.step_changed?(tick_count, bpm: DEFAULT_BPM)
      return true if tick_count == 0
      return false if tick_count < 0

      current_step(tick_count, bpm: bpm) != current_step(tick_count - 1, bpm: bpm)
    end

    def self.step_start_tick(step_index, bpm: DEFAULT_BPM)
      step_index.to_f * frames_per_step(bpm: bpm)
    end

    def self.scheduled_step_for_input(tick_count, bpm: DEFAULT_BPM, grace_ticks: 3)
      fps = frames_per_step(bpm: bpm)
      tick = tick_count.to_f
      current = (tick / fps).floor
      into_step = tick - current * fps
      return current + 1 if into_step <= 0.0

      until_next = fps - into_step
      until_next <= grace_ticks.to_f ? current + 1 : current + 2
    end
  end
end
