require 'app/game.rb'

class FakeState
  attr_accessor :request_game_reset, :debug_audio, :audio
end

class FakeArgs
  attr_accessor :state, :inputs, :outputs, :audio, :tick_count
end

class FakeKeyDown
  attr_accessor :truthy_keys

  def initialize
    @truthy_keys = []
  end

  def f3
    false
  end
end

class FakeKeyboard
  attr_reader :key_down

  def initialize
    @key_down = FakeKeyDown.new
  end
end

class FakeController
  attr_reader :key_down

  def initialize
    @key_down = FakeKeyDown.new
  end
end

class FakeInputs
  attr_reader :keyboard, :controller_one

  def initialize
    @keyboard = FakeKeyboard.new
    @controller_one = FakeController.new
  end
end

class FakeOutputs
  attr_reader :labels

  def initialize
    @labels = []
  end
end

class FakeRenderer
  attr_reader :calls

  def initialize
    @calls = []
  end

  def draw(*args, **kwargs)
    @calls << { args: args, kwargs: kwargs }
  end
end

class AudioSpy
  attr_reader :dot_calls, :power_calls, :enemy_calls, :level_complete_calls,
              :duck_calls, :tick_calls, :dot_totals_calls

  attr_accessor :duck_active, :duck_amount, :duck_gain_scale

  def initialize
    @dot_calls = []
    @power_calls = 0
    @enemy_calls = []
    @level_complete_calls = 0
    @duck_calls = []
    @tick_calls = 0
    @dot_totals_calls = []

    @duck_active = false
    @duck_amount = 0.0
    @duck_gain_scale = 0.55
  end

  def tick(_args)
    @tick_calls += 1
  end

  def set_dot_totals(totals)
    @dot_totals_calls << totals
  end

  def on_dot_collected(_args, color)
    @dot_calls << color
  end

  def on_power_pellet(_args)
    @power_calls += 1
  end

  def on_enemy_eaten(_args, sequence:)
    @enemy_calls << sequence
  end

  def on_level_complete(_args)
    @level_complete_calls += 1
  end

  def set_duck(_args, active:, gain_scale:, ramp_in:, ramp_out:)
    @duck_calls << {
      active: active,
      gain_scale: gain_scale,
      ramp_in: ramp_in,
      ramp_out: ramp_out
    }
    @duck_active = active
  end

  def duck_gain_multiplier
    0.55
  end
end

def make_args_with_audio_spy
  args = FakeArgs.new
  args.state = FakeState.new
  args.inputs = FakeInputs.new
  args.outputs = FakeOutputs.new
  args.audio = {}
  args.tick_count = 0
  args.state.request_game_reset = false
  args.state.debug_audio = false
  args.state.audio = AudioSpy.new
  args
end

def place_player_at_cell(game, gx, gy)
  projection = game.instance_variable_get(:@projection)
  player = game.instance_variable_get(:@player)
  rect = projection.cell_rect(gx, gy)
  player.x = rect[:x]
  player.y = rect[:y]
end

def find_cell_for_kind(game, kind)
  pellets = game.instance_variable_get(:@pellets)
  found = nil
  pellets.each_with_color do |(gx, gy), entry_kind, _color|
    next unless entry_kind == kind
    found = [gx, gy]
    break
  end
  found
end

def build_game_with_spy_audio
  game = Game.new
  args = make_args_with_audio_spy
  game.args = args
  game.instance_variable_set(:@renderer, FakeRenderer.new)
  [game, args, args.state.audio]
end

def test_player_eat_pellet_calls_on_dot_collected_with_color args, assert
  game, _args, audio = build_game_with_spy_audio

  gx, gy = find_cell_for_kind(game, :pellet)
  pellets = game.instance_variable_get(:@pellets)
  expected_color = pellets.color_at(gx, gy)
  place_player_at_cell(game, gx, gy)

  game.player_eat_pellets

  assert.equal! audio.dot_calls.length, 1
  assert.equal! audio.dot_calls[0], expected_color
  assert.equal! audio.power_calls, 0
end

def test_player_eat_power_calls_on_power_pellet args, assert
  game, _args, audio = build_game_with_spy_audio

  gx, gy = find_cell_for_kind(game, :power)
  place_player_at_cell(game, gx, gy)

  game.player_eat_pellets

  assert.equal! audio.power_calls, 1
end

def test_eat_ghost_calls_enemy_eaten_with_sequence args, assert
  game, _args, audio = build_game_with_spy_audio

  ghost = game.instance_variable_get(:@ghosts).first
  game.eat_ghost(ghost)

  assert.equal! audio.enemy_calls.length, 1
  assert.equal! audio.enemy_calls[0], 1
end

def test_level_complete_notifies_once args, assert
  game, _args, audio = build_game_with_spy_audio

  game.instance_variable_set(:@pellets, Pellets.new({}))

  first = game.check_level_complete
  second = game.check_level_complete

  assert.true! first
  assert.false! second
  assert.equal! audio.level_complete_calls, 1
end

def test_tick_duck_active_during_eat_pause args, assert
  game, _args, audio = build_game_with_spy_audio

  game.instance_variable_set(:@eat_pause_ticks, 2)
  game.tick

  assert.true! audio.duck_calls.any? { |call| call[:active] }
end

def test_tick_duck_inactive_during_normal_play args, assert
  game, _args, audio = build_game_with_spy_audio

  game.instance_variable_set(:@eat_pause_ticks, 0)

  game.define_singleton_method(:tick_phase) {}
  game.define_singleton_method(:tick_frightened) {}
  game.define_singleton_method(:tick_releases) {}
  game.define_singleton_method(:tick_player) { |_world| }
  game.define_singleton_method(:tick_ghosts) { |_world| }
  game.define_singleton_method(:tick_collisions) {}

  game.tick

  assert.true! audio.duck_calls.any? { |call| !call[:active] }
end
