extends "res://tests/framework/test_case.gd"
## 5d 업적 (기획서 8.6 · 8.7장, 별첨 B): 업적 데이터와 능력 지표의 연결, 판 끝 평가(캐릭터 업적 단계 순서·공통 업적·
## 히든 진행), 보상, 저장, 능력이 남기는 지표, 기획서 표와 일치.

const TEST_SAVE: String = "user://test_achievements_save.cfg"


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _book() -> AchievementBook:
	return load("res://resources/achievements.tres") as AchievementBook


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
	session.start()
	return session


func _tracker() -> AchievementTracker:
	return AchievementTracker.new(_book(), AchievementStore.new(TEST_SAVE), ProgressStore.new(TEST_SAVE))


## 어디에도 매치가 없는 판: 색 = (x + 2y) mod 4.
func _plain_board(size: int, player: Vector2i) -> Board:
	var board: Board = Board.new(size)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, (pos.x + 2 * pos.y) % 4)
	board.set_player(player)
	return board


## 5x5, 플레이어 (2,3). UP 이동 시 (2,2)에서 color 매치.
func _match_ready_board(color: int) -> Board:
	var board: Board = _plain_board(5, Vector2i(2, 3))
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, color)
	return board


func _names(completions: Array[AchievementTracker.Completion]) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for completion: AchievementTracker.Completion in completions:
		names.append(completion.name)
	return names


# --- 데이터 ---------------------------------------------------------------------

func test_book_is_valid_and_covers_the_roster() -> void:
	var book: AchievementBook = _book()
	assert_true(book.validate().is_empty(), "%s" % [book.validate()])
	assert_eq([book.common.size(), book.chains.size(), book.hidden.size()], [6, 31, 3])
	var pending: Array[StringName] = []
	for character: CharacterData in _roster().characters:
		if book.chain_for(character.id) == null:
			pending.append(character.id)
	assert_eq(pending, [&"basic"] as Array[StringName],
		"only the basic character has no achievements (E42)")


## 업적이 보는 지표는 모두 누군가 남기는 지표다 (능력의 METRIC_* 또는 RunMetrics의 판 공통 지표).
func test_every_metric_is_produced() -> void:
	var known: Dictionary[StringName, bool] = {}
	for key: String in RunMetrics.new().get_script().get_script_constant_map():
		var value: Variant = RunMetrics.new().get_script().get_script_constant_map()[key]
		if value is StringName:
			known[value] = true
	for character: CharacterData in _roster().characters:
		if character.ability == null:
			continue
		var constants: Dictionary = (character.ability.get_script() as Script).get_script_constant_map()
		for key: String in constants:
			if key.begins_with("METRIC_"):
				known[constants[key]] = true
	for chain: CharacterAchievementChain in _book().chains:
		for metric: String in chain.metrics:
			assert_true(known.has(StringName(metric)), "%s uses a produced metric (%s)" % [chain.character_id, metric])
	for item: HiddenAchievement in _book().hidden:
		assert_true(known.has(item.metric), "hidden %s metric" % item.character_id)


func test_design_doc_matches_the_book() -> void:
	var book: AchievementBook = _book()
	var doc: String = FileAccess.get_file_as_string("res://docs/game_design.md")
	for chain: CharacterAchievementChain in book.chains:
		var row: String = "| %s | %s |" % [_roster().find(chain.character_id).display_name, " | ".join(chain.texts)]
		assert_true(doc.contains(row), "별첨 B row '%s'" % row)
	for item: CommonAchievement in book.common:
		var goals: PackedStringArray = PackedStringArray()
		for goal: int in item.goals:
			goals.append(AchievementTracker.format_count(goal))
		var row: String = "| %s | %s | %s |" % [item.name, item.text, " / ".join(goals)]
		assert_true(doc.contains(row), "8.6 row '%s'" % row)
	for item: HiddenAchievement in book.hidden:
		assert_true(doc.contains("| %s | %s |" % [_roster().find(item.character_id).display_name, item.text]), "8.7 %s" % item.character_id)
	assert_true(doc.contains("단계 보상 I 코인 %d · II 다이아 %d · III 다이아 %d" % [book.tier_coin(0), book.tier_diamond(1), book.tier_diamond(2)]))
	assert_true(doc.contains("입문 코인 %d · 숙련 다이아 %d · 극한 다이아 %d" % [book.tier_coin(0), book.tier_diamond(1), book.tier_diamond(2)]))


# --- 평가 ------------------------------------------------------------------------

func test_character_tiers_complete_in_order_and_are_claimed_by_hand() -> void:
	var session: GameSession = _session(&"gardener")
	session.metrics.record_max(GrowAllAbility.METRIC_GROWN_ONCE, 8)
	session.metrics.add(GrowAllAbility.METRIC_USES, 15)
	session.metrics.add(GrowAllAbility.METRIC_GROWN, 50)
	var completions: Array[AchievementTracker.Completion] = _tracker().record_game(session, 0)
	assert_eq(_names(completions), PackedStringArray(["정원사 입문", "정원사 숙련"]), "tier 2 opens after tier 1 in the same game")
	var store: AchievementStore = AchievementStore.new(TEST_SAVE)
	assert_true(store.is_done("gardener_1") and store.is_done("gardener_2") and not store.is_done("gardener_3"))
	assert_eq(store.progress_of("gardener_3"), 50, "progress kept")
	var progress: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq([progress.coins, progress.diamonds], [0, 0], "nothing paid until claimed (E38)")
	var tracker: AchievementTracker = _tracker()
	var status: Array[AchievementTracker.TierStatus] = tracker.chain_status(&"gardener")
	assert_eq([status[0].done, status[1].done, status[2].done, status[2].value, status[2].goal], [true, true, false, 50, 100])
	assert_true(status[0].can_claim() and status[1].can_claim() and not status[2].can_claim())
	assert_true(tracker.has_claimable())
	assert_true(tracker.claim(status[0]) and tracker.claim(status[1]))
	assert_false(tracker.claim(status[0]), "only once")
	assert_false(tracker.claim(status[2]), "not reached")
	progress = ProgressStore.new(TEST_SAVE)
	assert_eq([progress.coins, progress.diamonds], [100, 10], "입문 ● 100 + 숙련 ◆ 10")
	assert_false(_tracker().has_claimable(), "claims are saved")


func test_locked_tier_does_not_progress() -> void:
	var session: GameSession = _session(&"gardener")
	session.metrics.add(GrowAllAbility.METRIC_USES, 20)  # 숙련 조건만
	assert_eq(_tracker().record_game(session, 0).size(), 0)
	var store: AchievementStore = AchievementStore.new(TEST_SAVE)
	assert_eq([store.progress_of("gardener_1"), store.progress_of("gardener_2")], [0, 0], "tier 2 locked until tier 1")
	var status: Array[AchievementTracker.TierStatus] = _tracker().chain_status(&"gardener")
	assert_eq([status[0].open, status[1].open], [true, false])


func test_only_the_played_character_progresses() -> void:
	var session: GameSession = _session(&"clock")
	session.metrics.record_max(GrowAllAbility.METRIC_GROWN_ONCE, 100)
	assert_eq(_tracker().record_game(session, 0).size(), 0)
	assert_false(AchievementStore.new(TEST_SAVE).is_done("gardener_1"))


func test_common_achievements_accumulate_over_games() -> void:
	for i: int in 10:
		var session: GameSession = _session(&"basic")
		session.stats.blocks_cleared = 40
		var completions: Array[AchievementTracker.Completion] = _tracker().record_game(session, 0)
		if i == 9:
			assert_true(_names(completions).has("단골 I"), "10 games")
		if i == 7:
			assert_true(_names(completions).has("블록 부수기 I"), "320 blocks ≥ 300 on the 8th game (%s)" % [_names(completions)])
	var store: AchievementStore = AchievementStore.new(TEST_SAVE)
	assert_eq([store.stat("games"), store.stat("blocks")], [10, 400])
	var tracker: AchievementTracker = _tracker()
	var games: AchievementTracker.TierStatus = tracker.common_status(_book().common[3], 0)
	assert_eq([games.name, games.value, games.goal, games.can_claim()], ["단골 I", 10, 10, true], "reached tier waits for the claim")
	assert_true(tracker.claim(games))
	games = tracker.common_status(_book().common[3], 0)
	assert_eq([games.name, games.text, games.value, games.goal, games.can_claim()], ["단골 II", "플레이한 판 100", 10, 100, false], "next tier shown after claiming")


func test_best_score_and_owned_characters() -> void:
	var progress: ProgressStore = ProgressStore.new(TEST_SAVE)
	for id: StringName in [&"gardener", &"clock", &"twins", &"wall", &"zeus"]:
		progress.unlock(id)
	var tracker: AchievementTracker = AchievementTracker.new(_book(), AchievementStore.new(TEST_SAVE), progress)
	assert_eq(_names(tracker.check_common(5000)), PackedStringArray(["최고 기록 I", "수집가 I"]))
	assert_eq(tracker.check_common(5000).size(), 0, "once")
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 0, "reaching pays nothing")
	assert_eq(_names(_tracker().check_common(12000)), PackedStringArray(["최고 기록 II"]))
	var fresh: AchievementTracker = _tracker()
	assert_true(fresh.claim(fresh.common_status(_book().common[2], 12000)))
	assert_true(fresh.claim(fresh.common_status(_book().common[2], 12000)))
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 100, "최고 기록 I ● 100")
	var best: AchievementTracker.TierStatus = fresh.common_status(_book().common[2], 12000)
	assert_eq([best.name, best.value, best.goal, best.done], ["최고 기록 III", 12000, 20000, false], "next tier after II")


func test_hidden_achievement_below_goal_only_records_progress() -> void:
	var session: GameSession = _session(&"basic")
	session.metrics.add(RunMetrics.STRAIGHT_MATCHES, 4)
	assert_eq(_tracker().record_game(session, 0).size(), 0, "4 of 5")
	var store: AchievementStore = AchievementStore.new(TEST_SAVE)
	assert_eq(store.progress_of("h_pachy"), 4)
	assert_false(store.is_done("h_pachy"))
	assert_false(ProgressStore.new(TEST_SAVE).is_unlocked(&"pachy"))


func test_hidden_achievement_unlocks_its_character_once() -> void:
	var session: GameSession = _session(&"basic")
	session.metrics.add(RunMetrics.STRAIGHT_MATCHES, 5)
	var completions: Array[AchievementTracker.Completion] = _tracker().record_game(session, 0)
	assert_eq(_names(completions), PackedStringArray(["돌머리"]))
	assert_false(completions[0].needs_claim, "the character is unlocked right away")
	assert_eq(GameController.achievement_lines(completions), [PackedStringArray(["업적 돌머리", "히든 캐릭터"])] as Array[PackedStringArray])
	assert_true(AchievementStore.new(TEST_SAVE).is_done("h_pachy"))
	assert_true(ProgressStore.new(TEST_SAVE).is_unlocked(&"pachy"))
	assert_false(ProgressStore.new(TEST_SAVE).is_unlocked(&"racer"), "only the achieved one")
	var again: GameSession = _session(&"basic")
	again.metrics.add(RunMetrics.STRAIGHT_MATCHES, 9)
	assert_eq(_tracker().record_game(again, 0).size(), 0, "already done")


func test_result_lines() -> void:
	var completions: Array[AchievementTracker.Completion] = [AchievementTracker.Completion.new("단골 I", "● 100")]
	assert_eq(GameController.achievement_lines(completions), [PackedStringArray(["업적 단골 I", "업적에서 받기"])] as Array[PackedStringArray], "the reward is claimed on the achievement screen")
	assert_eq([AchievementTracker.format_count(30000), AchievementTracker.format_count(500), AchievementTracker.format_count(1234567)],
		["30,000", "500", "1,234,567"])


# --- 지표 ------------------------------------------------------------------------

func test_run_metrics_movement_habits() -> void:
	var metrics: RunMetrics = RunMetrics.new()
	for _i: int in 4:
		metrics.on_move(Vector2i.RIGHT)
	metrics.on_move_match()
	assert_eq(metrics.value(RunMetrics.STRAIGHT_MATCHES), 0, "4 in a row is not enough")
	metrics.on_move(Vector2i.RIGHT)
	metrics.on_move_match()
	assert_eq(metrics.value(RunMetrics.STRAIGHT_MATCHES), 1, "5 in a row")
	metrics.on_move(Vector2i.LEFT)
	metrics.on_move(Vector2i.LEFT)
	assert_eq(metrics.value(RunMetrics.BOTH_SIDES_MOVES), 2, "min(left 2, right 5)")
	metrics.record_max(&"x", 3)
	metrics.record_max(&"x", 2)
	assert_eq(metrics.value(&"x"), 3)


func test_session_fills_common_metrics() -> void:
	var session: GameSession = _session(&"basic", _match_ready_board(1))
	session.request_move(Vector2i.UP)
	assert_eq(session.stats.blocks_cleared, 4)
	session.advance(2.0)
	session.metrics.fill_from_session(session)
	assert_eq(session.metrics.value(RunMetrics.MATCHES), 1)
	assert_eq(session.metrics.value(RunMetrics.MOVES_PER_SECOND_X100), 50, "1 move in 2 s")


func test_gardener_reports_grown_seeds() -> void:
	var session: GameSession = _session(&"gardener")
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		session.board.set_seed(pos, 1, 1.0, 1.0)
	session.ability.trigger(session)
	assert_eq([session.metrics.value(GrowAllAbility.METRIC_GROWN_ONCE), session.metrics.value(GrowAllAbility.METRIC_USES),
		session.metrics.value(GrowAllAbility.METRIC_GROWN)], [3, 1, 3])


func test_clock_counts_matches_during_one_stop() -> void:
	var session: GameSession = _session(&"clock", _match_ready_board(1))
	session.ability.trigger(session)
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.request_move(Vector2i.UP)
	assert_eq(session.metrics.value(TimeStopAbility.METRIC_STOP_MATCHES), 1)
	session.advance(5.0)  # 정지 끝
	(session.ability as TimeStopAbility).trigger(session)
	assert_eq(session.metrics.value(TimeStopAbility.METRIC_STOP_MATCHES), 1, "a new stop starts again from 0 (max kept)")


func test_wall_counts_pure_wall_recipes() -> void:
	var board: Board = _plain_board(5, Vector2i(1, 2))
	for pos: Vector2i in [Vector2i(0, 1), Vector2i(0, 3), Vector2i(0, 2)]:
		board.set_color_block(pos, 1)
	var session: GameSession = _session(&"wall", board)
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.request_move(Vector2i.LEFT)
	assert_eq(session.metrics.value(WallAbility.METRIC_WALL_MATCHES), 1)
	assert_eq(session.metrics.value(WallAbility.METRIC_WALLS), 1)
	assert_eq(session.metrics.value(WallAbility.METRIC_PURE_RECIPES), 1, "completed by a wall match")


func test_bounty_counts_hunts() -> void:
	var session: GameSession = _session(&"bounty", _match_ready_board(1))
	(session.ability as BountyAbility).bounty_color = 1
	session.request_move(Vector2i.UP)
	assert_eq(session.metrics.value(BountyAbility.METRIC_HUNTS), 1)
