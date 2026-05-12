require 'app/audio/wav_inspector.rb'

def test_wav_inspector_reads_music_stem_rate args, assert
  sample_rate = Audio::WavInspector.sample_rate("sounds/music/drums.wav")
  assert.equal! sample_rate, 44_100
end

def test_wav_inspector_returns_nil_for_missing_file args, assert
  sample_rate = Audio::WavInspector.sample_rate("sounds/music/missing.wav")
  assert.nil! sample_rate
end
