class_name IntegritySignature
extends RefCounted
## The integrity signature promised in docs/SECURITY.md, and nothing more than that.
##
## WHAT IT IS: a digest of the file's own contents, keyed with a constant that ships inside
## the game. It catches a file that was damaged in transit, mangled by a bad copy, edited by
## mistake, or casually hand-edited to change a wallet balance. It makes that kind of
## editing *visible*.
##
## WHAT IT IS NOT: anti-cheat. The key is in the binary; anyone willing to read the source
## (which is published) can recompute a valid signature. No check that runs on the player's
## own device can do better than this, and every game that claims otherwise is selling a
## feeling. See docs/SECURITY.md § 3.
##
## THE RULE THAT MATTERS: a failed signature never destroys progress on its own. It is
## reported, and the interface offers the player a choice — use the backup, continue with a
## warning, or cancel. The store layer never silently resets XP, a wallet or a world.
##
## WHY A CONSTANT KEY AND NOT THE PLAYER'S: there is no account, no server and no secret to
## derive a key from. Pretending otherwise would be security theatre.

## Version tag, so a future scheme can tell its signatures from this one's.
const VERSION := "wd1"
const KEY := "world-dominion/integrity/2026-11"
const SIGNATURE_KEY := "signature"

## Status values returned by `verify`: what happened, in words the interface can act on.
const STATUS_OK := "ok"
const STATUS_MISSING := "missing"
const STATUS_FAILED := "failed"


## The signature of a body dictionary. Numbers are normalised first, so a value that has
## been through JSON (where every number is a float) signs the same as it did before.
static func signature_of(body: Dictionary) -> String:
	var digest: String = CanonicalJson.sha256(CanonicalJson.normalise_numbers(body))
	if digest.is_empty():
		return ""
	return "%s:%s" % [VERSION, CanonicalJson.sha256({"key": KEY, "digest": digest})]


## Compare a stored signature with the body it claims to cover.
static func verify(body: Dictionary, stored: String) -> String:
	if stored.is_empty():
		return STATUS_MISSING
	var expected: String = signature_of(body)
	if not expected.is_empty() and expected == stored:
		return STATUS_OK
	# A file written before Milestone 07 was signed over the older number form. It is
	# intact, not tampered with, and saying otherwise would accuse an honest player.
	var legacy := signature_of_legacy(body)
	if not legacy.is_empty() and legacy == stored:
		return STATUS_OK
	return STATUS_FAILED


## The signature a pre-Milestone-07 build would have stored for this body.
static func signature_of_legacy(body: Dictionary) -> String:
	var digest: String = CanonicalJson.sha256_legacy(body)
	if digest.is_empty():
		return ""
	return "%s:%s" % [VERSION, CanonicalJson.sha256({"key": KEY, "digest": digest})]


## One plain-language sentence for the interface, given a status.
static func describe(status: String) -> String:
	match status:
		STATUS_OK:
			return "This file has not been changed since the game wrote it."
		STATUS_MISSING:
			return "This file was written before the game started signing its files. " \
					+ "It was read as written; nothing was reset."
		STATUS_FAILED:
			return "This file has been changed since the game wrote it."
		_:
			return "The integrity of this file could not be checked."
