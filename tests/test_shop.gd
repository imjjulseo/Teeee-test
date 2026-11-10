extends "res://tests/framework/test_case.gd"
## 5c 뽑기·상점 (기획서 8.4 · 8.5장): 뽑기 단계(가격·확률), 뽑기(새 캐릭터 해금 / 중복 선택권), 선택권 합성,
## 다이아 상점, 광고 보상, 수치 검증, 기획서 표와 일치.

const TEST_SAVE: String = "user://test_shop_save.cfg"
const Grade = CharacterData.Grade


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _gacha() -> GachaConfig:
	return load("res://resources/gacha.tres") as GachaConfig


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _collection() -> CharacterCollection:
	return CharacterCollection.new(_roster(), ProgressStore.new(TEST_SAVE), CharacterStore.new(TEST_SAVE), _gacha())


func _shop(seed_value: int = 7) -> CharacterShop:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return CharacterShop.new(_collection(), rng)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- 뽑기 단계 ------------------------------------------------------------------

func test_tier_by_level() -> void:
	var g: GachaConfig = _gacha()
	assert_eq(g.pull_price(), 500, "one fixed price at every machine stage (team decision 11/04)")
	assert_eq([g.tier_number(1), g.tier_number(8), g.tier_number(31)], [1, 2, 4])
	assert_eq(g.next_tier(7).min_level, 8)
	assert_true(g.next_tier(30) == null, "no tier after Lv30")
	assert_true(g.validate().is_empty(), "shipped config valid: %s" % [g.validate()])


func test_roll_follows_rates() -> void:
	for level: int in [1, 30]:
		var tier: GachaTier = _gacha().tier_for(level)
		var counts: Dictionary[int, int] = {}
		var rng: RandomNumberGenerator = _rng(level)
		var rolls: int = 40000
		for _i: int in rolls:
			var grade: int = tier.roll_grade(rng)
			counts[grade] = counts.get(grade, 0) + 1
		for grade: int in [Grade.RARE, Grade.HERO, Grade.LEGEND, Grade.MYTH]:
			var percent: float = 100.0 * counts.get(grade, 0) / rolls
			assert_near(percent, tier.rate_of(grade), 1.0, "Lv%d %s %.2f%%" % [level, CharacterData.GRADE_NAMES[grade], percent])
		assert_eq(counts.size(), 4, "only gacha grades")


# --- 뽑기 -----------------------------------------------------------------------

func test_pull_needs_coins() -> void:
	var shop: CharacterShop = _shop()
	shop.progress().add_currency(349, 0)
	assert_false(shop.can_pull())
	assert_true(shop.pull() == null)
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 349, "nothing spent")


func test_pull_unlocks_a_new_character() -> void:
	var shop: CharacterShop = _shop()
	shop.progress().add_currency(1000, 0)
	var result: CharacterShop.PullResult = shop.pull()
	assert_true(result != null)
	assert_true(result.is_new)
	assert_eq(result.character.grade, result.grade)
	assert_true(CharacterCollection.is_gacha(result.character), "never basic or hidden")
	var saved: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq(saved.coins, 500, "500 spent")
	assert_true(saved.is_unlocked(result.character.id), "saved")
	assert_eq(saved.ticket_count(result.grade), 0)


func test_duplicate_pull_gives_a_ticket_of_that_grade() -> void:
	var shop: CharacterShop = _shop(3)
	for character: CharacterData in _roster().characters:
		if CharacterCollection.is_gacha(character):
			shop.progress().unlock(character.id)
	shop.progress().add_currency(1000, 0)
	var first: CharacterShop.PullResult = shop.pull()
	var second: CharacterShop.PullResult = shop.pull()
	assert_false(first.is_new or second.is_new, "everything owned → duplicates")
	var saved: ProgressStore = ProgressStore.new(TEST_SAVE)
	var expected: Dictionary[int, int] = {}
	for result: CharacterShop.PullResult in [first, second]:
		expected[result.grade] = expected.get(result.grade, 0) + 1
	for grade: int in expected:
		assert_eq(saved.ticket_count(grade), expected[grade], "%s ticket" % CharacterData.GRADE_NAMES[grade])
	assert_eq(saved.coins, 0)


func test_many_pulls_stay_in_the_gacha_pool() -> void:
	var shop: CharacterShop = _shop(11)
	shop.progress().set_level(30)
	shop.progress().add_currency(500 * 60, 0)
	var seen: Dictionary[StringName, bool] = {}
	for _i: int in 60:
		var result: CharacterShop.PullResult = shop.pull()
		assert_true(CharacterCollection.is_gacha(result.character), "%s is a gacha character" % result.character.id)
		seen[result.character.id] = true
	assert_true(seen.size() >= 15, "pulls spread over the pool (%d different)" % seen.size())
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 0, "500 each at Lv30")


# --- 선택권 합성 · 다이아 상점 · 광고 ---------------------------------------------------

func test_fuse_five_tickets_into_the_next_grade() -> void:
	var shop: CharacterShop = _shop()
	for _i: int in 4:
		shop.progress().add_ticket(Grade.RARE)
	assert_false(shop.fuse(Grade.RARE), "needs 5 (team decision 11/04)")
	shop.progress().add_ticket(Grade.RARE)
	assert_true(shop.fuse(Grade.RARE))
	var saved: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq([saved.ticket_count(Grade.RARE), saved.ticket_count(Grade.HERO)], [0, 1])
	for _i: int in 5:
		shop.progress().add_ticket(Grade.MYTH)
	assert_false(shop.can_fuse(Grade.MYTH), "no grade above myth")


func test_buy_with_diamonds() -> void:
	var collection: CharacterCollection = _collection()
	var gardener: CharacterData = _roster().find(&"gardener")
	var wall: CharacterData = _roster().find(&"wall")
	collection.progress.add_currency(0, 79)
	assert_false(collection.buy_with_diamonds(gardener), "79 < 80")
	collection.progress.add_currency(0, 1000)
	assert_true(collection.buy_with_diamonds(gardener))
	assert_eq(collection.progress.diamonds, 999)
	assert_false(collection.buy_with_diamonds(gardener), "already owned")
	assert_false(collection.buy_with_diamonds(wall), "hero shop opens at Lv8")
	collection.progress.set_level(8)
	assert_true(collection.buy_with_diamonds(wall))
	assert_eq(collection.progress.diamonds, 799)
	assert_false(collection.buy_with_diamonds(_roster().find(&"racer")), "hidden not sold")
	assert_true(ProgressStore.new(TEST_SAVE).is_unlocked(&"wall"), "saved")


func test_ticket_works_before_the_shop_opens() -> void:
	var collection: CharacterCollection = _collection()
	collection.progress.add_ticket(Grade.MYTH)
	var zeus: CharacterData = _roster().find(&"zeus")
	assert_true(collection.unlock_with_ticket(zeus), "myth ticket at Lv1")


func _action(collection: CharacterCollection, id: StringName, use_ticket: bool = false) -> Array:
	var action: CharacterCollection.PurchaseAction = collection.purchase_action(_roster().find(id), use_ticket)
	return [action.kind, action.text, action.enabled]


func test_purchase_action_on_the_sheet() -> void:
	const P = CharacterCollection.Purchase
	var collection: CharacterCollection = _collection()
	assert_eq(_action(collection, &"gardener"), [P.DIAMOND, "◆ 80", false], "not enough diamonds")
	collection.progress.add_currency(0, 80)
	assert_eq(_action(collection, &"gardener"), [P.DIAMOND, "◆ 80", true])
	assert_eq(_action(collection, &"wall"), [P.CLOSED, "Lv 8에 열림", false], "hero shop opens at Lv8")
	collection.progress.add_ticket(Grade.HERO)
	assert_eq(_action(collection, &"wall"), [P.CLOSED, "Lv 8에 열림", false], "a ticket alone does not change it")
	assert_eq(_action(collection, &"wall", true), [P.TICKET, "선택권 사용", true], "use is on: works before the shop opens")
	assert_eq(_action(collection, &"gardener", true), [P.DIAMOND, "◆ 80", true], "no rare ticket: still the price")
	collection.progress.unlock(&"gardener")
	assert_eq(_action(collection, &"gardener"), [P.OWNED, "보유", false])
	assert_eq(_action(collection, &"gardener", true), [P.OWNED, "보유", false], "owned wins over use")


func test_ticket_selection_toggles_and_clears() -> void:
	var selection: TicketSelection = TicketSelection.new()
	assert_false(selection.is_on(Grade.RARE))
	selection.toggle(Grade.RARE, 0)
	assert_false(selection.is_on(Grade.RARE), "no ticket, no use")
	selection.toggle(Grade.RARE, 2)
	assert_true(selection.is_on(Grade.RARE))
	assert_false(selection.is_on(Grade.HERO), "per grade")
	selection.toggle(Grade.RARE, 2)
	assert_false(selection.is_on(Grade.RARE), "again = cancel")
	selection.toggle(Grade.RARE, 2)
	selection.sync(Grade.RARE, 1)
	assert_true(selection.is_on(Grade.RARE), "still has tickets")
	selection.sync(Grade.RARE, 0)
	assert_false(selection.is_on(Grade.RARE), "off when they run out")


func test_offer_for_the_sheet() -> void:
	var collection: CharacterCollection = _collection()
	collection.progress.add_currency(0, 100)
	var offer: CharacterCollection.Offer = collection.offer_for(_roster().find(&"wall"))
	assert_eq([offer.tickets, offer.diamond_price, offer.shop_level, offer.shop_open, offer.affordable], [0, 200, 8, false, false])
	offer = collection.offer_for(_roster().find(&"twins"))
	assert_eq([offer.diamond_price, offer.shop_open, offer.affordable], [80, true, true])


func test_ad_reward_three_times_a_day() -> void:
	var shop: CharacterShop = _shop()
	for _i: int in 3:
		assert_true(shop.claim_ad("2026-11-04"))
	assert_false(shop.claim_ad("2026-11-04"), "daily max 3")
	assert_eq(shop.ads_left("2026-11-04"), 0)
	assert_eq(ProgressStore.new(TEST_SAVE).diamonds, 15, "5 each")
	var again: CharacterShop = _shop()
	assert_eq(again.ads_left("2026-11-04"), 0, "count saved")
	assert_eq(again.ads_left("2026-11-05"), 3, "resets the next day")
	assert_true(again.claim_ad("2026-11-05"))
	assert_eq(ProgressStore.new(TEST_SAVE).ads_claimed_on("2026-11-05"), 1)


# --- 검증 · 기획서 -------------------------------------------------------------------

func test_invalid_rates_fall_back_to_defaults() -> void:
	var config: GachaConfig = _gacha().duplicate(true) as GachaConfig
	config.tiers[0].rates[Grade.RARE] = 10.0
	assert_false(config.validate().is_empty(), "rates must sum to 100")
	var fallback: GachaConfig = GachaConfig.ensure_valid(config)  # ERROR 로그가 정상
	assert_ne(fallback, config)


func test_progression_ensures_a_gacha_config() -> void:
	var progression: ProgressionConfig = ProgressionConfig.new()
	assert_true(ProgressionConfig.ensure_valid(progression).gacha != null, "missing gacha → empty defaults")
	assert_eq(ProgressionConfig.ensure_valid(load("res://resources/progression.tres")).gacha.pull_price(), 500, "progression.tres uses gacha.tres")


func test_design_doc_matches_gacha() -> void:
	var g: GachaConfig = _gacha()
	var doc: String = FileAccess.get_file_as_string("res://docs/game_design.md")
	var rates: PackedStringArray = PackedStringArray()
	for tier: GachaTier in g.tiers:
		var parts: PackedStringArray = PackedStringArray()
		for grade: int in [Grade.MYTH, Grade.LEGEND, Grade.HERO, Grade.RARE]:
			parts.append(Ability.format_number(tier.rate_of(grade)))
		rates.append("Lv%d %s" % [tier.min_level, "/".join(parts)])
	var shop_prices: PackedStringArray = PackedStringArray()
	var shop_levels: PackedStringArray = PackedStringArray()
	for grade: int in [Grade.RARE, Grade.HERO, Grade.LEGEND, Grade.MYTH]:
		shop_prices.append("%s %d" % [CharacterData.GRADE_NAMES[grade], g.shop_price(grade)])
		shop_levels.append("%s Lv%d" % [CharacterData.GRADE_NAMES[grade], g.shop_level(grade)])
	var rows: Array[String] = [
		"● %d 고정" % g.pull_price(), " · ".join(rates), " · ".join(shop_prices), " · ".join(shop_levels),
		"같은 등급 선택권 %d장 → 다음 등급 1장" % g.fuse_count,
		"광고(하루 %d회 × %d" % [g.ad_daily_max, g.ad_diamonds],
	]
	for row: String in rows:
		assert_true(doc.contains(row), "doc has '%s'" % row)


func test_card_text_follows_the_purchase_action() -> void:
	var progress: ProgressStore = ProgressStore.new(TEST_SAVE)
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var collection: CharacterCollection = CharacterCollection.new(roster, progress, CharacterStore.new(TEST_SAVE), (load("res://resources/progression.tres") as ProgressionConfig).gacha)
	var gardener: CharacterData = roster.find(&"gardener")
	var wall: CharacterData = roster.find(&"wall")
	assert_eq(collection.purchase_action(gardener, false).card_text, "◆ 80")
	assert_eq(collection.purchase_action(wall, false).card_text, "Lv 8", "closed grade")
	progress.add_ticket(wall.grade)
	assert_eq(collection.purchase_action(wall, true).card_text, "선택", "use is on")
	progress.unlock(gardener.id)
	assert_eq(collection.purchase_action(gardener, false).card_text, "보유")
