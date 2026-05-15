require 'app/ghost.rb'

def make_ghost
  Ghost.new(
    identity: :pinky, x: 0, y: 0, w: 1, h: 1, speed: 1.0,
    scatter_target: [0, 0], spawn_cell: [0, 0],
    controller: nil, direction: Direction::LEFT
  )
end

def test_ghost_starts_with_zero_absorbed_hits args, assert
  g = make_ghost
  assert.equal! g.absorbed_hits, 0
  assert.equal! g.enrage_step, :off
end

def test_absorb_bullet_increments args, assert
  g = make_ghost
  g.absorb_bullet!
  assert.equal! g.absorbed_hits, 1
  g.absorb_bullet!
  assert.equal! g.absorbed_hits, 2
end

def test_enrage_step_up_clears_absorbed args, assert
  # ADR-0011: partial damage at :enrage1 must NOT carry into :enrage2 immunity.
  g = make_ghost
  g.enrage_step = :enrage1
  g.absorb_bullet!
  assert.equal! g.absorbed_hits, 1
  g.enrage_step = :enrage2
  assert.equal! g.absorbed_hits, 0
end

def test_enrage_step_unchanged_keeps_absorbed args, assert
  g = make_ghost
  g.enrage_step = :enrage1
  g.absorb_bullet!
  g.enrage_step = :enrage1 # same step, no reset
  assert.equal! g.absorbed_hits, 1
end

def test_armor_flash_decays args, assert
  g = make_ghost
  g.armor_flash!
  assert.equal! g.armor_flash_ticks, Ghost::ARMOR_FLASH_TICKS
  # Render-time tick is in to_sprite; calling it once decrements by one.
  g.to_sprite
  assert.equal! g.armor_flash_ticks, Ghost::ARMOR_FLASH_TICKS - 1
end
