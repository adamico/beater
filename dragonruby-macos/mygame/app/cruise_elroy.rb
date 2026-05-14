# Cruise Elroy: Blinky's per-Level dot-count thresholds for accelerated chase.
# Thresholds come from LevelConfig (OG *Pac-Man Dossier* Table A.1).
# Suspended until Clyde leaves the pen after a life loss.

module CruiseElroy
  def self.state(pellets_remaining, clyde_in_house:, elroy1_dots:, elroy2_dots:)
    return :off if clyde_in_house
    return :elroy2 if pellets_remaining <= elroy2_dots
    return :elroy1 if pellets_remaining <= elroy1_dots
    :off
  end
end
