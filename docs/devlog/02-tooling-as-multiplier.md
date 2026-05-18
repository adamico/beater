# The dev tools that shipped Beater in two weeks

*Devlog #2: tooling as a force multiplier on a one-person team.*

> [SCREENSHOT 1: Sprite Lab scene. Left list of entities, right list of states,
> ghost sprite centred on a black stage.]

Beater is built by one person. The math on that is brutal. Two weeks,
four enemy types with distinct AI, a four-stem dynamic music system, a
maze with toroidal tunnels, a HUD, a high-score screen, a jukebox, a
title menu and a settings page. Plus art. Plus sound design. Plus the
postmortem you're reading.

The only way that math worked is dev tools. I built a sprite scrubber
and a music tester before I'd built half the actual game. Every
significant feature in Beater has a tool behind it that I never
shipped, and a couple of tools I *did* ship because they turned out
to be more fun than the game.

Let me walk through the four that mattered most, in the order I built
them.

---

## BeatClock: the tempo source of truth

The first bug I had was the bug I refused to ever have again. A
gameplay event that fired one frame off the beat. A drum hit that
landed on the wrong frame. Audio drift relative to the visual
metronome over a two-minute level.

The fix was structural, not a tuning pass. I made the beat a *pure
function* of `args.tick_count`. `BeatClock` exposes `beat_index(t)` and
`fraction_of_beat(t)`, both derived from the engine's tick count and a
constant `FRAMES_PER_BEAT = (FPS * 60.0) / LEVEL_BPM`. No state, no
accumulator, no "did we just tick" check. The same input always
returns the same output.

Two downstream wins fell out of this.

First, pause coherence. The game's pause state freezes simulation but
not `args.tick_count`. So `BeatClock` keeps returning the right beat
across pause without any resync logic. The audio stays in phase even
if you pause for a minute, unpause, and resume mid-bar.

Second, anything that needs to be beat-synced just calls `BeatClock`.
The HUD's beat pulse indicator. Each ghost's vertical bobbing
animation (phase-offset per identity so they bob in a chorus, not in
lock-step). The countdown stinger on level start. None of those need
their own timing logic; they're all derivative of one function call.

BeatClock isn't sexy. It's twenty lines of code. But it eliminated
an entire category of timing bug from the project, and that's
exactly the kind of dev tool I mean when I say tooling is a force
multiplier.

> [SCREENSHOT 2: the HUD's beat-pulse indicator at peak and trough,
> side by side.]

## Sprite Lab: scrubbing every sprite without playing the game

About four days in, I'd added enrage steps to the ghosts. Each ghost
now had four visual configurations stacked on top of its FSM state:
normal, `:enrage1` red overlay, `:enrage2` brighter red with a
beat-synced pulse, plus the per-hit `armor_flash` white blink. With
four ghosts and an existing eaten-flash anim, that's roughly thirty
distinct render outputs I needed to be able to eyeball.

Driving the actor into the right state through gameplay is unreliable
and slow. I built Sprite Lab.

It's a dev-only scene reachable from the title menu, hidden in production builds via
`$gtk.production?`. Two lists: pick an entity (player, blinky,
pinky, inky, clyde, eaten, …), pick a state (`scatter`, `chase`,
`dying`, `eaten`, …). The chosen sprite renders at native size on a
black stage. Modifier keys toggle render-affecting state: cycle
enrage step, fire an armor flash, advance death-anim by one frame.

The catch: Sprite Lab doesn't enumerate from the actor's FSM. It owns
a hand-curated catalog of `entity → state_label → lambda` entries.
The lab calls `to_sprite` on a real `Player` / `Ghost` instance, so
procedural anims (player death) stay in sync with shipping code — but
which previews exist is a separate decision from which FSM states
exist.

This is the right trade-off. Many FSM states render identically (an
`:in_house` ghost looks the same as a `:scatter` one); the lab
doesn't need to surface them. And many render variations *aren't*
FSM states (enrage step, armor flash, scale-pulse on hit). The
catalog is the single source of "what's previewable," not the FSM.

Sprite Lab paid for itself on day five. I was wiring the new red
guitar Blinky sheet and flicked through every ghost identity in the lab. The red guitar was
landing on the *bass* stem owned by Blinky-in-territory-terms, but
Blinky-in-canon-terms is supposed to be red and was instead green in
my codebase. The whole colour-to-ghost-to-stem mapping was off by one
identity swap. I'd have noticed eventually during gameplay; I noticed
in 30 seconds in the lab.

Cost of the swap, once spotted: 11 lines of changed config.

> [SCREENSHOT 3: Sprite Lab showing the four ghosts in their enrage
> states, side by side, with modifier-key legend visible.]

## Progression Tester (which became the Jukebox)

The music in Beater is dot-driven. Each colour's track-completion
ratio feeds an interpolated cutoff and gain curve per stem. To tune
those curves I'd otherwise have to play levels to specific dot
counts, which is the most annoying way to A/B mix decisions ever
invented.

I built `ProgressionTester`: vertical faders per stem, scrub the
completion ratio of any stem in real time, mute/solo, audition every
SFX from a side panel. It runs on the *real* `Audio::Manager` the
game uses, so what you hear at completion = 60% in the tester is
exactly what plays at completion = 60% in-game.

Then I noticed something. The tool was more fun than parts of the
game.

So I added it to the title menu as the Jukebox scene and gave it the
post-3 treatment it earned. That story is the next
devlog. The point for this one: the tool didn't become a feature
because I needed a new feature. It became a feature because the
shortest path to a tunable music mix happened to also be a fun thing
to use.

The next time you build a debug screen and catch yourself enjoying
it, that's signal. Ship the debug screen too.

> [SCREENSHOT 4: ProgressionTester / Jukebox UI with faders mid-mix.]

## LevelConfig: porting the Dossier as data

Pittman's *Pac-Man Dossier* contains a table (A.1) of per-level
parameters: ghost speed ratio, ghost tunnel speed ratio, Cruise
Elroy thresholds and speeds, scatter-chase phase tables, frightened
duration, bonus type. The table goes from level 1 to level 21,
with the spec note "21+ clamps to the last row."

I typed it in. Verbatim. Frozen Ruby hash, one entry per level,
column names matching Pittman's. The frightened and bonus columns go unused (no frightened state in
Beater, no fruit system yet) but stay in the data so the structure
matches the source.

This is not a tool in the SpriteLab sense. There's no UI. It's a
*data file you can edit without recompiling intuition*. When level 4
felt too slow, I changed one ratio in the table and ran. When
Pittman's Elroy thresholds didn't feel right with finite-ammo
gameplay, I had a row to point at and adjust, not a tuning constant
buried in a controller.

The tool-ness is in the fact that the source of truth lives outside
the code that consumes it. `Game#apply_level_config` is one method
that reads the row. Adding a new level = adding a row. Re-tuning
existing levels = editing rows.

Pittman did the design work in 2003. My job in 2026 was to make his
work loadable as data instead of rederiving it. The hardest part
was resisting the urge to rederive.

---

## What this looks like in practice

Four tools, four different shapes. A pure-function timing primitive.
A scene with a curated catalog. A debug UI that grew up. A frozen
data file.

What they share: each one took *less* than a day to write, and each
one paid for itself within a week. That's the ratio I look for. If a
tool would take three days to build and would save me four days
over the rest of the project, it's a wash. If it takes a day and
saves a week, build it.

The instinct most one-person teams get wrong is treating tools as
overhead. They're not overhead. They're the only way the math
works.

Every shipped feature in Beater has a dev tool behind it that you'll
never see. The Jukebox is the one that escaped containment. Next
devlog is about how that happened and why I'm glad it did.

> [SCREENSHOT 5: split image, SpriteLab on the left, Jukebox on the
> right, showing two tools that look like different kinds of UI but
> serve the same role.]

---

*Beater is built in [DragonRuby GTK](https://dragonruby.org/). Engine,
design, code, art and music: Andrea D'Amico (kc00l) at Fifth Layer
Studio. Reference: [The Pac-Man Dossier](https://pacman.holenet.info)
by Jamey Pittman.*
