# From Pac-Man to Beater

*Devlog #1: the arcade-remake spine of a rhythm maze game.*

> [SCREENSHOT 1: hero shot. Player mid-fire, enraged ghost, particles popping.]

I spent two weeks arguing with a 45-year-old game. Pac-Man kept winning,
so I changed the rules. Beater is what we agreed on: same maze, same
ghosts, no power pellets, you have a gun now. This is the story of what
I had to throw out to make the music work.

The pitch was simple. A Pac-Man-shaped maze where eating dots builds a
music track. Eat all the red dots, the bass comes in. Eat the greens,
drums. Each colour is a stem. The level *is* a song you assemble by
playing well.

That pitch told me which arcade machinery was load-bearing and which
actively fought the music hook. Most of what follows is me figuring out
the difference.

---

## Kept

A lot of Pac-Man's design is correct. I kept the bits that are correct.

The maze topology stays. Toroidal X-axis tunnels (you exit left, you
come back right). Passability roles per tile (some cells let ghosts
through but not players; the door above the ghost house is the
canonical case). Distinct tunnel tiles that slow ghosts down. Those are
not quirks. They are the maze. Touch them and Pac-Man stops being
Pac-Man.

The ghosts' AI stays. Blinky chases your tile. Pinky targets four cells
ahead of your facing. Inky uses Blinky's position to set up pincers.
Clyde charges until he gets close, then retreats. The scatter-chase
phase table is straight out of Jamey Pittman's *Pac-Man Dossier*. I
literally typed his Table A.1 into a frozen Ruby data file, kept the
"levels past 21 clamp to the last row" rule, and called it a day. There
is no point rederiving what someone already wrote down in 2003.

Pac-Man's movement is beat-locked. Load-bearing decision. Player speed
is one cell every quarter-beat at 128 BPM. Not a value tuned by ear; a
derived value, `CELL_SIZE / FRAMES_PER_CELL`, where `FRAMES_PER_CELL =
FRAMES_PER_BEAT / CELLS_PER_BEAT`. The beat is the single tempo source
of truth, and everything else (ghost speeds, animation, projectile
speed) is a multiplier of it. The OG already moved Pac-Man at a
metronomic rate. I just made it a literal metronome.

> [SCREENSHOT 2: OG Pac-Man corner, for the reader who's forgotten what
> we're remaking.]

## Cut

This is where the music wedge starts paying off.

The frightened state is gone. No power-pellet-induced ghost-edible
window. No blue-flashing scared ghosts. No 200-400-800-1600 chain.
Frightened ghosts were Pac-Man's only player-side aggression, and they
worked because the music told you when the window was closing. That
descending stinger every kid recognises. But my music had to do
something else. It had to track *dot progress*, not arbitrary chase
timers. A frightened-window stinger would step on the music I needed
for the actual game.

So frightened died, and with it the power pellet's primary purpose
went too. The pellets are still there, but they now drop ammo for the
gun (more on this below). The visual icon stayed; the timer mechanic
behind it didn't.

Cruise Elroy went too, in its original form. Elroy in OG was a
Blinky-only speed bump triggered by *total* dots remaining. At the
last 20 dots he gets faster, at 10 he gets faster again. I broke this
into something more rhythmic. See Enrage, below.

The fruit/bonus row is on the shelf. No bonus collectables in Beater's
first slice. The pitch was already complicated enough without bolting
a risk/reward currency to the side of it. ([docs/TODO.md](../TODO.md)
has "bonus score collectables" filed as a future thing.)

## Added

A gun, in place of the power-pellet edibility window
([ADR-0007](../adr/0007-finite-ammo-manual-fire.md)). Power-pellets
now drop 5 rounds of ammo. Fire input (space / controller south)
launches a projectile in your travel direction at 2× player speed.
Walls stop it, tunnels wrap it. It kills any active ghost on contact.
No frightened state to gate the kill. Your aggression is *your*
problem now, not the game's.

This is the cut-and-add load-bearing pair. Without frightened, the
player has no way to fight back. Without a finite ammo gun, the
ghosts' AI would crush you on level 3. Power pellets had to keep doing
*something*, and discrete ammo drops are rhythmic in a way the
frightened timer never was.

Quadrant Territories and Enrage
([ADR-0010](../adr/0010-quadrant-territory-enrage.md),
[ADR-0011](../adr/0011-enrage-bullet-resistance.md)). The big one. The
maze splits into four quadrants by ghost-scatter corner: Blinky owns
top-left, Pinky top-right, Clyde bottom-left, Inky bottom-right. The
dots in each quadrant are *that ghost's* dots, tinted to match. Eating
dots from a quadrant escalates its owner ghost through three discrete
`Enrage` steps:

- `:off`: normal behaviour, dies to 1 bullet.
- `:enrage1`: ignores scatter (always chasing), modest speed bump,
  takes 2 bullets.
- `:enrage2`: same plus harder speed, immune to bullets.

When you clear a quadrant's last dot, that ghost Pacifies. Permanently
despawns for the rest of the level, plus an Enrage-scaled bonus. The
level becomes a four-toothed sawtooth of difficulty. Each quadrant
gets meaner and meaner until you snap it off, then the maze is calmer
until the next quadrant heats up.

> [SCREENSHOT 3: the kept / cut / added grid as one image. Visual
> equivalent of this section's TL;DR.]

---

## The frightened cut, in detail

This deserves its own section. It's the cut most readers will balk at.

Pac-Man's frightened state is *the* moment of catharsis in the game.
You stop being prey and become predator for ten seconds. The whole
mood inverts. The music inverts with it. It's load-bearing for the
emotional arc, not just the mechanics.

I cut it for the music. Beater's music is dot-progress-driven. Track
completion ratio per colour feeds an interpolated lowpass-cutoff and
gain curve per stem. Eating reds opens the bass filter. Eating greens
brings up the drums. A frightened-window stinger would have to live
*alongside* this progression and crash it every ten seconds. I tried.
It sounded terrible. The music needs the level's full attention, or
it doesn't earn its place in the title.

I also cut it for the asymmetry. Frightened is binary aggression: you
are either hunting or being hunted. Beater wants analog aggression.
You have ammo. You have a gun. The ghosts' threat level rises as you
eat. The gun made frightened redundant, and two systems competing for
the same job is a smell.

> [SCREENSHOT 4: a before/after sketch. Frightened-window timer on the
> left, ammo row and enrage gauges on the right.]

The hardest part was sitting with it. Cutting frightened felt like
removing Pac-Man's soul. It took me three days to admit the game
worked better without it.

## The Enrage add, in detail

> [SCREENSHOT 5: HUD shot. Four enrage meters, ghost identity icons
> with red overlay, quadrant-tinted floor.]

Enrage is Beater's identity. It's also the system I rewrote three
times.

First pass: a single global enrage bar driven by total dots eaten.
Boring. Indistinguishable from a difficulty slider.

Second pass: per-ghost enrage driven by how often you bullet that
ghost. Punished the player for using the gun. Made the gun feel like
a trap.

Third pass, the shipped one, drops the trigger onto territory
clearance. Each ghost's enrage is its quadrant's clearance ratio.
This binds the four ghosts' difficulty curves to four spatial regions
of the maze. The player chooses which quadrant to clear first; that
ghost gets meaner first; the player can Pacify it to *delete* it from
the level ([ADR-0010](../adr/0010-quadrant-territory-enrage.md)),
trading a Pacify bonus for permanent quadrant calm. By the time
you're working on the fourth quadrant, three ghosts are gone. The
OG's "lonely victory lap after all dots cleared" feel arrives four
times per level instead of once.

The HUD shows it. Four meters across the bottom, one per quadrant,
left-anchored by the ghost's identity icon. Icon tints red at
`:enrage1`, brighter red plus beat-synced pulse at `:enrage2`, dims
when the quadrant is Pacified. The bar tells you *how close*; the
icon tells you *what kind of trouble*. Same two channels the OG used
(progress and state), repurposed.

The bullet-resistance ladder
([ADR-0011](../adr/0011-enrage-bullet-resistance.md)) is what keeps
the player from cheesing the system. At `:enrage2` the ghost is
immune. Every hit is a bright flash and a metallic clank, no damage.
You can't shoot your way through. You have to either Pacify a
neighbouring quadrant first (changes the threat geometry) or accept
the chase.

---

## What I keep coming back to

Remaking an arcade game well means knowing exactly which load-bearing
wall you're knocking out.

Pac-Man is mostly load-bearing walls. The maze, the AI, the
beat-locked movement, the scatter-chase phase table. Those are not
suggestions. Touch them carelessly and the game forgets it was
Pac-Man.

The frightened state was a wall I could move. The fruit row was a
piece of trim. Cruise Elroy was a handrail I rebuilt as four separate
handrails, one per quadrant.

The two-week clock helped. Long enough to dissect the OG with
respect. Short enough that I couldn't afford to reinvent anything
that already worked. Most of Beater's ADRs cite *The Pac-Man Dossier*
directly. Pittman had already done the homework on ghost AI, and I
had a music hook to ship.

Next devlog: the dev tools that made all of this tractable in two
weeks. Spoiler. I built a sprite scrubber and a music-tester before I
built half the actual game, and that's the only reason the schedule
held.

> [SCREENSHOT 6: full Beater playfield, mid-game, all four ghosts
> visible, HUD active.]

---

*Beater is built in [DragonRuby GTK](https://dragonruby.org/). Engine,
design, code, art and music: Andrea D'Amico (kc00l) at Fifth Layer
Studio. Reference: [The Pac-Man Dossier](https://pacman.holenet.info)
by Jamey Pittman.*
