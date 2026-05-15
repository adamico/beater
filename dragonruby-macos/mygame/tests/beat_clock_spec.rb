require 'app/audio/beat_clock.rb'

def test_current_step_uses_bpm_derived_float_timing args, assert
  bpm = 120
  assert.equal! Audio::BeatClock.current_step(0, bpm: bpm), 0
  assert.equal! Audio::BeatClock.current_step(7, bpm: bpm), 0
  assert.equal! Audio::BeatClock.current_step(8, bpm: bpm), 1
  assert.equal! Audio::BeatClock.current_step(15, bpm: bpm), 2
end

def test_schedule_step_uses_early_grace_window args, assert
  bpm = 120

  # tick=5 is 2.5 frames before next 16th step at tick=7.5.
  near = Audio::BeatClock.scheduled_step_for_input(5, bpm: bpm, grace_ticks: 3)
  far = Audio::BeatClock.scheduled_step_for_input(1, bpm: bpm, grace_ticks: 3)

  assert.equal! near, 1
  assert.equal! far, 2
end

def test_step_formula_does_not_accumulate_rounding_drift args, assert
  bpm = 140
  frames_per_step = Audio::BeatClock.frames_per_step(bpm: bpm)
  ticks = 5 * 60 # 5 minutes @ 60fps

  expected_steps = (ticks.to_f / frames_per_step).floor % Audio::BeatClock::STEPS_PER_LOOP
  actual_steps = Audio::BeatClock.current_step(ticks, bpm: bpm)

  assert.equal! actual_steps, expected_steps
end
