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


func test_serialisation_round_trip_and_sanitising() -> void:
	var wallet := GameWallet.new()
	wallet.add(GameWallet.Currency.GOLD_COINS, 750)
	wallet.add(GameWallet.Currency.DIAMONDS, 12)
	var data := wallet.to_dict()
	check_eq(typeof(data["gold_coins"]), TYPE_INT, "serialised gold must be an integer")
	var restored := GameWallet.from_dict(data)
	check_eq(restored.gold_coins(), 750, "gold must survive a round trip")
	check_eq(restored.diamonds(), 12, "diamonds must survive a round trip")

	var hostile := GameWallet.from_dict({"gold_coins": -50, "diamonds": "lots"})
	check_eq(hostile.gold_coins(), 0, "negative saved balances must be clamped to zero")
	check_eq(hostile.diamonds(), 0, "malformed saved balances must become zero")


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
