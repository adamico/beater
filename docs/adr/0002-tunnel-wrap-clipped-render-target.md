# Player rendered through a clipped target sized to the visible play area

The maze is toroidal on X (ADR-0001), so the player teleports across the left/right seam in pixel space (`GridMover#advance`). Drawing the player straight to `outputs.sprites` lets the sprite peek out of the wrap-edge columns mid-step, which reads as a visual glitch at the seam. We render the player into an off-screen render target (`outputs[:clipped_area]`) sized to the *visible play area* — the maze inset by its wrap-edge columns — and blit that target onto the screen at the same rect. Anything outside the visible area is clipped for free, so the seam looks clean without per-frame visibility math.

The visible bounds live on `Maze` (`#visible_cell_bounds`) and are derived from `#wrap` rather than hardcoded: if Y ever wraps, the inset follows automatically. `GridProjection#rect_for_cell_bounds` does the grid→pixel conversion so `Maze` stays pixel-free. Renderer holds no layout constants; it asks the maze and projection.

Rejected: per-frame "is the player crossing the seam?" branching in the renderer — works, but every new wrap axis or moving entity (ghosts) would need the same logic. The clipped target generalizes for free.
