class_name GameWallet
extends RefCounted
## The player's wallet for the game's two permanent currencies.
##
## DESIGN RULE (see GAME_DESIGN.md § Currencies): Gold Coins and Diamonds are
## *game-wallet* currencies. They are not national currencies and are never
## touched by national economic simulation — inflation, exchange-rate
## depreciation, recessions, debt crises and bankruptcies all operate on country
## economies only.
##
## Implementation rules that follow from that:
##   * balances are 64-bit integers (no floats, no rounding drift);
##   * every mutation is range-checked and cannot go negative;
##   * saved values are only restored when they are *exactly* integers — a
##     fractional or malformed saved balance is discarded, never rounded into a
##     different, valid-looking number;
##   * there is no reference to any national economy type anywhere in this file.
##
## This milestone ships the primitive and its invariants only. Earning, spending,
## sinks and sources arrive with the gameplay milestones; there is no purchase,
## premium currency or monetisation path in the project.

enum Currency { GOLD_COINS, DIAMONDS }

## Upper bound per currency. Chosen below 2^53 (9,007,199,254,740,992) so that a
## balance stays exact even if it is ever routed through a float, and far below
## int64's limit so additions can never overflow. Roughly nine quadrillion units:
## unreachable in play.
const MAX_BALANCE := 9_000_000_000_000_000

## Currency → save-file key. Kept next to the balances so a save-format change is
## a one-line edit rather than a hunt for string literals.
const _SAVE_KEYS := {
	Currency.GOLD_COINS: "gold_coins",
	Currency.DIAMONDS: "diamonds",
}

## True when `from_dict()` had to discard or clamp a saved value. The save layer
## can use this to tell the player their file was repaired instead of letting a
## corrupt balance disappear silently.
var had_invalid_values := false

var _balances := {
	Currency.GOLD_COINS: 0,
	Currency.DIAMONDS: 0,
}


func balance(currency: Currency) -> int:
	return int(_balances.get(currency, 0))


func gold_coins() -> int:
	return balance(Currency.GOLD_COINS)


func diamonds() -> int:
	return balance(Currency.DIAMONDS)


## Adds `amount` and returns how much was actually credited (the request is
## clamped at MAX_BALANCE). Negative amounts and unknown currencies are rejected.
func add(currency: Currency, amount: int) -> int:
	if not _balances.has(currency):
		push_error("GameWallet: unknown currency %d." % currency)
		return 0
	if amount < 0:
		push_error("GameWallet: refusing negative amount %d." % amount)
		return 0
	var current := balance(currency)
	var headroom := MAX_BALANCE - current
	var credited: int = min(amount, headroom)
	_balances[currency] = current + credited
	return credited


## Removes `amount` if the balance allows it. All-or-nothing: a partial spend is
## never applied. Returns true when the full amount was spent.
func spend(currency: Currency, amount: int) -> bool:
	if not _balances.has(currency):
		push_error("GameWallet: unknown currency %d." % currency)
		return false
	if amount < 0:
		push_error("GameWallet: refusing negative amount %d." % amount)
		return false
	if balance(currency) < amount:
		return false
	_balances[currency] = balance(currency) - amount
	return true


func can_afford(currency: Currency, amount: int) -> bool:
	if not _balances.has(currency):
		return false
	return amount >= 0 and balance(currency) >= amount


## Plain-data form for future save files. Uses integers, never floats.
func to_dict() -> Dictionary:
	return {
		_SAVE_KEYS[Currency.GOLD_COINS]: gold_coins(),
		_SAVE_KEYS[Currency.DIAMONDS]: diamonds(),
	}


## Rebuilds a wallet from saved data.
##
## A saved value becomes a balance only when it is exactly a non-negative
## integer within range. Everything else is discarded instead of being coerced:
## `12.6` does not become `12` and does not become `13`, a negative balance does
## not become a credit, and a string does not become a number. Integral floats
## *are* accepted, because a JSON round trip turns every number into a float and
## rejecting those would break honest saves.
##
## A missing key means "not saved yet" and leaves that currency at zero without
## flagging the save as damaged; see `had_invalid_values`.
static func from_dict(data: Dictionary) -> GameWallet:
	var wallet := GameWallet.new()
	for currency: Currency in _SAVE_KEYS:
		var key: String = _SAVE_KEYS[currency]
		if not data.has(key):
			continue
		wallet._restore_currency(currency, data[key])
	return wallet


## The exact integer a saved value represents, or null when it represents none.
## Floats are only accepted when they carry no fraction. Values outside the legal
## range are reported as just past the bound (MAX_BALANCE + 1 / -MAX_BALANCE - 1)
## so the caller can clamp them and record the repair, and `null` means the value
## is not an exact integer at all.
static func _exact_integer(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var number := float(value)
			if not is_finite(number) or number != floorf(number):
				return null
			if number > float(MAX_BALANCE):
				return MAX_BALANCE + 1
			if number < -float(MAX_BALANCE):
				return -MAX_BALANCE - 1
			return int(number)
		_:
			return null


func _restore_currency(currency: Currency, saved: Variant) -> void:
	var exact: Variant = _exact_integer(saved)
	if exact == null:
		had_invalid_values = true
		return
	var amount: int = exact
	var clamped := clampi(amount, 0, MAX_BALANCE)
	if clamped != amount:
		had_invalid_values = true
	_balances[currency] = clamped
