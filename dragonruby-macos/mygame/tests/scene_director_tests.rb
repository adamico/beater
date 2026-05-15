require 'app/scenes/scene_director'

def test_scene_director_starts_on_title(_args, assert)
  SceneDirector.reset!
  assert.equal! SceneDirector.current, :title
  assert.equal! SceneDirector.phase, :idle
  assert.equal! SceneDirector.transitioning?, false
end

def test_scene_director_request_starts_fade_out(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:playing)
  assert.equal! SceneDirector.phase, :fading_out
  assert.equal! SceneDirector.transitioning?, true
  # Scene does not change until fade-out apex.
  assert.equal! SceneDirector.current, :title
end

def test_scene_director_swap_happens_at_fade_apex(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:playing)
  swap_count = 0
  SceneDirector::FADE_FRAMES.times { SceneDirector.tick_transition { swap_count += 1 } }
  assert.equal! swap_count, 1
  assert.equal! SceneDirector.current, :playing
  assert.equal! SceneDirector.phase, :fading_in
end

def test_scene_director_fade_in_completes(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:playing)
  (SceneDirector::FADE_FRAMES * 2).times { SceneDirector.tick_transition }
  assert.equal! SceneDirector.phase, :idle
  assert.equal! SceneDirector.current, :playing
  assert.equal! SceneDirector.transitioning?, false
end

def test_scene_director_ignores_request_while_transitioning(_args, assert)
  SceneDirector.reset!
  SceneDirector.request(:playing)
  SceneDirector.request(:title)
  # Second request dropped; still heading to :playing.
  SceneDirector::FADE_FRAMES.times { SceneDirector.tick_transition }
  assert.equal! SceneDirector.current, :playing
end

def test_scene_director_fade_alpha_ramps(_args, assert)
  SceneDirector.reset!
  assert.equal! SceneDirector.fade_alpha, 0
  SceneDirector.request(:playing)
  # Mid-fade-out alpha is non-zero and < 255.
  (SceneDirector::FADE_FRAMES / 2).to_i.times { SceneDirector.tick_transition }
  a = SceneDirector.fade_alpha
  assert.true! a > 0 && a < 255
end
