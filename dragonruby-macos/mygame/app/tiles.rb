# app/tiles.rb
#
# Runtime source of truth for the layout char alphabet. See CONTEXT.md for the
# glossary. All readers (Maze, Pellets, MapGenerator) reference these constants
# rather than string literals.

module Tiles
  PELLET        = "."
  POWER_PELLET  = "o"
  EMPTY         = "_"
  WALL_INTERIOR = "w"
  WALL_H        = "h"
  WALL_V        = "v"
  CORNER_BR     = "1"
  CORNER_BL     = "2"
  CORNER_TR     = "3"
  CORNER_TL     = "4"

  WALKABLE = [PELLET, POWER_PELLET, EMPTY].freeze

  def self.walkable?(ch)
    WALKABLE.include?(ch)
  end
end
