require 'app/audio/music_theory.rb'
require 'app/audio/native_bridge.rb'
require 'app/audio/track_player.rb'

def test_detect_wav_sample_rate_reads_music_stem_rate args, assert
  sample_rate = Audio::TrackPlayer.detect_wav_sample_rate("sounds/music/drums.wav")
  assert.equal! sample_rate, 44_100
end

def test_detect_wav_sample_rate_returns_nil_for_missing_file args, assert
  sample_rate = Audio::TrackPlayer.detect_wav_sample_rate("sounds/music/missing.wav")
  assert.nil! sample_rate
end
