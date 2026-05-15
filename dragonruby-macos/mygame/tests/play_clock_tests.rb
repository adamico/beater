require 'app/game.rb'
require_relative 'game_audio_wiring_tests.rb'

# ADR-0013: @play_ticks counts the time the player was actually playing.
# It advances exactly once per tick_playing call and does not advance in
# :ready / :paused / :dying / :level_complete / :game_over.

# Extend the shared fakes so we can drive Game#tick through every state.
# Any unspecified key reads as "not pressed". Keeps tests resilient when
# MenuInput / KeyboardController grow new key references.
class FakeKeyDown
  def method_missing(_name, *_args)
    false
  end

  def respond_to_missing?(_name, _include_private = false)
    true
  end
end

class FakeState
  attr_accessor :debug_ghost, :debug_layout, :request_replay
end

class FakeOutputs
  attr_accessor :background_color
  attr_reader :primitives, :solids, :sprites

  alias_method :_orig_initialize_play_clock_outputs, :initialize
  def initialize
    _orig_initialize_play_clock_outputs
    @primitives = []
    @solids = []
    @sprites = []
  end
end

class FakeMouse
  attr_accessor :x, :y, :click, :moved
  def initialize
    @x = -1
    @y = -1
    @click = false
    @moved = false
  end
end

class FakeInputs
  attr_accessor :up_down, :left_right
  attr_reader :mouse

  alias_method :_orig_initialize_play_clock, :initialize
  def initialize
    _orig_initialize_play_clock
    @up_down = 0
    @left_right = 0
    @mouse = FakeMouse.new
  end
end

def build_game_for_play_clock
  game, args, _audio = build_game_with_spy_audio
  game.instance_variable_set(:@renderer, FakeRenderer.new)
  [game, args]
end

def test_play_clock_starts_at_zero_on_new_game(_args, assert)
  game = Game.new
  assert.equal! game.instance_variable_get(:@play_ticks), 0
end

def test_tick_playing_increments_play_clock_by_one(_args, assert)
  game, _args = build_game_for_play_clock
  before = game.instance_variable_get(:@play_ticks)
  game.tick_playing
  assert.equal! game.instance_variable_get(:@play_ticks), before + 1
end

def test_tick_paused_does_not_advance_play_clock(_args, assert)
  game, _args = build_game_for_play_clock
  game.enter_paused
  before = game.instance_variable_get(:@play_ticks)
  game.tick_paused
  assert.equal! game.instance_variable_get(:@play_ticks), before
end

def test_tick_ready_does_not_advance_play_clock(_args, assert)
  game, _args = build_game_for_play_clock
  game.enter_ready
  before = game.instance_variable_get(:@play_ticks)
  game.tick_ready
  assert.equal! game.instance_variable_get(:@play_ticks), before
end

def test_tick_dying_does_not_advance_play_clock(_args, assert)
  game, _args = build_game_for_play_clock
  game.enter_dying
  before = game.instance_variable_get(:@play_ticks)
  game.tick_dying
  assert.equal! game.instance_variable_get(:@play_ticks), before
end

def test_tick_level_complete_does_not_advance_play_clock(_args, assert)
  game, _args = build_game_for_play_clock
  game.instance_variable_set(:@state, :level_complete)
  before = game.instance_variable_get(:@play_ticks)
  game.tick_level_complete
  assert.equal! game.instance_variable_get(:@play_ticks), before
end

def test_tick_game_over_does_not_advance_play_clock(_args, assert)
  game, _args = build_game_for_play_clock
  game.enter_game_over
  before = game.instance_variable_get(:@play_ticks)
  game.tick_game_over
  assert.equal! game.instance_variable_get(:@play_ticks), before
end

# Sanity bundle: many calls in :playing accumulate one-for-one; that count
# is preserved across a pause round-trip — pausing freezes the clock and
# resuming continues from there.
def test_play_clock_count_survives_pause_round_trip(_args, assert)
  game, _args = build_game_for_play_clock
  3.times { game.tick_playing }
  game.enter_paused
  5.times { game.tick_paused }
  before_resume = game.instance_variable_get(:@play_ticks)
  game.exit_paused
  2.times { game.tick_playing }
  assert.equal! before_resume, 3
  assert.equal! game.instance_variable_get(:@play_ticks), 5
end
