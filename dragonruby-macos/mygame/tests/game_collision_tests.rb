require 'app/game.rb'
require_relative 'game_audio_wiring_tests.rb'

# Body-contact with any non-house, non-eaten ghost kills the player.
# The frightened-eats-on-touch path is gone (ADR-0007).

def collision_setup
  game, args, _audio = build_game_with_spy_audio
  game.instance_variable_set(:@renderer, FakeRenderer.new)
  [game, args]
end

def place_player_on_ghost(game, ghost)
  player = game.instance_variable_get(:@player)
  player.x = ghost.x
  player.y = ghost.y
end

def first_active_ghost_for_collision(game)
  game.instance_variable_get(:@ghosts).find { |g| g.state != :in_house && g.state != :eaten }
end

def test_body_contact_with_active_ghost_enters_dying args, assert
  game, _args = collision_setup
  ghost = first_active_ghost_for_collision(game)
  lives_before = game.instance_variable_get(:@lives)

  # Body-contact no longer teleports instantly: it enters the Dying state,
  # decrements a life, and begins the death animation. The actual respawn
  # happens later when the animation completes.
  place_player_on_ghost(game, ghost)
  game.tick_collisions

  player = game.instance_variable_get(:@player)
  assert.equal! game.instance_variable_get(:@state), :dying
  assert.equal! game.instance_variable_get(:@lives), lives_before - 1
  assert.true! player.dying?
end

def test_body_contact_with_eaten_ghost_does_not_kill args, assert
  game, _args = collision_setup
  ghost = first_active_ghost_for_collision(game)
  ghost.state = :eaten
  place_player_on_ghost(game, ghost)
  spawn_cell = game.instance_variable_get(:@player_spawn)
  spawn = game.instance_variable_get(:@projection).cell_rect(*spawn_cell)
  pre_x = game.instance_variable_get(:@player).x

  game.tick_collisions

  player = game.instance_variable_get(:@player)
  # If the player got reset to spawn it'd match spawn[:x]; we should still be
  # on top of the ghost (i.e. unchanged).
  assert.equal! player.x, pre_x
end

def test_player_dies_preserves_ammo args, assert
  game, _args = collision_setup
  player = game.instance_variable_get(:@player)
  player.gain_ammo
  ghost = first_active_ghost_for_collision(game)
  place_player_on_ghost(game, ghost)

  game.tick_collisions

  assert.equal! player.ammo, Player::AMMO_PER_POWER_PELLET
end

def test_level_complete_resets_ammo args, assert
  game, _args = collision_setup
  player = game.instance_variable_get(:@player)
  player.gain_ammo

  game.instance_variable_set(:@pellets, Pellets.new({}))
  game.check_level_complete

  assert.equal! player.ammo, 0
end
