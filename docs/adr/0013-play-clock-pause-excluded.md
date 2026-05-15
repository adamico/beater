# ADR-0013: Play clock excludes pause, ready, dying, level_complete, game_over

## Status

Accepted — 2026-05-15.

## Context

UI5 introduces a highscore table that records the time taken for each run. "Time taken" has more than one sensible definition, and the choice is sticky: once scores are persisted, changing the clock breaks comparability across saves.

Candidates considered:

- **Wall-clock seconds** from first `:playing` entry to `:game_over`. Simple, but rewards leaving the game paused (e.g. AFK during a hard section) and counts the death animation, level-complete fanfare, and `ready` count-in — none of which the player is actually playing.
- **Total ticks ÷ 60** across all `Game state`s. Same problem: pauses and animations inflate the number.
- **Tick count incremented only in `tick_playing`**. Matches the player's intuition of "how long I was actually playing". Pauses, deaths, and level transitions don't count. Cheaters can't pad time by pausing — but also can't lose time to a long death sequence.

Highscore semantics: lower time at equal score is "better" in any future leaderboard sort, so we want time to reflect *engagement time*, not *elapsed time*.

## Decision

`Game` owns `@play_ticks`, incremented exactly once per `tick_playing` call. `Play clock` advances **only** in `:playing`; it does not advance in `:ready`, `:paused`, `:dying`, `:level_complete`, or `:game_over`. Displayed as `MM:SS` (`@play_ticks / 60`) on the UI5 game-over screen and stored in `highscores.txt` as `time_seconds`. Reset to 0 on full `Game` rebuild (i.e. on `request_scene(:playing)`).

## Consequences

- Pausing is "free" — encourages players to use the pause menu without penalty. This matches the spirit of a single-player game.
- The death animation (~30–40 frames) and the level-complete ease don't count against the player. Slower deaths from later levels don't pad the time.
- Time is comparable across runs only as long as `tick_playing` runs at a stable 60 Hz, which DragonRuby guarantees.
- Migrating the saved format later (e.g. to wall-clock or sub-second precision) requires a versioned `highscores.txt` schema. Worth doing up front: include a `version: 1` key in the serialised payload.
