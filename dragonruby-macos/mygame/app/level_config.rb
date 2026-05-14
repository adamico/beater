# Per-Level difficulty data, ported from the OG *Pac-Man Dossier* Table A.1
# (see docs/OG/pacman_dossier_extracts.md) and the scatter/chase phase table.
#
# Speeds are RATIOS of PLAYER_SPEED, never absolute — the beat stays the single
# tempo source of truth (ADR-0009). Pac-Man's own speed does not scale with the
# level, so it has no entry here. The Fright. and Bonus columns of Table A.1 are
# unused (no frightened state per ADR-0007, no fruit system yet).
#
# Levels past the last explicit row clamp to it (the dossier's "21+" row).
module LevelConfig
  S = 60 # ticks per second

  # Scatter/chase phase tables, tiered: level 1, levels 2-4, levels 5+.
  # Each entry is [mode, duration_ticks]; a nil duration means indefinite.
  # The 1/60s scatter entries collapse to a single tick (a direction reversal).
  PHASE_TIER1 = [
    [:scatter,  7 * S], [:chase, 20 * S],
    [:scatter,  7 * S], [:chase, 20 * S],
    [:scatter,  5 * S], [:chase, 20 * S],
    [:scatter,  5 * S], [:chase, nil]
  ].freeze

  PHASE_TIER2 = [
    [:scatter,  7 * S], [:chase,   20 * S],
    [:scatter,  7 * S], [:chase,   20 * S],
    [:scatter,  5 * S], [:chase, 1033 * S],
    [:scatter,      1], [:chase,      nil]
  ].freeze

  PHASE_TIER3 = [
    [:scatter,  5 * S], [:chase,   20 * S],
    [:scatter,  5 * S], [:chase,   20 * S],
    [:scatter,  5 * S], [:chase, 1037 * S],
    [:scatter,      1], [:chase,      nil]
  ].freeze

  def self.phase_table(level)
    return PHASE_TIER1 if level <= 1
    return PHASE_TIER2 if level <= 4
    PHASE_TIER3
  end

  # Per-level rows: [ghost_speed, ghost_tunnel, elroy1_dots, elroy1_speed,
  #                  elroy2_dots, elroy2_speed]. Index 0 is unused (level 1 = [1]).
  ROWS = [
    nil,
    [0.75, 0.40, 20, 0.85, 10, 0.95], # 1
    [0.85, 0.45, 30, 0.90, 15, 0.95], # 2
    [0.85, 0.45, 40, 0.90, 20, 0.95], # 3
    [0.85, 0.45, 40, 0.90, 20, 0.95], # 4
    [0.95, 0.50, 40, 1.00, 20, 1.05], # 5
    [0.95, 0.50, 50, 1.00, 25, 1.05], # 6
    [0.95, 0.50, 50, 1.00, 25, 1.05], # 7
    [0.95, 0.50, 50, 1.00, 25, 1.05], # 8
    [0.95, 0.50, 60, 1.00, 30, 1.05], # 9
    [0.95, 0.50, 60, 1.00, 30, 1.05], # 10
    [0.95, 0.50, 60, 1.00, 30, 1.05], # 11
    [0.95, 0.50, 80, 1.00, 40, 1.05], # 12
    [0.95, 0.50, 80, 1.00, 40, 1.05], # 13
    [0.95, 0.50, 80, 1.00, 40, 1.05], # 14
    [0.95, 0.50, 100, 1.00, 50, 1.05], # 15
    [0.95, 0.50, 100, 1.00, 50, 1.05], # 16
    [0.95, 0.50, 100, 1.00, 50, 1.05], # 17
    [0.95, 0.50, 100, 1.00, 50, 1.05], # 18
    [0.95, 0.50, 120, 1.00, 60, 1.05], # 19
    [0.95, 0.50, 120, 1.00, 60, 1.05], # 20
    [0.95, 0.50, 120, 1.00, 60, 1.05]  # 21+
  ].freeze

  MAX_ROW = ROWS.length - 1 # 21; levels beyond clamp here

  def self.for(level)
    row = ROWS[level.clamp(1, MAX_ROW)]
    {
      ghost_speed_ratio:  row[0],
      ghost_tunnel_ratio: row[1],
      elroy1_dots:        row[2],
      elroy1_ratio:       row[3],
      elroy2_dots:        row[4],
      elroy2_ratio:       row[5],
      phase_table:        phase_table(level)
    }.freeze
  end
end
