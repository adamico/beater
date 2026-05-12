require 'app/audio/music_theory.rb'
require 'app/audio/wave_generator.rb'
require 'app/audio/track_config.rb'
require 'app/audio/beat_clock.rb'
require 'app/audio/track_library.rb'
require 'app/audio/native_bridge.rb'
require 'app/audio/track_player.rb'
require 'app/audio/sfx_player.rb'
require 'app/audio/manager.rb'

PROGRESSION_TESTER_MODE = (
  File.exist?('mygame/tmp/progression_tester_mode') ||
  File.exist?('tmp/progression_tester_mode')
).freeze

require 'tools/progression_tester.rb' if PROGRESSION_TESTER_MODE
require 'app/game.rb' unless PROGRESSION_TESTER_MODE

def boot args
  begin
    DR.ffi_misc.gtk_dlopen('audio_stem_fx')
  rescue StandardError
    # Native bridge will fall back to legacy mode if loading fails.
  end
end

def tick args
  if PROGRESSION_TESTER_MODE
    ProgressionTester.tick(args)
    return
  end

  $game ||= Game.new
  $game.args = args
  $game.tick

  if args.state.request_game_reset
    reset(args)
  end
end

def reset args
  $game = nil
  Audio::NativeBridge.reset_runtime_state!
  args.state.audio = nil
  args.state.request_game_reset = false
end
