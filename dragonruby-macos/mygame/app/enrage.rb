# Per-Territory Enrage step — discrete escalation keyed to a territory's
# clearance % (expressed as dots remaining in that territory). Replaces the
# old CruiseElroy module per ADR-0010: same data shape, new scope.
# The `:enrage1` / `:enrage2` symbols match the existing Ghost#enrage_step
# field that ghost controllers already inspect.
module Enrage
  # ADR-0011: bullet resistance gated by enrage step. Partial damage clears
  # on every step-up (see Ghost#enrage_step=).
  HITS_REQUIRED = {
    off:     1,
    enrage1: 2,
    enrage2: Float::INFINITY # immune; only Pacify removes the ghost
  }.freeze

  def self.step(territory_dots_remaining, enrage1_dots:, enrage2_dots:)
    return :enrage2 if territory_dots_remaining <= enrage2_dots
    return :enrage1 if territory_dots_remaining <= enrage1_dots
    :off
  end

  def self.hits_required(step)
    HITS_REQUIRED[step] || 1
  end
end
