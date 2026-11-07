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
	"backup.title": "Backup and restore",
	"worlds.title": "Your worlds",
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
