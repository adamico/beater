# Cruise Elroy: Blinky's per-level dot-count threshold for accelerated chase.
# OG Lvl 1: Elroy 1 at 20 pellets remaining; Elroy 2 at 10 remaining.
# Suspended until Clyde leaves the pen after a life loss.

module CruiseElroy
  ELROY1_DOTS_REMAINING = 20
  ELROY2_DOTS_REMAINING = 10

  def self.state(pellets_remaining, clyde_in_house:)
    return :off if clyde_in_house
    return :elroy2 if pellets_remaining <= ELROY2_DOTS_REMAINING
    return :elroy1 if pellets_remaining <= ELROY1_DOTS_REMAINING
    :off
  end
end
