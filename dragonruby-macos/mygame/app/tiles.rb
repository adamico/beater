# app/tiles.rb
#
# Runtime source of truth for walkable-tile chars. See CONTEXT.md for the
# glossary. Wall chars live in WallShape.

module Tiles
  PELLET       = "."
  POWER_PELLET = "o"
  EMPTY        = "_"
  DOOR         = "-"
  GHOST_HOME   = "G"

  WALKABLE = [PELLET, POWER_PELLET, EMPTY, GHOST_HOME].freeze

  ROLE_DEFAULT       = :default
  ROLE_GHOST_EATEN   = :ghost_eaten
  ROLE_GHOST_LEAVING = :ghost_leaving

  PASSABILITY = {
    ROLE_DEFAULT       => WALKABLE,
    ROLE_GHOST_EATEN   => (WALKABLE + [DOOR]).freeze,
    ROLE_GHOST_LEAVING => (WALKABLE + [DOOR]).freeze
  }.freeze

  def self.walkable?(ch)
    WALKABLE.include?(ch)
  end

  def self.passable_for?(ch, role)
    table = PASSABILITY[role] || WALKABLE
    table.include?(ch)
  end
end
