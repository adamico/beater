# Passability is a role-indexed policy on Tiles, not a bool on Maze

The ghost-house door tile (`-`) is walkable for some actors and a wall for others: ghosts in `:ghost_eaten` state pass through it going down (eyes returning to the pen); ghosts in `:ghost_leaving` state pass through it going up; the player and ghosts in any active chase state treat it as a wall. A single-arity `Maze#walkable?(gx, gy) -> bool` cannot express that.

We move the policy into the `Tiles` module: `Tiles.passable_for?(ch, role)` returns a bool given a tile char and an actor role (`:default`, `:ghost_eaten`, `:ghost_leaving`). `Maze#walkable?(gx, gy, role: :default)` delegates. Adding a new role (e.g. a future "phasing" power-up) is one column in the policy table; Maze and GridMover do not change.

Rejected — context arg on Maze (`walkable?(gx, gy, for: :ghost_eaten)`): puts knowledge of actor states inside Maze, which currently knows nothing about agents. Tiles already owns the char alphabet, so policy keyed by char belongs there.

Rejected — keep `walkable?` as bool, special-case the door at every ghost-mover call site: forces every actor that touches movement to know about every special tile. The point of the alphabet is to keep that knowledge in one place.

Cost: callers must now pass a role when they aren't asking about the default actor. GridMover defaults to `:default`, so player code is unchanged. Ghost movement code passes the role from current state.
