# ADR-0012: Scene-transition request as the single full-rebuild path

## Status

Accepted — 2026-05-15.

## Context

Pre-UI1, `Game` was the top-level object. `main.rb` owned a single `@game` and a `request_game_reset` flag set by the bare game-over screen; the next tick rebuilt `Game.new`. CONTEXT.md called this "the only remaining full-rebuild path".

UI1/UI2/UI4/UI5 introduce screens that should **not** own a live `Game`: the title screen, the settings screen, and (in part) the highscore/game-over screen. They are not "states of a run" — they are sibling top-level modes. Putting `:title`/`:settings` inside `Game`'s state machine would force a `Game` instance to exist before the player has chosen to play, drag run state through unrelated UI, and bloat `Game` with concerns that have nothing to do with the maze.

Alternatives considered:

- **Extend `Game state` enum** with `:title`/`:settings`. Rejected — couples UI lifecycle to a run instance; `Game.new` allocates a maze, ghosts, audio progression, etc. before any reason to.
- **New `Scene` class** owning an optional `@game`. Rejected for MVP — adds an abstraction layer before there's pressure for it. Can be introduced later if scenes accumulate behavior.

## Decision

`main.rb` owns a single `$scene` symbol (`:title`, `:playing`, `:settings`, `:highscores`) and tick-dispatches on it. The existing `request_game_reset` flag is generalised to `request_scene(name)`: any code path can request a scene swap, applied at the top of the next tick. Transitioning *into* `:playing` builds a fresh `Game`; transitioning *out* drops the reference. This stays the **only** full-rebuild path — no other code calls `Game.new`.

Pause is **not** a scene. It's a `Game state` (`:paused`) so the run instance survives pause/resume without rebuild. Settings-from-pause is a scene swap with a "return scene" memoized so resume re-enters `:playing` with the same `Game`.

## Consequences

- `Game` no longer needs to know about title/settings. Its state machine stays run-scoped.
- Adding more scenes (level select, credits) is a one-line enum extension + a `tick_<scene>` method in `main.rb`.
- The "single full-rebuild path" invariant in CONTEXT.md is preserved and made more explicit.
- Settings opened from pause must round-trip back to the same `Game` — implemented via a `@scene_return_to` slot in `main.rb`, not by re-entering `:playing` (which would rebuild).
