require 'app/territory.rb'

def test_territory_color_to_owner_round_trip args, assert
  Territory::COLOR_TO_GHOST.each do |color, owner|
    assert.equal! Territory.owner_of(color), owner
    assert.equal! Territory.color_of(owner), color
  end
end

def test_territory_unknown_returns_nil args, assert
  assert.nil! Territory.owner_of(:purple)
  assert.nil! Territory.color_of(:wakkity)
end

def test_territory_matches_scatter_corner_geometry args, assert
  # Sanity: the four corner-anchored ghosts each own the matching quadrant.
  # red=top-left, green=top-right, blue=bottom-left, yellow=bottom-right.
  assert.equal! Territory.owner_of(:red),    :blinky
  assert.equal! Territory.owner_of(:green),  :pinky
  assert.equal! Territory.owner_of(:blue),   :clyde
  assert.equal! Territory.owner_of(:yellow), :inky
end
