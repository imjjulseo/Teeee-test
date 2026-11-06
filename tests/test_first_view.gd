extends "res://tests/framework/test_case.gd"
## 6d 처음 볼 때 안내 (기획서 8.8장): 안내 차례(안 본 것만, 띄우는 순간 본 것으로), 족보 동시 진행 판정, 저장 키, 문구 데이터.

const TEST_SAVE: String = "user://test_first_view_save.cfg"


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _spotlight() -> SpotlightOverlay:
	var spotlight: SpotlightOverlay = (load("res://scenes/spotlight_overlay.tscn") as PackedScene).instantiate() as SpotlightOverlay
	spotlight.notification(Node.NOTIFICATION_READY)
	return spotlight


func _no_holes() -> Array[Rect2]:
	return [] as Array[Rect2]


func test_guides_show_unseen_ones_in_order() -> void:
	var spotlight: SpotlightOverlay = _spotlight()
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	store.mark_seen(TutorialStore.SEEN_CHARACTERS)
	var guides: GuideQueue = GuideQueue.new(spotlight, store)
	assert_false(guides.add(TutorialStore.SEEN_CHARACTERS, "캐릭터", "x", _no_holes), "already seen → skipped")
	assert_true(guides.add(TutorialStore.SEEN_ACHIEVEMENTS, "업적", "a", _no_holes))
	assert_false(guides.add(TutorialStore.SEEN_ACHIEVEMENTS, "업적", "a", _no_holes), "no duplicates")
	var scrolled: Array[bool] = [false]
	assert_true(guides.add(TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS, "히든 업적", "h", _no_holes, true, func() -> void: scrolled[0] = true))
	guides.next()
	assert_eq([guides.current_key(), spotlight.caption_head(), spotlight.is_blocking()], [TutorialStore.SEEN_ACHIEVEMENTS, "업적", true])
	assert_true(TutorialStore.new(TEST_SAVE).has_seen(TutorialStore.SEEN_ACHIEVEMENTS), "seen as soon as shown")
	assert_false(TutorialStore.new(TEST_SAVE).has_seen(TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS))
	guides.next()
	assert_eq([guides.current_key(), spotlight.caption_head(), scrolled[0]], [TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS, "히든 업적", true])
	guides.next()
	assert_false(guides.is_open() or spotlight.is_open(), "closed after the last")
	spotlight.free()


func test_multi_recipe_slots() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var session: GameSession = GameSession.new(load("res://resources/game_config.tres") as GameConfig, rng)
	var recipes: RecipeSet = session.recipes
	recipes.replace_all([PackedInt32Array([0, 1]), PackedInt32Array([2, 3, 1]), PackedInt32Array([3, 1, 2, 0])] as Array[PackedInt32Array])
	assert_eq(recipes.slots_waiting_same_color(), [] as Array[int], "all different next colors")
	recipes.replace_all([PackedInt32Array([0, 1]), PackedInt32Array([2, 3, 1]), PackedInt32Array([3, 1, 2, 0])] as Array[PackedInt32Array],
		PackedInt32Array([1, 0, 1]))
	assert_eq(recipes.slots_waiting_same_color(), [0, 2] as Array[int], "slots 0 and 2 both wait for red")
	assert_eq(recipes.slots_waiting_same_color(func(color: int) -> int: return 0), [0, 1, 2] as Array[int], "canonical colors (colorblind)")
	recipes.replace_all([PackedInt32Array([1]), PackedInt32Array([1, 2])] as Array[PackedInt32Array], PackedInt32Array([1, 0]))
	assert_eq(recipes.slots_waiting_same_color(), [] as Array[int], "finished recipes don't wait")


func test_finished_saves_skip_first_view_guides() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	store.finish_all()
	for key: String in [TutorialStore.SEEN_MULTI_RECIPES, TutorialStore.SEEN_EXPERIENCE, TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS,
			TutorialStore.SEEN_ACHIEVEMENTS, TutorialStore.SEEN_CHARACTERS]:
		assert_true(TutorialStore.new(TEST_SAVE).has_seen(key), key)
	store.restart_all()
	assert_false(TutorialStore.new(TEST_SAVE).has_seen(TutorialStore.SEEN_EXPERIENCE), "restart shows them again")


func test_tips_are_the_html_texts() -> void:
	var tips: FirstViewTips = load("res://resources/first_view_tips.tres") as FirstViewTips
	assert_eq([tips.multi_head, tips.multi_text], ["족보 동시 진행", "두 족보를 동시에 올릴 수도 있어요"])
	assert_eq([tips.experience_head, tips.experience_text], ["경험치", "점수만큼 경험치를 얻어요"])
	assert_eq(tips.hidden_text, "조건은 비밀. 달성하면 히든 캐릭터를 얻어요")
	assert_eq(tips.characters_text, "눌러서 능력 보기 · 다이아로 해금 · 한 판 체험 · 튜토리얼")
