# ADR-0015: Jukebox mutes stems via gain, not the `paused` flag

## Status

Accepted — 2026-05-17

## Context

The jukebox scene (`app/jukebox.rb`) opens with all four stems silent so the
user can audition each one on demand by clicking M/S or pressing 1–4. The
first implementation expressed mute by writing `args.audio[key].paused = true`
on each track and flipping it to `false` on unmute.

DragonRuby's `paused` flag halts the stream **and freezes its play position**.
Every stem registered at jukebox init started paused at frame 0. When the
first unmute fired, that stem resumed from 0. The other three stems were
still frozen at 0. A few seconds later, unmuting a second stem started it
from its own 0 — now offset from the first by however many frames elapsed
between the two clicks. The four stems were no longer phase-locked to a
single timeline, so the mix was audibly off-grid (drums and bass landing on
different downbeats).

The native audio backend (`audio_stem_fx.dylib`) compounded this: gain on
native streams is pushed through `NativeBridge.push_track_params` from
`sync_gains` every tick, so writing `args.audio[key].gain = 0` from the
jukebox would have been silently overwritten. That's the original reason the
jukebox reached for `paused` instead of `gain` — but `paused` solves the
gain-write problem while breaking the sync invariant the whole design relies
on.

## Decision

Stems always stream (registered with `paused: false`, never re-paused by the
jukebox). Mute is expressed as a gain multiplier of 0 or 1, applied inside
`Audio::Manager#sync_gains` so it flows through the same path as progression
gain and duck multiplier — and therefore through `NativeBridge` on the native
backend.

- `Audio::Manager` owns a `@mute` hash and a `set_mute(track, bool)` setter.
- `sync_gains` multiplies each track's progression gain by `0.0` or `1.0`
  from `@mute`.
- The jukebox computes silence per frame as
  `solo ? (solo != track) : muted[track]` and calls `audio.set_mute(track,
  silenced)` before `audio.tick`. Solo stays a jukebox-only concept; the
  game never solos.

## Consequences

- Phase alignment is preserved: all four stems advance on the same timeline
  whether audible or silent, so any unmute order produces a coherent mix.
- All four stems decode continuously while the jukebox is open. The user
  authored this as throwaway-style audition UI; the cost is acceptable.
- `args.audio[key].paused = ...` is no longer the jukebox's tool for
  silencing music. `Audio::Manager#on_game_over` still uses `paused = true`
  as a terminal stop because the Manager is replaced on replay and a WAV-
  based game-over track will land there later. Outside game-over, treat
  `paused` on music streams as a code smell.
- If a future scene needs the silence-the-mix-without-killing-phase
  behaviour, reuse `set_mute`. Don't reach for `paused`.
