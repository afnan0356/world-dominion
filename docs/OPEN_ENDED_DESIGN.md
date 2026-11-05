# Open-ended design (design only — nothing here is implemented)

This document is a design sketch for what WORLD DOMINION is *for*, once the simulation can
actually produce consequences: a game about leading a nation through an open-ended world, where
the interesting decisions are the ones the player invents.

**Status: entirely PLANNED.** None of it exists in this build. There is no economy, no politics,
no diplomacy, no military, no events, no goals and no scenario editor. Milestone 03 ships a
calendar, a map, a save system and the shell to hold them. This page exists so that the pieces
being built now — versioned state, named random streams, an event bus, data versioning — are
built in a shape that can hold this design later.

Everything below is labelled with what it would need from the systems that do not exist yet.

---

## 1. Simulation-generated events

**Idea.** The world produces events from its own state rather than from a script: a shortage
becomes a price spike becomes a protest becomes a policy change. The player reacts, or does not.

**PLANNED.** Requires: country statistics, an economy, and systems that write state.

What the design depends on, and how the current core supports it:

| Need | Support that exists today |
| --- | --- |
| Events that fire on exact dates (monthly/quarterly/annual) | `SimulationSystem.frequency` (DAILY/MONTHLY/YEARLY) and an integer calendar |
| Events that fire on a condition, not a date | Systems read `WorldState` each tick and publish; ordering is deterministic |
| Reproducible "why did this happen" | Seeded named streams + state hash + a deterministic update order (a bug report can be replayed) |
| Events other systems can react to without tight coupling | Queued `EventBus` with priorities and no mutation during delivery |
| A trail the player can read | A recorded event log is *not* implemented; the bus can keep history for debugging only |

**Design rules proposed for events:**

1. **Every event is derived from state that can be saved.** If an event depends on something
   that is not in `WorldState`, it is not reproducibly part of the game.
2. **Events never mutate state directly.** They are notifications; systems decide what to do,
   in order. This keeps a replay identical.
3. **Severity is a property of the state, not of the presentation.** The interface may rank
   events by importance, but importance must not change what happens.
4. **No hidden dice.** Any randomness is drawn from the owning system's named stream and its
   position is saved, so a reload cannot re-roll an outcome.

---

## 2. Player-defined goals

**Idea.** Instead of the game handing out objectives, the player writes them: "reduce debt below
X by 2030", "hold the region", "stay in power for twenty years". The game watches the state and
reports progress — it does not pretend to judge.

**PLANNED.** Requires: country statistics to measure progress against, and a place to store goals.

Where goals would live: a per-campaign section in `WorldState`, not a new top-level save field:

```jsonc
// world.countries.<id>.sections.goals  (PLANNED shape, not implemented)
{ "version": 1, "values": { "items": [
    { "text": "cut debt below 40% of GDP", "metric": "debt_ratio", "target": 40, "deadline": 2030 }
] } }
```

Because a section carries its own version, adding goals later does not change the file schema
for anyone who never uses them, and a goal written by a newer build can be refused without
refusing the campaign.

**Design rules proposed for goals:**

1. **A goal is text plus an optional machine-checkable condition.** Free text always works; the
   progress bar only appears when the condition can be computed from real state.
2. **The game never invents a metric.** If a goal refers to something the build does not
   simulate, the goal is kept and marked "cannot be measured in this version" — not faked.
3. **Failure is not a game-over.** A missed goal is information, not a verdict.

---

## 3. Custom scenarios and data files, without writing code

**Idea.** A player (or a modder) drops a folder into the game's data directory: a scenario
definition, a country list, optional parameters. The game lists it next to the shipped scenario
and refuses anything it cannot validate.

**PLANNED.** Requires: a scenario loader that reads from `user://`, a documented data schema, and
the validation rules that currently only cover shipped data.

The pieces this needs, and the state of each:

| Piece | Status |
| --- | --- |
| Scenario file with an `id`, `name`, `start_date`, `implemented` flag | Implemented for shipped scenarios (`data/scenarios/`) |
| Loading scenarios from a user directory | PLANNED |
| Data validation with precise errors, refusing rather than repairing | Implemented for the shipped atlas; PLANNED for user data |
| Data version stamp so a save can say which data it needs | Implemented (`data_stamp`) |
| A refusal message a non-programmer can act on | Implemented for saves; PLANNED for custom data |

**Design rules proposed for custom data:**

1. **Validated on load, refused with reasons.** A custom scenario that names an id that does not
   exist fails to appear, with an explanation, instead of producing a broken campaign.
2. **Saves are pinned to data.** A save made with custom data records the stamp; loading it
   without that data is refused with a message naming what is missing.
3. **Custom data cannot change the meaning of an existing id.** If a scenario redefines
   "BGD", a save from the shipped data would silently change meaning. The stamp's id
   fingerprint is what makes this detectable.
4. **No code execution.** Data files are data. A scenario cannot ship a script; anything that
   needs behaviour needs a build.

---

## 4. Why saves reference the registry instead of copying the map

A save that copied geometry would be ~1.3 MB, would go stale the moment a border is corrected,
and would let two campaigns in the same build disagree about the shape of the world. A save that
references the registry by **version + id** gets three things:

1. **Corrections reach old saves.** Fixing a coastline does not invalidate a campaign, because
   geometry is not campaign state.
2. **Saves stay small and fast.** A save is kilobytes, so autosaving once per in-game month is
   cheap enough to be invisible.
3. **Incompatibility becomes detectable and explainable.** The id fingerprint answers "does this
   save refer to countries this build has?" — and the answer can be said in one sentence to the
   player instead of manifesting as a crash.

The same reasoning applies to custom data: it is the *ids* a save depends on, so the fingerprint
covers exactly those.

---

## 5. Explicitly out of scope

Even as design, these are not planned for the foreseeable milestones, and this document should
not be read as promising them: multiplayer or any networking, cloud saves or accounts,
monetisation, generative-AI content, real-time tactical combat, or a world editor. The game is a
single-player, offline sandbox; anything that needs a server is out.
