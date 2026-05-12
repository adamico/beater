require 'app/audio/music_theory.rb'
require 'app/audio/wave_generator.rb'
require 'app/audio/track_config.rb'
require 'app/audio/beat_clock.rb'
require 'app/audio/track_library.rb'
require 'app/audio/track_player.rb'
require 'app/audio/sfx_player.rb'
require 'app/audio/manager.rb'

class RhythmAudioArgs
  attr_accessor :audio, :state, :tick_count

  def initialize
    @audio = {}
    @state = RhythmAudioState.new
    @tick_count = 0
  end
end

class RhythmAudioState
  attr_accessor :sfx_cache, :sfx_counter
end

def count_sfx_entries(args)
  args.audio.keys.count { |k| k.to_s.start_with?("sfx_") }
end

def test_dot_tick_is_queued_until_step_boundary args, assert
  audio_args = RhythmAudioArgs.new
  manager = Audio::Manager.new(audio_args)
  manager.set_dot_totals(drums: 4, bass: 1, lead: 1, chords: 1)
  manager.set_rhythm_bpm(120)

  manager.on_dot_collected(audio_args, :red)

  audio_args.tick_count = 1
  manager.tick(audio_args)
  assert.equal! count_sfx_entries(audio_args), 0

  audio_args.tick_count = 15
  manager.tick(audio_args)
  assert.equal! count_sfx_entries(audio_args), 1
end

def test_power_pellet_suppresses_dot_tick_on_same_boundary args, assert
  audio_args = RhythmAudioArgs.new
  manager = Audio::Manager.new(audio_args)
  manager.set_dot_totals(drums: 4, bass: 1, lead: 1, chords: 1)
  manager.set_rhythm_bpm(120)

  manager.on_dot_collected(audio_args, :red)
  manager.on_power_pellet(audio_args)

  audio_args.tick_count = 15
  manager.tick(audio_args)

  # One SFX should be emitted (power pellet priority), not both.
  assert.equal! count_sfx_entries(audio_args), 1
end