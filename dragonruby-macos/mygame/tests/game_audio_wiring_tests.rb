require 'app/game.rb'

class FakeState
  attr_accessor :request_game_reset, :debug_audio, :audio, :sfx_cache, :sfx_counter
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

  def on_player_death(args)
    set_duck(args, active: true, gain_scale: 0.12, ramp_in: 18, ramp_out: 8)
  end

  def on_respawn(args, ramp_out: 30)
    set_duck(args, active: false, gain_scale: 0.12, ramp_in: 18, ramp_out: ramp_out)
  end

  def on_count_in_beat(_args)
  end

  def on_game_over(_args)
  end

  def set_duck(_args, active:, gain_scale:, ramp_in:, ramp_out:, immediate: false)
    @duck_calls << {
      active: active,
      gain_scale: gain_scale,
      ramp_in: ramp_in,
      ramp_out: ramp_out,
      immediate: immediate
    }
    @duck_active = active
  end

  def on_level_complete_duck_clear(args)
    set_duck(args, active: false, gain_scale: 0.4, ramp_in: 1, ramp_out: 2)
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

def test_tick_no_duck_during_normal_play args, assert
  game, _args, audio = build_game_with_spy_audio

  game.instance_variable_set(:@state, :playing)
  game.instance_variable_get(:@eat_sequencer).eat_pause_ticks = 0

  game.define_singleton_method(:tick_phase) {}
  game.define_singleton_method(:tick_releases) {}
  game.define_singleton_method(:tick_player) { |_world| }
  game.define_singleton_method(:tick_ghosts) { |_world| }
  game.define_singleton_method(:tick_fire_input) { |_world| }
  game.define_singleton_method(:tick_projectiles) {}
  game.define_singleton_method(:tick_collisions) {}

  game.tick

  # Eat-duck was removed (TG2): no path should activate the duck during play.
  assert.false! audio.duck_calls.any? { |call| call[:active] }
end

def force_legacy_audio_backend!
  Audio::NativeBridge.define_singleton_method(:backend_mode) { :legacy }
  Audio::NativeBridge.define_singleton_method(:ready_for_streaming?) { false }
  Audio::NativeBridge.define_singleton_method(:load_stems) { |_| true }
end

def test_audio_manager_registers_looping_music_stems args, assert
  force_legacy_audio_backend!
  audio_args = make_args_with_audio_spy
  manager = Audio::Manager.new(audio_args)

  assert.equal! audio_args.audio[:track_drums][:input], "sounds/music/drums.wav"
  assert.equal! audio_args.audio[:track_bass][:input], "sounds/music/bass.wav"
  assert.equal! audio_args.audio[:track_lead][:input], "sounds/music/lead.wav"
  assert.equal! audio_args.audio[:track_chords][:input], "sounds/music/chords.wav"
  assert.true! audio_args.audio[:track_drums][:looping]
  assert.false! audio_args.audio[:track_drums][:paused]
end

def test_audio_manager_linearly_updates_track_gain_from_completion args, assert
  force_legacy_audio_backend!
  audio_args = make_args_with_audio_spy
  manager = Audio::Manager.new(audio_args)

  manager.set_dot_totals(drums: 4, bass: 1, lead: 1, chords: 1)
  manager.on_dot_collected(audio_args, :red)
  manager.tick(audio_args)

  expected_gain = Audio::TRACK_CONFIGS[:drums].start_gain + 0.25 *
                  (Audio::TRACK_CONFIGS[:drums].end_gain - Audio::TRACK_CONFIGS[:drums].start_gain)

  assert.equal! manager.completion[:drums], 0.25
  assert.equal! audio_args.audio[:track_drums][:gain], expected_gain
  assert.true! audio_args.audio.keys.any? { |key| key.to_s.start_with?("sfx_") }
end
