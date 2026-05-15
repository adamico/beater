require 'app/audio/music_theory'
require 'app/audio/wave_generator'
require 'app/audio/track_config'
require 'app/audio/beat_clock'
require 'app/audio/track_library'
require 'app/audio/native_bridge'
require 'app/audio/track_player'
require 'app/audio/sfx_player'
require 'app/audio/manager'
require 'app/game_settings'
require 'app/highscores'
require 'app/game'
require 'app/scenes/scene_director'
require 'app/scenes/scene_layout'
require 'app/scenes/scrollable_list'
require 'app/scenes/menu_input'
require 'app/scenes/menu_controller'
require 'app/scenes/menu_renderer'
require 'app/scenes/menu_scene'
require 'app/scenes/title'
require 'app/scenes/settings'
require 'app/scenes/credits'
require 'app/scenes/instructions'
require 'app/jukebox'

def boot(_args)
  begin
    DR.ffi_misc.gtk_dlopen('audio_stem_fx')
  rescue StandardError
    # Native bridge will fall back to legacy mode if loading fails.
  end
  GameSettings.load!
  GameSettings.apply_window!
  Highscores.load!
end

def tick(args)
  $title ||= Scenes::Title.new

  # Apply pending scene swap at the apex of the fade-out (see ADR-0012).
  SceneDirector.tick_transition { apply_scene_swap(args) }

  case SceneDirector.current
  when :title
    $title.tick(args)
  when :settings
    $settings ||= Scenes::Settings.new
    $settings.tick(args)
  when :credits
    $credits ||= Scenes::Credits.new
    $credits.tick(args)
  when :instructions
    $instructions ||= Scenes::Instructions.new
    $instructions.tick(args)
  when :jukebox
    ProgressionTester.tick(args)
    SceneDirector.draw_fade(args.outputs) if SceneDirector.transitioning?
  when :playing
    $game ||= Game.new
    $game.args = args
    $game.tick
    SceneDirector.draw_fade(args.outputs) if SceneDirector.transitioning?
  end

  Scenes::SceneLayout.tick_debug(args)

  if args.state.request_replay
    replay(args)
  elsif args.state.request_game_reset
    reset(args)
  end
end

# Runs once per scene swap, at the fade apex. Build/teardown live `Game`,
# audio, etc. here — this is the only full-rebuild path.
def apply_scene_swap(args)
  case SceneDirector.current
  when :title
    # Returning to title from anywhere drops the run.
    $game = nil
    $settings = nil
    $credits = nil
    $instructions = nil
    args.state.pt_version = nil
    Audio::NativeBridge.reset_runtime_state!
    args.state.audio = nil
  when :playing
    # Settings → playing keeps the existing Game (pause survives the round-trip).
    $settings = nil
    if $game.nil?
      Audio::NativeBridge.reset_runtime_state!
      args.state.audio = nil
      $game = Game.new
    end
  when :settings
    # Settings can be reached from title or pause — both keep $game intact.
  when :jukebox
    # Jukebox is reachable only from title where $game is already nil.
    # Drop audio so ProgressionTester rebuilds a fresh Audio::Manager.
    Audio::NativeBridge.reset_runtime_state!
    args.state.audio = nil
    args.state.pt_version = nil
  end
end

def reset(args)
  $game = nil
  Audio::NativeBridge.reset_runtime_state!
  args.state.audio = nil
  args.state.request_game_reset = false
  SceneDirector.request(:title)
end

# RETRY from game-over: full Game rebuild without bouncing through title.
# Re-enters scene :playing; apply_scene_swap sees $game == nil and rebuilds.
def replay(args)
  $game = nil
  Audio::NativeBridge.reset_runtime_state!
  args.state.audio = nil
  args.state.request_replay = false
  SceneDirector.request(:playing)
end
