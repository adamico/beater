# Project Context

## Tile Alphabet

Single source of truth for layout characters. Layout files (`data/maps/*_layout.rb`)
emit these chars; runtime modules read them.

| Char | Meaning              | Walkable | Pellets    | Notes                                  |
|------|----------------------|----------|------------|----------------------------------------|
| `.`  | Regular pellet       | yes      | `:pellet`  | Default for corridor floor              |
| `o`  | Power pellet         | yes      | `:power`   | Larger pellet, ghost-fright timer       |
| `_`  | Empty floor          | yes      | none       | Tunnel, ghost house, spawn area         |
| `1`  | Wall, corner BR      | no       | —          | Bottom + right segments meet at center  |
| `2`  | Wall, corner BL      | no       | —          | Bottom + left                           |
| `3`  | Wall, corner TR      | no       | —          | Top + right                             |
| `4`  | Wall, corner TL      | no       | —          | Top + left                              |
| `h`  | Wall, horizontal     | no       | —          | Centerline left↔right                   |
| `v`  | Wall, vertical       | no       | —          | Centerline top↕bottom                   |
| `w`  | Wall, interior       | no       | —          | No segment drawn (filler)               |

Reserved (not yet emitted by `MapGenerator`, planned):

| Char | Meaning        | Notes                              |
|------|----------------|------------------------------------|
| `P`  | Player spawn   | Replaces hardcoded `PLAYER_SPAWN`  |
| `G`  | Ghost spawn    | Multiple per layout                |

`MapGenerator` currently emits only `.` for walkable cells. `o` / `_` are authored
manually in `*_layout.rb` until generator support lands.

## Modules

- **Maze** — topology. `walkable?(gx, gy)`, `wall_segments(projection)`. Pure-grid; swallows the GMM→world y-flip at construction.
- **GridProjection** — pixel↔ordinal geometry. `cell_rect(gx, gy)`, `cells_touched(rect)`, `aligned?(rect)`. Holds `cell_size` + offsets.
- **Pellets** — consumable state. `at(gx, gy)`, `eat(gx, gy)`, `remaining`. Reads same layout as Maze.
- **MapGenerator** — compiles `.gmm` → `*_layout.rb` (only when stale). Owns wall-corner classification (assigns `1234hvw`).

Agents (Player, future Enemy) consult **Maze** (semantics) + **GridProjection** (geometry).
