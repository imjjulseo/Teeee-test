extends "res://tests/framework/test_case.gd"
## 캐릭터 선택과 능력 (기획서 5.2장, 3단계에서 HTML 기준으로 전환). 색 ID: 0 노랑, 1 빨강, 2 파랑, 3 초록 (E16).

const TEST_SAVE: String = "user://test_character_save.cfg"


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _session(id: StringName, board: Board = null) -> GameSession:
	var config: GameConfig = make_config()
	if board != null:
		config.board_size = board.size
	var session: GameSession = GameSession.new(config, _rng(), board, _roster().find(id))
	session.start()  # 시계 시작 (첫 이동 없이)
	return session


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## 5x5, 플레이어 (2,3). UP 이동 시 (2,2)에서 색 1 매치.
func _match_ready_board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 3))
	return board


func _run(session: GameSession, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


## 캐릭터 족보를 순서대로 깨서 발동한다.
func _trigger(session: GameSession) -> void:
	for color: int in session.character.condition_colors:
		session.advance_ability_condition(color)


# --- 데이터 -----------------------------------------------------------------

func test_roster_ids_in_order_without_alchemist() -> void:
	var ids: Array[StringName] = []
	for character: CharacterData in _roster().characters:
		ids.append(character.id)
	assert_eq(ids, [&"basic", &"gardener", &"twins", &"clock", &"artisan", &"wall", &"marathon", &"bounty",
		&"gambler", &"painter", &"joker", &"navigator", &"explorer", &"bomber", &"fever", &"mirror", &"poseidon",
		&"colorblind", &"retro", &"architect", &"wanderer", &"seer", &"runner", &"sewer", &"zeus",
		&"photo", &"arson", &"madan", &"vampire", &"racer", &"pachy", &"ambi"] as Array[StringName], "기획서 5.2장 표 순서")
	assert_eq(_roster().default_character().id, &"basic", "basic is the default")


func test_characters_as_specified() -> void:
	# id: [이름, 능력 클래스, 캐릭터 족보, 캐릭터 색(HTML)]
	var expected: Dictionary = {
		&"gardener": ["정원사", "GrowAllAbility", [0, 1], Color("C6F36B")],
		&"clock": ["시계공", "TimeStopAbility", [2, 3, 2], Color("F7E27A")],
		&"gambler": ["도박사", "AllInAbility", [1, 1, 1], Color("56E6E6")],
		&"fever": ["축제꾼", "FeverAbility", [3, 0, 2], Color("FF7A45")],
		&"joker": ["조커", "WildAbility", [0, 1, 2, 3, 0], Color("FF6FD8")],
	}
	for id: StringName in expected:
		var spec: Array = expected[id]
		var character: CharacterData = _roster().find(id)
		assert_eq(character.id, id)
		assert_eq(character.display_name, spec[0])
		assert_eq((character.ability.get_script() as Script).get_global_name(), StringName(spec[1]), "%s class" % id)
		assert_eq(character.condition_colors, PackedInt32Array(spec[2]), "%s recipe" % id)
		assert_true(character.accent_color.is_equal_approx(spec[3]), "%s color" % id)
		assert_true(character.player_border.is_equal_approx(spec[3]), "%s player border = character color" % id)
		assert_true(character.ability_description.begins_with(character.ability_name), "%s description starts with the name" % id)
	var basic: CharacterData = _roster().find(&"basic")
	assert_false(basic.has_ability())
	assert_eq(basic.ability, null)


func test_ability_values_as_specified() -> void:
	assert_near((_roster().find(&"clock").ability as TimeStopAbility).duration, 4.0)
	var gambler: AllInAbility = _roster().find(&"gambler").ability as AllInAbility
	assert_eq([gambler.multiplier, gambler.max_charges], [2, 2])
	var fever: FeverAbility = _roster().find(&"fever").ability as FeverAbility
	assert_near(fever.duration, 10.0)
	assert_eq(fever.stack_points, 50)
	assert_near(fever.refill_rate, 2.0)
	assert_eq((_roster().find(&"joker").ability as WildAbility).charges_per_trigger, 2)


func test_unknown_id_falls_back_to_default() -> void:
	assert_eq(_roster().find(&"nobody").id, &"basic")
	assert_eq(_roster().find(&"").id, &"basic")
	assert_eq(_roster().find(&"alchemist").id, &"basic", "alchemist is not ported (E18)")


# --- 저장 -------------------------------------------------------------------

func test_selection_is_saved_and_keeps_best_score() -> void:
	_clean()
	BestScoreStore.new(TEST_SAVE).submit(600)
	assert_eq(CharacterStore.new(TEST_SAVE).selected_id, &"", "nothing selected yet")
	CharacterStore.new(TEST_SAVE).select(&"clock")
	assert_eq(CharacterStore.new(TEST_SAVE).selected_id, &"clock", "reloaded from disk")
	assert_eq(BestScoreStore.new(TEST_SAVE).best, 600, "best score kept")
	BestScoreStore.new(TEST_SAVE).submit(1000)
	assert_eq(CharacterStore.new(TEST_SAVE).selected_id, &"clock", "selection kept after best score save")
	_clean()


# --- 공통: 캐릭터 족보 --------------------------------------------------------

func test_basic_character_has_no_ability_recipe() -> void:
	var session: GameSession = _session(&"basic")
	assert_eq(session.ability_recipe, null)
	session.advance_ability_condition(1)  # 오류 없이 무시
	assert_eq(session.ability, null)
	assert_false(session.is_clock_stopped())


func test_condition_follows_recipe_rules_and_repeats() -> void:
	var session: GameSession = _session(&"gardener")
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	session.advance_ability_condition(1)  # 빨강 먼저 → 다음 필요 색(노랑)이 아니므로 무시
	assert_eq(session.ability_recipe.progress, 0)
	session.advance_ability_condition(0)  # 노랑
	assert_eq(session.ability_recipe.progress, 1)
	session.advance_ability_condition(2)  # 다른 색 → 무시, 진행 유지
	assert_eq(session.ability_recipe.progress, 1, "wrong color does not reset")
	session.advance_ability_condition(1)  # 빨강 → 발동
	assert_eq(messages, ["촉진: 씨앗 전부 성장"] as Array[String], "trigger message")
	assert_eq(session.ability_recipe.progress, 0, "progress resets after trigger")
	session.advance_ability_condition(0)
	session.advance_ability_condition(1)
	assert_eq(messages.size(), 2, "ability can trigger again")
	assert_eq(session.stats.ability_triggers, 2)


func test_condition_gives_no_score() -> void:
	var session: GameSession = _session(&"gardener")
	_trigger(session)
	assert_eq(session.score, 0)


## E11: 효과가 켜져 있는 동안에도 캐릭터 족보는 진행되고 다시 발동한다 (HTML 규칙).
func test_condition_progresses_and_retriggers_during_an_effect() -> void:
	var session: GameSession = _session(&"clock")
	_trigger(session)
	_run(session, 1.0)
	session.advance_ability_condition(2)
	assert_eq(session.ability_recipe.progress, 1, "progresses while stopped")
	session.advance_ability_condition(3)
	session.advance_ability_condition(2)
	assert_near((session.ability as TimeStopAbility).time_left, 7.0, 1e-6, "3s left + 4s")


# --- 정원사: 촉진 ------------------------------------------------------------

func test_gardener_completes_all_growing_blocks() -> void:
	var session: GameSession = _session(&"gardener")
	var board: Board = session.board
	board.set_seed(Vector2i(0, 0), 2, 1.0, 1.0)
	board.set_seed(Vector2i(6, 6), 3, 0.0, 0.5)
	var refilled: Array = []
	session.cells_refilled.connect(func(cells: Array[Vector2i]) -> void: refilled.append(cells))
	session.advance_ability_condition(0)
	assert_eq(board.count_type(Board.CellType.SEED), 2, "not yet")
	session.advance_ability_condition(1)
	assert_eq(board.count_type(Board.CellType.SEED), 0)
	assert_eq(board.get_cell_type(Vector2i(0, 0)), Board.CellType.COLOR_BLOCK)
	assert_eq(board.get_color(Vector2i(0, 0)), 2, "grows into its pending color")
	assert_eq(board.get_color(Vector2i(6, 6)), 3)
	assert_eq(refilled.size(), 1)
	assert_eq((refilled[0] as Array).size(), 2)


func test_gardener_via_real_match_grows_everything_without_extra_match() -> void:
	var session: GameSession = _session(&"gardener", _match_ready_board())
	session.ability_recipe = RecipeSet.Recipe.new(PackedInt32Array([1]), 0)  # 이번 매치(색 1)로 발동
	session.board.set_seed(Vector2i(0, 0), 2, 1.0, 1.0)
	var matches: Array[int] = [0]
	session.matched.connect(func(_c: Vector2i, _col: int, _cells: Array[Vector2i]) -> void: matches[0] += 1)
	session.request_move(Vector2i.UP)
	assert_eq(session.board.count_type(Board.CellType.SEED), 0, "matched 4 + existing seeds all grown")
	assert_eq(matches[0], 1, "grown blocks are not auto-judged")
	_run(session, 1.0)
	assert_eq(matches[0], 1)


# --- 시계공: 정지 4초 --------------------------------------------------------

func test_clock_stops_timer_for_4_seconds() -> void:
	var session: GameSession = _session(&"clock")
	_run(session, 10.0)
	var remaining: float = session.remaining_time()
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	_trigger(session)
	assert_eq(messages, ["정지: 4초"] as Array[String])
	assert_true(session.is_clock_stopped())
	_run(session, 3.9)
	assert_near(session.remaining_time(), remaining, 1e-9, "time does not decrease while stopped")
	_run(session, 0.1 + 1.0)
	assert_false(session.is_clock_stopped())
	assert_near(session.remaining_time(), remaining - 1.0, 1e-6, "clock resumes after 4s")


func test_clock_stop_splits_inside_a_frame() -> void:
	var session: GameSession = _session(&"clock")
	_trigger(session)
	session.advance(7.0)  # 한 프레임에 4초 정지 + 3초 진행
	assert_near(session.remaining_time(), 57.0, 1e-9)


func test_clock_retrigger_adds_time() -> void:
	var session: GameSession = _session(&"clock")
	_trigger(session)
	_run(session, 2.0)
	_trigger(session)
	assert_near((session.ability as TimeStopAbility).time_left, 6.0, 1e-6, "2s left + 4s")


func test_clock_stop_is_frame_rate_independent() -> void:
	var results: Array[float] = []
	for fps: int in [30, 60, 120]:
		var session: GameSession = _session(&"clock")
		_run(session, 3.0, 1.0 / fps)
		_trigger(session)
		_run(session, 9.0, 1.0 / fps)
		results.append(session.remaining_time())
	assert_near(results[0], results[1], 1e-6)
	assert_near(results[1], results[2], 1e-6)


func test_refill_keeps_growing_during_time_stop() -> void:
	var session: GameSession = _session(&"clock")
	session.board.set_seed(Vector2i(0, 0), 1, 1.0, 1.0)
	_trigger(session)
	_run(session, 2.1)
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.COLOR_BLOCK, "only the game timer stops")


func test_time_stop_does_not_count_during_pause_or_waiting() -> void:
	var flow: GameFlow = GameFlow.new(make_config(), _roster().find(&"clock"))
	flow.start_new_game(_rng())
	_trigger(flow.session)
	for _i: int in 3:
		flow.advance(0.5)  # 첫 이동 전: 정지 시간 소모 안 함
	assert_near((flow.session.ability as TimeStopAbility).time_left, 4.0, 1e-9)
	flow.request_move(Vector2i.ZERO)  # 잘못된 방향: 판은 그대로 두고 시계만 시작
	flow.pause()
	flow.advance(10.0)
	assert_near((flow.session.ability as TimeStopAbility).time_left, 4.0, 1e-9, "paused")
	flow.resume()
	flow.advance(1.0)
	assert_near((flow.session.ability as TimeStopAbility).time_left, 3.0, 1e-9)


func test_flow_passes_character_and_keeps_it_on_retry() -> void:
	var config: GameConfig = make_config()
	config.game_duration = 1.0
	var clock: CharacterData = _roster().find(&"clock")
	var flow: GameFlow = GameFlow.new(config, clock)
	flow.start_new_game(_rng())
	flow.request_move(Vector2i.ZERO)  # 시계 시작 (판은 그대로)
	assert_eq(flow.session.character, clock)
	flow.session.ability_recipe.progress = 2
	for _i: int in 5:
		flow.advance(1.0)
	assert_eq(flow.state, GameFlow.GameState.RESULT)
	flow.retry(_rng(2))
	assert_eq(flow.session.character, clock)
	assert_eq(flow.session.ability_recipe.progress, 0, "condition progress reset on retry")
	assert_near((flow.session.ability as TimeStopAbility).time_left, 0.0)


# --- 도박사: 올인 ×2, 최대 2번 ------------------------------------------------

func _gambler_with_recipes() -> GameSession:
	var session: GameSession = _session(&"gambler")
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([3, 3, 3, 3]))
	return session


func test_gambler_doubles_next_completed_recipe() -> void:
	var session: GameSession = _gambler_with_recipes()
	_trigger(session)
	var ability: AllInAbility = session.ability as AllInAbility
	assert_eq(ability.charges, 1)
	assert_eq(ability.status_text(), "×2")
	session.apply_clear_to_recipes(1)  # 진행만, 완성 없음 → 기회 유지
	assert_eq(session.score, 0)
	assert_eq(ability.charges, 1, "kept until a recipe completes")
	session.apply_clear_to_recipes(2)  # 슬롯0 완성 100 × 2
	assert_eq(session.score, 200)
	assert_eq(ability.charges, 0, "consumed")
	assert_eq(ability.status_text(), "")
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.apply_clear_to_recipes(1)
	assert_eq(session.score, 325, "only the next completion is doubled")


func test_gambler_charges_stack_up_to_two() -> void:
	var session: GameSession = _gambler_with_recipes()
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	for _i: int in 3:
		_trigger(session)
	var ability: AllInAbility = session.ability as AllInAbility
	assert_eq(ability.charges, 2, "capped at 2")
	assert_eq(messages, ["올인: 다음 완성 족보 ×2", "올인: 다음 완성 ×2 (2회)", "올인: 다음 완성 ×2 (2회)"] as Array[String])
	assert_eq(ability.status_text(), "×2 (2)")
	session.apply_clear_to_recipes(1)
	session.apply_clear_to_recipes(2)  # 완성 1번 → 기회 1번만 씀
	assert_eq(ability.charges, 1)
	assert_eq(session.score, 200)


func test_gambler_triggering_clear_is_not_multiplied() -> void:
	# 올인을 발동시킨 매치(빨강) 자체가 족보를 완성해도 배수는 다음 완성부터.
	var session: GameSession = _session(&"gambler", _match_ready_board())
	session.ability_recipe.progress = 2  # 빨강 하나 더 → 발동
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.request_move(Vector2i.UP)
	assert_eq(session.score, 125)
	assert_eq((session.ability as AllInAbility).charges, 1)


func test_gambler_simultaneous_completion_doubles_total_with_one_charge() -> void:
	var session: GameSession = _session(&"gambler")
	session.recipes.set_recipe_colors(0, PackedInt32Array([2, 2]))
	session.recipes.recipes[0].progress = 1
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 2]))
	session.recipes.recipes[1].progress = 2
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 0]))
	_trigger(session)
	_trigger(session)
	var outcomes: Array = []
	session.recipes_updated.connect(func(_r: RecipeSet, o: RecipeSet.ClearOutcome) -> void: outcomes.append(o.points))
	session.apply_clear_to_recipes(2)
	assert_eq(session.score, (125 + 375) * 2)
	assert_eq(outcomes, [1000], "HUD receives the multiplied points")
	assert_eq((session.ability as AllInAbility).charges, 1, "one charge per completing clear")


# --- 축제꾼: 피버 -------------------------------------------------------------

func _fever(session: GameSession) -> FeverAbility:
	return session.ability as FeverAbility


func test_fever_payout_formula() -> void:
	var fever: FeverAbility = _roster().find(&"fever").ability as FeverAbility
	assert_eq([fever.payout(0), fever.payout(1), fever.payout(5), fever.payout(10), fever.payout(15)],
		[0, 50, 750, 2750, 6000])


func test_fever_stacks_on_every_match_and_pays_at_the_end() -> void:
	var session: GameSession = _session(&"fever")
	var bonuses: Array = []
	session.bonus_scored.connect(func(points: int, label: String) -> void: bonuses.append([points, label]))
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	_trigger(session)
	assert_eq(messages, ["피버 10초"] as Array[String])
	assert_true(_fever(session).is_active())
	for color: int in [0, 1, 2, 3, 1]:  # 색 무관 매치 5번
		_fever(session).on_match(session, color, [] as Array[Vector2i])
	assert_eq(_fever(session).stacks, 5)
<<<<<<< HEAD
	assert_eq(_fever(session).status_text(), "10초 / 5스택")
=======
	assert_eq(_fever(session).status_text(), "10초 · 5스택")
>>>>>>> Choi
	session.apply_clear_to_recipes(1)
	assert_eq(session.recipes.recipes[0].progress, 1, "recipes progress as usual during fever")
	_run(session, 9.9)
	assert_eq(bonuses.size(), 0, "not yet")
	_run(session, 0.2)
	assert_eq(bonuses, [[750, "피버 5스택!"]])
	assert_eq(session.score, 750)
	assert_eq(session.stats.score_by_time[0], 750, "counted in play-log score buckets")
	assert_false(_fever(session).is_active())
	assert_eq(_fever(session).status_text(), "")


func test_fever_triggering_match_is_not_stacked_but_next_matches_are() -> void:
	var session: GameSession = _session(&"fever", _match_ready_board())
	session.ability_recipe.progress = 2
	session.ability_recipe.colors[2] = 1  # 이번 매치(빨강)로 발동
	session.request_move(Vector2i.UP)
	assert_true(_fever(session).is_active())
	assert_eq(_fever(session).stacks, 0, "the match that started the fever does not count")


func test_fever_doubles_refill_speed_only_while_active() -> void:
	var session: GameSession = _session(&"fever")
	session.board.set_seed(Vector2i(0, 0), 1, 0.0, 4.0)  # 자람 4초
	session.board.set_seed(Vector2i(6, 6), 2, 0.0, 30.0)
	_trigger(session)
	_run(session, 2.05)
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.COLOR_BLOCK, "4s of growth in 2s")
	_run(session, 7.95)  # 피버 끝 (10초) → 리필 시계 20초 진행
	var left: float = session.board.get_cell(Vector2i(6, 6)).seed_remaining
	assert_near(left, 10.0, 1e-6)
	_run(session, 1.0)
	assert_near(session.board.get_cell(Vector2i(6, 6)).seed_remaining, 9.0, 1e-6, "back to normal speed")


func test_fever_end_is_frame_rate_independent() -> void:
	var results: Array = []
	for frame: float in [1.0 / 30.0, 1.0 / 120.0, 0.25, 3.0]:
		var session: GameSession = _session(&"fever")
		session.board.set_seed(Vector2i(6, 6), 2, 0.0, 30.0)
		_trigger(session)
		_fever(session).on_match(session, 0, [] as Array[Vector2i])
		var at: Array[float] = [-1.0]
		var session_ref: WeakRef = weakref(session)
		session.bonus_scored.connect(func(_p: int, _l: String) -> void: at[0] = (session_ref.get_ref() as GameSession).elapsed)
		_run(session, 15.0, frame)
		results.append([snappedf(at[0], 1e-6), snappedf(session.board.get_cell(Vector2i(6, 6)).seed_remaining, 1e-6)])
	assert_eq(results[0], [10.0, 5.0], "paid at 10 s, refill 20 + 5 = 25 s")
	for result: Array in results:
		assert_eq(result, results[0])


func test_fever_retrigger_extends_and_keeps_stacks() -> void:
	var session: GameSession = _session(&"fever")
	_trigger(session)
	_fever(session).on_match(session, 0, [] as Array[Vector2i])
	_run(session, 4.0)
	_trigger(session)
	assert_near(_fever(session).time_left, 16.0, 1e-6, "6s left + 10s")
	assert_eq(_fever(session).stacks, 1, "stacks kept")
	_run(session, 16.1)
	assert_eq(session.score, 50)


func test_fever_is_settled_when_the_game_ends() -> void:
	var config: GameConfig = make_config()
	config.game_duration = 2.0
	var flow: GameFlow = GameFlow.new(config, _roster().find(&"fever"))
	flow.start_new_game(_rng())
	var results: Array[int] = []
	var flow_ref: WeakRef = weakref(flow)  # 람다가 flow를 붙잡으면 순환 참조로 누수된다
	flow.state_changed.connect(func(s: GameFlow.GameState) -> void:
		if s == GameFlow.GameState.RESULT:
			results.append((flow_ref.get_ref() as GameFlow).session.score))
	flow.request_move(Vector2i.ZERO)
	_trigger(flow.session)
	for _i: int in 3:
		_fever(flow.session).on_match(flow.session, 2, [] as Array[Vector2i])
	flow.advance(5.0)
	assert_eq(flow.state, GameFlow.GameState.RESULT)
	assert_eq(results, [300] as Array[int], "result already includes the fever payout")
	flow.session.finish()
	assert_eq(flow.session.score, 300, "settled only once")


func test_fever_does_not_run_while_paused() -> void:
	var flow: GameFlow = GameFlow.new(make_config(), _roster().find(&"fever"))
	flow.start_new_game(_rng())
	flow.request_move(Vector2i.ZERO)
	_trigger(flow.session)
	flow.pause()
	flow.advance(30.0)
	assert_near(_fever(flow.session).time_left, 10.0, 1e-9)


func test_abandoned_game_does_not_settle_fever() -> void:
	var flow: GameFlow = GameFlow.new(make_config(), _roster().find(&"fever"))
	flow.start_new_game(_rng())
	flow.request_move(Vector2i.ZERO)
	_trigger(flow.session)
	_fever(flow.session).on_match(flow.session, 2, [] as Array[Vector2i])
	flow.pause()
	flow.abandon()
	assert_eq(flow.session.score, 0)


# --- 조커: 와일드 2번, 누적 -----------------------------------------------------

func test_joker_wild_advances_all_recipes_for_two_matches() -> void:
	var session: GameSession = _session(&"joker")
	session.recipes.set_recipe_colors(0, PackedInt32Array([0, 1]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([2, 2, 2]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([3, 3, 3, 3]))
	session.recipes.recipes[0].progress = 1  # 다음 한 칸이면 완성
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	_trigger(session)
	var wild: WildAbility = session.ability as WildAbility
	assert_eq(messages, ["와일드 2회 준비"] as Array[String])
	assert_eq(wild.status_text(), "와일드 2")
	session.apply_clear_to_recipes(1)  # 빨강 매치지만 색 무관 전체 진행
	assert_eq(session.score, 100, "slot 0 completed by wild")
	assert_eq(session.recipes.recipes[1].progress, 1, "slot 1 advanced despite color")
	assert_eq(session.recipes.recipes[2].progress, 1, "slot 2 advanced despite color")
	assert_eq(wild.status_text(), "와일드")
	session.apply_clear_to_recipes(1)
	assert_eq(session.recipes.recipes[2].progress, 2, "second wild")
	assert_eq(wild.charges, 0)
	session.apply_clear_to_recipes(0)  # 이제 일반 규칙 → 3, 4칸 족보 진행 없음
	assert_eq(session.recipes.recipes[1].progress, 2)
	assert_eq(session.recipes.recipes[2].progress, 2)


func test_joker_charges_accumulate() -> void:
	var session: GameSession = _session(&"joker")
	_trigger(session)
	_trigger(session)
	assert_eq((session.ability as WildAbility).charges, 4)


func test_joker_condition_still_advances_by_the_real_color() -> void:
	var session: GameSession = _session(&"joker", _match_ready_board())
	(session.ability as WildAbility).charges = 1
	session.ability_recipe.progress = 1  # 다음 색: 빨강
	session.request_move(Vector2i.UP)  # 빨강 매치 (와일드로 족보 진행)
	assert_eq((session.ability as WildAbility).charges, 0)
	assert_eq(session.ability_recipe.progress, 2, "character recipe uses the matched color")


# --- 능력 클래스 구조 ----------------------------------------------------------

func test_ability_state_is_per_session_not_in_shared_resource() -> void:
	var clock: CharacterData = _roster().find(&"clock")
	var original: TimeStopAbility = clock.ability as TimeStopAbility
	var first: GameSession = _session(&"clock")
	_trigger(first)
	assert_true(first.ability != original, "session uses its own copy")
	assert_near((first.ability as TimeStopAbility).time_left, 4.0)
	assert_near(original.time_left, 0.0, 1e-9, "shared resource untouched")
	var second: GameSession = _session(&"clock")
	assert_near((second.ability as TimeStopAbility).time_left, 0.0, 1e-9, "new session starts clean")
	assert_near((second.ability as TimeStopAbility).duration, 4.0, 1e-9, "exported values copied")


func test_background_effect_only_for_timed_effects() -> void:
	var clock: GameSession = _session(&"clock")
	assert_true(clock.ability.effect_remaining() < 0.0)
	_trigger(clock)
	assert_near(clock.ability.effect_remaining(), 4.0)
	assert_eq(clock.ability.effect_block_color(), Board.NO_COLOR, "character color by default")
	var gambler: GameSession = _session(&"gambler")
	_trigger(gambler)
	assert_true(gambler.ability.effect_remaining() < 0.0, "waiting effects have no background")


func test_format_seconds() -> void:
	assert_eq([Ability.format_seconds(4.0), Ability.format_seconds(3.66), Ability.format_seconds(0.04), Ability.format_seconds(-1.0)],
		["4", "3.7", "0", "0"])
