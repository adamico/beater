# Tunnel slowdown is an explicit tile, not an edge-walk heuristic

Ghost tunnel slowdown (`GHOST_TUNNEL_SPEED`, 0.4× player) requires knowing which cells are "in the tunnel". The original implementation derived this by walking every row from both edges and marking any walkable cell reachable in an unbroken run from a wrap-edge cell.

That heuristic over-approximates. On the pacman layout's tunnel row, the unbroken run from each edge extends past the intended slowdown zone into the pellet at col 7 and the `_` cells past it, so ghosts slowed on tiles that should be full speed.

We introduce `Tiles::TUNNEL = "t"` as an explicit, hand-authored marker in the layout. `Maze#compute_tunnel_cells` becomes a flat scan that collects exactly the `t`-marked cells. `t` joins `Tiles::WALKABLE`, so it inherits passability for every role (including `:ghost_eaten` and `:ghost_leaving`) without separate plumbing. Speed lookup in `Game#effective_ghost_speed` is unchanged — tunnel check still wins over frightened/elroy, matching the OG dossier (tunnel 40% < frightened 50%, no stack).

Rejected — extend the heuristic and additionally honor `t`: layers two rules with overlapping intent. The point is to make the map the single source of truth, not to add a second source on top.

Rejected — keep heuristic, document the off-by-N cells as known limitation: leaves a permanent precision gap on every map that doesn't happen to terminate the run at exactly the desired cell.

Cost: every new map must mark tunnel tiles explicitly; the alphabet grows by one char. Worth it — tunnel zones are gameplay-significant and small in count, so they should be authored, not inferred.
