extends "res://tests/framework/test_case.gd"
## 기획서 5.1 족보 시스템 (B6~B8, B10, E7): 점수 공식, 생성 조건(첫 색 4개 이상·중복 금지), 진행·완성.


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 판의 색별 개수를 고정으로 돌려주는 함수.
func _counts(counts: PackedInt32Array) -> Callable:
	return func() -> PackedInt32Array: return counts


func _make_set(seed_value: int = 1, counts: PackedInt32Array = PackedInt32Array([20, 20, 20, 20])) -> RecipeSet:
	return RecipeSet.from_config(make_config(), _rng(seed_value), _counts(counts))


## 슬롯 0=[1,2], 1=[1,3,0], 2=[2,2,1,0] 으로 고정한 족보.
func _fixed() -> RecipeSet:
	var recipes: RecipeSet = _make_set()
	recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	recipes.set_recipe_colors(1, PackedInt32Array([1, 3, 0]))
	recipes.set_recipe_colors(2, PackedInt32Array([2, 2, 1, 0]))
	return recipes


# --- 점수 (E7) ----------------------------------------------------------------

func test_score_table_from_section_5_1() -> void:
	var scoring: RecipeScoring = RecipeScoring.from_config(make_config())
	var cases: Array = [
		[[0, 1], 100], [[2, 2], 125],
		[[0, 1, 2], 300], [[0, 0, 1], 375], [[3, 3, 3], 450],
		[[0, 1, 2, 3], 600], [[0, 0, 1, 2], 750], [[0, 0, 1, 1], 900], [[1, 1, 1, 1], 1050],
		[[0, 1, 2, 3, 0], 1000], [[0, 0, 0, 0, 0], 2000],
	]
	for case: Array in cases:
		var colors: PackedInt32Array = PackedInt32Array(case[0])
		assert_eq(scoring.points_for(colors), case[1], "%s" % [colors])


func test_repeat_count_counts_only_neighbors() -> void:
	assert_eq(RecipeScoring.repeat_count(PackedInt32Array([1, 2, 1, 2])), 0, "same colors apart are not repeats")
	assert_eq(RecipeScoring.repeat_count(PackedInt32Array([3, 3, 3])), 2)


# --- 생성 (E7) ----------------------------------------------------------------

func test_three_recipes_with_lengths_2_3_4() -> void:
	var recipes: RecipeSet = _make_set()
	assert_eq(recipes.slot_count(), 3)
	var lengths: Array[int] = []
	for recipe: RecipeSet.Recipe in recipes.recipes:
		lengths.append(recipe.length())
		assert_eq(recipe.progress, 0)
		assert_eq(recipe.points, recipes.points_for(recipe.colors), "points follow the formula")
		for color: int in recipe.colors:
			assert_true(color >= 0 and color < 4, "color in range")
	assert_eq(lengths, [2, 3, 4] as Array[int])


func test_first_color_must_have_at_least_four_on_the_board() -> void:
	# 색 1·3은 판에 3개뿐 → 첫 색이 될 수 없다.
	for seed_value: int in range(1, 60):
		var recipes: RecipeSet = _make_set(seed_value, PackedInt32Array([30, 3, 30, 3]))
		for recipe: RecipeSet.Recipe in recipes.recipes:
			assert_true(recipe.colors[0] == 0 or recipe.colors[0] == 2, "seed %d first color %d" % [seed_value, recipe.colors[0]])


func test_generator_avoids_recipes_already_on_screen() -> void:
	# 2색, 2칸 → 가능한 순서는 4개뿐. 나와 있는 순서를 피하면 남은 순서 중에서만 나온다.
	var generator: RecipeGenerator = RecipeGenerator.new(2, _rng(3), 0, 200, _counts(PackedInt32Array([9, 9])))
	var avoid: Array[PackedInt32Array] = [PackedInt32Array([0, 0]), PackedInt32Array([0, 1]), PackedInt32Array([1, 0])]
	for _i: int in 20:
		assert_eq(generator.make_colors(2, avoid), PackedInt32Array([1, 1]))


func test_generator_gives_up_after_attempts_and_uses_the_last_draw() -> void:
	var generator: RecipeGenerator = RecipeGenerator.new(4, _rng(), 99, 5, _counts(PackedInt32Array([1, 1, 1, 1])))
	assert_eq(generator.make_colors(3).size(), 3, "no color can satisfy the minimum, still returns a recipe")


func test_same_seed_same_recipes() -> void:
	var a: RecipeSet = _make_set(42)
	var b: RecipeSet = _make_set(42)
	for slot: int in 3:
		assert_eq(a.recipes[slot].colors, b.recipes[slot].colors)


func test_repeated_colors_are_allowed() -> void:
	var found_repeat: bool = false
	for seed_value: int in range(1, 30):
		if RecipeScoring.repeat_count(_make_set(seed_value).recipes[2].colors) > 0:
			found_repeat = true
	assert_true(found_repeat, "4-color recipes should sometimes repeat a color")


func test_lengths_follow_config_for_board_stages() -> void:
	var config: GameConfig = make_config()
	config.recipe_lengths = PackedInt32Array([2, 3])
	var recipes: RecipeSet = RecipeSet.from_config(config, _rng(), _counts(PackedInt32Array([20, 20, 20, 20])))
	assert_eq(recipes.slot_count(), 2)


# --- 진행·완성 (B6~B8, B10) -----------------------------------------------------

func test_matching_color_advances() -> void:
	var recipes: RecipeSet = _fixed()
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(2)
	assert_eq(outcome.advanced_slots, [2] as Array[int])
	assert_eq(recipes.recipes[2].progress, 1)
	assert_eq(recipes.recipes[2].next_color(), 2)
	assert_eq(outcome.points, 0)


func test_wrong_color_is_ignored_without_reset() -> void:
	var recipes: RecipeSet = _fixed()
	recipes.apply_clear(2)  # 슬롯2 진행 1
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(3)  # 어느 족보의 다음 색도 아님
	assert_eq(outcome.advanced_slots.size(), 0)
	assert_eq(recipes.recipes[2].progress, 1, "progress kept after wrong color")
	assert_eq(recipes.recipes[0].progress, 0)


func test_one_clear_advances_multiple_slots() -> void:
	var recipes: RecipeSet = _fixed()
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(1)
	assert_eq(outcome.advanced_slots, [0, 1] as Array[int])
	assert_eq(recipes.recipes[0].progress, 1)
	assert_eq(recipes.recipes[1].progress, 1)
	assert_eq(recipes.recipes[2].progress, 0)


func test_completion_scores_and_replaces_with_same_length() -> void:
	var recipes: RecipeSet = _fixed()
	recipes.apply_clear(1)
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(2)  # 슬롯0 [1,2] 완성, 슬롯2도 진행
	assert_eq(outcome.points, 100)
	assert_eq(outcome.completed_slots, [0] as Array[int])
	assert_true(outcome.advanced_slots.has(0) and outcome.advanced_slots.has(2))
	var fresh: RecipeSet.Recipe = recipes.recipes[0]
	assert_eq(fresh.length(), 2, "new recipe has the same length")
	assert_eq(fresh.progress, 0)


func test_full_sequence_for_four_block_recipe() -> void:
	var recipes: RecipeSet = _fixed()
	var total: int = 0
	for color: int in [2, 2, 1, 0]:
		total += recipes.apply_clear(color).points
	# 2,2 → 슬롯2 진행 2 / 1 → 슬롯0·1·2 진행 / 0 → 슬롯2 완성 (반복 1번 → 750)
	assert_true(total >= 750, "4-block recipe completed (got %d)" % total)
	assert_eq(recipes.recipes[2].progress, 0, "slot 2 replaced")


func test_simultaneous_completion_sums_points() -> void:
	var recipes: RecipeSet = _make_set()
	recipes.set_recipe_colors(0, PackedInt32Array([3, 1]))
	recipes.set_recipe_colors(1, PackedInt32Array([0, 3, 1]))
	recipes.set_recipe_colors(2, PackedInt32Array([2, 2, 2, 2]))
	recipes.apply_clear(0)  # 슬롯1 진행
	recipes.apply_clear(3)  # 슬롯0, 슬롯1 진행
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(1)  # 슬롯0, 슬롯1 동시 완성
	assert_eq(outcome.completed_slots, [0, 1] as Array[int])
	assert_eq(outcome.points, 400)


func test_apply_wild_advances_every_slot() -> void:
	var recipes: RecipeSet = _fixed()  # [1,2] [1,3,0] [2,2,1,0]
	var outcome: RecipeSet.ClearOutcome = recipes.apply_wild()
	assert_eq(outcome.advanced_slots, [0, 1, 2] as Array[int])
	for recipe: RecipeSet.Recipe in recipes.recipes:
		assert_eq(recipe.progress, 1)


func test_best_progress_slot_rules() -> void:
	var recipes: RecipeSet = _fixed()
	assert_eq(recipes.best_progress_slot(), 0, "all 0 → fewest remaining (2-step)")
	recipes.recipes[2].progress = 2
	assert_eq(recipes.best_progress_slot(), 2, "most progress wins")
	recipes.recipes[1].progress = 2
	assert_eq(recipes.best_progress_slot(), 1, "tie → fewer remaining (3-step: 1 left vs 4-step: 2 left)")

