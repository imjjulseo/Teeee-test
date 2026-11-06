extends "res://tests/framework/test_case.gd"
## 플레이 기록: 판 통계(SessionStats)와 CSV 기록(PlaytestLog).

const LOG_PATH: String = "user://test_playtest_log.csv"
const STEP: float = 0.12


func after_each() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 5x5, 플레이어 (2,3). UP 이동 시 (2,2)에서 색 1 매치.
func _match_ready_board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 3))
	return board


func _session() -> GameSession:
	var config: GameConfig = make_config()
	config.board_size = 5
	return GameSession.new(config, _rng(), _match_ready_board())


# --- 통계 -------------------------------------------------------------------

func test_stats_count_moves_blocks_matches_and_recipes() -> void:
	var session: GameSession = _session()
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.request_move(Vector2i.UP)  # 이동 + 매치 + 족보 완성 (125점)
	session.advance(STEP)
	for _i: int in 3:
		session.request_move(Vector2i.UP)  # (2,2) → (2,1) → (2,0) → 벽
		session.advance(STEP)
	var stats: SessionStats = session.stats
	assert_eq(stats.moves, 3)
	assert_eq(stats.blocked_moves, 1)
	assert_eq(stats.matches, 1)
	assert_eq(stats.recipes_completed, 1)
	assert_eq(stats.score_by_time, PackedInt32Array([125, 0, 0]))
	assert_near(stats.play_time, STEP * 4, 1e-6)
	assert_near(stats.max_remaining, 62.5, 1e-9, "the clear time raised the max remaining")


func test_stats_score_buckets_by_play_time() -> void:
	var stats: SessionStats = SessionStats.new()
	stats.add_score(200)
	stats.play_time = 30.0
	stats.add_score(600)
	stats.play_time = 59.9
	stats.add_score(200)
	stats.play_time = 75.0
	stats.add_score(1000)
	assert_eq(stats.score_by_time, PackedInt32Array([200, 800, 1000]))


func test_stats_count_ability_triggers_and_play_time_during_stop() -> void:
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var session: GameSession = GameSession.new(make_config(), _rng(), null, roster.find(&"clock"))
	session.request_move(Vector2i.UP)  # 시계 시작
	var remaining: float = session.remaining_time()
	for color: int in [2, 3, 2]:
		session.advance_ability_condition(color)
	session.advance(2.0)  # 정지 중: 남은 시간은 멈추지만 실제 플레이 시간은 흐른다
	assert_eq(session.stats.ability_triggers, 1)
	assert_near(session.stats.play_time, 2.0, 1e-9)
	assert_near(session.elapsed, 2.0, 1e-9)
	assert_near(session.remaining_time(), remaining, 1e-9)


# --- CSV ----------------------------------------------------------------------

func test_row_has_every_column_in_order() -> void:
	var session: GameSession = _session()
	var row: PackedStringArray = PlaytestLog.row_for(session, &"gambler", PlaytestLog.END_RESULT, "2026-09-28 12:00:00")
	assert_eq(row.size(), PlaytestLog.COLUMNS.size())
	assert_eq(row[0], "2026-09-28 12:00:00")
	assert_eq(row[1], str(session.base_seed))
	assert_eq(row[2], "gambler")
	assert_eq(row[3], "result")
	assert_eq(row[4], "0")
	assert_eq(PlaytestLog.row_for(session, &"", PlaytestLog.END_ABANDONED)[2], "none", "no character")


func test_append_writes_header_once_then_rows() -> void:
	var session: GameSession = _session()
	assert_true(PlaytestLog.append(PlaytestLog.row_for(session, &"basic", PlaytestLog.END_RESULT), LOG_PATH))
	assert_true(PlaytestLog.append(PlaytestLog.row_for(session, &"joker", PlaytestLog.END_ABANDONED), LOG_PATH))
	var lines: PackedStringArray = FileAccess.get_file_as_string(LOG_PATH).strip_edges().split("\n")
	assert_eq(lines.size(), 3, "header + 2 rows")
	assert_eq(lines[0], ",".join(PlaytestLog.COLUMNS))
	assert_eq(lines[1].split(",")[2], "basic")
	assert_eq(lines[2].split(",")[3], "abandoned")
	for line: String in lines:
		assert_eq(line.split(",").size(), PlaytestLog.COLUMNS.size(), "every line has all columns")


func test_override_path_is_used_when_no_path_given() -> void:
	PlaytestLog.path_override = LOG_PATH
	PlaytestLog.append(PlaytestLog.row_for(_session(), &"basic", PlaytestLog.END_RESULT))
	PlaytestLog.path_override = ""
	assert_true(FileAccess.file_exists(LOG_PATH))


func test_logging_can_be_turned_off() -> void:
	var config: GameConfig = make_config()
	assert_eq(PlaytestLog.is_enabled(config), OS.is_debug_build(), "on by default in debug builds")
	config.playtest_logging = false
	assert_false(PlaytestLog.is_enabled(config))
	assert_false(PlaytestLog.is_enabled(null))


# --- 7b: 10.1장 지표 --------------------------------------------------------------

func test_moves_per_match_buckets() -> void:
	var stats: SessionStats = SessionStats.new()
	for moves: int in [0, 3, 4, 5, 7, 8, 12]:
		for _i: int in moves:
			stats.count_move()
		stats.record_match_moves()
	assert_eq(stats.match_moves, PackedInt32Array([3, 2, 2]), "0·3·4 / 5·7 / 8·12")
	assert_eq(stats.measured_matches(), 7)
	assert_near(stats.average_match_moves(), 39.0 / 7.0, 1e-6)
	assert_eq(stats.moves, 39)
	assert_eq(SessionStats.new().average_match_moves(), 0.0, "no matches")


func test_session_records_match_moves_points_and_revives() -> void:
	var session: GameSession = _session()
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.request_move(Vector2i.UP)  # 첫 이동으로 매치 → 1수 구간, 족보 125점
	session.add_bonus_score(50, "보너스")
	assert_eq([session.stats.match_moves, session.stats.match_moves_total], [PackedInt32Array([1, 0, 0]), 1])
	assert_eq([session.stats.recipe_points, session.stats.bonus_points, session.score], [125, 50, 175])
	session.advance(100.0)
	assert_true(session.revive(10.0))
	assert_eq(session.stats.revives, 1)


func test_row_appends_7b_columns_with_context() -> void:
	var session: GameSession = _session()
	session.request_move(Vector2i.UP)
	var context: PlaytestLog.Context = PlaytestLog.Context.new()
	context.account_level = 4
	context.board_stage = 3
	context.control = "dpad"
	var row: PackedStringArray = PlaytestLog.row_for(session, &"basic", PlaytestLog.END_RESULT, "t", context)
	var at: Callable = func(column: String) -> String: return row[PlaytestLog.COLUMNS.find(column)]
	assert_eq(row.size(), PlaytestLog.COLUMNS.size())
	assert_eq(PlaytestLog.COLUMNS.find("score_60_plus"), 15, "old columns keep their positions")
	assert_eq([at.call("match_moves_1_4"), at.call("match_moves_avg"), at.call("account_level"), at.call("board_stage"), at.call("control")],
		["1", "1.00", "4", "3", "dpad"])


func test_old_header_file_is_moved_aside() -> void:
	var old: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	old.store_line("timestamp,seed,score")
	old.store_line("x,1,100")
	old.close()
	assert_true(PlaytestLog.append(PlaytestLog.row_for(_session(), &"basic", PlaytestLog.END_RESULT), LOG_PATH))
	var lines: PackedStringArray = FileAccess.get_file_as_string(LOG_PATH).split("\n", false)
	assert_eq([lines.size(), lines[0]], [2, ",".join(PlaytestLog.COLUMNS)], "fresh file with the current header")
	var retired: Array[String] = []
	for file: String in DirAccess.get_files_at("user://"):
		if file.begins_with("test_playtest_log_old_"):
			retired.append(file)
	assert_eq(retired.size(), 1, "old log kept, not deleted")
	for file: String in retired:
		assert_true(FileAccess.get_file_as_string("user://" + file).begins_with("timestamp,seed,score"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file))


func test_summary_groups_results() -> void:
	var header: String = ",".join(PlaytestLog.COLUMNS)
	var lines: PackedStringArray = [header]
	# 캐릭터, 끝, 점수, 초, 레벨, 매치 구간
	for spec: Array in [["basic", "result", 1000, 60, 1, [6, 2, 2]], ["basic", "result", 3000, 60, 5, [4, 4, 2]],
			["clock", "result", 2000, 30, 9, [0, 0, 0]], ["basic", "abandoned", 50, 5, 1, [1, 0, 0]]]:
		var values: Dictionary = {"character": spec[0], "end": spec[1], "score": str(spec[2]), "play_seconds": str(spec[3]),
			"account_level": str(spec[4]), "match_moves_1_4": str(spec[5][0]), "match_moves_5_7": str(spec[5][1]),
			"match_moves_8_plus": str(spec[5][2]), "match_moves_avg": "5.00"}
		var row: PackedStringArray = PackedStringArray()
		for column: String in PlaytestLog.COLUMNS:
			row.append(values.get(column, "0"))
		lines.append(",".join(row))
	lines.append("x,1,basic,result,500")  # 옛 기록: 새 열 없음
	var summary: PlaytestSummary = PlaytestSummary.from_csv("\n".join(lines))
	assert_eq([summary.overall.games, summary.abandoned], [4, 1])
	assert_eq([summary.overall.score_median, summary.overall.score_top10], [1000.0, 3000.0])
	assert_near(summary.overall.score_mean, 6500.0 / 4.0, 1e-3)
	assert_eq(summary.overall.match_count, 20)
	assert_near(summary.overall.match_share[0], 50.0, 1e-3, "10 of 20 matches in 1~4 moves")
	assert_near(summary.overall.match_share[2], 20.0, 1e-3)
	assert_eq(summary.by_character.map(func(g: PlaytestSummary.Group) -> String: return g.name), ["basic", "clock"])
	assert_eq(summary.by_level.map(func(g: PlaytestSummary.Group) -> int: return g.games), [3, 0], "Lv1~20 · Lv21~ (old row has no level)")
	assert_true(summary.lines().size() > 8)
