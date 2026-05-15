require 'app/enrage.rb'

def test_enrage_off_when_remaining_above_step1 args, assert
  assert.equal! Enrage.step(60, enrage1_dots: 20, enrage2_dots: 10), :off
end

def test_enrage_step1_when_remaining_at_threshold args, assert
  assert.equal! Enrage.step(20, enrage1_dots: 20, enrage2_dots: 10), :enrage1
  assert.equal! Enrage.step(15, enrage1_dots: 20, enrage2_dots: 10), :enrage1
end

def test_enrage_step2_when_remaining_at_or_below_step2 args, assert
  assert.equal! Enrage.step(10, enrage1_dots: 20, enrage2_dots: 10), :enrage2
  assert.equal! Enrage.step(0,  enrage1_dots: 20, enrage2_dots: 10), :enrage2
end

def test_enrage_step2_takes_precedence_over_step1 args, assert
  # Both thresholds satisfied -> step2 wins (the higher escalation).
  assert.equal! Enrage.step(5, enrage1_dots: 20, enrage2_dots: 10), :enrage2
end
