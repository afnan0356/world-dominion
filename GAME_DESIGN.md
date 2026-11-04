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
| World model | Countries, borders, regions, population, resources, time | Planned |
| Politics | Government type, parties, elections, approval, stability, corruption | Planned |
| Economy | GDP, budget, taxation, trade, inflation, unemployment, debt | Planned |
| Diplomacy | Relations, treaties, alliances, sanctions, blocs, negotiations | Planned |
| Military | Forces, readiness, logistics, conflict resolution, occupation | Planned |
| Intelligence | Information gathering, uncertainty, misinformation | Planned |
| Player progression | Long-horizon goals, achievements, scenario outcomes | Planned |
| Save management | Multiple local campaigns, autosave, export/import | Planned |

No system in this table is implemented. Milestone 01 delivers the foundation only.

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

## Out of scope for this milestone

World map, country selection, simulation loop, economy, elections, military, diplomacy, save files,
audio, localisation and any export build. See [ROADMAP.md](ROADMAP.md) for what comes next.
