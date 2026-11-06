# Game vision

Where World Dominion is going, what it is trying not to become, and the questions that are
still genuinely open. `ROADMAP.md` is the schedule; `docs/WALKTHROUGH.md` is what exists
today. This document is the long view.

---

## 1. The idea in one paragraph

You choose a real country and are handed a map of the real world. You build it up — not
through a grid of provinces, a hex map or a spreadsheet of modifiers, but through the
country itself: its geography, its neighbours, its resources, the way its position in the
world constrains and enables it. The map you are looking at is the same real map on every
device, drawn from public-domain data with its sources on screen. The game is offline, has
no accounts, does not ask for your attention between sessions and has no monetisation of any
kind.

## 2. What the player does

- **Starts from a real country**, chosen with its own facts in front of them: population,
  area, income, capital, region, and honest gaps where the reference data has none.
- **Builds, trades and defends** through a simulation driven by those facts rather than by a
  generic multiplier table. A landlocked country feels landlocked; an island country feels
  far away.
- **Reads the map as the game board.** Geography is the puzzle: coastlines, borders,
  distances, the shape of a peninsula.
- **Learns something true.** Every figure in the game can be traced to the file it came
  from, and the About screen names the exact dataset version.

## 3. What the game is not

Stated so that scope creep has something to fail against:

- **Not a map-painting power fantasy with real peoples as villains.** No real ethnic,
  religious or national group is the enemy. Conflict is between countries acting as states,
  not between peoples.
- **Not a live-service product.** No network at runtime, no accounts, no battle pass, no
  daily login, no push notifications to pull you back.
- **Not a political statement.** Borders are drawn from a public-domain dataset that
  includes Natural Earth's own decisions about disputed territories, and the game shows
  those decisions as data rather than as opinions. No claim of sovereignty is made by this
  project — see the code rule in `docs/COUNTRY_CODES_AND_REGIONS.md`: a territory is never
  given its administering state's code.
- **Not a cheat-proof competitive game.** It is single-player and offline; integrity work
  protects the player's files from corruption, not a leaderboard from them
  (`docs/SECURITY.md`).
- **Not a simulator that pretends to precision it does not have.** Estimates are labelled as
  estimates, derived figures as derived, and missing data as missing.

## 4. Multiplayer: offline, and only offline

Planned multiplayer is **hot-seat**: several people, one device, taking turns in the same
world. It is mentioned because it shapes the design — every action must be legal as a turn
taken by a named player, and the save format has to hold more than one player's hand — and
because saying it plainly prevents the question "will you add online play?" from being
answered by silence.

There is no plan for online multiplayer, matchmaking, servers or accounts. The game makes no
network calls, and that is a feature.

## 5. Progression

Progress belongs to the **player**, not to a save: a profile that levels up across every
campaign, with a level curve that starts quickly and then stretches, VIP tiers that reward
time spent rather than money, and rewards that are earned by playing the game — never
purchased. The wallet exists today; nothing awards into it yet. Progression must be
skippable: a player who wants to play without a tutorial should never be trapped by one.

## 6. Data and mods

The world is data: country folders, each with its identity, geometry, statistics and sources,
validated against the pinned dataset. That structure is what makes **data-only mods**
possible — a new scenario, corrected statistics, an alternative region grouping — without
touching code and without the security and integrity problems of a plugin system. Recommended
direction: mods change data, never execute code.

## 7. Art and tone

Drawn entirely by code: no external art, no fonts beyond the engine's own, no stock icons.
The visual language is cartographic — paper, ink, a ruler — and the interface stays out of the
map's way. Both themes are contrast-tested. Text is plain English; the game explains itself
where it needs to and does not lecture.

## 8. Platforms

Desktop first (Windows, Linux, macOS), then Android. iOS is not buildable from this
repository alone (it needs Xcode, signing identities and an Apple Developer account held by
the owner). Landscape-first everywhere; the interface is reachable by touch, mouse and
keyboard.

## 9. Open questions for the owner

These are decisions the project cannot make for its owner. They are listed rather than
resolved, because guessing at any of them would be inventing a game the owner did not ask
for.

1. **Religion: model it, or keep the game neutral?** Modelling religion adds depth and adds
   the fastest possible route to a game that reads as a commentary on real people. The
   recommendation, if asked: leave it out of the simulation, or treat it purely as a
   *statistic shown in the dossier* with no mechanical effect. This is the single largest
   tone decision in the project.
2. **How realistic should a dictatorship be?** A tyranny the player can run for profit is a
   different game from one that costs them something. Options run from "any government can be
   played efficiently, no moral weight" to "authoritarian paths carry real internal costs."
   The middle is usually the worst of both: neither a critique nor a sandbox.
3. **Mods: data-only (recommended) or a script layer?** Data-only keeps the offline,
   no-execution posture intact and is achievable with today's folder structure. A script
   layer would bring a plugin sandbox, integrity problems and a compatibility burden, for
   content the data layer can mostly already express.
4. **What is the win condition?** Total regional dominance, survival to a date, a score, or a
   sandbox with no end? This decides the turn structure more than any other question.
5. **How much of the real world's politics belongs in the game?** The data includes
   disputed territories and unrecognised states. Today they are shown as the dataset shows
   them. Whether they are *playable*, and how their status is described in-game, is a product
   and editorial decision, not a technical one.
6. **Monetisation: none, permanently?** The current position is none at all — no ads, no
   purchases, no subscriptions. If the game is ever sold, that is a sale, not monetisation of
   play; if gems ever become purchasable, that decision should be made deliberately and
   written into this document before it is made in code.
7. **Difficulty and accessibility scope.** Interface scale and both themes exist. Colour-blind
   palettes beyond the current non-colour-only selection states, colour-blind-safe map ramps
   and a high-contrast mode are all reasonable; which of them ship is the owner's call.
8. **Localisation: ever?** Text is authored in English with no extraction pipeline. Adopting
   one later is cheap if the strings are kept translatable now, and expensive if they are not.

## 10. The test for a feature

A feature is in scope when it (a) makes the real world feel real, (b) can be explained in the
interface without a manual, (c) works offline, (d) can be tested, and (e) does not turn a
real people into a villain. A feature that fails any of those is not a matter of scheduling.
