require 'app/banner.rb'

def test_banner_empty_for_playing_state args, assert
  assert.equal! Banner.build(:playing)[:labels], []
end

def test_banner_empty_for_dying_state args, assert
  assert.equal! Banner.build(:dying)[:labels], []
end

def test_banner_ready_shows_main_only args, assert
  labels = Banner.build(:ready)[:labels]
  assert.equal! labels.length, 1
  assert.equal! labels.first[:text], 'READY?'
end

def test_banner_level_complete_shows_main_plus_subtext args, assert
  labels = Banner.build(:level_complete)[:labels]
  assert.equal! labels.length, 2
  assert.true!(labels.any? { |l| l[:text] == 'LEVEL COMPLETE' })
  assert.true!(labels.any? { |l| l[:text] == 'press any key' })
end

def test_banner_game_over_shows_main_plus_subtext args, assert
  labels = Banner.build(:game_over)[:labels]
  assert.equal! labels.length, 2
  assert.true!(labels.any? { |l| l[:text] == 'GAME OVER' })
  assert.true!(labels.any? { |l| l[:text] == 'press any key' })
end

def test_banner_main_text_centered_on_screen args, assert
  main = Banner.build(:ready)[:labels].first
  assert.equal! main[:x], Camera::SCREEN_W / 2
  assert.equal! main[:alignment_enum], 1
  assert.equal! main[:vertical_alignment_enum], 1
end
