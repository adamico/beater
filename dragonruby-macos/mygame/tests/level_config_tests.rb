require 'app/level_config.rb'

def test_level_config_level_1_matches_dossier args, assert
  c = LevelConfig.for(1)
  assert.equal! c[:ghost_speed_ratio], 0.75
  assert.equal! c[:ghost_tunnel_ratio], 0.40
  assert.equal! c[:elroy1_dots], 20
  assert.equal! c[:elroy1_ratio], 0.85
  assert.equal! c[:elroy2_dots], 10
  assert.equal! c[:elroy2_ratio], 0.95
  assert.equal! c[:phase_table], LevelConfig::PHASE_TIER1
end

def test_level_config_phase_table_tiers args, assert
  assert.equal! LevelConfig.for(1)[:phase_table], LevelConfig::PHASE_TIER1
  assert.equal! LevelConfig.for(2)[:phase_table], LevelConfig::PHASE_TIER2
  assert.equal! LevelConfig.for(4)[:phase_table], LevelConfig::PHASE_TIER2
  assert.equal! LevelConfig.for(5)[:phase_table], LevelConfig::PHASE_TIER3
  assert.equal! LevelConfig.for(99)[:phase_table], LevelConfig::PHASE_TIER3
end

def test_level_config_clamps_past_max_row args, assert
  last = LevelConfig.for(LevelConfig::MAX_ROW)
  assert.equal! LevelConfig.for(99), last
  assert.equal! last[:elroy1_dots], 120
  assert.equal! last[:elroy2_dots], 60
end

def test_level_config_elroy_speeds_exceed_one_from_level_5 args, assert
  # OG: Elroy ghosts outrun Pac-Man from level 5 on — ratios are uncapped.
  assert.true! LevelConfig.for(5)[:elroy2_ratio] > 1.0
  assert.true! LevelConfig.for(1)[:elroy2_ratio] < 1.0
end

def test_level_config_chase_4_is_indefinite args, assert
  [LevelConfig::PHASE_TIER1, LevelConfig::PHASE_TIER2, LevelConfig::PHASE_TIER3].each do |table|
    mode, dur = table.last
    assert.equal! mode, :chase
    assert.nil! dur
  end
end
