# ADR-0014: Canon ghost colours + red/green stem swap

## Status

Accepted — 2026-05-16.

## Context

Phase-4 enemy art (`sprites/guitar_blinky.png`) introduces a per-identity guitar visual for Blinky. The first sheet is a **red** guitar. This collided with two prior arbitrary choices:

1. **Territory ownership.** `Territory::COLOR_TO_GHOST` mapped `red→Pinky, green→Blinky`. Pac-Man canon is the opposite (Blinky is red); the project's mapping fell out of scatter-corner geometry choices in ADR-0010 without regard to canon.
2. **Stem-to-colour binding.** `Audio::Manager::DOT_COLORS` mapped `red→drums, green→bass`. Combined with (1), Blinky owned the bass stem — fine in isolation, but with a *guitar* sheet about to land on Blinky, "guitar visual + drum stem on the same ghost" reads as a bug to any new player or reviewer.

Quadrant geometry (TL/TR/BL/BR) is sacred — maze layout, scatter-corner targets, HUD meter order, dot-recolour pipeline, prison cells, and per-`Territory` enrage thresholds all anchor to it. Only the labels on top of the geometry are negotiable.

## Decision

Apply two paired swaps so the red guitar lands on the bass stem owned by Blinky:

| Region | Colour | Ghost (was → now) | Stem (was → now) |
|--------|--------|-------------------|------------------|
| TL     | red    | Pinky → **Blinky** | drums → **bass** |
| TR     | green  | Blinky → **Pinky** | bass → **drums** |
| BL     | blue   | Clyde              | lead             |
| BR     | yellow | Inky               | chords           |

Concretely:

- `Territory::COLOR_TO_GHOST`: swap red↔green ghost values.
- `Audio::Manager::DOT_COLORS`: swap red↔green stem values.
- `Game#initialize_ghosts` scatter targets: swap Blinky↔Pinky so each ghost still scatters to the corner of its owned territory.
- `Ghost::SPRITES` placeholders: Blinky → `square/red.png`, Pinky → `square/green.png` (Blinky additionally gets the new sheet config via `Ghost::SHEETS`).

## Consequences

- Restores Pac-Man canon (Blinky=red, Pinky=pink-ish/green here) — players coming from the OG read the colours correctly.
- Guitar art lands on the bass stem — semantically coherent (guitar ≈ bass-line carrier in this slice).
- Existing highscore entries are unaffected (no schema touch).
- Ghost identity ↔ behaviour controller binding is unchanged; only colour/territory/stem labels move. `BlinkyController` still does Blinky's targeting (player tile), `PinkyController` still does the 4-ahead-with-overflow-bug, etc.
- HUD meter colour order unchanged (still red/green/blue/yellow LTR), but the *stem* each meter represents shifts.
- Tests asserting the old `Territory.owner_of` mapping updated in lockstep.
- Future per-ghost sheets land on the now-canonical colours: red guitar = Blinky, green = Pinky, etc. No further glossary churn expected.

## Alternatives considered

- **Stem-only swap, keep ghost ownership.** Pinky would own bass + red guitar. Pinky's identity stays mismatched against canon; the next sheet (e.g. green for Pinky in canon) would re-open the question.
- **Recolour the art.** Recolour `guitar_blinky.png` to green and keep all current mappings. Rejected — the art intent is explicitly red, and the canon-restoration win is worth the one-time swap.
- **Rename identities** (e.g. rename internal `:blinky` to `:pinky`). Rejected — every controller, spec, spawn marker, and prison tile would churn for no gameplay change.
