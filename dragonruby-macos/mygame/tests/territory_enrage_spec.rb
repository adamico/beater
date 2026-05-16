require 'app/territory.rb'
require 'app/enrage.rb'

def test_territory_color_to_owner_mapping args, assert
  # Each colour quadrant is owned by the ghost that scatters to its corner.
  assert.equal! Territory.owner_of(:red),    :blinky
  assert.equal! Territory.owner_of(:green),  :pinky
  assert.equal! Territory.owner_of(:blue),   :clyde
  assert.equal! Territory.owner_of(:yellow), :inky
end

def test_territory_owner_to_color_is_inverse args, assert
  Territory::COLOR_TO_GHOST.each do |color, ghost|
    assert.equal! Territory.color_of(ghost), color
  end
end

def test_enrage_step_thresholds_at_level_1 args, assert
  # L1 thresholds: enrage1 at 20 territory-dots-remaining, enrage2 at 10.
  off = Enrage.step(60, enrage1_dots: 20, enrage2_dots: 10)
  one = Enrage.step(20, enrage1_dots: 20, enrage2_dots: 10)
  two = Enrage.step(10, enrage1_dots: 20, enrage2_dots: 10)
  zero = Enrage.step(0, enrage1_dots: 20, enrage2_dots: 10)
  assert.equal! off, :off
  assert.equal! one, :enrage1
  assert.equal! two, :enrage2
  assert.equal! zero, :enrage2 # cleared territory: still :enrage2 until pacify path runs
end

def test_enrage_is_monotonic_below_thresholds args, assert
  assert.equal! Enrage.step(21, enrage1_dots: 20, enrage2_dots: 10), :off
  assert.equal! Enrage.step(11, enrage1_dots: 20, enrage2_dots: 10), :enrage1
end

def test_enrage_hits_required_per_step args, assert
  # ADR-0011: :off=1, :enrage1=2, :enrage2=immune.
  assert.equal! Enrage.hits_required(:off),     1
  assert.equal! Enrage.hits_required(:enrage1), 2
  assert.true!  Enrage.hits_required(:enrage2).infinite?
end
