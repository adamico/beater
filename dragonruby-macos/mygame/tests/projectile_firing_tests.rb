require 'app/game.rb'
require_relative 'game_audio_wiring_tests.rb'

# Edge-triggered fire input: pressing Space spends one ammo and spawns a
# projectile in the player's current direction. Empty mag, no direction,
# or no key press all yield no spawn.

def fire_test_game
  game, args, _audio = build_game_with_spy_audio
  game.instance_variable_set(:@renderer, FakeRenderer.new)
  player = game.instance_variable_get(:@player)
  [game, args, player]
end

def fire_world(game, args)
  World.new(
    inputs: args.inputs,
    maze: game.instance_variable_get(:@maze),
    projection: game.instance_variable_get(:@projection),
    player: game.instance_variable_get(:@player),
    pellets: game.instance_variable_get(:@pellets),
    ghosts: game.instance_variable_get(:@ghosts)
  )
end

def press_space!(args)
  args.inputs.keyboard.key_down.define_singleton_method(:space) { true }
end

def release_space!(args)
  args.inputs.keyboard.key_down.define_singleton_method(:space) { false }
end

def test_fire_with_ammo_and_direction_spawns_projectile args, assert
  game, sys_args, player = fire_test_game
  player.gain_ammo
  press_space!(sys_args)
  game.tick_fire_input(fire_world(game, sys_args))
  projectiles = game.instance_variable_get(:@projectiles)
  assert.equal! projectiles.length, 1
  assert.equal! projectiles.first.direction, player.direction
  assert.equal! player.ammo, Player::AMMO_PER_POWER_PELLET - 1
end

def test_fire_with_zero_ammo_is_noop args, assert
  game, sys_args, player = fire_test_game
  player.reset_ammo!
  press_space!(sys_args)
  game.tick_fire_input(fire_world(game, sys_args))
  assert.equal! game.instance_variable_get(:@projectiles).length, 0
  assert.equal! player.ammo, 0
end

def test_fire_when_stationary_is_noop args, assert
  game, sys_args, player = fire_test_game
  player.gain_ammo
  player.face(Direction::NONE)
  press_space!(sys_args)
  game.tick_fire_input(fire_world(game, sys_args))
  assert.equal! game.instance_variable_get(:@projectiles).length, 0
  # No ammo consumed because we early-returned before consume_ammo!.
  assert.equal! player.ammo, Player::AMMO_PER_POWER_PELLET
end

def test_no_fire_when_space_not_pressed args, assert
  game, sys_args, player = fire_test_game
  player.gain_ammo
  release_space!(sys_args)
  game.tick_fire_input(fire_world(game, sys_args))
  assert.equal! game.instance_variable_get(:@projectiles).length, 0
  assert.equal! player.ammo, Player::AMMO_PER_POWER_PELLET
end

def test_two_presses_spawn_two_projectiles args, assert
  game, sys_args, player = fire_test_game
  player.gain_ammo
  press_space!(sys_args)
  game.tick_fire_input(fire_world(game, sys_args))
  game.tick_fire_input(fire_world(game, sys_args))
  assert.equal! game.instance_variable_get(:@projectiles).length, 2
  assert.equal! player.ammo, Player::AMMO_PER_POWER_PELLET - 2
end
