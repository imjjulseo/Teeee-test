extends "res://tests/framework/test_case.gd"
## 기획서와 실제 데이터(설정·캐릭터 리소스)가 어긋나지 않는지 확인한다.
## 규칙·수치를 바꿀 때 기획서를 함께 고치지 않으면 여기서 실패한다.
## 게임 규칙 설정은 10장 표, 로스터의 캐릭터는 5.2장 표(| 이름 | id | 등급 | 족보 | 능력 | …)와 비교한다.

const DOC_PATH: String = "res://docs/game_design.md"
## 색 ID 순서의 색 이름 (E16).
const COLOR_NAMES: Array[String] = ["노랑", "빨강", "파랑", "초록"]


func _num(value: float) -> String:
	return str(snappedf(value, 0.01)).trim_suffix(".0")


func test_doc_is_version_1_0() -> void:
	assert_true(FileAccess.get_file_as_string(DOC_PATH).contains("Version 1.0"), "design doc version")


func test_balance_table_matches_game_config() -> void:
	var config: GameConfig = load("res://resources/game_config.tres")
	var doc: String = FileAccess.get_file_as_string(DOC_PATH)
	var lengths: PackedStringArray = PackedStringArray()
	for length: int in config.recipe_lengths:
		lengths.append(str(length))
	var expected: Dictionary = {
		"| BoardSize | %d |" % config.board_size: "board size",
		"| ColorCount | %d |" % config.color_count: "color count",
		"| GameDuration | %s초 |" % _num(config.game_duration): "game duration",
		"| ClearTime | %s초 − %s초 × (매치 수 − 1), 최저 %s초 |" % [
			_num(config.clear_time_start), _num(config.clear_time_decay), _num(config.clear_time_min)]: "clear time",
		"| RefillTotal | %s초 → %s초 (%s초에 걸쳐) |" % [
			_num(config.refill_total_start), _num(config.refill_total_end), _num(config.refill_ramp_time)]: "refill total",
		"| RefillSplit | 대기 %s : 자람 %s |" % [_num(config.refill_wait_weight), _num(config.refill_grow_weight)]: "refill split",
		"| RecipeLengths | %s칸 |" % " · ".join(lengths): "recipe lengths",
		"| RecipeScore | %d × L(L−1)/2 × (1 + %s × 반복) |" % [config.recipe_base_score, _num(config.recipe_repeat_bonus)]: "recipe score",
		"| RecipeFirstColorMin | %d개 |" % config.recipe_first_color_min: "recipe first color",
		"| CoinChance / Life / Max / ChainGap | %d%% / %s초 / %d개 / %s초 |" % [
			roundi(config.coin_chance * 100.0), _num(config.coin_life), config.coin_max, _num(config.coin_chain_gap)]: "coins",
		"/ %s초 |" % _num(config.revive_time): "revive time",
		"| SwipeThreshold | %dpx |" % roundi(config.swipe_threshold): "swipe threshold",
		"| PadRepeatDelay / Interval | %s초 / %s초 |" % [_num(config.pad_repeat_delay), _num(config.pad_repeat_interval)]: "pad repeat",
		"| MaxFrameDelta | %s초 |" % _num(config.max_frame_delta): "max frame delta",
		"| InitialSeed | %d(랜덤) |" % config.initial_seed: "initial seed",
	}
	for row: String in expected:
		assert_true(doc.contains(row), "%s: doc row '%s' not found" % [expected[row], row])


func test_character_table_matches_roster() -> void:
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var lines: PackedStringArray = FileAccess.get_file_as_string(DOC_PATH).split("\n")
	for character: CharacterData in roster.characters:
		var row: String = ""
		for line: String in lines:
			if line.begins_with("| %s | %s |" % [character.display_name, character.id]):
				row = line
				break
		assert_true(not row.is_empty(), "%s (%s) row in 5.2 table" % [character.display_name, character.id])
		if row.is_empty():
			continue
		var cells: PackedStringArray = row.split("|")  # ["", 이름, id, 등급, 족보, 능력, 세부, ""]
		var recipe: String = "상시" if character.has_ability() else "없음"
		if character.has_recipe():
			var names: PackedStringArray = PackedStringArray()
			for color: int in character.condition_colors:
				names.append(COLOR_NAMES[color])
			recipe = " → ".join(names)
		assert_eq(cells[3].strip_edges(), CharacterData.GRADE_NAMES[character.grade], "%s grade" % character.display_name)
		assert_eq(cells[4].strip_edges(), recipe, "%s recipe" % character.display_name)
		assert_eq(cells[5].strip_edges(), character.ability_description, "%s description" % character.display_name)
