# WORLD DOMINION — Game Design

> Status: living document. Everything marked **Planned** is intent, not implementation.
> Nothing outside the application shell exists in the codebase yet.

## Vision

WORLD DOMINION is a single-player, offline grand strategy sandbox. The player leads a nation and
shapes its place in a world that keeps moving: domestic politics, an economy that can boom or
collapse, diplomacy between states, and military force as one instrument among several.

The intended feeling is **consequence and clarity**: a world deep enough that decisions have
second-order effects, presented through an interface calm enough to read at a glance. It should feel
like a professionally authored strategy game, not a dashboard.

## Design pillars

1. **A living world.** Other nations pursue their own interests. The world does not wait for the
   player and does not revolve around them.
2. **Legible depth.** Complex systems are acceptable; opaque systems are not. Every number has a
   visible cause and a visible trend.
3. **Consequence over spectacle.** Trade, debt, elections, treaties and wars change the state of the
   world in ways the player can trace afterwards.
4. **One game, every platform.** The same simulation, interface logic and content pipeline serve
   phones, tablets and desktops. Touch is a first-class input, not a fallback.
5. **Offline first.** The full game must work with the device in flight mode. Accounts and servers
   are never required.

## Player role (planned)

The player governs one country from a chosen scenario. Governance is expressed through policy,
budget, appointments, negotiation and, where necessary, force. The player is powerful but not
omniscient: intelligence is imperfect, information has a delay, and decisions are made with the
information available at the time.

## Major systems (planned)

| System | Intent | Status |
| --- | --- | --- |
| World model | Countries, borders, regions, population, resources, time | Atlas + clock implemented; population and resources planned |
| Politics | Government type, parties, elections, approval, stability, corruption | Planned |
| Economy | GDP, budget, taxation, trade, inflation, unemployment, debt | Planned |
| Diplomacy | Relations, treaties, alliances, sanctions, blocs, negotiations | Planned |
| Military | Forces, readiness, logistics, conflict resolution, occupation | Planned |
| Intelligence | Information gathering, uncertainty, misinformation | Planned |
| Player progression | Long-horizon goals, achievements, scenario outcomes | Planned |
| Save management | Multiple local campaigns, autosave, export/import | Implemented (Milestone 03) |

Only the parts marked *implemented* exist: the atlas, the calendar that keeps in-game time, and local
saves. Every other row is design. Nothing in the game pretends otherwise — the campaign screen's
simulation panel lists the systems that are registered, and today that list has exactly one line.

## Currencies — permanent decisions

These are permanent game-design decisions and must remain true in every future milestone.

### Two separate gameplay currencies

The player has exactly two game-wallet currencies:

- **Gold Coins**
- **Diamonds**

They are **game-wallet currencies, not national currencies.** They represent the player's own
resources, independent of whichever country they lead.

### Separation from national economies

- Wallet balances are **never** affected by national inflation, exchange-rate depreciation,
  recessions, debt crises or bankruptcies.
- National economic simulation must never read, write or adjust wallet balances.
- Wallet balances use **safe integer representations** (64-bit integers with an explicit maximum and
  no floating-point arithmetic). Rounding drift is not acceptable in currency code.
- Spending is all-or-nothing; a balance can never go negative.
- **Saved balances are validated, never coerced.** A restore accepts a value only when it is exactly a
  non-negative integer within range; `12.6` is discarded rather than rounded to `12` or `13`, and a
  malformed or negative entry is dropped and reported (`GameWallet.had_invalid_values`) instead of
  quietly becoming a balance. Integral floats are accepted because a JSON round trip turns every
  number into a float, and rejecting those would break honest saves.

This separation is enforced structurally: the wallet primitive
(`src/core/economy/game_wallet.gd`) has no reference to any country or economy type, and the test
suite fails if such a reference is introduced.

### National economies are separate

Countries have their own currencies and their own macroeconomics: inflation, depreciation,
unemployment, recession, sovereign debt and bankruptcy are country-level states. A bankrupt country
does not empty the player's wallet; a rich player does not strengthen a country's currency.

### Monetisation

There are no real-money purchases, no premium currency sales and no monetisation of any kind in this
milestone. Introducing any of it later would be a product decision for the project owner, and would
have to be documented here before implementation.

## The world: atlas and country selection (implemented in Milestone 02)

The map is a **geographic atlas, not a game board of invented provinces**. It is drawn from real
country polygons (Natural Earth 1:50m, public domain) with a documented equirectangular projection,
and every unit the dataset contains is selectable — including dependencies, disputed areas and
Antarctica, each labelled with the dataset's own classification. See
[DATA_SOURCES.md](DATA_SOURCES.md) for provenance and for the deliberate, documented neutrality
policy on contested sovereignty.

How it reads:

- Country shapes are filled flat, bordered with a hairline, and tinted brass when selected. There is
  no gradient, no glow and no drop shadow: the map is a map.
- The player can pan, wheel-zoom or pinch, and there are always visible zoom in / zoom out / fit
  controls, because a pinch is not discoverable on a desktop.
- Labels appear as the player zooms in, taken from the dataset's own label anchors and ranked so
  that a world view is not a wall of text. Ocean names appear only at world zoom, never over a
  zoomed-in region where they would be noise.
- A scale bar states how far a stretch of the map is, computed at the centre of the view; the
  equirectangular projection means the top of a zoomed-out world is stretched, and the bar reports the
  middle rather than pretending otherwise.
- Countries too small to see (Singapore at world zoom, Pacific atolls, European micro-states) get a
  small marker ring and a generous selection radius. The radius is a *tap target*, not a bigger
  country: the polygon keeps its exact position and size, and the assist can only ever reach shapes
  that are already tiny, so a large neighbour cannot absorb a nearby tap.
- The dossier beside (or below) the map is organised into **Overview**, **Geography**,
  **Administration**, **Key figures** and **Data sources**, and states only what is sourced: name,
  long name, ISO codes, region and subregion, capital when the dataset records one, the dataset's
  classification, how many landmasses and vertices its shape has, and where the data came from.
  Missing values say "Not recorded in source".
- **Key figures** (Milestone 05) are the one exception to "no numbers yet", and a careful one: three
  readings — population, GDP and area — from a single pinned source, each with the year it refers to
  and the source named underneath. They are labelled *baseline reference data for the 2026 scenario
  start, not live*. A figure the source does not give says "Not available" and is never shown as
  zero. Nothing simulates them: the game shows them, and that is all it does with them.
- The seven systems the game will eventually track — population, national economy, government and
  politics, military, diplomacy, natural resources and society — are listed as **planned** in the
  dossier, with no values at all. A section that says "not implemented" is honest; a mocked-up
  population figure would be the worst kind of lie in a grand strategy game.

Selection is a **stable country id**, never a screen coordinate, so choosing a nation survives
zooming, panning, filtering and a future save format.

## Campaign setup (implemented in Milestone 02)

New Campaign → scenario → nation → review. The flow is data-driven:

1. The scenario catalogue (`data/scenarios/*.json`) lists only what the build can start. Today that
   is exactly one entry, **Modern World**, starting **1 January 2026**, and the dossier says so in
   words instead of implying a menu of eras.
2. The player chooses a nation on the map, through the search field (name, common name, ISO code,
   keyboard-navigable results), by picking a region chip and then a country, or by tapping the map.
3. A three-stage line (**1 Scenario → 2 Nation → 3 Review**) states which stage the player is in, in
   words as well as colour. The stage is derived from real state, so it cannot drift from what the
   screen actually allows.
4. The confirm action is disabled until the choice validates: an implemented scenario, a country
   that exists in the atlas, and a start date that belongs to the scenario. Stepping back from the
   review keeps a valid nation selected instead of resetting the work.
5. Confirming shows a **campaign brief**: scenario, starting date, nation, region, ISO and the
   dataset's classification. It then states plainly that Milestone 02 ends there — no simulation
   runs, no turn is taken, nothing is saved — and returns to the title screen.

A campaign configuration is a small versioned record (`schema_version`, `scenario_id`,
`country_id`, `start_date`, display metadata). It is the shape a future save file will carry; it is
not a save file.

## Loading and error states (deliberate)

The atlas loads synchronously in about 60 ms when the campaign screen opens, which is faster than one
transition. A spinner or skeleton would flash for a single frame and read as a glitch, so there is
none: the screen appears with the map already drawn. If a later milestone loads data asynchronously, it
must add an honest loading state at that point.

Failures are stated in words where the player is looking. A missing or broken atlas leaves the map
empty, says "World data unavailable" on the map surface and "Atlas unavailable" with the recorded
reason in the dossier; a country with no shape is listed in the status line rather than silently
skipped. The developer-facing record of what was dropped (with the source file and record id) comes
from the loaders' `issues()`.

## Scenarios are data, not fiction

The project will not ship a list of historical scenarios it has not built. A scenario becomes
visible when it is implemented, not when it is imagined, and the catalogue is a plain JSON folder so
that adding a real one does not require touching a screen.

## Interface principles

- The interface is part of the design, not a wrapper around it. Every milestone includes UI/UX
  refinement before it is considered complete.
- One coherent visual language across every screen; see [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).
- Implemented functionality and planned functionality are always visually distinct. Nothing in the
  game may pretend a system works when it does not.
- Landscape is the design target, but layouts respond to the space available rather than to a device
  name.
- Touch, mouse and keyboard are all supported: minimum 48 px touch targets, visible keyboard focus,
  and no interaction that depends on hover alone.

## Fairness and information rules (planned)

- No hidden rule changes for the player; difficulty comes from situation, not from cheating AI.
- The player can always inspect why a value changed once the corresponding system exists.
- No pay-to-win, no timed gating, no energy systems.

## The campaign shell (implemented in Milestone 03)

The first playable screen is deliberately thin, because everything else would have to be invented.

| What the player sees | What is behind it |
| --- | --- |
| In-game date, pause, four speeds | `GameClock`: one tick is one in-game day; speed 1 = 2 days/s, 4 = 128 days/s |
| "Simulation" panel | The system registry, not a hard-coded list — one line today: the calendar |
| The world map, their nation marked | The atlas from Milestone 02, plus a player-nation marker that is not colour-only |
| The dossier of any country they tap | The existing dossier; selecting does not change who they play |
| **Compare this country** on the dossier | The read-only comparison of up to three countries, hosted as an overlay so the campaign keeps running underneath; the clock pauses while it is open |
| Save / Save As / Load / Autosave | `SaveStore`: three slots, one autosave, one rolling backup |
| A short first-run guide | `Settings.get_guide_seen()`; skippable, re-openable from the pause menu |

Two deliberate decisions are worth recording, because they are easy to undo by accident:

* **A campaign starts paused.** The player reads the situation before time moves. The pause button,
  Space, or a speed key starts it.
* **The status panel says what does *not* exist.** Economy, politics, diplomacy and military are not
  simulated; the panel says so in words rather than showing a zero that looks like a real value.

## Out of scope for this milestone

Simulation loop, economy, budgets, elections, parties, government, diplomacy, trade, sanctions,
military, intelligence, country AI, global tick, save slots, multiplayer and any online service.
Also: historical or alternate scenarios (none are implemented, so none are offered), audio,
localisation and any export build. See [ROADMAP.md](ROADMAP.md) for what comes next.

Since Milestone 05 the dossier *does* show population and GDP — but only as sourced reference figures
with their vintage, never as something the game calculates, changes or competes with. Economy,
growth, trends and any use of these numbers by a system remain out of scope until a milestone that
says so. See [docs/STATISTICS_DESIGN.md](docs/STATISTICS_DESIGN.md).
