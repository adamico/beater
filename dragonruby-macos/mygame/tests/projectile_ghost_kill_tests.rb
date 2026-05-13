require 'app/game.rb'
require_relative 'game_audio_wiring_tests.rb'

# Bullet vs ghost: any active ghost (chase/scatter/leaving) → killed via
# EatSequencer. :eaten and :in_house ghosts pass through. After kill,
# game enters eat-freeze; this is checked by EatSequencer.frozen?.

def kill_test_setup
  game, args, _audio = build_game_with_spy_audio
  game.instance_variable_set(:@renderer, FakeRenderer.new)
  [game, args]
end

def place_projectile_on_ghost(game, ghost)
  projectile = Projectile.new(
    cx: ghost.x + ghost.w / 2.0,
    cy: ghost.y + ghost.h / 2.0,
    direction: Direction::RIGHT,
    speed: 0
  )
  game.instance_variable_get(:@projectiles) << projectile
  projectile
end

def first_active_ghost(game)
  game.instance_variable_get(:@ghosts).find { |g| g.state != :in_house && g.state != :eaten }
end

def test_bullet_kills_active_ghost args, assert
  game, _args = kill_test_setup
  ghost = first_active_ghost(game)
  starting_state = ghost.state
  assert.true! starting_state != :eaten
  projectile = place_projectile_on_ghost(game, ghost)

  game.resolve_projectile_hits

  assert.equal! ghost.state, :eaten
  assert.true!  projectile.dead?
  assert.true!  game.instance_variable_get(:@eat_sequencer).frozen?
end

def test_bullet_passes_through_eaten_ghost args, assert
  game, _args = kill_test_setup
  ghost = first_active_ghost(game)
  ghost.state = :eaten
  projectile = place_projectile_on_ghost(game, ghost)

  game.resolve_projectile_hits

  assert.false! projectile.dead?
end

def test_bullet_passes_through_in_house_ghost args, assert
  game, _args = kill_test_setup
  ghost = game.instance_variable_get(:@ghosts).find { |g| g.state == :in_house }
  assert.true! !ghost.nil?
  projectile = place_projectile_on_ghost(game, ghost)

  game.resolve_projectile_hits

  assert.false! projectile.dead?
end

def test_bullet_kill_routes_through_eat_sequencer_score args, assert
  game, _args = kill_test_setup
  ghost = first_active_ghost(game)
  score_before = game.instance_variable_get(:@score)
  place_projectile_on_ghost(game, ghost)

  game.resolve_projectile_hits

  assert.true! game.instance_variable_get(:@score) > score_before
end
