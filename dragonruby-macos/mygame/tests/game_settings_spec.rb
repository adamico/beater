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
