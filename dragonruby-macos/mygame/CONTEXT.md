# Project Context

## Tile Alphabet

Single source of truth for layout characters. Layout files (`data/maps/*_layout.rb`)
emit these chars; runtime modules read them.

| Char | Meaning              | Walkable | Pellets    | Notes                                  |
|------|----------------------|----------|------------|----------------------------------------|
| `.`  | Regular pellet       | yes      | `:pellet`  | Default for corridor floor              |
| `o`  | Power pellet         | yes      | `:power`   | Larger pellet, ghost-fright timer       |
| `_`  | Empty floor          | yes      | none       | Ghost house, spawn area, tunnel approach |
| `t`  | Tunnel floor         | yes      | none       | Marks ghost-slowdown zone (`Maze#tunnel?`) |
| `-`  | Ghost-house door     | role     | none       | Walkable only for `:ghost_eaten` (down) and `:ghost_leaving` (up); wall to player + active ghosts |
| `G`  | Ghost-house home cell| yes      | none       | Reserved anchor cell (currently unused; identities use individual marker chars below) |
| `b`  | Blinky spawn         | yes      | none       | Spawn marker. Anchor = leftmost occurrence (sprite is 2 tiles wide). |
| `p`  | Pinky spawn          | yes      | none       | Spawn marker. |
| `i`  | Inky spawn           | yes      | none       | Spawn marker. |
| `c`  | Clyde spawn          | yes      | none       | Spawn marker. |
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
- **Ghost-house** — encoded in the layout via spawn-marker chars (`b/p/i/c`) and the door (`-`). Spawn cells are scanned at init (`Game#scan_spawn_cells`); `@above_door_cell` is taken from Blinky's spawn and used as the leaving/respawn rendezvous. Non-Blinky ghosts start in `:in_house` (frozen). On release they switch to `:leaving_house`, role `:ghost_leaving`, and target the above-door cell; on arrival they swap to the active phase mode. Eaten ghosts target their own spawn cell with role `:ghost_eaten`, then immediately transition to `:leaving_house` on arrival. Door + pen-corridor passability (cells between door and spawn row) is what makes this path resolvable.
- **Ghost controllers** — one per behavior: `BlinkyController` (target = player tile), `PinkyController` (4 ahead of player, **with arcade up-direction overflow bug intentionally replicated**), `InkyController` (reflect Blinky tile through 2-ahead-of-player), `ClydeController` (player tile if ≥8 tiles away, else scatter corner), `FrightenedController` (random non-reverse exit at intersections), `EatenController` (target = door, then home-slot), `LeavingHouseController` (waypoint path). Decisions taken at intersections (`GridMover#at_cell_center?` + ≥2 non-reverse exits); else `NONE`. Reverse excluded from candidates.
- **Release schedule** — arcade-faithful per-ghost dot counter (Pinky:0, Inky:30, Clyde:60 at level 1) + 4s stall timer. Blinky starts outside the pen.
- **Scatter/Chase phase** — global timer in Game (7s scatter / 20s chase, arcade phase table). Pauses while any ghost frightened. On phase change, all non-frightened/non-eaten ghosts reverse direction.
- **Power-pellet → Frightened** — all non-eaten ghosts reverse, swap to `FrightenedController`, slow to ~50% speed, 10s timer. On expiry, re-swap to active (Scatter or Chase per phase). Eaten ghost is unaffected.
- **Speeds** — ghost = 0.75× player, frightened = 0.5×, eaten = ghost speed (MVP; tunnel slowdown deferred).
- **Player↔ghost collision** — AABB after advance. Active ghost → reset all actors to spawn (lives stubbed). Frightened ghost → +200/400/800/1600, ghost → `Eaten`. Eaten ghost → no-op.

Agents (Player, future Enemy) consult **Maze** (semantics) + **GridProjection** (geometry).

## Audio

- **Music stems** — four looping `.wav` files (`drums`, `bass`, `lead`, `chords`) registered through `args.audio` at startup. They are the canonical background music source.
- **Track progression** — each pellet color maps to one music stem. Collecting pellets raises that stem's gain from its configured `start_gain` toward `end_gain`.
- **Procedural SFX** — gameplay feedback sounds (`dot_tick`, `power_pellet`, `enemy_eaten`, `game_over`) are still synthesized at runtime. Music simplification does not remove procedural SFX.

## Rhythm Timing

- **Beat step** — a 16th-note timing boundary derived from level BPM.
- **Quantized movement** — player movement commits to beat steps rather than firing immediately on input.
- **Quantized dot feedback** — dot-eat SFX resolves on the same beat step boundary as movement commitment.
- **Responsiveness window** — a small early/late input grace window is allowed so rhythm-locking feels intentional instead of laggy.
- **Tempo source of truth** — each level owns BPM, and runtime timing derives from BPM using floating accumulation (no rounded integer frame buckets).
- **Input scheduling** — input snaps to upcoming beat step; if input lands within 3 frames before boundary, it executes on that boundary, else on next one; never snaps backward.
- **Commit override** — during ramp, a new input can cancel and restart ramp only when that new direction is currently valid (no wall).
- **Wall handling during commit** — if committed direction becomes blocked before boundary, commit cancels immediately and player returns to idle input polling.
- **Collision during commit** — ghost collision rules are unchanged while committing; commit state grants no protection.
- **Ramp curve default** — commit acceleration uses square-root easing (`sqrt(t)`) to front-load responsiveness.
- **Post-commit movement model** — after commit boundary, movement remains continuous; quantization applies to direction commits and rhythmic feedback timing.
- **Pellet feedback split** — pellet removal resolves immediately on collision; dot-eat SFX is queued to next beat step boundary.
- **Power-pellet timing split** — power pellet consumption and frightened-state activation resolve immediately; power-pellet SFX is queued to next beat step boundary.
- **Queued dot SFX cap** — at most one dot-tick SFX plays per beat step; additional same-step pellet events still apply gameplay/progression but do not stack dot ticks.
- **SFX conflict priority** — if dot-tick and power-pellet SFX are both queued for the same step, play only power-pellet SFX and suppress dot-tick.
- **Queued SFX staleness** — queued rhythmic SFX expires if it is more than one beat step late; stale events are dropped.
- **Beat indicator** — gameplay shows an always-on subtle beat pulse to communicate timing boundaries.
- **Commit anticipation animation** — player always shows squash/stretch wind-up during commit ramp to signal locked timing.
- **Orthogonal turn ramp** — side inputs begin ramp immediately, then snap to the first legal turn cell center.
- **Orthogonal turn quantization** — if the orthogonal ramp reaches a beat boundary early, the actual turn still snaps on that next boundary.
- **Orthogonal grace window** — orthogonal turns use a tighter grace window than forward commits.
- **Orthogonal grace default** — 1 frame.
- **Held orthogonal intent** — while orthogonal input is held, turn scheduling retries at each legal intersection until applied.
- **Orthogonal pending timeout** — none; pending orthogonal intent remains active as long as input is held.
- **Orthogonal legal-turn priority** — when a held orthogonal turn becomes legal at an intersection, it applies immediately even outside beat grace.
- **Timing tuning scope** — grace window, ramp curve, and ramp duration scaling are per-level settings with global defaults.
- **Ghost tempo coupling** — ghost speeds remain state ratios of player speed, and player speed is BPM-derived.
- **Beat subdivision** — rhythmic step boundaries are fixed at 16th-note resolution for MVP.
- **Implementation order** — first shipping slice is core timing and commit mechanics (BeatClock + scheduler + commit state), then feedback polish.
- **Slice-1 acceptance gates** — scheduler deterministic under fixed ticks; commit timing stays on beat grid in long run; wall-block + reramp rules hold consistently.
- **Runtime safety fallback** — if rhythm scheduler desyncs/fails, game auto-falls back to immediate movement and immediate SFX with warning log.
- **Fallback trigger control** — fallback is triggered by automatic runtime invariant checks and can also be toggled manually via debug control.
- **Diagnostics visibility** — rhythm debug overlay/logging is detailed in development builds and minimal in release builds.
- **MVP rule freeze** — rhythm rules are frozen until slice-1 acceptance gates pass; only bug fixes are allowed during this phase.

## Tunnel

A **Tunnel** is a horizontal corridor whose `_` cells touch column 0 and column `width-1` on the same row. **Wrapping** is the act of crossing the seam: actor walks off one edge and reappears fully on the opposite edge.

Two layers:

- **Topology**: `Maze#walkable?` wraps `gx`, so probes across the seam see the cell on the other side. The grid is toroidal on X.
- **Pixel motion**: `GridMover#advance` teleports `@x` once the rect has fully exited the playfield horizontally (`x + w <= playfield_left` or `x >= playfield_right`). Actor is briefly invisible during transit; `Renderer` skips draw for fully-off-playfield rects.

**Slowdown** is explicit: tiles authored as `t` flag tunnel cells consumed by `Maze#tunnel?`. `Game#effective_ghost_speed` returns `GHOST_TUNNEL_SPEED` (0.4× player) for any ghost whose current cell is `tunnel?`, taking precedence over frightened/elroy. Eaten ghosts skip the lookup. Topology and pixel motion stay unchanged — only `t`-marked cells slow ghosts. See ADR-0005.
