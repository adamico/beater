require 'app/game_settings'

def test_game_settings_defaults_match_spec(_args, assert)
  GameSettings.reset!
  assert.equal! GameSettings.get(:master_volume), 0.8
  assert.equal! GameSettings.get(:music_volume), 0.7
  assert.equal! GameSettings.get(:sfx_volume), 0.9
  assert.equal! GameSettings.get(:fullscreen), false
  assert.equal! GameSettings.get(:reduced_flash), false
end

def test_game_settings_bus_multiplies_master_with_channel(_args, assert)
  GameSettings.reset!
  GameSettings.set(:master_volume, 0.5)
  GameSettings.set(:music_volume, 0.6)
  GameSettings.set(:sfx_volume, 1.0)
  assert.equal! GameSettings.music_gain.round(4), 0.3
  assert.equal! GameSettings.sfx_gain.round(4), 0.5
end

def test_game_settings_set_get_round_trip(_args, assert)
  GameSettings.reset!
  GameSettings.set(:master_volume, 0.42)
  GameSettings.set(:reduced_flash, true)
  assert.equal! GameSettings.get(:master_volume), 0.42
  assert.equal! GameSettings.get(:reduced_flash), true
end

def test_scene_director_return_to_survives_swap(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:settings, return_to: :playing)
  SceneDirector::FADE_FRAMES.times { SceneDirector.tick_transition }
  # return_to must persist past the swap so the destination scene can read
  # it on cancel (e.g. settings -> back to pause).
  assert.equal! SceneDirector.return_to, :playing
  assert.equal! SceneDirector.current, :settings
end

def test_scene_director_request_without_return_to_does_not_overwrite(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:settings, return_to: :playing)
  # While transitioning, a second request is ignored (Phase 1 guarantee),
  # so return_to from the first request stands.
  SceneDirector.request(:title)
  assert.equal! SceneDirector.return_to, :playing
end
