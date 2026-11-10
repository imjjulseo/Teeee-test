extends "res://tests/framework/test_case.gd"
## GameConfig: 기본값·리소스 파일이 기획서 v1.0 값이고, 잘못된 설정을 걸러낸다.


func test_default_config_is_valid() -> void:
	assert_true(make_config().validate().is_empty())


func test_config_resource_file_matches_the_defaults() -> void:
	var config: GameConfig = load("res://resources/game_config.tres") as GameConfig
	assert_true(config != null, "game_config.tres should load as GameConfig")
	if config == null:
		return
	assert_true(config.validate().is_empty(), ", ".join(config.validate()))
	var defaults: GameConfig = make_config()
	for property: Dictionary in defaults.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = property["name"]
			assert_eq(config.get(name), defaults.get(name), "game_config.tres %s matches the script default" % name)


func test_v1_values() -> void:
	var config: GameConfig = make_config()
	assert_eq(config.board_size, 9)
	assert_eq(config.recipe_lengths, PackedInt32Array([2, 3, 4]))
	assert_eq(config.recipe_base_score, 100)
	assert_near(config.max_frame_delta, 0.1)


func test_even_board_size_is_invalid() -> void:
	var config: GameConfig = make_config()
	config.board_size = 6
	assert_false(config.validate().is_empty())


func test_board_size_below_three_is_invalid() -> void:
	var config: GameConfig = make_config()
	config.board_size = 1
	assert_false(config.validate().is_empty())


func test_color_count_need_not_divide_the_block_count() -> void:
	var config: GameConfig = make_config()
	config.color_count = 3  # 80칸 / 3색 → 27·27·26 (2.1장)
	assert_true(config.validate().is_empty())


func test_bad_values_are_invalid() -> void:
	var setters: Array[Callable] = [
		func(c: GameConfig) -> void: c.recipe_lengths = PackedInt32Array(),
		func(c: GameConfig) -> void: c.recipe_lengths = PackedInt32Array([2, 0]),
		func(c: GameConfig) -> void: c.refill_total_end = 0.0,
		func(c: GameConfig) -> void: c.refill_wait_weight = 0.0; c.refill_grow_weight = 0.0,
		func(c: GameConfig) -> void: c.coin_life = 0.0,
		func(c: GameConfig) -> void: c.revive_time = 0.0,
		func(c: GameConfig) -> void: c.game_duration = 0.0,
	]
	for i: int in setters.size():
		var config: GameConfig = make_config()
		setters[i].call(config)
		assert_false(config.validate().is_empty(), "case %d" % i)


func test_frame_delta_is_clamped() -> void:
	var config: GameConfig = make_config()
	assert_near(config.clamp_frame_delta(0.016), 0.016, 1e-9, "normal frame untouched")
	assert_near(config.clamp_frame_delta(0.8), 0.1, 1e-9, "hitch clamped to max_frame_delta")
	assert_near(config.clamp_frame_delta(-0.1), 0.0, 1e-9, "negative → 0")


func test_max_frame_delta_must_be_positive() -> void:
	var config: GameConfig = make_config()
	config.max_frame_delta = 0.0
	assert_false(config.validate().is_empty())
