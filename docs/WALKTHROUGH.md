# Walkthrough — what you can actually do today

This is a walkthrough of the **implemented** game as of Milestone 09, not of the plan. If something is not
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

The menu is grouped into **Play**, **You** and **Library**.

| Group | Item | What it does |
| --- | --- | --- |
| Play | **New campaign** | Opens the campaign setup screen |
| Play | **Continue** | Resumes the most recent valid save; disabled, with the reason, when there is none |
| Play | **Worlds** | Every saved world on this device; a world the game cannot read is reported rather than deleted |
| You | **Profile** | Your name, username, player ID, level, XP, VIP, wallet and avatar |
| You | **Settings** | Display, performance, audio, controls, backup, privacy, developer tools and this build |
| Library | **Help** | Plain-language help: what this build is, saving and backups, why there is no account, and where to report a problem |
| Library | **Roadmap** | What is built and what is next, each item citing the document it comes from |
| Library | **About the data** | Where the map data comes from, its licence, what is estimated and what is derived |
| Library | **Keyboard shortcuts** | Every keyboard binding, for the platform you are on |
| Library | **Diagnostics** | Version, data version, engine, platform, screen, frame-rate cap and the last 50 warnings, with an export and a copy button |
| Library | **About & Credits** | Version, engine, credits, licence and a plain-English statement of what the game is |
| — | **Quit** | Leaves the game (the desktop platforms; a phone simply backgrounds it) |

On a short window — a phone in landscape, or a 640×360 window — the menu column scrolls rather
than shrinking: every entry is still there, one swipe or one Tab away.

Everything is reachable with touch, mouse or keyboard, and every screen keeps its back
path: no dead ends.

### Deleting a world

Open **Library → Your worlds**. Each world has a **Delete** button beside it. Deleting is always
two steps: the confirmation names the slot, the country, the in-game date and how long you played
that world, and it tells you whether a recovery copy can be made. **Delete this world** makes that
copy first, then removes the world — and the status line then offers **Undo**, which works until
you close the game. **Keep it** changes nothing at all.

Where a recovery copy cannot be made (a device that will not allow one), the confirmation says so
before you agree, and the deletion is permanent. The profile, and every other world, are never
touched: they are different files, and the deletion code can only reach the slot you chose.

### What the dossier says about money

The dossier's **Identity** section carries a **Currency** row. It shows the currency the
pinned CLDR release records for that country — for Bangladesh, "Bangladeshi Taka (BDT)" —
and it says **"Not available"** for the records the source cannot answer for, with the
reason underneath. Countries the source lists two currencies for (Bhutan, Namibia, Panama,
Lesotho, Haiti, Palestine, Zimbabwe) are in that second group on purpose: the project does
not pick one, and it never borrows a territory's currency from the country it belongs to.
No exchange rate is stored anywhere, and the currency never reaches the simulation or a
save file.

### Help

Help answers the questions a first-time player actually asks, in plain words: what this build
is (an early foundation), what you can do today, how saving, backups and several worlds work,
why there is no account, what the notification choice does (nothing yet), and where to go when
something breaks.

Every section points at the screens it is talking about, so a sentence cannot describe a screen
that is not there. The only two sections without links explain scope rather than a feature. The
suite fails if either rule is broken.

### Roadmap

The roadmap is a calm page: one column of cards, no animation at all (so reduced motion needs no
special case), and an honest status on each item — **PLANNED**, **NOT PLANNED**, or **OPEN
QUESTION**. Every card also shows the document and the sentence it came from; a test reads those
documents and fails if the sentence is gone.

Two statuses are worth reading carefully, because the milestone's list and the project's own
vision disagreed:

* **Online multiplayer** is **NOT PLANNED**. `docs/GAME_VISION.md` says there is no plan for it;
  the multiplayer the project does plan is hot-seat, several people on one device.
* **Religion and society** is an **OPEN QUESTION** for the owner, because the vision lists it as
  the project's largest tone decision rather than a committed feature.

### Diagnostics

Diagnostics answers one question: *what is this build doing on this device?* It shows the
version, the data pack's version and generation date, the engine, the platform, the screen size
and interface scale, the frame-rate cap, and the game's own last 50 warnings and errors.

Two buttons follow the text. **Export diagnostics** writes a plain-text file into the game's own
`diagnostics` folder — no dialog, because no file dialog has been verified on every target
platform, so choosing another folder is PLANNED and **UNVERIFIED**. **Copy to clipboard** puts the
same text on the clipboard where the platform has one; where it does not, the button is disabled
and the reason is on screen. The text is also selectable in the page, so the report is never
trapped.

The file contains no personal information: no name, username, player ID, avatar, wallet, save
contents or folder path beyond the game's own folder name. It is built without reading the
profile, and every path-like token is reduced to its last component. Nothing is sent anywhere —
there is no network code in the build at all.

One limitation, stated on the screen and in the export itself: the log is the game's own log, not
the engine's console output. Godot 4.6 does not give a script access to that stream, so
engine-level warnings are not captured.

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
