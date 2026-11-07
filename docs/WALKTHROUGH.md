# Walkthrough — what you can actually do today

This is a walkthrough of the **implemented** game, not of the plan. If something is not
described here, it is not in the build (see `ROADMAP.md` for what is coming and
`docs/GAME_VISION.md` for where it is all going). Every behaviour below is covered by the
test suite, which is the reason it can be described this precisely.

The game is landscape-first, offline, needs no account and requests no permissions.

---

## 1. Launching

The first time you start the game you get the **first-run flow**: a loading screen that
reports the real work it is doing, the **Terms and Privacy** page, a **notifications
preference**, and profile creation. Accepting is remembered; the terms are shown again only if
their version changes. After that, the game opens on the **main menu**. From here:

| Item | What it does |
| --- | --- |
| **New campaign** | Opens the campaign setup screen |
| **Load game** | Lists your saved games; a save you cannot parse is reported rather than deleted |
| **Profile** | Your name, username, player ID, level, XP, VIP, wallet and avatar |
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
   by name, alias or either ISO code (`BD`, `BGD`), click a country directly, pick from the
   **country picker** on the right, or swipe the **flag strip** along the bottom of the map.
   The picker lists one region group at a time, with an A–Z index and an A–Z list; the map,
   the list and the strip always show the same country, and choosing in one moves the other
   two. A record the flag source has no picture for shows a neutral **code badge** instead of
   a flag. Countries that cannot be chosen are shown as unavailable **with the reason**, not
   silently missing — the eligibility rules are explicit, and a country that has no ISO code
   of its own, or no usable starting data, says so on its dossier.
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

## 5. Your profile

**Profile** is reachable from the main menu and from the pause menu inside a campaign.

- It shows your display name, username, player ID, level, an XP bar with the numbers beside
  it (`150 / 250 XP to level 5`), your VIP tier, and both wallet balances — Gold Coins and
  Red Gems.
- **Avatars.** Twenty drawings, made by the game itself, in a grid. Each has a name under it;
  the chosen one carries a tick and a heavier border as well as a colour change. Pick one and
  it is saved with the profile. There is **no picture from a link and no upload**: nothing you
  paste can be loaded, and nothing is downloaded. Importing a picture from your own device is
  **PLANNED** — it needs a file picker that behaves on every platform.
- **Display name.** The first change is free; after that a change costs 100 Red Gems and the
  screen says so, with your exact balance, *before* you confirm. If you cannot afford it, the
  confirm button is disabled and nothing is taken.
- **Username.** It can be set **once**, and the screen warns you before you type. After that
  the field is gone and the screen explains why.
- Achievements are **PLANNED**, and the screen says so rather than showing an empty shelf.

## 6. The tutorial

The first campaign opens **Getting started**, six short steps: the date, the time controls,
the map, the dossier, the pause menu and saving. **Next** moves on and **Skip** leaves at any
point.

- Finishing pays the one-time reward once per profile: **100 XP, 100 Gold Coins and 25 Red
  Gems**, through the profile's own rule, and the claim is saved — so finishing again, or
  reinstalling under the same profile file, never pays twice.
- **Skipping pays nothing.** It records that you skipped, and nothing else.
- **Show the guide again** in the pause menu reopens it, at any time, as often as you like.
- Every step describes something the build really has. The one sentence that mentions
  economy and politics says, in the same breath, that they are not running yet.

## 7. Your worlds, and backups

**Load game** holds two more screens.

- **Your worlds** lists every slot on the device with the country and the date. A world that
  opens is loaded; a world the game cannot read is **never** deleted or replaced quietly —
  the recovery dialog asks, with three answers: **use the backup** (load the copy the game
  kept), **continue with a warning** (leave every file exactly as it is and carry on), or
  **cancel** (change nothing).
- **Backup and restore** writes one plain file with your profile and every world into the
  game's own `user://backups` folder, lists what is in that folder, and puts a chosen one
  back. Restoring over a world asks first, and the same three answers apply. The file is
  plain JSON with a checksum and a signature, so it can be read in a text editor and repaired
  by hand if you like.
- Choosing a folder or a file through your device's own file dialog is **PLANNED**: it needs
  a picker verified on every platform, and that has not been done. The screens say so instead
  of showing a button that might not work.

## 8. Implemented in the engine, not yet reachable from a screen

These are real and tested. Where a screen now exposes part of one, the bullet says which
part; what is left is engine-only, so a player cannot reach it from the menu:

- the **player profile** (name, username, player ID, XP, level, VIP, wallet, tutorial state,
  terms acceptance, notification preference) — saved atomically with a rolling backup with
  its own checksum and signature. The profile screen (§5) shows it and edits the parts a
  player may edit.
- the **XP curve, levels and VIP tiers**, and the extra speed VIP 5 unlocks; the speeds are
  visible in a campaign (Normal, Fast-forward, and the VIP speed at VIP 5) and §5 shows your
  level and XP, but **nothing awards XP yet** — the award path is the tutorial's, which is
  still Task 5;
- **integrity signatures** over saves, the profile and backups, with the three recovery
  choices available from the store layer;
- **one-file backup and restore** with checksum, choose-worlds and overwrite confirmation.
  **Engine only, no screen yet.**

## 9. What is not here yet

For the avoidance of doubt, and because a walkthrough that oversells is worse than none:

- The tutorial is the six-step guide described in §6; there is no multi-campaign tutorial,
  no objectives and nothing to follow beyond the interface itself.
- The only XP and wallet income in the game is the tutorial's one-time reward (§6); nothing
  else awards or pays anything yet.
- Choosing where a backup lives with your device's file dialog is PLANNED and **UNVERIFIED**;
  the game's own backup folder is what works today (§7).
- Deleting a world from the interface: the store can, no screen offers it.
- No achievements, and no import of your own avatar picture (both labelled PLANNED on the
  profile screen).
- No settings groups beyond the existing screen, no diagnostics screen, no roadmap or help
  screen, and no audio at all.
- No combat, no diplomacy, no economy beyond the wallet's storage.
- No multiplayer of any kind. Planned multiplayer is **offline** (hot-seat on one device)
  and that is the only kind this project intends to build; see `docs/GAME_VISION.md`.

## 10. If something goes wrong

The game tells you what happened and does not destroy evidence. A save it cannot read is
kept. A screen that cannot find its data says which file is missing. The About screen always
names the exact data commit the build was made from, so "which version of the map is this?"
has an answer that does not depend on memory.
