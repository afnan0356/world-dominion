class_name PlayerProfile
extends RefCounted
## The player: one profile, global to the installation, separate from any world save.
##
## WHY SEPARATE FROM WORLD SAVES: progress belongs to the person, not to a campaign. A
## player starts a new world and keeps their level, their name and their wallet. That is
## also why this file holds no country, no map and nothing that a world save owns.
##
## WHAT THIS IS NOT: there are no accounts, no servers and no identity checks. The player
## ID is a number this installation made up for itself, generated once and never sent
## anywhere. Nothing here can prove who anyone is, and nothing here pretends to.
##
## VALIDATION RULE (the same one the save system follows): a saved value is restored only
## when it is *exactly* valid. A field that is malformed is replaced with the documented
## default and the repair is reported, never silently rounded into something plausible.
## The one exception is a value that could give the player something they did not earn —
## XP, levels, wallet balances — which is clamped rather than "repaired upwards".
##
## NOT IMPLEMENTED HERE, ON PURPOSE: offensive-word filtering. The name validator rejects
## structural abuse (empty, too long, control characters, mixed-script look-alikes) and
## claims nothing more. There is no profanity list, and neither the game nor this file
## says there is one.

const SCHEMA_VERSION := 1
const MIN_SCHEMA_VERSION := 1

## Name and username limits, in characters, as shown to the player in the error messages.
const NAME_MIN := 1
const NAME_MAX := 24
const USERNAME_MIN := 3
const USERNAME_MAX := 20

## The first change of display name is free; every later change costs this many Diamonds.
## Diamonds come from the tutorial and from future rewards only: there is no purchase path
## anywhere in this project, and no grinding loop that pays out.
const NAME_CHANGE_COST := 100

## Twenty avatars, drawn by code (see src/ui/profile/avatar_art.gd). Stored as an index,
## never as a path or a URL: a profile file cannot point the game at an image.
const AVATAR_COUNT := 20

## Player IDs are long and numeric, generated locally. 18 digits fits in int64 and in a
## double without losing precision, so the ID survives any JSON round trip.
const PLAYER_ID_DIGITS := 18

## Characters that look like Latin letters in other scripts, used only to detect a name
## that is *entirely* made of look-alikes or that mixes scripts. This is a structural
## check, not a content filter: it never inspects meaning.
const LOOKALIKES := "аеорсухіѕјԁԛԝАВЕКМНОРСТУХІЈ"

var schema_version := SCHEMA_VERSION
var player_id := ""
var display_name := "Player"
var display_name_changes := 0
var username := ""
var username_locked := false
var xp := 0
var avatar_id := 0
var created_at := ""
var wallet: GameWallet = GameWallet.new()
var tutorial_completed := false
var tutorial_skipped := false
var tutorial_reward_claimed := false
var terms_version := 0
var terms_accepted_at := ""
var notifications_consent := false

## Problems found while loading, in plain language, for the screen that shows them.
var problems: PackedStringArray = PackedStringArray()

## True when `from_dict` had to repair anything.
var repaired := false


# --- Creation -----------------------------------------------------------------

## A brand-new profile, with a player ID generated once from the offline RNG.
static func create(seed_value: int, today: String) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.player_id = generate_player_id(seed_value)
	profile.created_at = today
	return profile


## A long numeric ID. Built from a seeded generator so the same seed gives the same ID —
## which is what makes it testable — and from the clock plus entropy in play, so two
## installations do not collide. It is not a secret and not an identity: it is a local
## label, and it is never transmitted anywhere.
static func generate_player_id(seed_value: int) -> String:
	var rng := DeterministicRng.from_seed(seed_value)
	var digits := ""
	# The first digit is never 0, so the ID has a stable width.
	digits += str(rng.next_int(1, 9))
	while digits.length() < PLAYER_ID_DIGITS:
		digits += str(rng.next_int(0, 9))
	return digits


# --- Display name -------------------------------------------------------------

## Why a name was rejected, in words the player can act on. Empty string means accepted.
static func name_problem(candidate: String) -> String:
	var trimmed := candidate.strip_edges()
	if trimmed.is_empty():
		return "A display name cannot be empty."
	if trimmed.length() < NAME_MIN or trimmed.length() > NAME_MAX:
		return "A display name must be between %d and %d characters." % [NAME_MIN, NAME_MAX]
	for index in trimmed.length():
		var code := trimmed.unicode_at(index)
		if code < 0x20 or code == 0x7F:
			return "A display name cannot contain control characters."
		if code == 0x202E or code == 0x202D or code == 0x200F or code == 0x200E:
			return "A display name cannot contain direction overrides."
	if trimmed != candidate:
		return "A display name cannot start or end with a space."
	if contains_mixed_scripts(trimmed):
		return "A display name cannot mix alphabets that look alike."
	return ""


## True when a string mixes Latin letters with look-alike letters from another script, or
## is built entirely from look-alikes. Deliberately conservative: it stops the cheapest
## impersonation trick (a Cyrillic "а" in a Latin name) and nothing else.
static func contains_mixed_scripts(text: String) -> bool:
	var latin := false
	var lookalike := false
	for index in text.length():
		var glyph := text.substr(index, 1)
		if glyph.is_empty():
			continue
		var code := glyph.unicode_at(0)
		var is_ascii_latin: bool = (code >= 0x41 and code <= 0x5A) \
				or (code >= 0x61 and code <= 0x7A)
		if LOOKALIKES.contains(glyph):
			lookalike = true
		elif is_ascii_latin:
			latin = true
	return lookalike and latin


## Change the display name, paying the documented cost when it is not the first change.
## Returns {ok, reason, cost, charged}; a rejection leaves the profile untouched.
func set_display_name(candidate: String, allow_charge := true) -> Dictionary:
	var problem := name_problem(candidate)
	if not problem.is_empty():
		return {"ok": false, "reason": problem, "cost": 0, "charged": 0}
	var cost := 0 if display_name_changes == 0 else NAME_CHANGE_COST
	if cost > 0 and not allow_charge:
		return {"ok": false, "reason": "This change costs %d Diamonds." % cost,
				"cost": cost, "charged": 0}
	if cost > 0 and not can_afford_name_change():
		return {"ok": false,
				"reason": "You need %d Diamonds to change your name again." % cost,
				"cost": cost, "charged": 0}
	if cost > 0:
		wallet.spend(GameWallet.Currency.DIAMONDS, cost)
	display_name = candidate.strip_edges()
	display_name_changes += 1
	return {"ok": true, "reason": "", "cost": cost, "charged": cost}


func can_afford_name_change() -> bool:
	return display_name_changes == 0 \
			or wallet.can_afford(GameWallet.Currency.DIAMONDS, NAME_CHANGE_COST)


## What the next name change will cost, for the confirmation text.
func next_name_change_cost() -> int:
	return 0 if display_name_changes == 0 else NAME_CHANGE_COST


# --- Username -----------------------------------------------------------------

## Why a username was rejected. Lower-case letters, digits and underscore only: it is a
## handle, not a second display name.
static func username_problem(candidate: String) -> String:
	if candidate.length() < USERNAME_MIN or candidate.length() > USERNAME_MAX:
		return "A username must be between %d and %d characters." \
				% [USERNAME_MIN, USERNAME_MAX]
	for index in candidate.length():
		var glyph := candidate.substr(index, 1)
		var code := glyph.unicode_at(0)
		var is_lower: bool = code >= 0x61 and code <= 0x7A
		var is_digit: bool = code >= 0x30 and code <= 0x39
		if not (is_lower or is_digit or glyph == "_"):
			return "A username can use lower-case letters, digits and underscores only."
	return ""


## Set the username once. After that it is locked for the life of the profile: the
## project has no rename flow and no paid rename, so the lock is absolute.
func set_username(candidate: String) -> Dictionary:
	if username_locked:
		return {"ok": false, "reason": "A username can only be set once."}
	var problem := username_problem(candidate)
	if not problem.is_empty():
		return {"ok": false, "reason": problem}
	username = candidate
	username_locked = true
	return {"ok": true, "reason": ""}


# --- XP, level and VIP --------------------------------------------------------

func add_xp(amount: int) -> int:
	if amount <= 0:
		return xp
	xp = clampi(xp + amount, 0, Progression.xp_to_reach(Progression.MAX_LEVEL) - 1)
	return xp


func level() -> int:
	return Progression.level_for_xp(xp)


func vip() -> int:
	return Progression.vip_for_level(level())


func xp_into_level() -> int:
	return xp - Progression.xp_to_reach(level() - 1)


func xp_for_next_level() -> int:
	if level() >= Progression.MAX_LEVEL:
		return 0
	return Progression.xp_to_reach(level()) - Progression.xp_to_reach(level() - 1)


# --- Tutorial -----------------------------------------------------------------

## Completing the tutorial pays out once per profile, ever: the flag is what makes the
## reward one-time, not the screen that awards it.
func complete_tutorial() -> Dictionary:
	var awarded := {"xp": 0, "gold_coins": 0, "diamonds": 0}
	tutorial_completed = true
	if tutorial_reward_claimed:
		return awarded
	tutorial_reward_claimed = true
	awarded["xp"] = Progression.TUTORIAL_XP
	awarded["gold_coins"] = Progression.TUTORIAL_GOLD
	awarded["diamonds"] = Progression.TUTORIAL_DIAMONDS
	add_xp(awarded["xp"])
	wallet.add(GameWallet.Currency.GOLD_COINS, awarded["gold_coins"])
	wallet.add(GameWallet.Currency.DIAMONDS, awarded["diamonds"])
	return awarded


## Skipping teaches nothing and pays nothing. It does not lock the tutorial away: the
## player can open it again from the profile screen.
func skip_tutorial() -> void:
	tutorial_skipped = true


func tutorial_done() -> bool:
	return tutorial_completed


# --- Terms and notifications ----------------------------------------------------

func accept_terms(version: int, when: String) -> void:
	terms_version = version
	terms_accepted_at = when


func has_accepted_terms(version: int) -> bool:
	return terms_version >= version and not terms_accepted_at.is_empty()


# --- Serialisation -------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"player_id": player_id,
		"display_name": display_name,
		"display_name_changes": display_name_changes,
		"username": username,
		"username_locked": username_locked,
		"xp": xp,
		"avatar_id": avatar_id,
		"created_at": created_at,
		"wallet": wallet.to_dict(),
		"tutorial": {
			"completed": tutorial_completed,
			"skipped": tutorial_skipped,
			"reward_claimed": tutorial_reward_claimed,
		},
		"terms": {"version": terms_version, "accepted_at": terms_accepted_at},
		"notifications_consent": notifications_consent,
	}


## Rebuild a profile from saved data, repairing anything invalid and recording why.
static func from_dict(source: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	if source.is_empty():
		profile.problems.append("The profile file was empty; a new profile was made.")
		profile.repaired = true
		return profile

	var version := _int(source.get("schema_version"), -1)
	if version < MIN_SCHEMA_VERSION or version > SCHEMA_VERSION:
		profile.problems.append(
				"The profile file has an unsupported version (%d); it was read with "
				% version + "the current rules and nothing was deleted.")
		profile.repaired = true

	profile.player_id = _player_id(source.get("player_id"))
	if profile.player_id.is_empty():
		profile.player_id = generate_player_id(
				int(Time.get_unix_time_from_system()) + _stable_offset(source))
		profile.problems.append("The player ID was missing; a new one was generated.")
		profile.repaired = true

	var name_text := _text(source.get("display_name"))
	if name_text.is_empty() or not name_problem(name_text).is_empty():
		profile.problems.append("The display name was invalid; it was reset to \"Player\".")
		profile.repaired = true
		profile.display_name = "Player"
	else:
		profile.display_name = name_text.strip_edges()

	profile.display_name_changes = clampi(_int(source.get("display_name_changes"), 0), 0, 1_000_000)

	var saved_username := _text(source.get("username"))
	if saved_username.is_empty() or not username_problem(saved_username).is_empty():
		profile.username = ""
		profile.username_locked = false
		if not saved_username.is_empty():
			profile.problems.append("The username was invalid; it was cleared.")
			profile.repaired = true
	else:
		profile.username = saved_username
		profile.username_locked = true

	var saved_xp := _int(source.get("xp"), 0)
	var cap := Progression.xp_to_reach(Progression.MAX_LEVEL) - 1
	if saved_xp < 0 or saved_xp > cap:
		profile.problems.append("The saved XP was out of range and was clamped.")
		profile.repaired = true
	profile.xp = clampi(saved_xp, 0, cap)

	var saved_avatar := _int(source.get("avatar_id"), 0)
	if saved_avatar < 0 or saved_avatar >= AVATAR_COUNT:
		profile.problems.append("The saved avatar was out of range; avatar 1 is used.")
		profile.repaired = true
		saved_avatar = 0
	profile.avatar_id = saved_avatar

	profile.created_at = _text(source.get("created_at"))

	var wallet_data: Variant = source.get("wallet")
	if wallet_data is Dictionary:
		profile.wallet = GameWallet.from_dict(wallet_data)
		if profile.wallet.had_invalid_values:
			profile.problems.append("The saved wallet had values that could not be kept.")
			profile.repaired = true
	else:
		profile.wallet = GameWallet.new()
		if source.has("wallet"):
			profile.problems.append("The saved wallet was unreadable and was reset to zero.")
			profile.repaired = true

	var tutorial: Variant = source.get("tutorial")
	if tutorial is Dictionary:
		profile.tutorial_completed = bool(tutorial.get("completed", false))
		profile.tutorial_skipped = bool(tutorial.get("skipped", false))
		# The reward flag can never be lost by editing: XP already granted stays, and a
		# cleared flag would only allow a second payout. It follows the completion flag.
		profile.tutorial_reward_claimed = bool(tutorial.get("reward_claimed", false)) \
				or profile.tutorial_completed

	var terms: Variant = source.get("terms")
	if terms is Dictionary:
		profile.terms_version = clampi(_int(terms.get("version"), 0), 0, 1_000_000)
		profile.terms_accepted_at = _text(terms.get("accepted_at"))
		if profile.terms_version > 0 and profile.terms_accepted_at.is_empty():
			profile.problems.append("The terms acceptance had no date and was cleared.")
			profile.repaired = true
			profile.terms_version = 0

	profile.notifications_consent = bool(source.get("notifications_consent", false))
	return profile


static func _text(value: Variant) -> String:
	if value == null:
		return ""
	if value is String:
		return value
	return ""


static func _int(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_equal_approx(value, round(value)):
		return int(round(value))
	return fallback


static func _player_id(value: Variant) -> String:
	var text := _text(value)
	if text.length() != PLAYER_ID_DIGITS:
		return ""
	for index in text.length():
		var code := text.unicode_at(index)
		if code < 0x30 or code > 0x39:
			return ""
	if text.begins_with("0"):
		return ""
	return text


## A deterministic offset from the file's own contents, so repairing a file twice in the
## same second does not produce the same replacement ID as another installation.
static func _stable_offset(source: Dictionary) -> int:
	return abs(source.size() * 7919 + source.keys().hash() % 10_000)
