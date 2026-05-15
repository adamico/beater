require 'app/player.rb'

class AmmoControllerStub
  def next_direction(_world); Direction::NONE; end
end

def make_ammo_player
  Player.new(
    x: 0, y: 0, w: 20, h: 20, speed: 1,
    controller: AmmoControllerStub.new,
    direction: Direction::RIGHT
  )
end

def test_player_starts_with_zero_ammo args, assert
  p = make_ammo_player
  assert.equal! p.ammo, 0
end

def test_gain_ammo_default_grants_per_power_pellet args, assert
  p = make_ammo_player
  p.gain_ammo
  assert.equal! p.ammo, Player::AMMO_PER_POWER_PELLET
end

def test_gain_ammo_stacks args, assert
  p = make_ammo_player
  p.gain_ammo
  p.gain_ammo
  assert.equal! p.ammo, Player::AMMO_PER_POWER_PELLET * 2
end

def test_consume_ammo_decrements_and_returns_true args, assert
  p = make_ammo_player
  p.gain_ammo
  before = p.ammo
  result = p.consume_ammo!
  assert.true!  result
  assert.equal! p.ammo, before - 1
end

def test_consume_ammo_at_zero_is_noop args, assert
  p = make_ammo_player
  result = p.consume_ammo!
  assert.false! result
  assert.equal! p.ammo, 0
end

def test_reset_ammo_sets_to_zero args, assert
  p = make_ammo_player
  p.gain_ammo
  p.gain_ammo
  p.reset_ammo!
  assert.equal! p.ammo, 0
end

def test_gain_ammo_explicit_count args, assert
  p = make_ammo_player
  p.gain_ammo(3)
  assert.equal! p.ammo, 3
end
