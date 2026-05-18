# The Jukebox: the debug screen that shipped

*Devlog #3: a tuning UI that earned its own scene on the title menu.*

> [SCREENSHOT 1: Jukebox scene. Four vertical faders, mute/solo buttons,
> SFX side panel.]

I never set out to build a Jukebox. I set out to A/B-test the music
progression curves without playing levels. The thing that resulted is
on the title menu now, and people who try Beater spend more time on
it than I expected.

This is the story of how a tuning tool became a feature.

## The problem the tool solved

Beater's music progression is dot-driven. Each stem (drums, bass,
lead, chords) interpolates a lowpass cutoff and a gain curve as you
eat dots of its colour. At completion = 0 the stem is barely audible
and heavily filtered. At completion = 1 the filter is wide open and
the stem is at full gain. The curves are exponential on cutoff,
linear on gain, with per-stem start/end values defined in a config
table.

To tune those curves I'd otherwise need to play four parallel levels,
each eating only one colour, to specific dot counts, while listening.
That's the most annoying audio-tuning workflow ever invented.

What I wanted was a panel of four faders, one per stem completion
ratio. Drag a fader, hear what 60% bass sounds like layered against
30% drums. Mute a stem, hear the mix without it. Solo a stem, hear
it alone. While I'm here, audition every SFX too.

That panel took me about two hours.

> [SCREENSHOT 2: ProgressionTester early-build screenshot, faders only,
> no chrome.]

## Why it had to use the real audio path

The temptation when writing a music tester is to wire it up to a
parallel audio pipeline. Quick to build, easy to throw away. Also
useless: a tester that doesn't play exactly what the game plays
isn't a tester, it's a different song.

So the Jukebox uses `Audio::TrackPlayer` directly. Same class the
game uses. Same stem registration, same mix function, same native
DSP path on the macOS build. The fader value *is* the completion
ratio that `TrackProgression#params` would compute for that stem in
gameplay. What you hear in the Jukebox at fader = 0.6 is exactly
what you hear in level 3 with 60% of that colour eaten.

This buys two things. The tuning is meaningful. Every decision I
make at the faders translates 1:1 to gameplay. And the Jukebox stays
correct for free as the audio path evolves. When I added the native
backend, the Jukebox got native rendering automatically.

## The bug that earned the ADR

First implementation: stems registered with `paused: true`,
unpausing on mute toggle. Felt natural. Mute = paused stem, unmute =
playing stem.

Wrong. DragonRuby's `paused` flag freezes the stream *and* freezes
its play position. Every stem started at frame 0. Unmute the drums:
drums begin at frame 0. Three seconds later unmute the bass: bass
also begins at frame 0, three seconds offset from drums on the
shared timeline. The four stems were no longer phase-locked. The
mix was audibly off-grid, drums and bass landing on different
downbeats.

The fix: never pause. Every stem always streams. Mute is expressed
as a gain of 0.0 pushed through the same `apply_mix_settings`
function the game uses. The audio decodes continuously whether
you're listening or not. Any unmute order produces a coherent mix.

This is one of those decisions that looks obvious in retrospect and
needed a bug to discover. The kind of thing that earns an ADR.

> [SCREENSHOT 3: jukebox UI mid-jam, two stems solo'd, mute button
> highlighted on a third.]

## When it stopped being a debug screen

I'd put the Jukebox on a hidden dev key (Ctrl+J or something) for
about three days while I tuned the actual game's music. The third
day I caught myself opening it to jam.

Not to test anything. Just to mix.

That's the moment a tool becomes a feature. The tool hadn't acquired
new powers. I'd already given it everything it needed to be fun:
real audio, real-time response, mute/solo, the four stems of every
level the game ships.

So I:

1. Moved it from the dev keybind to the title menu.
2. Renamed `ProgressionTester` to `Jukebox` in the codebase so the
   name matched the role.
3. Added an SFX audition panel to the side so the jukebox could
   double as a sound-design reference.
4. Kept the jukebox-mode catalog of every level's `TRACK_CONFIGS` so
   you can mix tracks from levels you haven't reached yet.
5. Gave it its own Esc-to-title exit handler and a low-volume
   ambient mode so it doesn't blast at full volume on entry.

The total work to ship it as a Scene was about ninety minutes. Most
of that was menu wiring. The actual *mixer* was already done because
I'd built it as a tuning tool first.

## Why this matters more than it looks

Most "secret jam mode" features in games are added late, on purpose,
as a marketing bullet. They're usually thin. The reason Beater's
Jukebox isn't thin is that it wasn't a feature first. It was a
working tool that I happened to notice was fun.

That ordering matters. If I'd set out to build a Jukebox as a
feature on day one, I'd have built a Jukebox-shaped thing with no
particular need to be honest to the gameplay mix. Because I built
it as a tuning tool, the gameplay-mix honesty was the whole point.
Promoting it to a feature was a relabelling, not a rewrite.

The lesson generalises. If you're working alone and you build a
debug screen that you keep wanting to open even when nothing's
broken, that's signal. The bar for shipping a debug screen as a
feature is lower than the bar for building a feature from scratch,
because the debug screen has already proven it earns its keep with
the one user that matters most: the person who built it.

If your debug screen is more fun than your game, ship the debug
screen too.

> [SCREENSHOT 4: Jukebox shown on the title-menu list as a first-class
> option, alongside Play, Settings, Credits.]

---

That's the three-post series. The arcade-remake spine, the dev tools
that made it tractable, the tool that broke containment. Together
they're the shape of what Beater actually was: two weeks of
dissecting Pac-Man with respect, two weeks of building the
scaffolding that let me move fast enough to ship.

Thanks for reading. Beater is on itch.

> [SCREENSHOT 5: full Beater title menu, with Jukebox visible as a
> menu entry.]

---

*Beater is built in [DragonRuby GTK](https://dragonruby.org/). Engine,
design, code, art and music: Andrea D'Amico (kc00l) at Fifth Layer
Studio.*
