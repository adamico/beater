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
unless PROGRESSION_TESTER_MODE
  require 'app/game.rb'
  require 'app/scenes/scene_director.rb'
  require 'app/scenes/menu_input.rb'
  require 'app/scenes/menu_controller.rb'
  require 'app/scenes/menu_renderer.rb'
  require 'app/scenes/title.rb'
end

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

  $title ||= Scenes::Title.new

  # Apply pending scene swap at the apex of the fade-out (see ADR-0012).
  SceneDirector.tick_transition { apply_scene_swap(args) }

  case SceneDirector.current
  when :title
    $title.tick(args)
  when :playing
    $game ||= Game.new
    $game.args = args
    $game.tick
    SceneDirector.draw_fade(args.outputs) if SceneDirector.transitioning?
  end

  if args.state.request_game_reset
    reset(args)
  end
end

# Runs once per scene swap, at the fade apex. Build/teardown live `Game`,
# audio, etc. here — this is the only full-rebuild path.
def apply_scene_swap(args)
  case SceneDirector.current
  when :title
    $game = nil
    Audio::NativeBridge.reset_runtime_state!
    args.state.audio = nil
  when :playing
    if $game.nil?
      Audio::NativeBridge.reset_runtime_state!
      args.state.audio = nil
      $game = Game.new
    end
  end
end

def reset args
  $game = nil
  Audio::NativeBridge.reset_runtime_state!
  args.state.audio = nil
  args.state.request_game_reset = false
  SceneDirector.request(:title)
end
