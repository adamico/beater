# Project Context

## Tile Alphabet

Single source of truth for layout characters. Layout files (`data/maps/*_layout.rb`)
emit these chars; runtime modules read them.

| Char | Meaning              | Walkable | Pellets    | Notes                                  |
|------|----------------------|----------|------------|----------------------------------------|
| `.`  | Regular pellet       | yes      | `:pellet`  | Default for corridor floor              |
| `o`  | Power pellet         | yes      | `:power`   | Larger pellet, ghost-fright timer       |
| `_`  | Empty floor          | yes      | none       | Tunnel mouths, ghost house, spawn area  |
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

`pacman_layout.rb` is the source of truth for the map and is hand-authored.

## Modules

- **Tiles** — walkable-tile char alphabet (`.`, `o`, `_`) + `walkable?(ch)`.
- **WallShape** — wall-tile vocabulary. Owns wall chars (`1234hvw`), char↔shape (`from_char`, `.char`), neighbor-mask classification (`classify(t:, b:, l:, r:, tl:, tr:, bl:, br:)`), and pixel-rect geometry (`.segments(rect)`). Single edit-site for adding wall shapes.
- **Maze** — topology. `walkable?(gx, gy)`, `wrap(gx, gy)`, `wall_segments(projection)`. Pure-grid; swallows the layout→world y-flip at construction. Toroidal on X: `walkable?` wraps `gx` so out-of-bounds horizontal coords resolve across the seam (Y stays strict).
- **GridProjection** — pixel↔ordinal geometry. `cell_rect(gx, gy)`, `cells_touched(rect)`, `aligned?(rect)`, `playfield_rect`. Holds `cell_size`, offsets, and grid extents.
- **Pellets** — consumable state. `at(gx, gy)`, `eat(gx, gy)`, `remaining`. Reads same layout as Maze.
- **Direction** — value object: `Direction::UP/DOWN/LEFT/RIGHT/NONE`, each with `.dx`, `.dy`, `.opposite`. Replaces ad-hoc symbols and dx/dy pairs across actor code.
- **GridMover** — mixin providing grid-aligned movement. Holds `x, y, w, h, dx, dy, speed` state and `try_turn(direction, maze, projection)` / `advance(maze, projection)` methods. Player and Ghost both `include GridMover`.
- **Controller** — strategy object that decides an actor's next direction. `Controller#next_direction(world) -> Direction`. `KeyboardController` reads `world.inputs` for the player; ghost controllers (chase/scatter/frightened) come later. Pure function of `world`; mode swap is `actor.controller = NewController.new`.
- **World** — per-tick bag passed to controllers (`inputs`, `maze`, `projection`, `player`, `pellets`). Built by Game each tick; private to the actor/controller pipeline.
- **Renderer** — owns all drawing. `draw(outputs, maze, pellets, player)` pushes primitives into DR's outputs each tick. Holds the projection; stateless w.r.t. outputs. Theme constants (colors, pellet sizes) live here.

Agents (Player, future Enemy) consult **Maze** (semantics) + **GridProjection** (geometry).

## Tunnel

A **Tunnel** is a horizontal corridor whose `_` cells touch column 0 and column `width-1` on the same row. **Wrapping** is the act of crossing the seam: actor walks off one edge and reappears fully on the opposite edge.

Two layers:

- **Topology**: `Maze#walkable?` wraps `gx`, so probes across the seam see the cell on the other side. The grid is toroidal on X.
- **Pixel motion**: `GridMover#advance` teleports `@x` once the rect has fully exited the playfield horizontally (`x + w <= playfield_left` or `x >= playfield_right`). Actor is briefly invisible during transit; `Renderer` skips draw for fully-off-playfield rects.

No tunnel char in the alphabet — tunnels are implicit by edge-adjacency.
