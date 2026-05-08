# app/tiles.rb
#
# Runtime source of truth for walkable-tile chars. See CONTEXT.md for the
# glossary. Wall chars live in WallShape.

module Tiles
  PELLET       = "."
  POWER_PELLET = "o"
  EMPTY        = "_"

  WALKABLE = [PELLET, POWER_PELLET, EMPTY].freeze

  def self.walkable?(ch)
    WALKABLE.include?(ch)
  end
end
