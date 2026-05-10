# Pinky's up-direction overflow bug is replicated intentionally

Pinky targets the tile 4 steps ahead of the player's facing direction. In the original arcade, when the player faces UP, the targeting code adds the offset to *both* X and Y (an off-by-one-axis bug), so the target ends up 4 up + 4 left of the player rather than straight ahead. Without this bug, head-on encounters with Pinky become predictable: player can stand still or walk straight up and Pinky's intercept is trivially read.

We replicate the bug deliberately. `PinkyController` applies the up-direction X-offset when player direction is UP. The arcade feel — Pinky cutting in from a non-obvious angle when the player is heading north — is load-bearing for the chase dynamic that GDD calls out ("ambush ahead"). Players who've internalized arcade Pac-Man read the offset correctly; "fixing" it would feel wrong to anyone who's played the original.

This is the kind of decision that will look like a bug in code review. The targeting math has a comment pointing here. If a future maintainer "fixes" it, head-on Pinky play breaks.

Rejected: corrected 4-ahead targeting. Cleaner code, but flattens Pinky into a slower Blinky variant on vertical corridors.
