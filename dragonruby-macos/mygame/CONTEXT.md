# Project Context

## Tile Alphabet

Single source of truth for layout characters. Layout files (`data/maps/*_layout.rb`)
emit these chars; runtime modules read them.

| Char | Meaning              | Walkable | Pellets    | Notes                                  |
|------|----------------------|----------|------------|----------------------------------------|
| `.`  | Regular pellet       | yes      | `:pellet`  | Default for corridor floor              |
| `o`  | Power pellet         | yes      | `:power`   | Larger pellet, ghost-fright timer       |
| `_`  | Empty floor          | yes      | none       | Tunnel mouths, ghost house, spawn area  |
| `-`  | Ghost-house door     | role     | none       | Walkable only for `:ghost_eaten` (down) and `:ghost_leaving` (up); wall to player + active ghosts |
| `G`  | Ghost-house home cell| yes      | none       | Marks the pen's anchor cell; ghost identities (Blinky/Pinky/Inky/Clyde) are assigned in code at fixed offsets from `G` |
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

`pacman_layout.rb` is the source of truth for the map and is hand-authored.

## Passability Roles

`Tiles.passable_for?(ch, role)` is the policy table. `Maze#walkable?(gx, gy, role: :default)` delegates. Roles:

- `:default` — player + active ghosts. Walls + door block.
- `:ghost_eaten` — eyes returning to pen. Door + interior empties pass.
- `:ghost_leaving` — ghost exiting pen via door. Door passes.

Adding a new actor mode = add a role + a column. Maze stays dumb.

## Modules

- **Tiles** — walkable-tile char alphabet (`.`, `o`, `_`) + `walkable?(ch)`.
- **WallShape** — wall-tile vocabulary. Owns wall chars (`1234hvw`), char↔shape (`from_char`, `.char`), and pixel-rect geometry (`.segments(rect)`). Single edit-site for adding wall shapes.
- **Maze** — topology. `walkable?(gx, gy)`, `wrap(gx, gy)`, `wall_segments(projection)`. Pure-grid; swallows the layout→world y-flip at construction. Toroidal on X: `walkable?` wraps `gx` so out-of-bounds horizontal coords resolve across the seam (Y stays strict).
- **GridProjection** — pixel↔ordinal geometry. `cell_rect(gx, gy)`, `cells_touched(rect)`, `aligned?(rect)`, `playfield_rect`. Holds `cell_size`, offsets, and grid extents.
- **Pellets** — consumable state. `at(gx, gy)`, `eat(gx, gy)`, `remaining`. Reads same layout as Maze.
- **Direction** — value object: `Direction::UP/DOWN/LEFT/RIGHT/NONE`, each with `.dx`, `.dy`, `.opposite`. Replaces ad-hoc symbols and dx/dy pairs across actor code.
- **GridMover** — mixin providing grid-aligned movement. Holds `x, y, w, h, dx, dy, speed` state and `try_turn(direction, maze, projection)` / `advance(maze, projection)` methods. Player and Ghost both `include GridMover`.
- **Controller** — strategy object that decides an actor's next direction. `Controller#next_direction(world) -> Direction`. `KeyboardController` reads `world.inputs` for the player; ghost controllers (chase/scatter/frightened) come later. Pure function of `world`; mode swap is `actor.controller = NewController.new`.
- **World** — per-tick bag passed to controllers (`inputs`, `maze`, `projection`, `player`, `pellets`, `ghosts`). Built by Game each tick; private to the actor/controller pipeline. Ghost controllers read peers via `world.ghosts` (Inky needs Blinky's tile).
- **Renderer** — owns all drawing. `draw(outputs, maze, pellets, player, ghosts)` pushes primitives into DR's outputs each tick. Holds the projection; stateless w.r.t. outputs. Theme constants (colors, pellet sizes) live here.
- **Ghost** — actor like Player; `include GridMover`. Holds identity (`:blinky/:pinky/:inky/:clyde`), scatter-corner target, `state` (`:in_house/:leaving_house/:scatter/:chase/:frightened/:eaten`), and current `controller`. Identity is fixed; state + controller swap. Sprite resolves via state+identity (`square/red.png`, `square/white.png` frightened, `square/empty.png` eaten).
- **GhostHouse** — _planned, not yet implemented_. Will hold door tile coord, above-door tile, 4 home-slot coords, and the `LeavingHouse` waypoint path. Current MVP picks 4 spawn cells by scanning the maze for `_` cells farthest from the player; eaten ghost retargets its own spawn cell directly (no eyes path through a door yet). Adding the pen requires editing `pacman_layout.rb` to introduce `G` and `-` cells.
- **Ghost controllers** — one per behavior: `BlinkyController` (target = player tile), `PinkyController` (4 ahead of player, **with arcade up-direction overflow bug intentionally replicated**), `InkyController` (reflect Blinky tile through 2-ahead-of-player), `ClydeController` (player tile if ≥8 tiles away, else scatter corner), `FrightenedController` (random non-reverse exit at intersections), `EatenController` (target = door, then home-slot), `LeavingHouseController` (waypoint path). Decisions taken at intersections (`GridMover#at_cell_center?` + ≥2 non-reverse exits); else `NONE`. Reverse excluded from candidates.
- **Release schedule** — arcade-faithful per-ghost dot counter (Pinky:0, Inky:30, Clyde:60 at level 1) + 4s stall timer. Blinky starts outside the pen.
- **Scatter/Chase phase** — global timer in Game (7s scatter / 20s chase, arcade phase table). Pauses while any ghost frightened. On phase change, all non-frightened/non-eaten ghosts reverse direction.
- **Power-pellet → Frightened** — all non-eaten ghosts reverse, swap to `FrightenedController`, slow to ~50% speed, 10s timer. On expiry, re-swap to active (Scatter or Chase per phase). Eaten ghost is unaffected.
- **Speeds** — ghost = 0.75× player, frightened = 0.5×, eaten = ghost speed (MVP; tunnel slowdown deferred).
- **Player↔ghost collision** — AABB after advance. Active ghost → reset all actors to spawn (lives stubbed). Frightened ghost → +200/400/800/1600, ghost → `Eaten`. Eaten ghost → no-op.

Agents (Player, future Enemy) consult **Maze** (semantics) + **GridProjection** (geometry).

## Tunnel

A **Tunnel** is a horizontal corridor whose `_` cells touch column 0 and column `width-1` on the same row. **Wrapping** is the act of crossing the seam: actor walks off one edge and reappears fully on the opposite edge.

Two layers:

- **Topology**: `Maze#walkable?` wraps `gx`, so probes across the seam see the cell on the other side. The grid is toroidal on X.
- **Pixel motion**: `GridMover#advance` teleports `@x` once the rect has fully exited the playfield horizontally (`x + w <= playfield_left` or `x >= playfield_right`). Actor is briefly invisible during transit; `Renderer` skips draw for fully-off-playfield rects.

No tunnel char in the alphabet — tunnels are implicit by edge-adjacency.
