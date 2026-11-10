extends "res://tests/framework/test_case.gd"
## 5a 진행 기반 (기획서 8.2 · 8.4장): 경험치 곡선, 판 끝 정산(코인·경험치·레벨업 보상·선택권), 보드 단계,
## 진행 저장, 다이아 부활(판당 1번).

const TEST_SAVE: String = "user://test_progression_save.cfg"
const Grade = CharacterData.Grade


func _progression() -> ProgressionConfig:
	return load("res://resources/progression.tres") as ProgressionConfig


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- 수치 ---------------------------------------------------------------------

func test_exp_curve() -> void:
	var p: ProgressionConfig = _progression()
	var needs: Array[int] = []
	for level: int in [1, 2, 10, 19, 20, 21, 22, 30]:
		needs.append(p.exp_to_next(level))
	assert_eq(needs, [500, 600, 1400, 2300, 2400, 2610, 2840, 5400] as Array[int],
		"linear 500 + 100 × (Lv − 1) below Lv20, then 2400 + 200d + 10d² (team decision 11/04, E26)")
	assert_eq(p.exp_for_score(5099), 1774, "500 + 0.25 × 5099, floored")
	assert_eq(p.exp_for_score(-5), 500, "negative score counts as 0")
	assert_eq(p.coins_for_run(5099, 30), 80, "⌊5099 ÷ 100⌋ + 30 picked")
	assert_eq([p.diamonds_for_level(4), p.diamonds_for_level(5), p.diamonds_for_level(10)], [10, 10, 10], "same every level")
	assert_eq(p.ticket_levels, {10: Grade.HERO, 20: Grade.LEGEND, 30: Grade.MYTH} as Dictionary[int, int])


func test_exp_formula_is_data() -> void:
	var p: ProgressionConfig = ProgressionConfig.new()
	p.exp_per_game = 0
	p.exp_per_point = 0.01
	p.curve_from_level = 3
	p.linear_base = 10
	p.linear_step = 5
	p.curve_base = 100
	p.curve_step = 0
	p.curve_square = 1.5
	assert_eq([p.exp_for_score(1000), p.exp_to_next(1), p.exp_to_next(2), p.exp_to_next(3), p.exp_to_next(5)], [10, 10, 15, 100, 106],
		"every number comes from the resource")
	assert_true(p.validate().is_empty())
	p.linear_base = 0
	assert_false(p.validate().is_empty(), "a level that needs 0 exp is invalid")


func test_board_stages() -> void:
	var p: ProgressionConfig = _progression()
	var base: GameConfig = make_config()
	var one: GameConfig = p.stage_for_level(1).apply_to(base)
	assert_eq([one.color_count, one.recipe_lengths, one.refill_total_start, one.refill_total_end, one.game_duration],
		[3, PackedInt32Array([2, 3]), 10.0, 4.0, 40.0], "Lv1: 3 colors, 2 recipes, refill 10 → 4 s, 40 s")
	assert_near(p.stage_for_level(2).apply_to(base).game_duration, 45.0)
	var main: GameConfig = p.stage_for_level(30).apply_to(base)
	assert_eq([main.color_count, main.recipe_lengths, main.game_duration], [4, PackedInt32Array([2, 3, 4]), 60.0], "Lv3+ = main board")
	assert_eq(base.color_count, 4, "base config untouched")
	var session: GameSession = GameSession.new(one, _rng())
	assert_eq(session.recipes.slot_count(), 2)
	assert_eq(session.board.color_counts(3), PackedInt32Array([27, 27, 26]), "3-color board (80 blocks)")


# --- 판 끝 정산 ---------------------------------------------------------------

func test_rewards_level_up_and_board_upgrade() -> void:
	var r: RunRewards.Result = RunRewards.compute(200, 3, 1, 0, _progression())
	assert_eq([r.coins, r.exp_gained], [5, 550])
	assert_eq([r.level_after, r.exp_after, r.exp_needed], [2, 50, 600], "500 to Lv2, 50 left of 600")
	assert_eq(r.level_ups.size(), 1)
	assert_eq([r.level_ups[0].level, r.level_ups[0].coins, r.level_ups[0].diamonds, r.level_ups[0].ticket_grade], [2, 100, 10, -1])
	assert_true(r.board_upgraded())
	assert_eq(r.upgraded_description, "제한시간 45초")
	assert_eq(r.next_stage_description, "4색 · 4칸 족보")
	assert_eq(ResultPanel.reward_lines(r), [PackedStringArray(["보드 업그레이드", "제한시간 45초"])] as Array[PackedStringArray], "no level rewards on the result (E36)")


func test_rewards_several_levels_milestone_and_ticket() -> void:
	var r: RunRewards.Result = RunRewards.compute(8000, 0, 8, 0, _progression())  # 2500 exp: Lv8 1200 + Lv9 1300
	assert_eq([r.level_after, r.exp_after, r.exp_needed], [10, 0, 1400])
	assert_eq(r.level_ups.map(func(up: RunRewards.LevelUp) -> int: return up.level), [9, 10])
	assert_eq(r.level_ups[1].diamonds, 10, "no milestone diamonds")
	assert_eq([r.level_ups[0].ticket_grade, r.level_ups[1].ticket_grade], [-1, Grade.HERO], "Lv10 hero ticket")
	assert_false(r.board_upgraded(), "already the main board")
	assert_eq(r.next_stage_description, "")
	assert_eq(ResultPanel.reward_lines(r), [] as Array[PackedStringArray], "tickets are not on the result either")


func test_bar_steps_fill_each_level_in_turn() -> void:
	var p: ProgressionConfig = _progression()
	var stay: RunRewards.Result = RunRewards.compute(0, 0, 3, 10, p)
	assert_eq(stay.bar_steps.size(), 1)
	assert_near(stay.bar_steps[0].from, 10.0 / p.exp_to_next(3))
	assert_near(stay.bar_steps[0].to, 510.0 / p.exp_to_next(3))
	var two: RunRewards.Result = RunRewards.compute(8000, 0, 8, 600, p)  # 2500 exp: Lv8 나머지 600 + Lv9 1300 + 600 남음
	assert_eq(two.bar_steps.map(func(step: RunRewards.BarStep) -> int: return step.level), [8, 9, 10])
	assert_near(two.bar_steps[0].from, 0.5)
	assert_near(two.bar_steps[0].to, 1.0)
	assert_near(two.bar_steps[1].from, 0.0)
	assert_near(two.bar_steps[1].to, 1.0)
	assert_near(two.bar_steps[2].to, float(two.exp_after) / two.exp_needed)


# --- 레벨 보상 받기 (E36) ------------------------------------------------------

func test_level_up_pays_nothing_until_claimed() -> void:
	var p: ProgressionConfig = _progression()
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	store.apply_rewards(RunRewards.compute(8000, 0, 8, 0, p))  # Lv8 → 10
	assert_eq([store.level, store.coins, store.diamonds, store.ticket_count(Grade.HERO)], [10, 80, 0, 0], "only the run's coins")
	assert_eq(store.claimable_levels(), [2, 3, 4, 5, 6, 7, 8, 9, 10] as Array[int], "every reached level")


func test_claim_pays_once_and_is_saved() -> void:
	var p: ProgressionConfig = _progression()
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	store.set_level(10)
	assert_true(store.claim_level_reward(p.level_up_for(10)))
	assert_eq([store.coins, store.diamonds, store.ticket_count(Grade.HERO)], [100, 10, 1], "coins, diamonds and the milestone ticket")
	assert_false(store.claim_level_reward(p.level_up_for(10)), "only once")
	assert_eq(store.coins, 100)
	assert_true(store.claim_level_reward(p.level_up_for(2)), "any order")
	var again: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_false(again.is_reward_claimable(10), "saved")
	assert_true(again.is_reward_claimable(3))
	assert_eq([again.coins, again.diamonds, again.ticket_count(Grade.HERO)], [200, 20, 1])


func test_cannot_claim_unreached_or_level_one() -> void:
	var p: ProgressionConfig = _progression()
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	store.set_level(3)
	assert_false(store.claim_level_reward(p.level_up_for(4)), "not reached")
	assert_false(store.claim_level_reward(p.level_up_for(1)), "Lv1 has no reward")
	assert_eq(store.coins, 0)


func test_zero_score_gives_picked_coins_and_base_exp() -> void:
	var r: RunRewards.Result = RunRewards.compute(0, 20, 3, 10, _progression())
	assert_eq([r.coins, r.exp_gained, r.level_after, r.exp_after, r.level_ups.size()], [20, 500, 3, 510, 0])


# --- 저장 ---------------------------------------------------------------------

func test_progress_starts_with_only_the_basic_character() -> void:
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq([store.level, store.experience, store.coins, store.diamonds], [1, 0, 0, 0])
	assert_true(store.is_unlocked(&"basic"))
	assert_false(store.is_unlocked(&"gardener"))


func test_progress_saves_and_reloads() -> void:
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	store.apply_rewards(RunRewards.compute(36000, 5, 4, 0, _progression()))
	store.add_currency(0, 80)
	store.add_ticket(Grade.HERO)
	store.unlock(&"clock")
	assert_true(store.spend_diamonds(20))
	assert_false(store.spend_diamonds(1000), "not enough")
	var again: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq([again.level, again.experience, again.coins, again.diamonds], [12, 300, 365, 80 - 20])
	assert_eq(again.ticket_count(Grade.HERO), 1)
	assert_true(again.is_unlocked(&"clock"))
	assert_eq(SaveData.new(TEST_SAVE).loaded_version(), SaveData.CURRENT_VERSION)


func test_progress_keeps_other_save_keys() -> void:
	BestScoreStore.new(TEST_SAVE).submit(900)
	CharacterStore.new(TEST_SAVE).select(&"clock")
	ProgressStore.new(TEST_SAVE).add_currency(100, 5)
	assert_eq(BestScoreStore.new(TEST_SAVE).best, 900)
	assert_eq(CharacterStore.new(TEST_SAVE).selected_id, &"clock")
	BestScoreStore.new(TEST_SAVE).submit(1000)
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 100)


func test_version_2_file_is_reset() -> void:
	var old: ConfigFile = ConfigFile.new()
	old.set_value("meta", "version", 2)
	old.set_value("score", "best", 4200)
	old.save(TEST_SAVE)
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq([store.level, store.coins], [1, 0])
	assert_eq(BestScoreStore.new(TEST_SAVE).best, 0, "old saves are reset (E26)")


# --- 부활 ---------------------------------------------------------------------

func _flow_with_diamonds(diamonds: int, duration: float = 1.0) -> GameFlow:
	var store: ProgressStore = ProgressStore.new(TEST_SAVE)
	store.add_currency(0, diamonds)
	var config: GameConfig = make_config()
	config.game_duration = duration
	var flow: GameFlow = GameFlow.new(config)
	flow.revive_policy = DiamondRevivePolicy.new(store, 20)
	flow.start_new_game(_rng())
	flow.request_move(Vector2i.ZERO)  # 시계 시작
	return flow


func test_diamond_revive_once_per_game() -> void:
	var flow: GameFlow = _flow_with_diamonds(50)
	flow.advance(1.5)
	assert_eq(flow.state, GameFlow.GameState.REVIVE, "enough diamonds → offer")
	assert_true(flow.accept_revive())
	assert_eq(ProgressStore.new(TEST_SAVE).diamonds, 30, "20 spent")
	assert_near(flow.session.remaining_time(), 10.0)
	for _i: int in 12:
		flow.advance(1.0)
	assert_eq(flow.state, GameFlow.GameState.RESULT, "only once per game")
	assert_eq(ProgressStore.new(TEST_SAVE).diamonds, 30)
	flow.retry(_rng(2))
	flow.request_move(Vector2i.ZERO)
	flow.advance(1.5)
	assert_eq(flow.state, GameFlow.GameState.REVIVE, "new game → can revive again")


func test_no_revive_without_enough_diamonds() -> void:
	var flow: GameFlow = _flow_with_diamonds(19)
	flow.advance(1.5)
	assert_eq(flow.state, GameFlow.GameState.RESULT)
	assert_eq(ProgressStore.new(TEST_SAVE).diamonds, 19)


func test_declined_revive_keeps_diamonds() -> void:
	var flow: GameFlow = _flow_with_diamonds(40)
	flow.advance(1.5)
	assert_true(flow.decline_revive())
	assert_eq(flow.state, GameFlow.GameState.RESULT)
	assert_eq(ProgressStore.new(TEST_SAVE).diamonds, 40)


# --- 기획서 ---------------------------------------------------------------------

func test_design_doc_matches_progression() -> void:
	var p: ProgressionConfig = _progression()
	var doc: String = FileAccess.get_file_as_string("res://docs/game_design.md")
	var tickets: PackedStringArray = PackedStringArray()
	var ticket_levels: Array = p.ticket_levels.keys()
	ticket_levels.sort()
	for level: int in ticket_levels:
		tickets.append("Lv%d %s" % [level, CharacterData.GRADE_NAMES[p.ticket_levels[level]]])
	var f: int = p.curve_from_level
	var rows: Array[String] = [
		"경험치 = 판마다 %d + %s × 점수" % [p.exp_per_game, str(p.exp_per_point).trim_suffix(".0")],
		"Lv%d 미만 `%d + %d × (Lv − 1)`, Lv%d부터 `%d + %d × (Lv − %d) + %s × (Lv − %d)²`" % [f, p.linear_base, p.linear_step,
			f, p.curve_base, p.curve_step, f, str(p.curve_square).trim_suffix(".0"), f],
		"레벨업 보상: 코인 %d + 다이아 %d (매 레벨 같음)" % [p.level_up_coins, p.level_up_diamonds],
		"레벨 마일스톤(%s)" % " · ".join(tickets),
		"부활: 다이아 %d" % p.revive_diamonds,
	]
	for i: int in p.stages.size():
		var stage: BoardStage = p.stages[i]
		var lengths: PackedStringArray = PackedStringArray()
		for length: int in stage.recipe_lengths:
			lengths.append(str(length))
		var level: String = str(i + 1) if i < p.stages.size() - 1 else "%d+" % (i + 1)
		rows.append("| %s | %d | %d장 (%s칸) | %s → %s초 | %s초 |" % [level, stage.color_count, stage.recipe_lengths.size(), "·".join(lengths),
			Ability.format_number(stage.refill_total_start), Ability.format_number(stage.refill_total_end), Ability.format_number(stage.game_duration)])
	for row: String in rows:
		assert_true(doc.contains(row), "doc has '%s'" % row)
