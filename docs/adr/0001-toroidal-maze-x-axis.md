# Maze is toroidal on the X axis

`Maze#walkable?` wraps `gx` modulo grid width before checking the tile, so any caller probing across the left/right seam sees the cell on the opposite edge as walkable. We picked this over caller-side normalization because every probe site (movement rollback, turn probes, future ghost AI, pellet checks) needs the same toroidal view; centralizing it in `Maze` removes a class of "forgot to wrap" bugs and lets layouts express tunnels implicitly via edge-adjacent `_` cells rather than a dedicated tile char.

Y is intentionally not wrapped: current and planned layouts cap top/bottom rows with solid wall, and a vertical tunnel would need its own design pass.

Pixel-space teleport at the seam lives separately in `GridMover#advance` — `Maze` owns topology, not motion.
