extends TestCase
## Guards the permanent currency rule: wallet balances are integers, cannot go
## negative, cannot overflow, and are independent of any national economy.

func test_new_wallet_is_empty() -> void:
	var wallet := GameWallet.new()
	check_eq(wallet.gold_coins(), 0, "a new wallet has no Gold Coins")
	check_eq(wallet.diamonds(), 0, "a new wallet has no Diamonds")


func test_add_and_spend_gold() -> void:
	var wallet := GameWallet.new()
	check_eq(wallet.add(GameWallet.Currency.GOLD_COINS, 1200), 1200, "adding must credit the amount")
	check_eq(wallet.gold_coins(), 1200, "balance must reflect the credit")
	check_true(wallet.spend(GameWallet.Currency.GOLD_COINS, 200), "affordable spend must succeed")
	check_eq(wallet.gold_coins(), 1000, "balance must reflect the debit")


func test_spending_is_all_or_nothing() -> void:
	var wallet := GameWallet.new()
	wallet.add(GameWallet.Currency.DIAMONDS, 30)
	check_true(wallet.can_afford(GameWallet.Currency.DIAMONDS, 30),
			"affordable amounts are reported")
	check_false(wallet.can_afford(GameWallet.Currency.DIAMONDS, 31),
			"unaffordable amounts are reported")
	check_false(wallet.spend(GameWallet.Currency.DIAMONDS, 31), "an unaffordable spend must fail")
	check_eq(wallet.diamonds(), 30, "a failed spend must not change the balance")


func test_negative_amounts_are_rejected() -> void:
	var wallet := GameWallet.new()
	wallet.add(GameWallet.Currency.GOLD_COINS, 10)
	check_eq(wallet.add(GameWallet.Currency.GOLD_COINS, -5), 0, "negative credit must be ignored")
	check_false(wallet.spend(GameWallet.Currency.GOLD_COINS, -5), "negative debit must be rejected")
	check_eq(wallet.gold_coins(), 10, "rejected amounts must not change the balance")


func test_balances_use_integer_arithmetic_without_drift() -> void:
	var wallet := GameWallet.new()
	var large := GameWallet.MAX_BALANCE - 10
	wallet.add(GameWallet.Currency.GOLD_COINS, large)
	check_eq(typeof(wallet.gold_coins()), TYPE_INT, "balances must be integers, never floats")
	check_eq(wallet.gold_coins(), large, "large integer balances must stay exact")
	for _i in 10:
		wallet.add(GameWallet.Currency.GOLD_COINS, 1)
	check_eq(wallet.gold_coins(), GameWallet.MAX_BALANCE,
			"repeated single-unit credits must stay exact up to the maximum")


func test_balance_is_clamped_at_the_maximum() -> void:
	var wallet := GameWallet.new()
	var credited := wallet.add(GameWallet.Currency.GOLD_COINS, GameWallet.MAX_BALANCE + 500)
	check_eq(credited, GameWallet.MAX_BALANCE, "credit must stop at the maximum")
	check_eq(wallet.gold_coins(), GameWallet.MAX_BALANCE, "balance must equal the maximum")
	check_eq(wallet.add(GameWallet.Currency.GOLD_COINS, 10), 0, "a full wallet accepts nothing more")


func test_serialisation_round_trip_is_exact() -> void:
	var wallet := GameWallet.new()
	wallet.add(GameWallet.Currency.GOLD_COINS, 750)
	wallet.add(GameWallet.Currency.DIAMONDS, 12)
	var data := wallet.to_dict()
	check_eq(typeof(data["gold_coins"]), TYPE_INT, "serialised gold must be an integer")
	check_eq(typeof(data["diamonds"]), TYPE_INT, "serialised diamonds must be an integer")
	var restored := GameWallet.from_dict(data)
	check_eq(restored.gold_coins(), 750, "gold must survive a round trip")
	check_eq(restored.diamonds(), 12, "diamonds must survive a round trip")
	check_false(restored.had_invalid_values, "an honest save is not a repair")


func test_serialised_wallet_survives_json() -> void:
	# JSON.parse_string() turns every number into a float, so a save that goes
	# through the save file must restore exactly instead of being rejected.
	var wallet := GameWallet.new()
	wallet.add(GameWallet.Currency.GOLD_COINS, GameWallet.MAX_BALANCE - 3)
	wallet.add(GameWallet.Currency.DIAMONDS, 4321)
	var text := JSON.stringify(wallet.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	check_true(parsed is Dictionary, "the serialised wallet must parse back as a dictionary")
	if not parsed is Dictionary:
		return
	var restored := GameWallet.from_dict(parsed)
	check_eq(restored.gold_coins(), GameWallet.MAX_BALANCE - 3,
			"a near-maximum balance must survive a JSON round trip exactly")
	check_eq(restored.diamonds(), 4321, "diamonds must survive a JSON round trip")
	check_false(restored.had_invalid_values, "a JSON round trip must not count as corruption")
	check_eq(restored.to_dict(), wallet.to_dict(), "the restored wallet must serialise identically")


func test_integral_floats_are_accepted() -> void:
	var wallet := GameWallet.from_dict({"gold_coins": 750.0, "diamonds": 0.0})
	check_eq(wallet.gold_coins(), 750, "an integral float is an exact saved balance")
	check_eq(wallet.diamonds(), 0, "a zero float is an exact saved balance")
	check_false(wallet.had_invalid_values, "integral floats are not corruption")
	check_eq(typeof(wallet.gold_coins()), TYPE_INT, "restored balances must be integers")


func test_fractional_saved_balances_are_rejected() -> void:
	# The review rule: 12.6 must not silently become 12 or 13.
	for bad: float in [12.6, 0.5, 0.0001, 99.999, -0.5]:
		var wallet := GameWallet.from_dict({"gold_coins": bad, "diamonds": bad})
		check_eq(wallet.gold_coins(), 0,
				"a fractional saved balance (%s) must not become a balance" % bad)
		check_eq(wallet.diamonds(), 0,
				"a fractional saved balance (%s) must not become a balance" % bad)
		check_true(wallet.had_invalid_values, "a discarded balance must be reported as a repair")


func test_negative_saved_balances_become_zero() -> void:
	for bad: Variant in [-50, -1, -50.0, -9_000_000_000_000_001]:
		var wallet := GameWallet.from_dict({"gold_coins": bad, "diamonds": 0})
		check_eq(wallet.gold_coins(), 0, "a negative saved balance (%s) must not become credit" % bad)
		check_gte(float(wallet.gold_coins()), 0.0, "balances can never be negative")
		check_true(wallet.had_invalid_values, "a negative balance must be reported as a repair")


func test_malformed_saved_balances_are_rejected() -> void:
	for bad: Variant in ["120", "", "12.6", "lots", true, false, [], {}, Vector2.ZERO, null]:
		var wallet := GameWallet.from_dict({"gold_coins": bad, "diamonds": bad})
		check_eq(wallet.gold_coins(), 0, "a malformed saved balance (%s) must become zero" % bad)
		check_eq(wallet.diamonds(), 0, "a malformed saved balance (%s) must become zero" % bad)
		check_true(wallet.had_invalid_values, "a malformed balance must be reported as a repair")

	var not_a_number := GameWallet.from_dict({"gold_coins": NAN, "diamonds": INF})
	check_eq(not_a_number.gold_coins(), 0, "NaN must not become a balance")
	check_eq(not_a_number.diamonds(), 0, "infinity must not become a balance")


func test_saved_balances_are_clamped_to_the_maximum() -> void:
	var wallet := GameWallet.from_dict({
		"gold_coins": GameWallet.MAX_BALANCE,
		"diamonds": GameWallet.MAX_BALANCE + 1,
	})
	check_eq(wallet.gold_coins(), GameWallet.MAX_BALANCE, "the maximum must survive exactly")
	check_eq(wallet.diamonds(), GameWallet.MAX_BALANCE,
			"an oversized saved balance must clamp to the maximum")

	var huge := GameWallet.from_dict({"gold_coins": 9.2e18, "diamonds": 1e300})
	check_eq(huge.gold_coins(), GameWallet.MAX_BALANCE, "an enormous float must clamp, not wrap")
	check_eq(huge.diamonds(), GameWallet.MAX_BALANCE, "an enormous float must clamp, not wrap")
	check_true(huge.had_invalid_values, "a clamped balance must be reported as a repair")


func test_missing_keys_are_not_corruption() -> void:
	var wallet := GameWallet.from_dict({})
	check_eq(wallet.gold_coins(), 0, "a save without wallet data starts at zero")
	check_eq(wallet.diamonds(), 0, "a save without wallet data starts at zero")
	check_false(wallet.had_invalid_values, "a missing key is not a damaged value")

	var partial := GameWallet.from_dict({"gold_coins": 25})
	check_eq(partial.gold_coins(), 25, "a present key must still be restored")
	check_eq(partial.diamonds(), 0, "an absent currency stays at zero")
	check_false(partial.had_invalid_values, "one absent currency is not corruption")


func test_restored_wallet_keeps_its_invariants() -> void:
	var wallet := GameWallet.from_dict({"gold_coins": 100, "diamonds": 5})
	check_true(wallet.spend(GameWallet.Currency.GOLD_COINS, 100), "a restored balance is spendable")
	check_eq(wallet.gold_coins(), 0, "spending a restored balance must debit exactly")
	check_false(wallet.spend(GameWallet.Currency.GOLD_COINS, 1), "a restored wallet cannot overspend")
	var headroom := GameWallet.MAX_BALANCE - 5
	check_eq(wallet.add(GameWallet.Currency.DIAMONDS, GameWallet.MAX_BALANCE), headroom,
			"a restored wallet still clamps at the maximum")


func test_unknown_currency_is_rejected() -> void:
	var wallet := GameWallet.new()
	var bogus: GameWallet.Currency = 42
	check_eq(wallet.add(bogus, 10), 0, "an unknown currency must not be credited")
	check_false(wallet.spend(bogus, 10), "an unknown currency must not be debited")
	check_eq(wallet.balance(bogus), 0, "an unknown currency has no balance")
	check_false(wallet.can_afford(bogus, 0), "an unknown currency is never affordable")
	check_eq(wallet.to_dict().size(), 2, "an unknown currency must not add a serialised key")


func test_wallet_has_no_national_economy_dependency() -> void:
	# The rule is architectural: the wallet must not reference country economy
	# types at all. This guards against a future refactor quietly coupling them.
	var source_path := "res://src/core/economy/game_wallet.gd"
	var file := FileAccess.open(source_path, FileAccess.READ)
	check_not_null(file, "wallet source must be readable")
	if file == null:
		return
	# Comments may legitimately explain the currency rule, so only executable
	# lines are scanned for economy concepts.
	var code_lines := PackedStringArray()
	for line: String in file.get_as_text().split("\n"):
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		code_lines.append(trimmed)
	file.close()
	var source := "\n".join(code_lines)
	for forbidden: String in ["inflation", "exchange_rate", "recession", "bankrupt", "Country"]:
		check_false(source.contains(forbidden),
				"game_wallet.gd must stay independent of national economy concepts ('%s')" % forbidden)
