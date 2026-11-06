# Walkthrough — what you can actually do today

This is a walkthrough of the **implemented** game, not of the plan. If something is not
described here, it is not in the build (see `ROADMAP.md` for what is coming and
`docs/GAME_VISION.md` for where it is all going). Every behaviour below is covered by the
test suite, which is the reason it can be described this precisely.

The game is landscape-first, offline, needs no account and requests no permissions.

---

## 1. Launching

Start the game and you arrive at the **main menu**. There is no loading screen and no
first-run flow yet: the menu is the first thing you see. From here:

| Item | What it does |
| --- | --- |
| **New campaign** | Opens the campaign setup screen |
| **Load game** | Lists your saved games; a save you cannot parse is reported rather than deleted |
| **Settings** | Theme, interface scale, and the developer options |
| **About** | Version, engine, credits, licence and a plain-English statement of what the game is |
| **About the data** | Where the map data comes from, what its licence is, what is estimated and what is derived |
| **Shortcuts** | The keyboard bindings, for the platform you are on |
| **Quit** | Leaves the game (the desktop platforms; a phone simply backgrounds it) |

Everything is reachable with touch, mouse or keyboard, and every screen keeps its back
path: no dead ends.

## 2. Starting a campaign

**Campaign setup** is where a run begins.

1. Choose a country. The world is drawn on a map you can pan and zoom; you can also search
   by name and click a country directly. Countries that cannot be chosen are shown as
   unavailable **with the reason**, not silently missing — the eligibility rules are
   explicit, and a country that has no ISO code of its own, or no usable starting data, says
   so on its dossier.
2. Read the dossier for the country you are pointing at. It is grouped into identity,
   geography, administration, key figures and sources, and every number says where it came
   from and what year it is for. Anything the data does not have shows an honest gap.
3. Begin. The campaign opens on the game screen with your country selected.

Your country's identity in the dossier includes both of its ISO 3166-1 codes — the two-letter
and the three-letter one — and states whether the code is officially assigned, widely used
but unofficial, or absent. A country the source has no code for is not given an invented
one.

## 3. The game screen

The map is the game. You can:

- **Pan and zoom** with touch, mouse or keyboard; the camera frames a country when you
  select it, and it lands on the part of the country you would call the country (an island
  nation's far-flung territory does not drag the view out to sea).
- **Select a country** by tapping it, and read its dossier.
- **Compare** two countries in the comparison screen: the same facts side by side, with the
  same sourcing, so a comparison never quietly compares an estimate with a measurement.
- **Open the menu** for save, load, settings and the other screens; the session stays alive
  underneath, so returning is instant and loses nothing.
- See the current session's status in the status line at the bottom, and your wallet's two
  currencies in the interface chrome.

The game clock can be paused and its speed changed. What the clock currently drives is
deliberately small; the simulation is the next thing to grow.

## 4. Saving, loading and settings

- **Save** writes a versioned file inside the game's own storage. Writes are atomic: an
  interrupted write leaves the earlier save intact.
- **Load** shows your saves with the country and the date, and reports a damaged file
  instead of discarding it.
- **Settings** covers the theme (light and dark, both contrast-tested), the interface scale,
  and developer options. Settings are stored with the same care as saves: validated,
  versioned, and never silently reset.

## 5. Implemented in the engine, not yet reachable from a screen

These are real, tested and loadable, but no screen exposes them yet, so a player cannot
reach them from the menu. They are listed here rather than described as features:

- the **player profile** (name, username, player ID, XP, level, VIP, wallet, tutorial state,
  terms acceptance, notification preference) — saved atomically with a rolling backup with
  its own checksum and signature. **Engine only, no screen yet.**
- the **XP curve, levels and VIP tiers**, and the extra speed VIP 5 unlocks; the speeds are
  visible in a campaign (Normal, Fast-forward, and the VIP speed at VIP 5), but there is no
  profile screen to show your level or XP;
- **integrity signatures** over saves, the profile and backups, with the three recovery
  choices available from the store layer;
- **one-file backup and restore** with checksum, choose-worlds and overwrite confirmation.
  **Engine only, no screen yet.**

## 6. What is not here yet

For the avoidance of doubt, and because a walkthrough that oversells is worse than none:

- No tutorial and no first-run terms or notification screens.
- No screen for progression: XP, levels and VIP exist in the engine and are saved, but
  nothing in the interface shows them, and nothing awards XP yet — the wallet exists and
  nothing pays into it yet either.
- No country picker with the region panel, flag strip or A–Z index; today's setup screen is
  the earlier map-and-search picker. No flags are drawn anywhere.
- No profile screen, no avatars, no display-name changes from the interface.
- No backup export or restore from the interface.
- No settings groups beyond the existing screen, no diagnostics screen, no roadmap or help
  screen, and no audio at all.
- No combat, no diplomacy, no economy beyond the wallet's storage.
- No multiplayer of any kind. Planned multiplayer is **offline** (hot-seat on one device)
  and that is the only kind this project intends to build; see `docs/GAME_VISION.md`.

## 7. If something goes wrong

The game tells you what happened and does not destroy evidence. A save it cannot read is
kept. A screen that cannot find its data says which file is missing. The About screen always
names the exact data commit the build was made from, so "which version of the map is this?"
has an answer that does not depend on memory.
