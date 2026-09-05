# Battle engine

Three armies of Rock-Paper-Scissors soldiers hunt each other across a rectangle. The engine owns the
battle — positions, kinds, the clock, the counts, the victor, the rules and every constant that
governs motion. The app owns everything visible: which emoji stands for which kind, glyph size, the
transform onto the screen, the HUD, the celebration, sound, accessibility and persistence.

One Swift package. No Apple frameworks, no Foundation, no dependencies. It builds and is proven on
Linux aarch64 with Swift 6.1.2; an iPhone app compiles the same source.

## The surface

Four public types, declared in `Sources/BattleEngine`: `Kind` (rock, paper, scissors, and what each
beats); `Setup` (who fights, how many, the screen's aspect, the seed, and what the setup implies —
`arena`, `soldierDiameter`, `storageBytes`); `Census` (the per-kind counts, the victor, whether time
can still change anything); and `Battle` (`init`, `advance(by:)`, `elapsed`, `census`,
`withSoldiers`). Read the declarations there; they are short, and this file does not copy them.

Everything else the module exposes sits behind `@_spi(Instrumentation)`: the counters, the audits and
the negative controls the proofs are built from. It is not part of what the engine promises, it moves
with any commit, and an app that imports it is on its own.

`Sources/BattleClient/main.swift` is a whole client: it links the public `BattleEngine` product and
nothing else, runs the game loop frame by frame at a speed multiplier, and reads the census, the
clock and the soldiers exactly as an app would. It is built by `swift build` and by `swift test`, so
the package cannot compile only for its own tools.

An invalid setup cannot be constructed: every field normalises on assignment and on decoding, so a
non-finite aspect or a count outside what the engine fields becomes a running battle rather than an
error to handle, however it arrived. Read the value back to see what the engine will field. Bytes
that are not a `Setup` at all — truncated, missing a key, of the wrong type — are a decoding error,
and that one the caller handles.

`init` scatters the armies at random over the whole battlefield, with the three kinds mixed through
them by the same draw; where a soldier stands is the engine's and the seed's, not the caller's. So the
first tap builds the `Battle` — armies drawn up and waiting — and the second starts calling
`advance`. Pausing is not calling `advance`; restarting is a new `Battle`; abandoning is releasing
it. Speed is the app's: `Duration × Int` is exact, so speed changes the rate
at which the battle is sampled and never the battle. The two buffers `withSoldiers` lends are the
engine's live storage, valid for the duration of the closure and directly uploadable as instance
data.

## Drawing it

The arena carries the screen's aspect and its area is 1: for `aspect = width/height` it is
`√aspect × 1/√aspect`. One uniform scale — `screenHeight / setup.arena.y` — maps the battlefield
onto the screen, fills it exactly, and cannot distort motion. Glyphs are drawn `soldierDiameter`
across in the same units, and two glyphs touching is exactly what converts one into the other.

A glyph is therefore `setup.soldierDiameter / setup.arena.y` of the screen's height — on a 19.5∶9
portrait screen, a 51st of it at 300 soldiers and a 456th at 24 000. That is one of the four limits
on how many soldiers an app may offer, and `docs/envelope.md` puts it beside the other three.

The arena is clamped so that it is never thinner than two soldier bodies and never longer than 65 536
of them. On a phone-shaped screen the thin clamp binds only for a battle of one soldier, which is over
before it starts, and the long clamp only above about 4 × 10⁸ soldiers — inside the 5.37 × 10⁸ the
surface accepts, and far beyond what a phone can hold. For shapes far outside a phone's the clamp binds
at any size, and then the realised arena is not the one asked for. Read `setup.arena`, scale by
`screenHeight / arena.y`, and letterbox what is left, as on rotation. The aspect is fixed for a battle:
a rotation letterboxes, it does not reshape the battlefield, because a reshaped arena is a different
battle.

## What the app must do, and cannot read off the surface

- **Draw a fresh seed for every battle.** A `Setup` is `Codable` and carries its seed, so an app that
  stores one and reopens it verbatim replays the same battle down to the bit. Store everything else
  and take a new seed each time the user starts one, or the rematch is a rerun. The app here stores
  the user's choices between launches and never the seed: it draws one when it opens and steps it for
  every battle, so reopening the app is not a rerun.
- **Choose the sizes it offers from a measurement on the device.** The ceiling is set by four
  things: what one core carries, how long a battle lasts, how much memory the battle holds, and
  whether a glyph is still legible. `docs/envelope.md` measures all four for this Linux box.
  Determinism transfers to a phone by construction; cost and memory do not.
- **Ask what a battle costs before building it.** `setup.storageBytes` is the memory a battle
  retains, counted by the code that buys it, and placing the armies buys nothing on top of it, so it
  is the whole price; `docs/envelope.md` measures it against the process high-water. A setup larger
  than the device can hold has nowhere to go: `init` fails to allocate and the process dies, which is
  the one failure the engine cannot report, so the app must not ask for it.
- **Keep calling `advance` after the battle ends.** It freezes; `elapsed` is then the battle's own
  length, and the display link can run through the celebration.

## What the engine will not do

- **It fields no more soldiers per army than keeps a cell index inside `Int32`.** The grid buys at
  most four cells a soldier and three armies share it, so the cap is `Int32.max / 12` an army —
  1.79 × 10⁸ each, 5.37 × 10⁸ in all. A larger count normalises down to that, and reading the count
  back says what the engine will field. Every count the surface accepts is arithmetically defined at
  every size; whether it is affordable is `storageBytes` and the device's business.
- **It takes a single delivery of at most `Int64.max` seconds** — 292 billion years — and treats
  anything longer as that. Every `Duration` the caller can build is therefore accepted, and time
  already run is never un-run: a negative delivery contributes nothing.
- **It never caps its own work.** Delivering an hour of battle time runs an hour of battle time, at
  the rate `docs/envelope.md` measures, and `advance` returns when that time is spent or when the
  battle ends, whichever comes first. A caller that hands it a year gets a year's work: that is the
  one way to make a call take arbitrarily long, and it is the caller's to avoid. The caller owns the
  clock.

## The app

`Sources/BattleApp` is the app's whole mind. It turns a screen rectangle, the seconds a frame lasted,
the characters the keyboard produced, the value the slider holds and the record the app was opened
with into everything the user sees — the bands and their heights, the three armies' faces and names,
the screen that chooses them, the projection of every soldier into screen points, the clock, the
counts, the controls, the winner's banner and its confetti — and it is proven here by
`swift test`, on Linux, against the engine's public surface only. `App/RockPaperScissors/` is the
SwiftUI that only a Mac can compile: it holds a `Director`, hands it the rectangle, the length of the
frame just drawn, the raw text and slider values its controls hold and the record it read back from
the system, stores the record that comes out, and draws the rest. Which armies fight, what they are
called, how many there are, every word the app says about them and every size it lays out come off
the `Frame`; the paint — shapes, strokes, weights, colours and the shrink-to-fit — is the folder's
own. A row of *n* controls is *n* slots and *n* + 1 gaps across the whole width: the folder spaces a
row by `layout.gap`, pads both ends with the same gap, and `Layout.slot(_:)` divides what is left.
`swift test` holds `slot` to that identity for every row the app draws, so the arithmetic cannot
drift here; the folder spending its width some other way is the half of the identity only a Mac can
break. Open `App/RockPaperScissors.xcodeproj`, choose an iPhone, and Run; the Run action is committed
as Release.

## Building, testing, measuring

```
swift build -c release
swift test
swift test -c release
BATTLE_SCALE=1 swift test -c release --filter ScaleTests
swift run -c release battle-measure <mode> <key=value>...
```

`swift test` is the everyday proof and takes seconds: the fixtures, the invariance partitions, the
rules, the bounds, the piles that bind the caps, and the gates at the sizes that fit in that budget.
The release run repeats all of it under `-O`, which is what proves that optimisation level cannot
change a battle: the golden digests are asserted at both levels. The scale run takes the same
guarantees where they are hardest — six thousand and twenty-four thousand soldiers, whole battles,
the crowd controls — and takes minutes. The last is the tool behind `docs/envelope.md`; its modes are
`battle`, `bench`, `spacing`, `steering`, `rings`, `geometry` and `invariance`, and that document
names the run behind every figure it measures, to the seed.
