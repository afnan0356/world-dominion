class_name Strings
extends RefCounted
## The string table (Milestone 08).
##
## Every player-facing string written from here on lives in `TABLE` under a stable key, and
## is read through `t()`. Keys are namespaced by screen (`first_run.terms.title`) so a
## translator can see where a sentence is used. Values are English today; there are no
## translations yet, and none are claimed.
##
## Why a table and not literals: localisation later is a data change rather than a hunt
## through scene files, and a test can fail when a screen grows a hard-coded sentence.
##
## Existing screens keep their literals for now — moving them is a mechanical job with no
## player-visible result, and it is not part of this milestone. New screens must use this
## table; `test_strings.gd` enforces that for `src/ui/screens/first_run/` and the profile and
## picker screens.

const TABLE := {
	"search.no_match": "No nation matches \"%s\". Try a different spelling or an ISO code.",
	"flag.tooltip": "Flag of %s.",
	"flag.tooltip_missing": "%s has no flag in the source data; its code is shown instead.",
	"flag.badge_hint": "Code badge",
	"first_run.loading.title": "WORLD DOMINION",
	"first_run.loading.body": "Preparing the world…",
	"first_run.loading.step": "%s (%d of %d)",
	"first_run.terms.title": "Terms and Privacy",
	"first_run.terms.version": "Version %d — updated %s",
	"first_run.terms.intro": ("This page says what the game does with information, in plain words. "
			+ "It is short because the answer is short: nothing leaves your "
			+ "device."),
	"first_run.terms.offline_title": "It works offline",
	"first_run.terms.offline_body": ("The game needs no internet connection to play. It has no "
			+ "server, no account and no sign-in."),
	"first_run.terms.data_title": "No data is collected",
	"first_run.terms.data_body": ("Nothing is measured, reported or uploaded. There is no "
			+ "analytics, no advertising and no tracking of any kind."),
	"first_run.terms.saves_title": "Your saves stay on your device",
	"first_run.terms.saves_body": ("Progress is stored in files the game writes on this device, "
			+ "and nowhere else. You can export a backup file yourself and "
			+ "keep it wherever you like."),
	"first_run.terms.purchases_title": "No purchases",
	"first_run.terms.purchases_body": ("There is nothing to buy. Gold Coins and Red Gems are "
			+ "earned in play and have no cash value."),
	"first_run.terms.changes_title": "If this text changes",
	"first_run.terms.changes_body": ("This page is versioned. You will see it again, and be asked "
			+ "again, if the version changes."),
	"first_run.terms.accept": "Accept and continue",
	"first_run.terms.decline": "Decline and close the game",
	"first_run.terms.declined": ("You declined the terms. The game will close. Nothing was changed "
			+ "on your device."),
	"first_run.notifications.title": "Notifications",
	"first_run.notifications.body": ("This is a preference, not a permission. Nothing will ask "
			+ "your device for permission to notify you, because the game "
			+ "cannot send notifications yet."),
	"first_run.notifications.planned": ("Real notifications are PLANNED, not built. Turning this "
			+ "on records your choice for when they exist."),
	"first_run.notifications.on": "I would like notifications later",
	"first_run.notifications.off": "No notifications, thank you",
	"first_run.notifications.saved": "Your choice is saved on this device and sent nowhere.",
	"first_run.profile.title": "Your profile",
	"first_run.profile.body": ("A display name is what the game calls you. A username is a short "
			+ "handle you can set once."),
	"first_run.profile.name_label": "Display name",
	"first_run.profile.username_label": "Username",
	"first_run.profile.username_warning": "A username can be set only once. Choose carefully.",
	"first_run.profile.avatar_label": "Avatar",
	"first_run.profile.avatar_placeholder": ("This is your starting avatar. You can choose "
			+ "from twenty of them later, in your profile."),
	"first_run.profile.create": "Create profile",
	"first_run.profile.name_problem": "%s",
	"first_run.profile.username_problem": "%s",
	"first_run.common.back": "Back",
	"first_run.common.continue": "Continue",
	"profile.title": "Profile",
	"profile.player_id": "Player ID",
	"profile.level": "Level %d",
	"profile.xp": "%d / %d XP to level %d",
	"profile.max_level": "%d XP — the highest level",
	"profile.vip": "VIP %d",
	"profile.vip_none": "VIP 0",
	"profile.wallet_gold": "Gold Coins: %d",
	"profile.wallet_gems": "Red Gems: %d",
	"profile.change_name": "Change display name",
	"profile.change_name_cost": "This change is free (your first).",
	"profile.change_name_price": "This change costs %d Red Gems. You have %d.",
	"profile.change_name_confirm": "Spend %d Red Gems and rename to \"%s\"?",
	"profile.username_set": "Set username",
	"profile.username_once": "Usernames can be set once. Yours is set.",
	"profile.avatar_title": "Choose an avatar",
	"profile.avatar_help": ("Avatars are drawn by the game itself. There is no upload and no "
			+ "picture from a link: nothing you paste can be loaded, and nothing is "
			+ "downloaded."),
	"profile.avatar_import_planned": ("Importing your own picture is PLANNED. It needs a file "
			+ "picker that works on every platform, which the game does "
			+ "not have yet."),
	"profile.achievements_planned": "Achievements are PLANNED.",
	"profile.back": "Back to the menu",
	"tutorial.title": "GETTING STARTED",
	"tutorial.counter": "Step %d of %d",
	"tutorial.skip": "Skip",
	"tutorial.next": "Next",
	"tutorial.finish": "Finish",
	"tutorial.close": "Close",
	"tutorial.done_title": "Tutorial complete",
	"tutorial.reward": "You earned %d XP, %d Gold Coins and %d Red Gems.",
	"tutorial.reward_taken": ("This profile already had the tutorial's one-time reward. "
			+ "Opening the guide again never pays twice."),
	"tutorial.save_failed": "The reward was paid, but the profile could not be saved: %s",
	"tutorial.skipped": ("Skipped. Skipping pays nothing. Open the guide again from the "
			+ "pause menu whenever you like."),
	"tutorial.date.title": "The date",
	"tutorial.date.body": ("The top bar shows the in-game date, and the line beside it says "
			+ "whether the clock is running. One tick is one in-game day. The "
			+ "calendar is the only thing the simulation does today: there is no "
			+ "economy and no politics running yet."),
	"tutorial.speeds.title": "Time controls",
	"tutorial.speeds.body": ("Pause stops the clock. Normal runs one in-game day per real "
			+ "second and Fast-forward runs ten; players at VIP 5 get a fourth speed "
			+ "of twenty. Speeds are counted in days, never frames, so a slower "
			+ "device sees exactly the same world."),
	"tutorial.map.title": "The map",
	"tutorial.map.body": ("Drag to pan, scroll or pinch to zoom, and tap a country to select "
			+ "it. Your own nation carries a ring and the words YOUR NATION, and "
			+ "browsing another country never changes who you lead."),
	"tutorial.dossier.title": "The dossier",
	"tutorial.dossier.body": ("The panel beside the map is the country's dossier: identity, "
			+ "geography, administration, key figures and data sources, with the year "
			+ "behind every figure. Where the data has nothing, it says so instead "
			+ "of guessing."),
	"tutorial.pause.title": "The pause menu",
	"tutorial.pause.body": ("Escape opens the pause menu: save, load, settings, this guide and "
			+ "quitting to the main menu. Space pauses, and the keys 1 to 3 set the "
			+ "speed (3 needs VIP 5)."),
	"tutorial.saving.title": "Saving",
	"tutorial.saving.body": ("Saving writes a versioned file on this device, and the game "
			+ "autosaves as you play; Load lists what is there. An interrupted write "
			+ "leaves the earlier save exactly as it was."),
	"picker.title": "Choose your nation",
	"picker.regions": "Regions",
	"picker.search": "Search by name, alias or code",
	"picker.no_results": "Nothing matches that search.",
	"picker.jump": "Jump to a letter",
	"picker.selected": "Selected: %s",
	"picker.ineligible": ("You cannot start a campaign as this nation yet. You can still read its "
			+ "dossier."),
	"picker.confirm": "Confirm nation",
	"picker.code_badge": "No flag in the source data — showing the code.",
	"recovery.title": "A saved file cannot be read",
	"recovery.backup": "Use the backup",
	"recovery.backup_hint": ("Load the previous copy the game kept. Changes made after that "
			+ "copy are not kept."),
	"recovery.no_backup": "There is no previous copy to fall back to.",
	"recovery.continue": "Continue with a warning",
	"recovery.continue_hint": ("Leave every file exactly as it is and carry on. Nothing is "
			+ "repaired, reset or deleted."),
	"recovery.cancel": "Cancel",
	"recovery.cancel_hint": "Change nothing and go back.",
	"recovery.done_backup": "The previous copy was used.",
	"recovery.done_continue": "Nothing was changed. The files are exactly as you left them.",
	"recovery.done_cancel": "Cancelled. Nothing was read, written or deleted.",
	"backup.title": "Backup and restore",
	"backup.help": ("A backup is one plain file holding your profile and every world. You "
			+ "choose where it lives; nothing is uploaded and there is no account."),
	"backup.create": "Create a backup now",
	"backup.default_label": "Backup made in the game",
	"backup.created": "Backup written: %s",
	"backup.failed": "The backup could not be written: %s",
	"backup.folder_note": ("Backups are kept in the game's own backup folder, where any file "
			+ "manager can reach them. Choosing another folder on your device is "
			+ "PLANNED: it needs a file dialog this project has not verified on "
			+ "every platform."),
	"backup.empty": "There are no backups in the folder yet.",
	"backup.row": "%s · %s · level %d · %d world(s)",
	"backup.row_damaged": "%s — cannot be read",
	"backup.missing": "That backup file is not there any more.",
	"backup.overwrite_warning": ("One or more worlds in this backup are already on this "
			+ "device. Restoring would replace them."),
	"backup.restored": "Restored: %s.",
	"backup.restored_none": "Nothing was restored.",
	"backup.reasons": "Reasons: %s",
	"backup.restore_kept": ("Kept the worlds already on this device. Nothing from the "
			+ "backup file was written."),
	"worlds.help": ("Every world saved on this device. A world the game cannot read is "
			+ "never deleted or quietly replaced: you are asked what to do."),
	"worlds.row_empty": "%s — empty",
	"worlds.row_ok": "%s — %s, %s",
	"worlds.row_damaged": "%s — this file cannot be read",
	"worlds.empty_slot": "%s is empty.",
	"worlds.engine_says": "The game says: %s",
	"worlds.backup_unreadable": ("The previous copy could not be read either. Nothing was "
			+ "changed."),
	"worlds.open_failed": "That world could not be opened: %s",
	"worlds.back": "Back",
	# --- Deleting a world (Milestone 09, Task 6) ---
	"worlds.delete": "Delete",
	"worlds.delete_title": "Delete %s?",
	"worlds.delete_detail": "%s · %s · played %s",
	"worlds.delete_unreadable": "This world cannot be read, so only its slot can be named.",
	"worlds.delete_keep_copy": ("A recovery copy is made first, so you can undo this until you "
			+ "close the game."),
	"worlds.delete_permanent": ("No recovery copy can be made here, so this deletion will be "
			+ "permanent."),
	"worlds.delete_confirm": "Delete this world",
	"worlds.delete_cancel": "Keep it",
	"worlds.deleted": "Deleted %s. You can undo this until you close the game.",
	"worlds.deleted_permanent": "Deleted %s. This deletion is permanent.",
	"worlds.delete_failed": "The world was not deleted: %s",
	"worlds.undo": "Undo",
	"worlds.undone": "Restored %s.",
	"worlds.undo_failed": "The recovery copy could not be restored.",
	"worlds.playtime_brief": "less than a minute",
	"worlds.playtime_minutes": "%d min",
	"worlds.playtime_hours": "%d h %02d min",
	"worlds.title": "Your worlds",
	# --- Diagnostics (Milestone 09, Task 4) ---
	"diagnostics.title": "Diagnostics",
	"diagnostics.subtitle": "What this build is, and the last warnings it reported.",
	"diagnostics.meta": "Milestone 09",
	"diagnostics.intro": ("This screen describes the build and the device it is running on. "
			+ "Nothing here is sent anywhere, and the exported file contains no personal "
			+ "information."),
	"diagnostics.build": "BUILD",
	"diagnostics.log": "RECENT WARNINGS AND ERRORS",
	"diagnostics.log_caption": ("The last %d of at most %d lines the game itself reported, "
			+ "oldest first. This is not the engine's console output: Godot does not give a "
			+ "script access to it, so engine-level warnings are not captured here. That is a "
			+ "known limitation of this build."),
	"diagnostics.log_empty": "Nothing has gone wrong this session.",
	"diagnostics.export": "Export diagnostics",
	"diagnostics.exported": "Written to %s, inside the game's own diagnostics folder.",
	"diagnostics.export_failed": "The file could not be written: %s",
	"diagnostics.copy": "Copy to clipboard",
	"diagnostics.copied": "The whole report is on the clipboard.",
	"diagnostics.copy_unavailable": ("This platform has no clipboard, so the report cannot be "
			+ "copied here. The text below can still be selected and read."),
	"diagnostics.privacy": ("Contains: version, data version, engine, platform, screen size and "
			+ "scale, frame-rate cap and the log above. Does not contain: your name, username, "
			+ "player ID, avatar, wallet, saves, or any folder path beyond the game's own "
			+ "folder name."),
	"diagnostics.folder_note": ("Choosing any folder on the device needs a file dialog that has "
			+ "not been verified on every platform, so this build writes next to its own files "
			+ "and offers the text for copying. A folder picker is PLANNED."),
	"diagnostics.select_hint": "Select any line and copy it, or use the buttons below.",
	"diagnostics.log_world_unreadable": "A saved world could not be read (%s).",
	"diagnostics.log_settings_failed": "The settings file could not be written (error %d).",
	"diagnostics.log_backup_failed": "A backup file could not be written.",
	"diagnostics.log_world_deleted": "A world was deleted (%s).",
	# --- Help (Milestone 09, Task 5) ---
	"help.title": "Help",
	"help.subtitle": "What this build does, in plain words.",
	"help.meta": "Milestone 09",
	"help.intro": ("WORLD DOMINION is an early foundation, not a finished game. This page says "
			+ "what you can do today and where the edges are, so nothing surprises you later."),
	"help.status_title": "What this is",
	"help.status_body": ("A world atlas you can explore, a country picker, a campaign shell "
			+ "with a running calendar, three save slots and backups. There is no economy, "
			+ "politics, diplomacy, military or artificial intelligence yet; they are PLANNED "
			+ "and the game does not pretend otherwise."),
	"help.can_do_title": "What you can do",
	"help.can_do_body": ("Start a campaign as any of 242 nations, watch the date advance, "
			+ "pause and change speed, look up a country's real data in the dossier, read the "
			+ "tutorial again from the pause menu, and see every world you have saved."),
	"help.saving_title": "Saving, backups and several worlds",
	"help.saving_body": ("The game saves when you ask it to, into three slots plus an autosave. "
			+ "Each save keeps a previous copy; the recovery dialog asks before anything is "
			+ "replaced, and the backup screen copies everything into a single file you can "
			+ "keep elsewhere."),
	"help.account_title": "Why there is no account",
	"help.account_body": ("There is no server, no sign-in and no account, because nothing leaves "
			+ "this device. There is no analytics and no advertising. A profile exists so the "
			+ "game can greet you and keep your settings; it never leaves the device."),
	"help.notifications_title": "The notification choice",
	"help.notifications_body": ("The first-run flow asks whether you would like notifications. "
			+ "It records your answer and nothing else: the game asks the device for no "
			+ "permission and cannot send a notification yet. Real notifications are PLANNED."),
	"help.report_title": "If something goes wrong",
	"help.report_body": ("Open Diagnostics from the Library group. Copy the report, or export it "
			+ "next to the game's files, and include it when you report the problem. The report "
			+ "contains no personal information, which is why it is safe to share."),
	"help.back": "Back",
	# --- Roadmap (Milestone 09, Task 5) ---
	"roadmap.title": "Roadmap",
	"roadmap.subtitle": "What is built, and what is next — in that order.",
	"roadmap.meta": "Milestone 09",
	"roadmap.intro": ("Every item below is PLANNED unless it says otherwise. Nothing on this page "
			+ "is a promise about when; it is a list of what the project intends to build, "
			+ "drawn from the project's own vision document."),
	"roadmap.planned": "PLANNED",
	"roadmap.now_title": "In this build",
	"roadmap.now_body": ("The world atlas and country data, the campaign shell with its "
			+ "calendar, saves, backups, the profile, the tutorial and this library of screens."),
	"roadmap.next_title": "Next",
	"roadmap.multiplayer": "Online multiplayer",
	"roadmap.multiplayer_body": ("Not planned. The project's vision is offline-only; the "
			+ "multiplayer it does plan is hot-seat — several people, one device, taking turns in "
			+ "the same world. There is no network code in this build and no server."),
	"roadmap.notifications": "Real notifications",
	"roadmap.notifications_body": ("A local reminder you choose to receive, never a push "
			+ "notification that pulls you back. The preference is recorded today; no permission "
			+ "is requested and nothing is sent."),
	"roadmap.mods": "Data-only mods",
	"roadmap.mods_body": ("Adding countries, flags or scenario numbers with files, without "
			+ "code. Mods would change data, never execute code."),
	"roadmap.achievements": "Achievements",
	"roadmap.achievements_body": ("Goals the game can recognise and record, kept on this device "
			+ "and never sent anywhere."),
	"roadmap.religion": "Religion and society",
	"roadmap.religion_body": ("An open question, not a plan: whether faith and social pressure "
			+ "are simulated, shown as statistics only, or left out. The project lists it as a "
			+ "decision for the owner because it changes the tone of the whole game."),
	"roadmap.economy": "Economy",
	"roadmap.economy_body": ("Production, trade and money, with resources kept separate from "
			+ "reserves and from production."),
	"roadmap.diplomacy": "Diplomacy",
	"roadmap.diplomacy_body": ("Relations, agreements and disputes between nations, stated in "
			+ "plain language."),
	"roadmap.un": "The United Nations",
	"roadmap.un_body": ("A forum where the world's nations meet, with rules the player can read. "
			+ "No UN mechanics exist in this build."),
	"roadmap.back": "Back",
	# --- What is new (Milestone 11, Task 5) ---------------------------------
	"whats_new.title": "What is new",
	"whats_new.subtitle": "What changed in this build, and what did not.",
	"whats_new.meta": "Version %s",
	"whats_new.intro": ("Every line below names the file that makes it true. The Notes column is "
			+ "the same sentence the test reads, so an entry cannot outlive the work it describes. "
			+ "This is a build in progress, not a release: nothing here is finished, and the "
			+ "section at the bottom says what is missing."),
	"whats_new.m11_title": "Milestone 11 — the foundation pass",
	"whats_new.m11_state": "IN THIS BUILD",
	"whats_new.icons_title": "Real icons, in the player's palette",
	"whats_new.icons_body": ("The marks on the menu, the HUD and the map were drawings in code. They "
			+ "are now icons from game-icons.net, pinned to one commit, credited in "
			+ "THIRD_PARTY_LICENSES.md and checked against their source file by a test. Where a "
			+ "file is missing the drawing comes back, so a broken asset is still legible."),
	"whats_new.inventory_title": "A list of every feature, and a map of every screen",
	"whats_new.inventory_body": ("docs/FEATURE_INVENTORY.md states what each feature does and "
			+ "whether it is complete, partial or a placeholder, with the file that proves it. "
			+ "docs/SCREEN_MAP.md does the same for screens and the routes between them, so the "
			+ "project cannot quietly claim a screen it does not have."),
	"whats_new.countries_title": "Each country keeps its own state",
	"whats_new.countries_body": ("Every one of the 242 countries now has a record of its own — "
			+ "statistics for now — stored by reference and saved as schema 5. Saves from schema "
			+ "1 still load: they are migrated forward one step at a time, and the baseline is "
			+ "rebuilt from the data pack rather than trusted from the file."),
	"whats_new.data_title": "Where the next data will come from, written down",
	"whats_new.data_body": ("Offline play only works if the data ships with the game, so the "
			+ "candidates were read at their source: licence, commit, country identifier and the "
			+ "gaps each one has. tools/check_data_candidates.py fails when a pinned commit or "
			+ "licence sentence changes. No new data was imported in this milestone."),
	"whats_new.missing_title": "Not in this build",
	"whats_new.missing_body": ("No economy, no politics, no country AI and no diplomacy: the clock "
			+ "runs and the map is real, and that is all. Election results, installed electricity "
			+ "capacity and a live head-of-state source are still missing from the data plan, and "
			+ "the reconnaissance page says so."),
	"whats_new.back": "Back",
	# --- Game screen shell (Milestone 10) -----------------------------------
	"field.not_available": "Not available",
	"hud.gold": "Gold Coins",
	"hud.gems": "Red Gems",
	"hud.level": "Level %d",
	"hud.xp": "%d / %d XP",
	"hud.xp_short": "%d XP",
	"hud.population": "Population",
	"hud.area": "Area",
	"hud.currency": "Currency",
	"hud.flag_tooltip": "Your flag. Opens the country overview.",
	"hud.avatar_tooltip": "Your profile, level and progress.",
	"hud.messages": "Messages",
	"hud.messages.unread": "%d unread",
	"hud.messages.none": "No unread messages",
	"hud.news": "News",
	"hud.news.empty": "No news yet",
	"hud.news.latest": "Latest: %s",
	"hud.menu": "Menu",
	"hud.menu_tooltip": "Pause menu, save, settings and help. Escape does the same.",
	"hud.tutorial": "Tutorial",
	"hud.tutorial_tooltip": "Show the guided tour again.",
	"hud.pause": "Pause",
	"hud.resume": "Resume",
	"hud.pause_tooltip": "Pause or resume the clock. Space does the same.",
	"hud.map": "Map",
	"hud.map_tooltip": "Map display: labels, borders, grid lines and capital markers.",
	"hud.speed": "Speed",
	"hud.speed_tooltip": "How fast the calendar runs.",
	"hud.simulation": "Simulation",
	"hud.paused": "Paused",
	"hud.running": "Running",
	"hud.autosaved": "Autosaved",
	"hud.date": "In-game date",
	"hud.category.country": "Country",
	"hud.category.economy": "Economy",
	"hud.category.government": "Government",
	"hud.category.diplomacy": "Diplomacy",
	"hud.category.military": "Military",
	"hud.category.research": "Research",
	"hud.category.world": "World",
	"hud.category.campaign": "Campaign",
	"hud.category.system": "System",
	"hud.category_hint": "%s — planned for a later version.",
	"hud.profile_title": "Profile",
	"hud.profile_name": "Name",
	"hud.profile_level": "Level",
	"hud.profile_xp": "Experience",
	"hud.profile_playtime": "Playtime",
	"planned_badge": "PLANNED — nothing here is simulated yet",
	"category.later_body": ("This part of the game is planned for a later version. There is "
			+ "no simulation behind this button in this build, so there is nothing to show "
			+ "you: no numbers, no controls that pretend to work, and no placeholder "
			+ "figures standing in for data that does not exist."),
	# --- Reusable panel and list (Milestone 10) ------------------------------
	"panel.close": "Close",
	"panel.close_tooltip": "Close this panel. Escape does the same.",
	"panel.tabs": "Sections",
	"list.search": "Search",
	"list.search_placeholder": "Type to search",
	"list.filter": "Filter",
	"list.filter_all": "All",
	"list.empty": "Nothing here yet.",
	"list.no_results": "Nothing matches \"%s\".",
	"list.count": "%d of %d shown",
	# --- Messages and news (Milestone 10) -----------------------------------
	"messages.title": "Messages",
	"messages.intro": ("Everything in this list happened in your campaign. Each entry names "
			+ "the system that recorded it."),
	"messages.empty": ("No messages yet. Entries appear here when something actually "
			+ "happens in your campaign — a save, a new month, a change you made."),
	"messages.mark_all": "Mark all read",
	"messages.mark_all_done": "Everything is read.",
	"messages.unread_only": "Unread only",
	"messages.all": "Everything",
	"messages.why": "Why am I seeing this?",
	"messages.unread": "Unread",
	"messages.read": "Read",
	"news.title": "News",
	"news.masthead": "WORLD DOMINION — CAMPAIGN NEWS",
	"news.subtitle": ("Printed from your campaign's own record. Nothing here was written "
			+ "ahead of time and nothing is predicted."),
	"news.empty": ("This edition has nothing to print yet: the newspaper reports events "
			+ "from your campaign, and none have happened."),
	"news.entry_origin": "Recorded by %s.",
	# --- Country overview (Milestone 10) ------------------------------------
	"overview.title": "Country",
	"overview.tab_overview": "Overview",
	"overview.tab_details": "Details",
	"overview.tab_history": "History",
	"overview.compare": "Compare with…",
	"overview.completeness": "%d of %d figures available",
	"overview.completeness_none": "No figures available for this country.",
	"overview.disputed": ("Where a border or a name is disputed, this game repeats its "
			+ "source's neutral wording and takes no side."),
	"overview.history_empty": "No events concern this country yet.",
	"overview.flag_missing": "No flag in the source data; the country code is shown instead.",
	"overview.source": "Sourced data, not simulated.",
	# --- Event log (Milestone 10) -------------------------------------------
	"about.icons.title": "Interface icons",
	"about.icons.licence": ("Icons made by the authors below. Available on "
			+ "https://game-icons.net. Licensed under Creative Commons Attribution 3.0, or CC0 "
			+ "where the source's licence file says so (marked here). Files are unmodified except "
			+ "for the removed background, which lets each mark take the theme's colour."),
	"about.icons.author": "Icons made by %s (%s).%s",
	"about.icons.cc0": " CC0.",
	"about.icons.source": ("Source: game-icons.net, from github.com/game-icons/icons at commit "
			+ "%s. The full licence text is in THIRD_PARTY_LICENSES.md."),
	"events.unknown": "This entry cannot be read in this version (it refers to \"%{key}\").",
	"events.campaign.started": "%{country} — the campaign begins.",
	"events.campaign.loaded": "%{country} — campaign resumed.",
	"events.save.autosave": "Autosaved to slot %{slot}.",
	"events.save.manual": "Saved to slot %{slot}.",
	"events.save.failed": "A save could not be written: %{reason}",
	"events.origin.campaign.start": "Raised once, when the campaign was created.",
	"events.origin.campaign.load": "Raised when the campaign was loaded from a save.",
	"events.origin.world.baseline": ("Raised once, when the baseline data a saved campaign "
			+ "recorded no longer matches the data this build ships."),
	"events.origin.save.autosave": "Raised by the autosave at a month boundary.",
	"events.world.baseline_changed": ("The reference data this campaign started from has "
			+ "changed since it was saved (%{recorded} → %{current}). The figures shown now come "
			+ "from the data this build ships."),
	"events.origin.save.manual": "Raised when you saved the campaign yourself.",
}


## The string for `key`, with `args` substituted in order when the entry has placeholders.
## A missing key returns the key itself, in angle quotes, so a screen can never render an
## empty label and a test can spot the mistake instead of hiding it.
static func t(key: String, args: Array = []) -> String:
	if not TABLE.has(key):
		push_warning("Strings: missing key '%s'" % key)
		return "<%s>" % key
	var text := str(TABLE[key])
	if args.is_empty():
		return text
	return text % args


## The string for `key` with named `%{name}` placeholders filled from `params`. Used by the
## event log, where parameters are stored by name so a sentence can be reworded later without
## invalidating saved games. A placeholder with no parameter is left visible rather than
## silently blanked, so a missing value is a bug somebody notices.
static func tn(key: String, params: Dictionary) -> String:
	var text := t(key)
	for name: Variant in params.keys():
		text = text.replace("%%{%s}" % str(name), str(params[name]))
	return text


static func has(key: String) -> bool:
	return TABLE.has(key)


static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in TABLE.keys():
		out.append(str(key))
	out.sort()
	return out
