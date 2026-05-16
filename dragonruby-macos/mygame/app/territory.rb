# Each dot quadrant is a Territory owned by the ghost that scatters to its
# corner — a mapping that falls out of existing geometry, see ADR-0010 and
# CONTEXT.md "Territory":
#
#   red    (top-left)     -> Blinky
#   green  (top-right)    -> Pinky
#   blue   (bottom-left)  -> Clyde
#   yellow (bottom-right) -> Inky
module Territory
  COLOR_TO_GHOST = {
    red:    :blinky,
    green:  :pinky,
    blue:   :clyde,
    yellow: :inky
  }.freeze

  GHOST_TO_COLOR = COLOR_TO_GHOST.invert.freeze

  def self.owner_of(color);  COLOR_TO_GHOST[color]; end
  def self.color_of(ghost);  GHOST_TO_COLOR[ghost]; end
end
