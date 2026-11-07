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
	"roadmap.multiplayer_body": ("Playing one world with other people. There is no network code "
			+ "of any kind in this build, and no server."),
	"roadmap.notifications": "Real notifications",
	"roadmap.notifications_body": ("A reminder when something needs you. The preference is "
			+ "recorded today; no permission is requested and nothing is sent."),
	"roadmap.mods": "Data-only mods",
	"roadmap.mods_body": ("Adding countries, flags or scenario numbers with files, without code."),
	"roadmap.achievements": "Achievements",
	"roadmap.achievements_body": "Goals the game can recognise and record, kept on this device.",
	"roadmap.religion": "Religion and society",
	"roadmap.religion_body": ("Faith, language and social pressure as things that change over "
			+ "time and matter to a nation."),
	"roadmap.economy": "Economy",
	"roadmap.economy_body": ("Production, trade and money, with resources kept separate from "
			+ "reserves and production."),
	"roadmap.diplomacy": "Diplomacy",
	"roadmap.diplomacy_body": ("Relations, agreements and disputes between nations, stated in "
			+ "plain language."),
	"roadmap.un": "The United Nations",
	"roadmap.un_body": ("A forum where the world's nations meet, with rules the player can read."),
	"roadmap.back": "Back",
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


static func has(key: String) -> bool:
	return TABLE.has(key)


static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in TABLE.keys():
		out.append(str(key))
	out.sort()
	return out
