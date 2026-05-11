require 'app/game.rb'

def build_world(game)
  World.new(
    inputs: nil,
    maze: game.instance_variable_get(:@maze),
    projection: game.instance_variable_get(:@projection),
    player: game.instance_variable_get(:@player),
    pellets: game.instance_variable_get(:@pellets),
    ghosts: game.instance_variable_get(:@ghosts)
  )
end

def test_pinky_leaves_house_and_enters_phase_state args, assert
  game = Game.new
  pinky = game.instance_variable_get(:@ghosts).find { |g| g.identity == :pinky }

  assert.equal! :in_house, pinky.state

  # Pinky has zero-dot release threshold and should be released immediately.
  game.tick_releases
  assert.equal! :leaving_house, pinky.state

  reached_active = false
  180.times do
    game.tick_ghosts(build_world(game))
    if pinky.state == :scatter || pinky.state == :chase
      reached_active = true
      break
    end
  end

  assert.true! reached_active, 'Pinky should exit house and enter scatter/chase state'
  assert.equal! Tiles::ROLE_DEFAULT, pinky.role
end