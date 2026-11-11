extends "res://tests/framework/test_case.gd"
## 5b 메뉴·캐릭터 화면 (기획서 8.1 · 8.3장): 캐릭터 모음(등급순, 카드 상태, 선택권 해금, 장착),
## 레벨 보상 문구, 메뉴 안내·단계 잠금, 체험 요청, 메인 메뉴·체험 결과 화면.

const SceneWiring = preload("res://tests/framework/scene_wiring.gd")
const TEST_SAVE: String = "user://test_collection_save.cfg"
const Grade = CharacterData.Grade
const Status = CharacterCollection.Status


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _progression() -> ProgressionConfig:
	return load("res://resources/progression.tres") as ProgressionConfig


func _collection() -> CharacterCollection:
	return CharacterCollection.new(_roster(), ProgressStore.new(TEST_SAVE), CharacterStore.new(TEST_SAVE), _progression().gacha)


func _find(id: StringName) -> CharacterData:
	return _roster().find(id)


# --- 캐릭터 모음 -------------------------------------------------------------------

func test_sorted_by_grade_then_roster_order() -> void:
	var list: Array[CharacterData] = _collection().sorted()
	assert_eq(list.size(), 32)
	assert_eq([list[0].id, list[1].id, list[2].id], [&"basic", &"gardener", &"twins"], "basic, then rares in roster order")
	assert_eq([list[29].id, list[30].id, list[31].id], [&"racer", &"pachy", &"ambi"], "hidden last")
	for i: int in range(1, list.size()):
		assert_true(list[i - 1].grade <= list[i].grade, "grade order at %d" % i)


func test_card_status() -> void:
	var collection: CharacterCollection = _collection()
	assert_eq(collection.status_of(_find(&"basic")), Status.EQUIPPED, "only basic at start")
	assert_eq(collection.status_of(_find(&"gardener")), Status.UNOWNED)
	assert_eq(collection.status_text(_find(&"gardener")), "미보유")
	assert_eq(collection.status_text(_find(&"wall")), "미보유", "shop state does not show on the card (E36)")
	assert_eq(collection.status_of(_find(&"racer")), Status.HIDDEN)
	assert_eq(collection.status_text(_find(&"racer")), "히든 업적")
	assert_true(collection.is_veiled(_find(&"racer")), "hidden character veiled")
	assert_false(collection.is_veiled(_find(&"zeus")), "myth shown even when locked")
	collection.progress.add_ticket(Grade.RARE)
	assert_eq(collection.status_text(_find(&"gardener")), "미보유", "a ticket does not change the card")


func test_unlock_with_ticket() -> void:
	var collection: CharacterCollection = _collection()
	assert_false(collection.unlock_with_ticket(_find(&"gardener")), "no ticket")
	collection.progress.add_ticket(Grade.RARE)
	assert_true(collection.unlock_with_ticket(_find(&"gardener")))
	assert_eq(collection.progress.ticket_count(Grade.RARE), 0, "ticket spent")
	assert_eq(collection.status_of(_find(&"gardener")), Status.OWNED)
	collection.progress.add_ticket(Grade.RARE)
	assert_false(collection.unlock_with_ticket(_find(&"gardener")), "already owned")
	assert_eq(collection.progress.ticket_count(Grade.RARE), 1, "ticket kept")
	collection.progress.add_ticket(Grade.HIDDEN)
	assert_false(collection.unlock_with_ticket(_find(&"racer")), "hidden only by achievement")
	assert_true(ProgressStore.new(TEST_SAVE).is_unlocked(&"gardener"), "saved")


func test_equip_only_owned_and_persists() -> void:
	var collection: CharacterCollection = _collection()
	assert_false(collection.equip(_find(&"clock")), "locked")
	collection.progress.unlock(&"clock")
	assert_true(collection.equip(_find(&"clock")))
	assert_eq(collection.status_of(_find(&"clock")), Status.EQUIPPED)
	assert_eq(collection.status_of(_find(&"basic")), Status.OWNED)
	assert_eq(_collection().equipped_character().id, &"clock", "reloaded")


func test_equipped_falls_back_to_basic_when_not_owned() -> void:
	CharacterStore.new(TEST_SAVE).select(&"zeus")  # 예전 판(모두 열려 있던 때)의 저장값
	assert_eq(_collection().equipped_character().id, &"basic")


func test_grade_counts() -> void:
	var collection: CharacterCollection = _collection()
	assert_eq([collection.grade_counts(Grade.RARE), collection.grade_counts(Grade.HERO), collection.grade_counts(Grade.LEGEND),
		collection.grade_counts(Grade.MYTH), collection.grade_counts(Grade.HIDDEN)],
		[Vector2i(0, 4), Vector2i(0, 8), Vector2i(0, 11), Vector2i(0, 5), Vector2i(0, 3)], "28 gacha + 3 hidden")
	collection.progress.unlock(&"twins")
	assert_eq(collection.grade_counts(Grade.RARE), Vector2i(1, 4))


# --- 레벨 보상·메뉴 안내 ----------------------------------------------------------

func test_level_reward_lines() -> void:
	var p: ProgressionConfig = _progression()
	assert_eq(p.rewards_for_level(1), PackedStringArray(["시작 보드 / 3색, 족보 2칸"]))
	assert_eq(p.rewards_for_level(2), PackedStringArray(["보드 업그레이드 / 제한시간 45초", "● 100", "◆ 10"]))
	assert_eq(p.rewards_for_level(4), PackedStringArray(["● 100", "◆ 10"]))
	assert_eq(p.rewards_for_level(5), PackedStringArray(["● 100", "◆ 10"]), "no milestone diamonds")
	assert_eq(p.rewards_for_level(10), PackedStringArray(["● 100", "◆ 10", "영웅 선택권"]))
	assert_eq(p.rewards_for_level(20), PackedStringArray(["● 100", "◆ 10", "전설 선택권", "뽑기 머신 업그레이드, 확률 상승", "상점 전설 열림"]))
	assert_eq(p.rewards_for_level(8), PackedStringArray(["● 100", "◆ 10", "뽑기 머신 업그레이드, 확률 상승", "상점 영웅 열림"]))
	assert_eq(p.rewards_for_level(30), PackedStringArray(["● 100", "◆ 10", "신화 선택권", "뽑기 머신 업그레이드, 확률 상승", "상점 신화 열림"]))
	assert_eq([p.levels_to_show(1), p.levels_to_show(29)], [30, 32], "at least 30, and 3 ahead")


func test_next_stage_and_menu_hint() -> void:
	var p: ProgressionConfig = _progression()
	assert_eq([p.next_stage_description(1), p.next_stage_description(2), p.next_stage_description(3)],
		["제한시간 45초", "4색, 4칸 족보", ""])


func test_level_row_state() -> void:
	var states: Array[int] = []
	for level: int in [3, 4, 5, 6]:
		states.append(LevelRewardRow.state_for(level, 4))
	assert_eq(states, [LevelRewardRow.State.REACHED, LevelRewardRow.State.CURRENT, LevelRewardRow.State.NEXT, LevelRewardRow.State.AHEAD] as Array[int])


func test_menu_unlocks_open_in_order() -> void:
	var all: MenuUnlocks = MenuUnlocks.new()
	for entry: int in MenuUnlocks.Entry.values():
		assert_true(all.is_open(entry), "all open until the tutorial flow (stage 6)")
	var first: MenuUnlocks = MenuUnlocks.new(1)
	assert_eq([first.is_open(MenuUnlocks.Entry.START), first.is_open(MenuUnlocks.Entry.LEVEL), first.is_open(MenuUnlocks.Entry.OPTIONS)],
		[true, false, true], "start first, options always")
	first.open_next()
	assert_true(first.is_open(MenuUnlocks.Entry.LEVEL))
	assert_false(first.is_open(MenuUnlocks.Entry.SHOP))
	for _i: int in 10:
		first.open_next()
	assert_eq(first.opened, MenuUnlocks.ORDER.size())


func test_trial_request_is_taken_once() -> void:
	TrialRequest.character_id = &"zeus"
	assert_eq(TrialRequest.take(), &"zeus")
	assert_eq(TrialRequest.take(), &"", "cleared after the game picked it up")


# --- 화면 -----------------------------------------------------------------------

func test_main_menu_shows_level_wallet_stage_and_character() -> void:
	var progress: ProgressStore = ProgressStore.new(TEST_SAVE)
	progress.set_level(2)
	progress.add_currency(120, 5)
	progress.unlock(&"clock")
	CharacterStore.new(TEST_SAVE).select(&"clock")
	var menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.save_path = TEST_SAVE
	menu.notification(Node.NOTIFICATION_READY)
	assert_eq((menu.get_node("%TopBar/%LevelLabel") as Label).text, "Lv 2")
	assert_eq((menu.get_node("%TopBar/%WalletLabel") as WalletView).text, "● 120  ◆ 5")
	assert_eq((menu.get_node("%BestLabel") as Label).text, "0")
	assert_eq((menu.get_node("%BottomNav") as BottomNav).block().shown_letter(), "시", "the equipped character on the block")
	for entry: int in MenuUnlocks.Entry.values():
		assert_true(menu.is_entry_enabled(entry), "entry %d open" % entry)
	menu.free()


func test_level_stem_fills_up_to_the_next_level() -> void:
	assert_eq([LevelRewardsScreen.stem_ratio(3, 4, 0.5), LevelRewardsScreen.stem_ratio(4, 4, 0.5), LevelRewardsScreen.stem_ratio(5, 4, 0.5), LevelRewardsScreen.stem_ratio(6, 4, 0.5)],
		[1.0, 1.0, 0.5, 0.0])


func test_character_best_is_saved_per_character() -> void:
	var store: BestScoreStore = BestScoreStore.new(TEST_SAVE)
	assert_eq(store.best_of(&"clock"), 0)
	assert_true(store.submit_character(&"clock", 500))
	assert_false(store.submit_character(&"clock", 400), "lower score")
	assert_true(store.submit_character(&"zeus", 900))
	var again: BestScoreStore = BestScoreStore.new(TEST_SAVE)
	assert_eq([again.best_of(&"clock"), again.best_of(&"zeus"), again.best], [500, 900, 0], "separate from the overall best")
