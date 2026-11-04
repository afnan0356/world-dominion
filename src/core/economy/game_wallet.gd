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
## clamped at MAX_BALANCE). Negative amounts are rejected.
func add(currency: Currency, amount: int) -> int:
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
	if amount < 0:
		push_error("GameWallet: refusing negative amount %d." % amount)
		return false
	if balance(currency) < amount:
		return false
	_balances[currency] = balance(currency) - amount
	return true


func can_afford(currency: Currency, amount: int) -> bool:
	return amount >= 0 and balance(currency) >= amount


## Plain-data form for future save files. Uses integers, never floats.
func to_dict() -> Dictionary:
	return {
		"gold_coins": gold_coins(),
		"diamonds": diamonds(),
	}


## Rebuilds a wallet from saved data, clamping anything out of range. Unknown or
## malformed values fall back to zero rather than failing.
static func from_dict(data: Dictionary) -> GameWallet:
	var wallet := GameWallet.new()
	wallet._balances[Currency.GOLD_COINS] = _sanitize(data.get("gold_coins"))
	wallet._balances[Currency.DIAMONDS] = _sanitize(data.get("diamonds"))
	return wallet


static func _sanitize(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(int(value), 0, MAX_BALANCE)
	if typeof(value) == TYPE_FLOAT:
		return clampi(roundi(float(value)), 0, MAX_BALANCE)
	return 0
