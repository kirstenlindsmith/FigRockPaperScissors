# Measured envelope

Every number here was measured on this engine, on one machine: Linux aarch64, 10 cores, 8 GB,
Swift 6.1.2, an `-O` build, a shared virtualised box. Each figure names the `battle-measure` run that
produced it, to the seed; the few taken off a fixture only the suite builds name the test instead.
Timings were taken with nothing else of ours running; work counters, memory, geometry and battle
outcomes are exact or machine-independent.

The thresholds the tests enforce are in `Tests/BattleEngineTests/Gates.swift`; this file is the
evidence they were set from. It reports what the engine does, not what it is allowed to do.

## Cost

`battle-measure bench n=<soldiers> armies=even seed=1 warm=30 ticks=<ticks> runs=5`, four passes over
every size. `ticks` is 200 up to 16 000 soldiers, 60 at 24 000–64 000 and 30 above; at 300 it is 100,
because a pass of five runs of 200 spends 1 030 ticks of a battle that lasts 1 044, and the last runs
of it would be timing the mop-up rather than the crowd. Run the tool through `swift run -c release`,
which rebuilds what it runs: the binary `swift test -c release` leaves behind in `.build/release` is
built for testability and times about a tenth slower.

Three of these columns belong to the engine and one belongs to the box. The visit counters and
`storageBytes` are exact, and the process high-water repeats to the tenth of a megabyte. **The
nanoseconds are a sample of a shared virtualised machine, not a constant of the engine.** What is
committed is the worst *pass*: the five runs of a pass measure one crowd, their median is what that
pass saw, and the bound is the largest of the four pass medians. The worst single run sits beside it
because the distance between the two columns is the box and not the engine — at 24 000 soldiers the
twenty runs of the sitting spanned 366 to 493 ns while the four pass medians sat between 455 and 458,
with every exact counter unmoved. A bound read off one starved window does not reproduce, and the
ceiling below is derived from the committed column.

| soldiers | ns per soldier per tick, committed bound | worst single run of 20 | candidate visits per soldier per tick | process high-water | `setup.storageBytes` |
|---|---|---|---|---|---|
| 300 | 420 | 445 | 13.30–15.01 | 7.7 MB | 0.02 MB |
| 1 000 | 459 | 475 | 13.47–15.90 | 7.7 MB | 0.07 MB |
| 1 500 | 481 | 489 | 14.14–15.96 | 7.9 MB | 0.10 MB |
| 4 000 | 505 | 521 | 14.39–16.63 | 8.0 MB | 0.27 MB |
| 6 000 | 507 | 517 | 14.55–16.22 | 8.1 MB | 0.41 MB |
| 16 000 | 513 | 517 | 14.72–16.42 | 8.7 MB | 1.09 MB |
| 24 000 | 458 | 493 | 13.31–16.36 | 9.4 MB | 1.64 MB |
| 50 000 | 463 | 499 | 13.35–16.20 | 11.1 MB | 3.43 MB |
| 64 000 | 464 | 496 | 13.37–16.28 | 12.1 MB | 4.38 MB |
| 256 000 | 424 | 461 | 12.78–15.71 | 25.2 MB | 17.52 MB |
| 1 000 000 | 444 | 473 | 12.78–15.73 | 76.1 MB | 68.38 MB |

Milliseconds per tick are the committed column times the army over a million: 0.13 at 300 soldiers,
11.0 at 24 000, 444 at a million.

**A sitting that exceeds a bound invalidates the ceiling below, which must then be re-earned rather
than edited**, and the app must in any case re-take the measurement on the device it ships on.

**Cost does not change as a battle deepens.** `bench n=6000 armies=even seed=1 warm=30|500|1500|3000
ticks=200 runs=3` gives 418–534 ns and 14.6–17.3 visits at every depth: the scattered opening becomes
the pursuit crowd within tens of ticks, and the crowd is what the column above measures.

Flat across three decades: from a thousand soldiers to a million the committed bound spans 424 to 513
ns — a fifth, with no trend in the size — which is the cache and the box, not the algorithm. The exact
column says the same without a clock: candidate visits per soldier stay between 12.8 and 16.6 across
that range, and a superlinear step cannot hide under a curve that flat.

There is no longer a setup axis to this section. A setup is a screen shape, a seed and three counts;
the counts change how long a battle lasts, not what a tick costs.

## Memory

`setup.storageBytes` is what a battle **retains**: the sixteen buffers `init` buys and holds until the
battle is released. Each buffer is stated once, as a count and a type, and the price is the sum of
those statements, so what the app is quoted and what the allocator is asked for are the same
sentence. The column above is that figure; the process high-water beside it is `VmHWM` from the same
run. The floor is 7.7 MB — the runtime, the binary and the tool, measured at 300 soldiers where the
engine's own storage is 0.02 MB.

**Above that floor the high-water is the price itself.** Placing the armies is one pass over the
lattice and allocates nothing, so the excess over `storageBytes` that a placement's scratch would buy
is not there: high-water minus floor is 1.6 MB against the 1.64 MB quoted at 24 000 soldiers, 4.4
against 4.38 at 64 000, 17.5 against 17.52 at 256 000 and 68.4 against 68.38 at a million. An app
that budgets `storageBytes` and the runtime's own floor will not be surprised.

## The ceiling

Four things limit the size an app may offer, and it must advertise the smallest of them.

- **What one core carries.** At the cost bound for that size and 64 ticks per second, the fastest
  speed one core sustains is `10⁹ / (ns × 64 × N)`.
- **How long a battle lasts.** Battle seconds ÷ that speed is how long the user watches.
- **What it costs to hold.** `setup.storageBytes`, above.
- **Whether a watcher can see a soldier.** A glyph is `soldierDiameter / arena.y` of the screen's
  height — `0.5·√aspect / √N`, which on a 19.5∶9 portrait screen is `1 / (2.94·√N)`. That is
  arithmetic on the public surface, not a measurement.

With equal counts and the battle lengths from § Battles:

| soldiers | fastest speed one core sustains | median battle | watched | longest battle | watched | held | glyph, 19.5∶9 portrait |
|---|---|---|---|---|---|---|---|
| 300 | 124× | 16.3 s | 0.13 s | 45.5 s | 0.4 s | 0.02 MB | 1/51 of the height |
| 1 500 | 21.7× | 48.1 s | 2.2 s | 131.7 s | 6.1 s | 0.10 MB | 1/114 |
| 6 000 | 5.14× | 160.4 s | 31 s | 314.6 s | 61 s | 0.41 MB | 1/228 |
| 24 000 | 1.42× | 318.0 s | 3.7 min | 511.9 s | 6.0 min | 1.64 MB | 1/456 |
| 50 000 | 0.67×, below real time | — | — | — | — | 3.43 MB | 1/658 |

Every battle of the matrix ended, at every size this table gives lengths for, so these are lengths and
not budgets. At 24 000 one core keeps up with the clock in this sitting — 1.42× at the committed bound
and 1.32× at the worst single run of the twenty — but that two-fifths of margin is about what the box
itself moves between runs of one sitting (366 to 493 ns), so an app offering 24 000 soldiers on
hardware like this is offering a battle that may not keep up on a busier day. Cost stops the app
outright at 50 000, and battle length stops it well before that: 24 000 soldiers is close to four
minutes of watching at the median, against a vision that asks for "a short spectacle that invites an
immediate rematch". Legibility binds earlier still on a phone: at 24 000 a soldier is about five
pixels on a 2 556-pixel screen, and the vision requires the app to stay legible for people with
limited vision. Memory never binds first at any size a phone would offer.

## Battles

`battle-measure battle n=<soldiers> armies=even|lopsided seed=1..<seeds>` at ten sizes, both count
mixes at each, with 300 seeds to 120 soldiers, 100 at 300, 48 at 1 500, 24 at 6 000, and 8 even and 4
lopsided at 24 000: 3 956 runs, of which 600 are uncontested (the lopsided counts at 3 and 6 soldiers,
where integer division gives one army everything) and are over at `init`. Every median in this
document is the middle of the sorted sample, the upper of the two when the sample is even.

**All 3 356 contested battles ended with one kind standing.** Nine sizes run inside the tool's default
budget of 600 battle-seconds; the twelve runs at 24 000 need `budget=76800` — 1 200 seconds — because
the longest of them is 809.9 s, and under the default that one is cut off unresolved at 38 400 ticks.

| soldiers | contested | resolved | seconds min/median/max | longest in ticks | hand-changes per soldier | surges |
|---|---|---|---|---|---|---|
| 3 | 300 | 300 | 0.1/0.3/0.8 | 54 | 1.0/1.0/1.0 | 0/0/1 |
| 6 | 300 | 300 | 0.2/0.7/2.1 | 137 | 1.0/1.5/2.5 | 0/1/4 |
| 15 | 600 | 600 | 0.1/1.4/3.9 | 249 | 0.2/1.0/4.4 | 0/1/10 |
| 30 | 600 | 600 | 0.7/1.9/8.5 | 543 | 1.0/1.6/7.7 | 0/1/16 |
| 60 | 600 | 600 | 1.0/3.2/14.5 | 927 | 1.0/2.1/10.6 | 0/2/18 |
| 120 | 600 | 600 | 1.2/5.2/21.3 | 1 361 | 1.0/2.6/19.2 | 0/2/19 |
| 300 | 200 | 200 | 1.8/10.8/45.5 | 2 915 | 1.0/4.0/18.7 | 0/3/35 |
| 1 500 | 96 | 96 | 8.5/26.7/131.7 | 8 430 | 2.0/6.8/73.7 | 1/6/85 |
| 6 000 | 48 | 48 | 12.3/78.6/314.6 | 20 137 | 2.0/15.6/133.7 | 1/13/87 |
| 24 000 | 12 | 12 | 49.1/265.5/809.9 | 51 834 | 3.0/37.2/244.5 | 2/50/111 |

**Waves.** With equal counts, churn grows with the army:

| soldiers | hand-changes per soldier min/median/max | surges | seconds |
|---|---|---|---|
| 6 | 1.0/1.5/2.5 | 0/1/4 | 0.2/0.7/2.1 |
| 60 | 1.5/3.2/10.6 | 1/4/18 | 1.1/4.6/14.5 |
| 300 | 3.8/6.7/18.7 | 3/8/35 | 6.6/16.3/45.5 |
| 1 500 | 6.8/12.9/73.7 | 6/17/85 | 23.0/48.1/131.7 |
| 6 000 | 14.7/27.1/133.7 | 11/34/87 | 73.4/160.4/314.6 |
| 24 000 | 20.0/54.2/153.4 | 18/60/87 | 170.8/318.0/511.9 |

Those rows are what the ceiling above is built on, and none of it moves with the box; the cheapest
check is `battle n=300 armies=even seed=1|2|3`, which gives 1 044 / 815 / 1 084 ticks and 6.550 /
5.220 / 8.650 hand-changes per soldier.

Legibility is the bound in the other direction: over the 318 battles of the matrix that changed hands
five or more times per soldier, the shortest mean kind lifetime is **0.622 s** — tens of frames per
emoji even in the churniest battle measured.

**The engine has no favourite kind.** With equal counts the three kinds are exchangeable, so every
deviation from a third of the wins is the engine's own:

| soldiers | 3 | 6 | 15 | 30 | 60 | 120 | 300 | 1 500 | 6 000 | 24 000 |
|---|---|---|---|---|---|---|---|---|---|---|
| seeds | 300 | 300 | 300 | 300 | 300 | 300 | 100 | 48 | 24 | 8 |
| rock/paper/scissors | 108/96/96 | 105/92/103 | 91/104/105 | 107/97/96 | 108/94/98 | 106/115/79 | 31/37/32 | 20/21/7 | 8/8/8 | 2/3/3 |
| largest share | 0.360 | 0.350 | 0.350 | 0.357 | 0.360 | 0.383 | 0.370 | 0.438 | 0.333 | 0.375 |
| smallest share | 0.320 | 0.307 | 0.303 | 0.320 | 0.313 | 0.263 | 0.310 | 0.146 | 0.333 | 0.250 |

The gate is two-sided and it is stated in the units the measurement has: no kind's share may sit
further from a third than four times the sampling noise of the sweep that measures it,
`√(⅓ · ⅔ / seeds)`. Every cell above is inside the band its own seed count draws. The gate itself
sweeps deeper at the sizes where a battle is small enough for placement to decide it — 900 seeds at
three, six and fifteen soldiers in the everyday suite, where the noise is 1.6 % and the band is 0.270
to 0.396: `battle n=3|6|15|30 armies=even seed=1..900` gives 335/284/281, 304/278/318, 295/293/312
and 301/291/308, a largest share of 0.372 and a smallest of 0.309.

**What earns it is the shuffled draw**, and the suite measures the engine against the engine without
it. Each soldier's kind is drawn from the counts not yet placed; take them in kind order instead and
the field falls into three bands, because the sites are settled in row order. `battle n=3|6|15|30
armies=even seed=1..900 fill=0` gives 277/267/356, 304/357/239, 475/113/312 and 441/89/370: at fifteen
and thirty soldiers the starved kind sits 13.2 and 14.9 noises below a third, where the shipped
engine's rarest sits 0.49 and 0.64 below. That is the whole width of the measurement between the
engine and its own control, which is why the suite runs the control at those two sizes. It needs a
third of the depth to show it, and that is what the suite spends: over the first 300 of those seeds
`seed=1..300 fill=0` gives 148/36/116 and 136/23/141, a starved kind 7.8 and 9.4 noises below a third
against a band that starts at 0.224 — still twice the four noises the gate asks for. At three and six
soldiers the bands are too coarse to decide a battle and the control barely separates at all: its
rarest kind takes 0.297 and 0.266 of 900 seeds against a band that starts at 0.270, so at three
soldiers the control would pass the gate outright. It is not run there.

**The counts decide how one-sided a battle is, and that is the caller's business.** They do not decide
it the way a bigger army suggests: at fifteen soldiers split 13/1/1 the big army wins **0.03** of the
seeds, because the single predator inside a crowd of its prey converts as it eats and grows
exponentially, while its own predator is one soldier that has to find it first. Mass tells only when
there is enough of it to close on the lone hunter: at 6 000 soldiers split 4 800/600/600 the big army
takes 0.58. Either way the battles are shorter than an even three-way — a median of 1.4 s against
1.6 s at fifteen soldiers and 35.7 s against 160.4 s at 6 000. The battle's *length* is the seed's
everywhere: over every cell of at least eight runs, the longest battle of a cell is at least **2.99×**
the shortest, and every such cell is won by at least two kinds.

**What the app can now be asked for is the user's, so it is measured.** The counts are chosen on the
app's own screen now, and what that reaches — any three counts up to two thousand — is wider than the
two mixes the matrix above measures. The runs are taken at the rectangle the app stages on — the field
band of its own device fixture, 402 × 558, an aspect of **0.7204** — and not at the tool's default
shape, because the shape is part of the battle: `battle n=300 armies=even seed=1|2|3 aspect=0.7204`
gives 709 / 592 / 1 120 ticks against the 1 044 / 815 / 1 084 the same three seeds give at the default
this section quotes above. `battle-measure battle counts=<a,b,c> seed=1|2|3 aspect=0.7204` at the corners
of what the app offers and up the even middle, thirty-three runs, **all thirty-three resolved**
(seconds of battle time):

| counts | soldiers | seed 1 | seed 2 | seed 3 |
|---|---|---|---|---|
| 1/1/1 | 3 | 0.41 | 0.39 | 0.19 |
| 100/100/100 | 300 | 11.08 | 9.25 | 17.50 |
| 500/500/500 | 1 500 | 76.56 | 71.48 | 43.91 |
| 1000/1000/1000 | 3 000 | 164.84 | 205.63 | 49.91 |
| 1500/1500/1500 | 4 500 | 122.53 | 119.45 | 56.70 |
| 2000/1/1 | 2 002 | 11.58 | 11.14 | 11.27 |
| 1/2000/1 | 2 002 | 18.30 | 16.33 | 8.61 |
| 1/1/2000 | 2 002 | 10.73 | 10.06 | 16.14 |
| 2000/2000/1 | 4 001 | 14.45 | 25.13 | 17.53 |
| 2000/1/2000 | 4 001 | 18.89 | 15.58 | 19.91 |
| 2000/2000/2000 | 6 000 | 500.73 | 290.73 | 246.78 |

In all fifteen runs with a lone soldier in them the field ends in that soldier's kind: at 2 002 by
converting the one big army it hunts, one hand-change a soldier and no surge; at 4 001 the same, after
the army it hunts has taken the third, at 1.5 hand-changes and one surge. That is the 13/1/1 finding
above at a hundred and more times the size. The corners do not bound length: every one of them but the
even 6 000 is under twenty-six seconds, while all four even mixes from five hundred an army upward run
longer than the longest lopsided corner. Nor does length climb with the count — 3 000 even outlasts
4 500 even at two of these three seeds. The longest of the thirty-three is the even 6 000, whose seed 1
runs 32 047 ticks against the tool's default budget of 38 400, so a longer seed is cut off unresolved
and needs `budget=` raised, as the runs at 24 000 do.

## Bounds and motion

`battle-measure battle ... check=1`, which tests every soldier on every tick for a finite position
inside the arena inset by half a body, and for a displacement over the cap.

- 18 whole battles — `battle n=300|1500|6000 armies=even|lopsided seed=1|2 check=1`, `battle n=24000
  armies=even seed=7 check=1`, `battle n=24000 armies=lopsided seed=3 check=1`, and 4 at the thinnest
  and widest arenas the surface admits (`n=300 armies=even seed=1|2 aspect=1e-30|1e30 check=1`). All
  18 resolved. **5.08 × 10⁸ soldier-ticks: zero out of bounds, zero non-finite coordinates, and no
  displacement standing more than 0.00 of the arena's ulps over the cap.**
- The worst single-tick displacement is **the cap itself** — 1.0000002 of it, at `n=24000
  armies=lopsided seed=3`, where the mop-up crowd pushes a body exactly as far as a tick may carry it.
  A displacement read back from two stored positions carries the rounding of the addition that placed
  them — under two of the arena's ulps, by the width of a `Float` there — so the tool reports the
  excess in those ulps rather than judging it, and the suite allows four. The worst measured is 0.00
  of them. The clamp is therefore load-bearing in a battle and not only in the suite's
  `nothingComesOutOfAPileFasterThanTheCap`, which puts three and twenty-four soldiers on one point and
  asserts both that nothing exceeds the cap and that something reaches it.
- The worst single soldier of any tick of those battles visited 78 candidates against the bound of
  192 — four candidate windows of 48, one for each row of the first ring and one for everything
  beyond it — and the longest first-ring row anywhere was 13 against the cap of 48.

## Crowding

`battle-measure spacing n=<soldiers> armies=<counts> seed=<seed> every=100`, which measures the
densest grid cell on **every** tick of a whole battle and nearest-neighbour spacing every hundredth
tick.

| run | densest cell | longest first-ring row | worst visits for one soldier | within half a body, worst moment | mean nearest neighbour, worst moment | closest pair, worst moment |
|---|---|---|---|---|---|---|
| `n=6000 armies=even seed=1` | 4 | 12 | 76 | 0.000 % | 1.067 B | 0.846 B |
| `n=6000 armies=lopsided seed=1` | 5 | 11 | 75 | 0.000 % | 1.058 B | 0.910 B |
| `n=24000 armies=even seed=7` | 5 | 12 | 78 | 0.000 % | 1.060 B | 0.841 B |
| `n=24000 armies=lopsided seed=3` | 6 | 13 | 78 | 0.000 % | 1.000 B | 0.513 B |
| `n=6000 armies=even seed=1 passes=1 push=0` | 71 | 112 | 106 | **6.383 %** | 0.932 B | 0 |
| `n=6000 armies=even seed=2 passes=1 push=0` | **124** | 204 | 115 | 4.267 % | 1.024 B | 0 |

A cell holds half a soldier on average. Nowhere in a battle does the crowd pack more than six
soldiers into one cell or put a single body inside half a body of another: that is the difference
between a packing and a pool, and the two control rows are what a pool looks like — with the solve
stopped after one pass, a cell holds up to a hundred and twenty-four soldiers and up to a sixteenth of
the army sits inside half a body of a neighbour. The candidate cap holds the work bound even in the
pool: its first-ring rows reach 204 soldiers and the worst soldier of any tick still visits 115
candidates against the bound of 192.

Two of the three measures separate a packing from a pool and the third does not: against gates of 64
soldiers a cell and 1 % of the army inside half a body, the pool reaches 124 and 6.383 %, while its
mean nearest neighbour — 0.932 and 1.024 bodies — sits inside the range whole battles keep
(1.000–1.067). **The mean is therefore gated only in the direction a battle holds it**, and the
no-solve control asserts the two that separate, which is what makes it evidence.

At `t = 0` nothing overlaps at all: over the placement sweep below the closest pair is 1.026 to 1.859
body diameters and no pair anywhere is inside a body.

## Steering

`battle-measure steering n=6000 armies=even|lopsided seed=1|2 at=64,256,1024,4096 stride=37`,
`steering n=1500 armies=even seed=1|2 at=64,256,1024,4096 stride=11` and `steering n=24000
armies=even|lopsided seed=1 at=64,512,4096 stride=37` — the last being the instants the scale suite
audits — which compare the target each sampled soldier actually steers at, the target chosen by the
same `decide` the move step uses, against a brute-force nearest over the whole army. Twenty-four of
the thirty instants have a live comparison; the other six are battles already finished.

| | measured |
|---|---|
| the nearest lay inside the searched ground, and the search returned it | 6 599 of 6 599 — **no exception** |
| soldiers whose search sampled rather than read a row | **0 of 7 598** |
| target is exactly the true nearest | 74.85–100 % of an instant, 5 749 of the 6 180 compared |
| heading error, median soldier | 0.00° |
| heading error, mean | 0.00–4.56° |
| heading error, 99th percentile of an instant | up to 142.35° |
| target distance ÷ true nearest, mean | 1.0000–1.0070 |
| the same, 99th percentile of an instant | ≤ 1.146 |
| the same, worst soldier anywhere | **1.234**, at `n=24000 armies=lopsided seed=1 t=512`, where the true nearest was 5.10 spacings away |
| chase-or-flee decision differs | ≤ 0.730 % of an instant |
| …and then where prey and predator stood within | 16.2 % of the same distance, at `n=24000 armies=even seed=1 t=512`; 1.1 % over the smaller corpora |

The distance error is bounded and the exactness is an identity where the eye could check it. What is
not bounded is the *heading* beyond the exact reach: two enemies at nearly the same distance in
opposite directions are a tie the field may break either way, which is why the 99th percentile of a
bad instant is large while the median soldier's error is zero. Nor is the tie itself as tight as the
small corpora suggest: in under half a percent of the samples of one 24 000-soldier instant the engine
takes the wrong one of the two, and the widest such gap is 16 % of the nearer distance, against the
1.1 % the 6 000- and 1 500-soldier corpora show. The tie widens with the army, which is why the suite
gates it at a quarter and audits it where the armies are largest.

The same guarantee is proven again without any instrument, on the path that moves soldiers:
`theTargetASoldierStepsTowardIsTheNearestItShouldSteerAt` snapshots the army through the public
surface, advances one tick, and for every soldier with no neighbour inside the interaction radius and
no wall within a step reads its actual displacement — the step length says whether it chased or fled,
the step direction says at what — and compares that against a brute-force nearest. What the suite asks
of that path is the floor under what the rows above show of the instrumented one: no target more than
half again as far as the true nearest, and exactness in nine soldiers of ten — under both the 93.0 %
this corpus measures (5 749 of 6 180) and the 98.2 % and 98.9 % the path itself measures on the six
hundred soldiers it runs.

## The exact reach

The search expands ring by ring while the ground it has covered does not yet contain the nearest
thing found in it, up to a reach of six grid cells — 4.2 mean spacings, 8.4 glyph diameters. The
requirement is the one a watcher can check: **a soldier never steers at something more than half
again as far as the nearest thing it should be steering at.**

`battle-measure rings n=6000 armies=even|lopsided seed=1|2 at=64,1024,4096 stride=37
depths=1,2,3,4,6,8` measures every reach **at the same states of the same battle**, so the arms differ
in nothing but the reach. `bench n=64000 armies=even seed=1 warm=30 ticks=60 runs=5 rings=<depth>`
measures what each reach costs.

| exact reach | worst target ÷ true nearest | true nearest at that worst case | worst mean heading error | nearest-inside-reach checks | identity broken | ns/soldier/tick at 64 000, one sitting |
|---|---|---|---|---|---|---|
| 1 ring | **1.718** — a breach | 1.10 spacings | 10.06° | 304 | 0 | 204–242 |
| 2 rings | 1.486 | 1.56 | 4.20° | 672 | 0 | 256–282 |
| 3 rings | 1.195 | 2.68 | 4.34° | 958 | 0 | 314–337 |
| 4 rings | 1.209 | 3.01 | 3.39° | 1 142 | 0 | 348–396 |
| 6 rings | **1.130** | 4.90 | 2.87° | 1 384 | 0 | 369–494 |
| 8 rings | 1.200 | 6.51 | 2.43° | 1 529 | 0 | 370–568 |

The worst error always sits just outside the reach, and the reach is what pushes it out. The identity
inside the searched ground holds at every reach — zero violations — because the search stops only when
the ground it has covered contains what it found. What the reach buys is how far that ground extends,
and the fifth column is that: six rings settles four and a half times as many soldiers exactly as one
ring does. The suite gates that gap on its own fixture, and the same tool measures it there:
`rings n=600 armies=even seed=1 at=16,64,256,1024 stride=5 depths=1,6` — the corpus
`aShallowerSearchIsMeasurablyWorseWhereTheArmiesMix` builds — puts one ring at **1.699** against six
rings' 1.000, where the gate asks the shallow arm to be at least 1.4 times the deep one.

Stopping there is worth **13 % to 26 % of the tick**: `bench n=64000 armies=even seed=1 warm=30
ticks=60 runs=3` against a build with the stop deleted, both through `swift run -c release`, three
times alternately, gives 371–464 ns against 500–539, with no overlap in either direction and that
saving run for run. It changes no answer — `invariance ticks=400` at `n=3 armies=even`,
`n=1500 armies=even` and `n=300 armies=lopsided aspect=0.46` returns the same three digests with the
stop deleted — because a cell outside the covered ground cannot hold anything nearer than what the
covered ground already holds, which is why no test of behaviour can fail without it.

**Why six and not four.** Six costs about a fifth more than four per tick — 463 against 385 ns at the
median of the sitting above — and is paid on every tick. The worst case is a tail statistic and it
moves between corpora: a second one at the same size, `rings n=6000 armies=even|lopsided seed=3|4
at=128,512,2048 stride=53 depths=1,2,3,4,6,8`, puts one ring at 1.499 rather than 1.718, two at 1.280
rather than 1.486, three at 1.275 rather than 1.195 and eight at 1.253 rather than 1.200, while four
and six barely move — 1.207 and 1.128. **Four is inside the requirement on both corpora**, and by more
than any reach that meets it swings between them (0.29 of the ratio against 0.21, which is two rings'
swing and the widest of them), so what six buys is not a breach avoided but margin — 0.37 against that
0.29 — and a fifth to a third more soldiers settled exactly (1 384 against 1 142 in the first corpus,
1 054 against 782 in the second). One ring is the depth that breaches, on the corpus above.

## Placement

`init` scatters the army over the whole arena. It lays a lattice of `1/√(3N)` spacing — 1.283 body
diameters between neighbouring sites — and walks it once in row order, taking each site with the
probability that leaves the soldiers it has still to place a uniformly random subset of the sites it
has still to visit. A soldier stands at its site's centre, wobbled by up to 0.45 of the slack between
the site and its own body, and is given a kind drawn from the counts not yet placed. One pass, no
scratch allocation, and one random number for every site the walk passes over plus three more for
every soldier it settles.

Where a soldier stands is settled before what it is: the draw that picks its kind is taken whatever
the counts are, so **the same total and the same seed lay out the same field however the counts are
split, and however the kinds are then handed out**. That is why the corpus below varies the seed
rather than the count mix for everything except the mixing figure, and why the control below is a
relabelling of one field rather than a second field.

`battle-measure geometry n=3|60|1500|100000|1000000 aspect=1e-30|0.46|1|2.16666|32|1e30` with
`armies=even seed=1|2` and `armies=lopsided seed=1`, 90 configurations.

- closest pair at `t = 0`: **1.026–1.859 body diameters**; no pair inside a body in any of them. The
  floor is arithmetic. One soldier stands on each site; a site is at least 1.283 bodies across; the
  wobble moves a soldier by at most 0.45 of the slack between the site and the body. Two soldiers on
  neighbouring sites therefore keep a tenth of the site and nine tenths of a body — 1.028 bodies —
  less the rounding of the two coordinates that hold them.
- lattice: **1.667–3.000 sites per soldier** at a spacing of **1.283–1.481 bodies**; 1.00–2.04 grid
  cells per soldier. Over a wider scan — every size from 1 to 40, then 45, 60, 80, 100, 150, 300, 700,
  1 500, 4 000, 10 000, 100 000 and 1 000 000, against the 61 aspects `1e-30` to `1e30` a decade
  apart, 3 172 configurations — the lattice offers **1.000–3.000 sites per soldier** at a spacing of
  1.283–2.222 bodies, inside the five sites a soldier the ceiling repair enforces and the one the
  floor repair does. One soldier is the only size that gets exactly one site, and the widest lattice
  is a million soldiers on almost any screen (3.000). A shape between those decades can be thinner
  than any of them: `geometry n=3 aspect=0.36` gives **1.333**, against 1.462 for the thinnest of the
  scan above one soldier, and that is the aspect the suite sweeps for it.
- mean nearest neighbour at `t = 0`: **1.125–2.191 bodies**, so glyphs stand apart on the opening
  screen rather than touching.
- **the field is covered.** Cut the arena into blocks of twenty expected soldiers: over the 54
  configurations of 1 500 soldiers and above — 49 to 75 blocks at the smallest of them, 50 000 at the
  largest — **no block is ever empty**, and the fullest and emptiest sit within 4.15 sampling noises of
  their share, the spread a uniformly random subset is expected to show over that many blocks. At 60
  soldiers the arena cuts into two or three blocks and at 3 into one, so those configurations carry no
  coverage evidence and are not counted here. The same army bunched into the middle of the field, hand
  placed through the instrumentation initialiser, leaves blocks empty at 300 and 1 500 soldiers on
  every aspect, and that is the control the everyday suite runs beside this measurement.
- the kinds are mixed throughout: the share of soldiers whose nearest neighbour is another kind is
  **58.3–100 %** at equal counts and **23.7–46.0 %** where the split is 80/10/10, against the
  census-implied `1 − Σpₖ²` of 66.7 % and 34.0 %. Every one of the 90 sits inside the four sampling
  noises of its own implied share that the suite gates, three soldiers of one kind included.
- **the draw is what mixes them.** `geometry n=300|1500|6000 armies=even|lopsided seed=2 fill=0`
  takes the kinds in order instead of drawing them, and mixing falls to **1.2–6.4 %** while every
  other figure of the run — closest pair, mean spacing, empty blocks, worst block — is identical to
  the digit: the same soldiers standing in the same places under a different set of labels.
- the arena's area is 1 to five decimals everywhere; measured in bodies it runs from 2.0 across (the
  thin clamp) to 65 536 long (the long clamp), and both clamps bind exactly where they are meant to.

Building a battle is placement, which is all the randomness there is: `geometry n=1000|100000|1000000
armies=even seed=1` takes **0.13 ms, 8.5 ms and 83 ms**, and 81 ms at 10⁶ on the widest arena the
surface admits (`aspect=1e30`). Those are the same kind of bound as § Cost's, and they move with the
box in the same way.

## Determinism

`battle-measure invariance seed=1 ticks=400` on nine setups — `n=3|60|1500 armies=even
aspect=2.16666`, `n=300 armies=lopsided aspect=0.46`, `n=6000 armies=even aspect=1`, `n=30
armies=even aspect=1e30|1e-30`, `n=120 armies=lopsided aspect=0.46`, `n=600 armies=lopsided
aspect=2.2`. Each setup is run as one delivery of the total, then as eight partitions of it (one tick
at a time, interleaved zero-length calls, sub-tick slivers, ragged chunks up to 5 ticks), and once
more preceded by a negative delivery: **all ten give one digest and one tick count per setup**, and
the nine setups give nine different digests.

**Seeds are independent battles, not one battle in different phases.** The seed is the state of the
engine's `Random`, which steps by a fixed constant. Two seeds a step or two apart on that stream would
lay related fields, and those are the seeds that differ by the constant itself — 1.1 × 10¹⁹ apart in
value, never the ones a caller reaches by counting up. Every other pair starts an astronomical
distance apart on the stream, and the wobble then puts a soldier somewhere inside its site rather than
on the middle of it. Over the first twelve seeds at 300 and at 1 500 soldiers no pair of openings
shares a single position, and the suite asserts it at both sizes (`noTwoSeedsDrawTheSameGround`). It is
stated here because every sweep in this document counts seeds as independent samples.

The image contains **zero** fused multiply-add instructions of any form (`fmadd`, `fmsub`, `fnmadd`,
`fnmsub`, `fmla`, `fmls`), and `sqrtf` is the only floating-point library entry point reached from
anywhere in the engine:

```
objdump -d .build/release/battle-measure | grep -cw fmadd
objdump -d .build/release/BattleEngine.build/*.o | grep -oE "<[a-z_]+>$" | sort -u
```

The second prints `malloc_usable_size`, `memcpy`, `memmove`, `memset`, `sqrtf` and three Swift
runtime entries: the library reaches no other C function at all.

Bit-identity across architectures is a design property, not yet a measurement; the golden digests in
`Tests/BattleEngineTests/Goldens.swift` are what will confirm it on the first device build. They are
asserted in both `swift test` and `swift test -c release`, which is what makes them evidence that
optimisation level cannot change a battle.

## Shortfalls

- **The user cannot say where a soldier stands.** The engine scatters the army over the whole field
  and mixes the kinds through it; nothing on the surface can move a soldier, and the user story's
  "the user can take the field in hand … painting new ones with a fingertip" is unmet. What a setup
  can say is who fights, how many, the screen's shape and a seed.
- **The app now offers armies its own screen cannot draw legibly.** It reserves field height for a
  ten-point soldier at the three hundred of its own default, not at the army the user chose, so the
  ten points are guaranteed there and nowhere above: `theFieldIsNeverDistorted` holds the drawn
  soldier at ten points or more on every one of the 147 screens and text sizes it sweeps, at that army
  and at no other. A glyph goes as `1/√N` (§ The ceiling), so at the top of what the app now offers,
  twenty times that army, the same soldier is a little over two points across. Above three hundred
  soldiers the vision's promise to stay legible for people with limited vision rests on the
  pinch-to-zoom the user story asks for and nothing has yet built. Two of § The ceiling's four limits
  now bind on what the app advertises rather than on what an app might, and in that order: legibility
  binds from a few hundred soldiers and length from a few thousand. § Battles measures length at the
  app's own rectangle: the three hundred it opens with resolves in 9.25 to 17.50 seconds of battle
  time over three seeds, five hundred an army — a quarter of the way up the slider — in 43.91 to
  76.56, and the even 6 000 at the top of it in 246.78 to 500.73, four to eight minutes of watching or
  half that at the app's double speed, against a vision asking for a short spectacle. Cost and memory
  do not bind at all: 0.41 MB retained at 6 000 soldiers (§ Cost), and one core carries 5.14× real
  time there at the bound that table commits (§ The ceiling), against the 2× the app's own speed
  control offers. This document's standing instruction — that the size ceiling the app advertises come
  from one measurement on real hardware — is now owed against a specific number and has not been
  taken.
- **A control's label stops fitting its box about twice the default text size.** The longest label
  the app shows is "START OVER", ten characters at the 28-unit `body` size, in a row of two that
  gives each control `(width − 3·gap)/2` — 189 points on the 402-point device fixture. Taking a
  character of the app's black uppercase face as 0.62 of the text size wide, and allowing the
  shrink-to-fit the rows carry, which stops at one half, label and box meet at `width/198` times the
  default text size: 1.62× on the narrowest screen the suite sweeps (320 points) and 2.03× on the
  device fixture. Above that the label is truncated with an ellipsis rather than clipped. That
  boundary is where it has always been: the control that reaches the config screen is a gear in the
  readout band, not a third word in this row, so the row is the two controls it has always been. A
  third would have moved the boundary to `width/292` — 1.09× and 1.37× — and put the squeeze on
  exactly the reader who asked for large text.
  `everyLabelFitsTheRowThatHoldsItAtTheDefaultTextSize` holds every label of every phase inside the
  row that holds it, at the default text size and below, on all seven widths the suite sweeps: a
  longer label, or a third control in that row, fails there. The advance is an assumption about a
  font this box does not have, not a measurement, and a wider face moves every boundary above down.
- **The gear is the smallest control the app draws, and it is the only way to the config screen.**
  It sits in the readout band and is square at that band's own height, `44 × unit`: exactly
  the 44 points Apple asks for at the default text size, and more for every reader who asks for more.
  It is smaller for a reader who asks for less, and it has no floor of its own — the control rows have
  two (`primary ≥ 44`, `secondary ≥ 28`, both reached at `Layout.smallestUnit`) and the readout band
  has none, so at that same smallest unit the gear is **22 points**. That unit is the floor `Layout`
  clamps to and is below any Dynamic Type a phone offers — the smallest a phone asks for is about
  0.8, which is 36 points — so the 22 is the suite's hostile corner rather than a reader's screen.
  It is recorded because the number is not bounded by anything that would notice if it moved, and
  because a control this one cannot be missed by a shaky hand: every other way off that screen leads
  somewhere else.
- **A screen-reader user reaches about eleven of the two thousand counts.** The chooser's count
  slider is continuous — 1 to 2 000, no step and no adjustable action of its own — so VoiceOver moves
  it a tenth of its range a swipe: about ten swipes end to end, eleven counts, and every count
  between them out of reach without sighted dragging. That is deliberate. Every one of the two
  thousand is a real battle, so a step of one is two thousand swipes and any coarser step hides sizes
  the app offers and the slider still shows. The count is spoken on every change, so what is reached
  is never in doubt; which of them can be reached is.
- **A setup larger than the device can hold has nowhere to go.** `init` buys its storage once and
  cannot fail gracefully: a count beyond memory takes the process down with the allocator's own
  error. The engine's answer is to price the setup before it is built — `setup.storageBytes`,
  measured against the process high-water above — and the app must ask. Counts beyond what the engine
  can address normalise down instead, and reading the count back says what will be fielded.
- **The cost figures are the least reproducible numbers here.** Twenty runs a size in one sitting
  span 363–445 ns at 300 soldiers and 366–493 at 24 000; the committed bound is the worst pass median
  and the worst single run is beside it, but neither transfers to another box or another day, and a
  sitting on a busier box reads slower at every size. The app must measure on the device.
- **Ten mechanisms have no test that fails when they are removed.** Every other mechanism dies when it
  is deleted or inverted in a copy of the tree and `swift test` is run against it — most on a test
  that names the guarantee it carries, a few by taking the run down, and four only on the golden
  digests: the wall term inside the constraint solve, the far-field block radius, the field cell's
  span and the field cell's seed, which change the battle without breaking any promise this document
  makes. The placement wobble used to be a fifth; deleting it now fails
  `noTwoSeedsDrawTheSameGround`, because two battles then put soldiers on the same site centres.
  These ten live:
  - *Six repairs for states the public surface cannot reach.* The grid halves its resolution if a
    setup would need more than four cells per soldier; the lattice doubles its spacing if it would
    offer more than five sites per soldier, and shrinks it if it would offer fewer than one; a soldier
    for whom no site was left stands in the middle of the arena; a position left of the arena is read
    as the first cell; and a count is capped so that a cell index stays inside `Int32`. Over the 3 172
    placements scanned above the realised figures are 1.00–2.04 cells and 1.00–3.00 sites per soldier,
    and the suite puts every soldier of every placement it makes inside the arena inset by half a
    body. Between them they are what makes the storage `Setup.storageBytes` quotes a bound rather than
    an expectation, what keeps every soldier inside the arena, and what keeps a cell index inside
    `Int32`, so they stay.
  - *The candidate window's turn.* The first ring reads at most 48 candidates from a row, and the
    window's start advances by its own length each tick so that successive windows tile a longer row.
    No battle has ever bound the cap (longest row 13 of 48 above), and where the suite binds it —
    `nowhereInACrowdTooDenseToReadAtOnceIsAPlaceToHide`, two hundred soldiers on one point, a cell
    holding all 200 at `t = 0` and 36 to 96 of them four ticks later over the twelve indices it stands
    the intruder at — the pile is taken whole within 42 ticks from every one of them, with the turn
    deleted as readily as with it. The advance is one line and is kept because without it the sample
    is biased by soldier index for as long as the crowd lasts, rather than rotating.
  - *The ring search's early stop.* Removing it changes no answer, only the 13 % to 26 % of the tick
    measured under § The exact reach.
  - *Two details of what happens on one point.* Coincident soldiers separate along a compass
    direction that is antisymmetric in their identities — that much is proven, and without it a pair
    never comes apart — but the tick also enters the choice, so the pair does not take the same line
    twice, and no watcher can tell one line from another. A soldier whose predator stands on its own
    point steps away from it; it is converted on that same tick either way, because a distance under
    10⁻¹⁰ is inside contact at every size.
- **Above 24 000 soldiers a battle is not certain to end.** Every contested battle of the matrix ended,
  including all twelve at 24 000. At 50 000 — `battle n=50000 armies=even|lopsided seed=1|2
  budget=76800` — three of four ended, in 94, 123 and 303 seconds of battle time, and the fourth was
  still running after 1 200 s with 10 782 / 2 699 / 36 519 soldiers alive. A battle that has not
  resolved is fully observable — a census with more than one kind — so the failure mode is a long
  battle, never a wrong one, and 50 000 is already below real time on this box.
- **Two of the caps that bound the work are never approached in a battle.** The densest cell reaches 6
  of the 64 the gate allows and the first-ring row 13 of 48. Those bounds are still load-bearing — the
  piles and the no-solve control in the suite drive both past their thresholds — but no battle in this
  corpus is evidence for them. The displacement cap is not among them: a battle reaches it exactly.
- **The endgame crowd is packed, not pooled, and packed is not perfect.** The closest pair of a whole
  battle falls to 0.513 bodies at 24 000 soldiers: two bodies come within half a diameter for a tick
  and are pushed apart again. What the guarantee bounds is pooling — the share of the army inside half
  a body, 0.000 % in every battle measured against 6.383 % with the solve stopped.
- **Beyond the exact reach the target is not the nearest, and nothing bounds its direction.** The
  distance is bounded — 1.234× the true nearest over 24 live instants — but where two enemies stand at
  nearly the same distance in different directions the field can take either, and the heading error
  reaches 142° in the tail of a bad instant. Which of prey and predator a soldier answers to is loose
  in the same way and by more: at 24 000 soldiers the two stood 16 % apart in distance where the
  engine took the further.
- **At three soldiers there is no spectacle.** Three soldiers scattered over a lattice of eight sites
  are done inside 54 ticks with one hand-change each. The engine has no favourite kind there —
  335/284/281 over 900 seeds — but where the three landed decides the battle.
- **Every cost and memory number is from this Linux box.** Determinism transfers to a phone by
  construction; cost does not, and the size ceiling the app advertises must come from one measurement
  on real hardware.
