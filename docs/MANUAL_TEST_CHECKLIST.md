# Manual test checklist — the current build (Milestones up to 08)

Automated tests cover the logic. This list is what a **person** has to check, on a **real device**,
because no test can feel whether an autosave stutters, whether a file dialog appears, or whether a
tap target is comfortable.

Nothing below has been performed on a phone yet. Until it has, everything in this document is the
plan for verification, and the status of anything device-specific remains **UNVERIFIED**.

How to record a result: replace `☐` with `✅` and add the device, OS version and date. If something
fails, write what happened and which step — do not mark it done.

---

## 0. What you need

- A desktop (Windows, macOS or Linux) and, later, an Android phone.
- Both themes, all three window sizes (expanded ≥ 1000 px wide, medium, compact/phone), and the
  shortest supported height (a phone in landscape, e.g. 844×390).
- About ten minutes. The save/backup section needs a file manager to damage a file on purpose.

---

## 1. Starting a campaign

- ☐ Main menu: the entries are grouped **Play** (New Campaign, Continue, Worlds), **You** (Profile,
  Settings) and **Library** (Help, Roadmap, About the data, Keyboard shortcuts, Diagnostics, About).
  Help, Roadmap and Diagnostics say PLANNED; everything else opens.
- ☐ Rotate a phone to landscape (or resize the window to about 640×360): the menu column scrolls,
  every row is still tappable and at least 48 px tall, and nothing is clipped.
- ☐ Library → **Help**: six sections, every link button opens the screen it names, and nothing is
  described that is not in the build.
- ☐ Library → **Roadmap**: each card shows PLANNED, NOT PLANNED or OPEN QUESTION and the document it
  comes from. With reduced motion on, the page looks and behaves exactly the same.
- ☐ Library → **Diagnostics**: the build, data version, engine, platform, screen size and scale and
  the frame-rate cap are all present and correct for your device.
- ☐ Diagnostics → **Export diagnostics**: a file appears in the game's own diagnostics folder (open
  it with a file manager). Check it names no player, no ID and no folder path.
- ☐ Diagnostics → **Copy to clipboard** (desktop): paste into a text editor and compare it with the
  text on screen. On a platform without a clipboard the button is disabled and says why.
- ☐ Main menu → **New Campaign** → choose a nation → **Start campaign**.
- ☐ A short "Starting your campaign…" transition appears and disappears. With **reduced motion** on,
      there is no animation: the game screen is simply there.
- ☐ The top bar shows: your country's name, the in-game date (1 January 2026), "Paused", the pause
      button, the speed buttons (two, or three at VIP 5) and the Menu button.
- ☐ The map shows your country with a **ring and the words "YOUR NATION"** — check in both themes and
      check it is legible without relying on colour.
- ☐ The dossier panel shows your country. Tap/click a different country: its dossier appears, but your
      nation's badge does not move and the top bar does not change.
- ☐ The status panel says the calendar is running and names what is *not* in this version. It must not
      show a population, GDP or military number.

## 2. Time controls

- ☐ Space pauses and resumes. The button and the "SIMULATION" label agree with the key.
- ☐ Keys 1–4 choose speeds; the segmented control highlights the same speed.
- ☐ At Fast-forward the date advances about 10 days per second; on a phone, note whether
      the interface stays responsive (this is the honest measurement we do not have yet).
- ☐ Leave it paused for a minute: the date must not move.
- ☐ Open the pause menu: the clock stops. Close it: the clock resumes at the speed it had.

## 3. Pause menu and quitting

- ☐ Escape (and the Menu button) opens **Resume / Save / Save as… / Load game / Settings / Show the
      guide again / Quit to main menu**, plus the "early foundation" version line.
- ☐ Settings opens and returns to the **same campaign**, still paused, same date.
- ☐ Quit to main menu after a few unpaused seconds: the confirmation appears, offering "Save to slot 1
      and quit", "Quit without saving" and "Cancel". All three do what they say.
- ☐ After quitting, the main menu's **Continue** is enabled and the caption names the country and date.

## 4. Saves, backups and recovery (the important part)

- ☐ Save to slot 1. The autosave indicator shows "Autosaved" briefly and never stutters the game
      (watch the frame counter with the performance overlay on).
- ☐ Run the game until the in-game month changes (Fast-forward, ~3 seconds), or until "Autosaving" appears.
      Load Game then shows an autosave slot whose date is the 1st of a month.
- ☐ Save to slot 1 again later. Load Game shows slot 1's new date.
- ☐ Close the app entirely, reopen it, main menu → **Continue** → the campaign resumes on the exact
      in-game date with the same country.
- ☐ **Deliberate damage:** with the app closed, open the save folder (paths in `docs/SAVE_FORMAT.md`),
      edit a letter in `1.json`, save the file, reopen the game. Load Game must list slot 1 as damaged,
      in plain language, and offer **Restore backup**. Restoring must load the *previous* save and say
      so.
- ☐ Damage both `1.json` and `1.bak.json`: the slot must refuse to load and explain itself. It must
      never invent a campaign.
- ☐ **Newer save:** change `"schema_version": 2` to `3` (and only that) in a save file. The game must
      refuse it, say it is from a newer version, and leave the file byte-for-byte unchanged.

## 5. Export and import

- ☐ Pause menu → Save as…, then Load game → **Export…**: a file dialog appears, and the exported file
      opens in a text editor as JSON.
- ☐ **Import…** with that file: the game validates it, then asks which slot to import into.
- ☐ Import a damaged file: refusal with a reason; nothing is written.
- ☐ Import into an occupied slot: the game says the previous save was kept as a backup.
- ☐ On Android/iOS specifically: do the file dialogs actually appear? **This is unverified** — record
      the result.

## 6. First-run guide and help

- ☐ On a fresh install (or after Settings → reset, or by clearing the settings file), the guide appears
      on the first campaign: four steps, **Skip** works, and it describes only what exists.
- ☐ Escape closes it. It does not reappear on the next campaign.
- ☐ **Show the guide again** in the pause menu reopens it.

## 7. Layout, themes, touch, accessibility

- ☐ Every screen at all three sizes: nothing clipped, nothing overlapping, no horizontal scrolling
      except inside a panel that is meant to scroll.
- ☐ Phone in landscape (844×390) **and** portrait (390×844) and the smallest supported landscape
      (640×360): the map stays usable, the dossier is reachable, the pause button is tappable.
- ☐ Both themes (Midnight and Parchment): all new panels, the pause menu, the guide and the autosave
      indicator are readable.
- ☐ Interface scale at minimum and maximum: no text clipped in the top bar or the pause menu.
- ☐ Reduced motion: no entrance animation, no autosave fade (the text appears and disappears), no
      pulsing anything.
- ☐ Keyboard only: Tab reaches every pause-menu entry, Enter activates it, focus is visible, Escape
      closes the menu.
- ☐ Touch only: every control is at least 44 px tall; no control needs a hover.
- ☐ The player's nation is identifiable without colour (ring + words), and the same is true for the
      selected-country highlight.

## 8. Repeated use (the state-leak check)

- ☐ Enter a campaign, quit to the main menu, enter it again: same date, no duplicated overlays, no
      second clock running.
- ☐ Enter → Settings → back → Worlds → back → main menu → New Campaign → start: all stable.
- ☐ Delete a save from Load Game, then check Continue is disabled if no valid save remains.

## 9. Performance to record

- ☐ F3 overlay on the game screen: note FPS and frame time at speeds 1 and 4 while panning the map.
- ☐ Settings → Developer → 30-second map stress test: record the verdict line and device.
- ☐ Save/load times: watch for any visible pause when saving manually (should be imperceptible).

Record the numbers in `docs/PERFORMANCE.md` under "Simulation and save cost", with the device name.
Until then those rows stay **UNVERIFIED**.

---

## On a phone: flags, and the first-run flow (Milestone 08)

1. Delete the game's data (or install fresh) and open the game. You should see the loading
   screen, then **Terms and Privacy**.
2. Read the page. Every claim should be true of what you have seen: no sign-in, no ads, no
   purchases. Press **Decline and close the game** — the game should close, and reopening
   should show the terms again.
3. Press **Accept and continue**. The notification step appears and says notifications are
   PLANNED. Choose either option; nothing should ask for a system permission.
4. Enter a display name and a username. Try an empty name and a name with a space in the
   username: both should be refused with a sentence. Then create the profile.
5. The main menu appears. Open **Settings → Privacy and terms** and check that "View terms
   and privacy" reopens the same page, and that the notification choice is remembered.
6. Start a campaign and search for "Bangladesh". The result row should carry a small flag,
   and the dossier header should show it too. Search for "Somaliland" (or open one of
   `ATC`, `IOA`, `CYN`, `KAS`, `SOL`) and check that a neutral code badge is shown instead
   of a flag — never a neighbouring country's flag.
7. Scroll the search list quickly through several queries. It should not stutter, and memory
   should not climb.

## On a phone: the country picker (Milestone 08, Task 3)

1. Open **New campaign**. On the right there should be **Choose your nation**: a group list, a
   search field, an A–Z index and a list below it. On a phone in landscape, the panel may sit
   below the map — that is the narrow layout, not a missing feature.
2. Pick a group, then press a letter. Only that group's countries starting with that letter
   should be listed, and the count line should match what you can count.
3. Tap a country in the list. The map should fly to it and the dossier should change. Now tap
   a different country on the map: the list and the bottom flag strip should move to it. Now
   swipe the strip and tap a tile: the map and the list should follow. All three stay in step.
4. Search `BD`, then `BGD`, then `Bangladesh`, then an alias. All four should find the same
   country. Clear the search.
5. Find one of `ATC`, `IOA`, `CYN`, `KAS`, `SOL`: it must show a neutral code badge, never a
   flag borrowed from a neighbour.
6. Scroll the list quickly and swipe the strip repeatedly. Nothing should stutter, the strip
   should snap to a page when you let go, and a selected tile must be marked with a tick and a
   thicker border, not only a colour.
7. Rotate to portrait and to a short window. The map must remain usable and the footer must
   stay on screen; the strip becomes smaller rather than pushing the footer off.

## On a phone: the profile screen (Milestone 08, Task 4)

1. Open **Profile** from the main menu. Check the numbers against what you know: the level, the
   `… / … XP to level …` line, Gold Coins and Red Gems. Nothing may be invented.
2. Choose a different avatar. The big drawing at the top should change with the grid, the old
   cell should lose its tick, and the new one should gain a tick and a heavier outline. Close
   the game and open **Profile** again: the choice should still be there.
3. Press **Change display name**. The first change is free; after the first, the sentence must
   name 100 Red Gems *and* your exact balance before you confirm. If your balance is lower, the
   confirm button must be disabled and your Red Gems must not change.
4. If your username is unset, try one with a space — it should be refused with a sentence. Set a
   valid one, and check the field is gone afterwards and the screen explains why.
5. Rotate the phone to landscape and back. Nothing should be clipped without a scroll, and the
   avatar cells must stay big enough to tap.
6. Start a campaign, open the pause menu, and check **Profile** is there and returns you to the
   paused campaign.

## On a phone: the tutorial (Milestone 08, Task 5)

1. Start a campaign for the first time. **Getting started** should open by itself, with
   `Step 1 of 6`.
2. Read every step. Each one must describe something you can see or do: the date in the top
   bar, the pause/speed buttons, the map, the dossier panel, the pause menu, saving. Nothing
   may promise a system the game does not have.
3. Press **Skip** on one run: the guide closes, no reward appears, and your profile's XP and
   wallet do not change (open **Profile** to check).
4. Run it again from the pause menu (**Show the guide again**) and read it to the end. The
   closing card should say 100 XP, 100 Gold Coins and 25 Red Gems, and **Profile** should show
   them. Run it to the end a second time: it must say the reward was already paid, and the
   numbers must not move.
5. Rotate the phone and open it again at the smallest window you can: the panel must stay
   inside the screen and both buttons must be big enough to tap.

## On a phone: worlds, backups and the recovery dialog (Milestone 08, Task 6)

1. Start a campaign twice so two worlds exist, then go to **Load game → Your worlds**. Both
   should be listed with a country and a date.
2. **Load game → Backup and restore → Create a backup now.** A file should appear in the list.
   With a file manager, confirm it is in the game's own `backups` folder and that it opens as
   text (it is plain JSON).
3. Restore it: the screen must ask before replacing a world that already exists. Choose
   **Cancel** — nothing may change. Do it again and choose **Continue with a warning** — the
   world should be replaced, and the earlier copy kept.
4. Break a save on purpose: edit one world file in a file manager so it is not valid JSON.
   Open **Your worlds**; that slot must say it cannot be read, and tapping it must open the
   dialog.
5. Try all three answers on the damaged world:
   - **Use the backup** should load the previous copy;
   - **Continue with a warning** must leave the damaged file exactly as it is (check the file
     size and contents afterwards), and must not delete it;
   - **Cancel** must change nothing.
6. Do the same for the profile: damage `profile.json`, open **Profile**, and check the dialog
   appears with the same three answers, and that the damaged file survives every choice.
7. Try to reach a file dialog anywhere in the game: there is none. That is deliberate — see
   `docs/layout-diagrams/recovery-screens.md` for exactly what is unverified.

## What is deliberately not tested here

- Anything about economy, politics, diplomacy, military, events or goals: none of it exists.
- Multi-device sync, accounts or cloud saves: not planned.
- Export builds: none exist for this milestone; see `docs/ANDROID.md` for the Android status.
