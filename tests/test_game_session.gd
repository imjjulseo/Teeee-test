extends "res://tests/framework/test_case.gd"
## 기획서 3.1 처리 순서, 4.2~4.4 매치·씨앗·금화, 5장 시간·시작·종료 (GameSession 단위)

const MATCH_CELLS: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 3), Vector2i(1, 2), Vector2i(3, 2)]

var matches: Array[Vector2i] = []
var refills: Array = []
var gained_times: Array[float] = []
var time_up_count: int = 0
var started_count: int = 0


func _config() -> GameConfig:
	var config: GameConfig = make_config()
	config.board_size = 5
	return config


## 5x5 보드. 플레이어 (2,3). 위로 1칸 이동하면 (2,2)에 서고 주변 4칸이 색 1이 되어 매치.
## (2,2)=1, (2,1)=1, (1,2)=1, (3,2)=1, 나머지 0.
func _match_ready_board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 3))
	return board


func _session(config: GameConfig, board: Board = null, seed_value: int = 7) -> GameSession:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var session: GameSession = GameSession.new(config, rng, board)
	matches.clear()
	refills.clear()
	gained_times.clear()
	time_up_count = 0
	started_count = 0
	session.matched.connect(func(center: Vector2i, _c: int, _cells: Array[Vector2i]) -> void: matches.append(center))
	session.cells_refilled.connect(func(cells: Array[Vector2i]) -> void: refills.append(cells))
	session.time_gained.connect(func(seconds: float) -> void: gained_times.append(seconds))
	session.time_up.connect(func() -> void: time_up_count += 1)
	session.started.connect(func() -> void: started_count += 1)
	return session


## 작은 step으로 total초 진행.
func _run(session: GameSession, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


# --- 시작 (E5) ----------------------------------------------------------------

func test_clock_waits_for_the_first_move() -> void:
	var session: GameSession = _session(_config())
	assert_true(session.is_waiting())
	_run(session, 5.0)
	assert_near(session.remaining_time(), 60.0, 1e-9, "no time passes before the first move")
	assert_near(session.elapsed, 0.0)
	session.request_move(Vector2i.LEFT)
	assert_eq(started_count, 1)
	assert_true(session.is_running())
	_run(session, 1.0)
	assert_near(session.remaining_time(), 59.0, 1e-6)


func test_a_wall_bump_also_starts_the_clock() -> void:
	var board: Board = _match_ready_board()
	board.set_color_block(Vector2i(2, 3), 0)
	board.set_player(Vector2i(2, 4))
	var session: GameSession = _session(_config(), board)
	assert_true(session.request_move(Vector2i.DOWN), "the request is handled")
	assert_eq(started_count, 1)
	assert_eq(session.stats.blocked_moves, 1)


# --- 즉시 판정 (E4) ----------------------------------------------------------

func test_match_is_judged_immediately() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.request_move(Vector2i.UP)
	assert_eq(matches, [Vector2i(2, 2)] as Array[Vector2i], "no waiting for the animation")
	for pos: Vector2i in MATCH_CELLS:
		assert_eq(session.board.get_cell_type(pos), Board.CellType.SEED, "pos %s" % pos)
	assert_eq(session.board.get_cell_type(Vector2i(2, 2)), Board.CellType.PLAYER)
	assert_eq(session.match_count, 1)
	assert_eq(session.score, 0, "a match alone gives no score (A2)")


func test_no_match_when_colors_differ() -> void:
	var board: Board = _match_ready_board()
	board.set_color_block(Vector2i(2, 1), 2)
	var session: GameSession = _session(_config(), board)
	session.request_move(Vector2i.UP)
	assert_eq(matches.size(), 0)
	assert_eq(session.board.count_type(Board.CellType.SEED), 0)


func test_pre_existing_pattern_is_not_judged_before_move() -> void:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 2))  # 시작부터 주변 4칸이 모두 색 1
	var session: GameSession = _session(_config(), board)
	_run(session, 3.0)
	assert_eq(matches.size(), 0, "no judgment without a move")


func test_wall_move_does_not_judge() -> void:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 0))
	var session: GameSession = _session(_config(), board)
	session.request_move(Vector2i.UP)
	assert_eq(matches.size(), 0)


# --- 족보 / 점수 -----------------------------------------------------------

func test_match_progresses_recipe_and_scores_on_completion() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1  # 색 1 한 번이면 완성 (125점)
	session.recipes.set_recipe_colors(1, PackedInt32Array([1, 2, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 0]))
	var scores: Array[int] = []
	session.score_changed.connect(func(s: int) -> void: scores.append(s))
	session.request_move(Vector2i.UP)
	assert_eq(session.score, 125)
	assert_eq(scores, [125] as Array[int])
	assert_eq(session.recipes.recipes[0].length(), 2, "completed slot replaced by the same length")
	assert_eq(session.recipes.recipes[1].progress, 1)
	assert_eq(session.recipes.recipes[2].progress, 0)
	assert_eq(session.stats.recipes_completed, 1)


# --- 매치 시간 (E5) -------------------------------------------------------------

func test_clear_time_decays_per_match_down_to_the_minimum() -> void:
	var config: GameConfig = make_config()
	assert_near(config.clear_time_for(1), 2.5)
	assert_near(config.clear_time_for(2), 2.42)
	assert_near(config.clear_time_for(22), 0.82, 1e-9)
	assert_near(config.clear_time_for(23), 0.8, 1e-9, "minimum from the 23rd match")
	assert_near(config.clear_time_for(100), 0.8)


func test_match_adds_the_decaying_clear_time() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.request_move(Vector2i.UP)
	assert_eq(gained_times, [2.5] as Array[float])
	assert_near(session.remaining_time(), 62.5, 1e-9)
	session.match_count = 9  # 다음 매치는 10번째
	session.board.set_player(Vector2i(2, 3))
	session.board.set_color_block(Vector2i(2, 2), 1)
	for pos: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		session.board.set_color_block(pos, 1)
	session.request_move(Vector2i.UP)
	assert_near(gained_times[1], 2.5 - 0.08 * 9, 1e-9)


func test_no_time_acceleration() -> void:
	var session: GameSession = _session(_config())
	session.request_move(Vector2i.LEFT)
	_run(session, 30.0)
	assert_near(session.remaining_time(), 30.0, 1e-6, "one game second per real second")


# --- 씨앗 (4.2~4.3) ------------------------------------------------------------

func test_seeds_follow_the_refill_total_at_planting_time() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.request_move(Vector2i.UP)
	for pos: Vector2i in MATCH_CELLS:
		var cell: BoardCell = session.board.get_cell(pos)
		assert_near(cell.seed_remaining, 3.0, 1e-9, "8 s total × 3/8 wait")
		assert_near(cell.seed_grow_duration, 5.0, 1e-9)
	_run(session, 7.9)
	assert_eq(refills.size(), 0)
	_run(session, 0.2)
	assert_eq(refills.size(), 1)
	assert_eq((refills[0] as Array).size(), 4)


func test_a_four_cell_match_refills_one_of_each_color() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.request_move(Vector2i.UP)
	var colors: Array[int] = []
	for pos: Vector2i in MATCH_CELLS:
		colors.append(session.board.get_color(pos))
	colors.sort()
	assert_eq(colors, [0, 1, 2, 3] as Array[int])


func test_refill_colors_are_deterministic_with_seed() -> void:
	var colors: Array = []
	for _i: int in 2:
		var session: GameSession = _session(_config(), _match_ready_board(), 12345)
		session.request_move(Vector2i.UP)
		var snapshot: PackedInt32Array = PackedInt32Array()
		for pos: Vector2i in MATCH_CELLS:
			snapshot.append(session.board.get_color(pos))
		colors.append(snapshot)
	assert_eq(colors[0], colors[1])


func test_refill_auto_pattern_gives_no_match() -> void:
	var config: GameConfig = _config()
	config.color_count = 1  # 씨앗이 전부 색 0 → 다 자라면 플레이어 주변 4칸이 같은 색
	var board: Board = _match_ready_board()
	for pos: Vector2i in board.all_positions():
		if board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK:
			board.set_color_block(pos, 0)
	var session: GameSession = _session(config, board)
	session.request_move(Vector2i.UP)
	_run(session, 9.0)
	assert_eq(refills.size(), 1)
	assert_eq(session.board.find_match(Vector2i(2, 2)), 0, "pattern exists after refill")
	assert_eq(matches.size(), 1, "but no extra match without a move")


func test_player_can_swap_with_a_seed() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.request_move(Vector2i.UP)
	_run(session, 1.0)
	var remaining: float = session.board.get_cell(Vector2i(2, 1)).seed_remaining
	session.request_move(Vector2i.UP)  # (2,1) 씨앗과 교환
	assert_eq(session.board.player_pos, Vector2i(2, 1))
	assert_eq(session.board.get_cell_type(Vector2i(2, 2)), Board.CellType.SEED)
	assert_near(session.board.get_cell(Vector2i(2, 2)).seed_remaining, remaining, 1e-9, "the seed keeps its timer")


# --- 금화 (4.4) ------------------------------------------------------------------

func test_matching_a_coin_block_collects_it() -> void:
	var session: GameSession = _session(_config(), _match_ready_board())
	session.board.get_cell(Vector2i(2, 1)).attach_coin(15.0)
	var collected: Array = []
	session.coins_collected.connect(func(amount: int, chain: int) -> void: collected.append([amount, chain]))
	session.request_move(Vector2i.UP)
	assert_eq(collected, [[10, 1]])
	assert_eq(session.collected_coins(), 10)
	assert_eq(session.board.coin_count(), 0, "the coin left with the block")


# --- 종료 ------------------------------------------------------------------

func test_time_up_blocks_new_input() -> void:
	var config: GameConfig = _config()
	config.game_duration = 1.0
	var session: GameSession = _session(config)
	session.request_move(Vector2i.LEFT)
	_run(session, 0.98)
	assert_eq(time_up_count, 0, "still playing just before 0")
	_run(session, 0.03)
	assert_eq(time_up_count, 1)
	assert_eq(session.phase, GameSession.Phase.TIMED_OUT)
	assert_near(session.remaining_time(), 0.0)
	var pos: Vector2i = session.board.player_pos
	assert_false(session.request_move(Vector2i.RIGHT), "input rejected after time up")
	_run(session, 1.0)
	assert_eq(session.board.player_pos, pos)
	assert_eq(time_up_count, 1, "time_up emitted once")


func test_time_up_happens_exactly_at_zero_even_with_long_frames() -> void:
	var config: GameConfig = _config()
	config.game_duration = 1.0
	var session: GameSession = _session(config)
	session.request_move(Vector2i.LEFT)
	session.advance(5.0)
	assert_eq(time_up_count, 1)
	assert_near(session.elapsed, 1.0, 1e-9, "the session stops at the zero instant")


func test_revive_sets_the_remaining_time_and_continues() -> void:
	var config: GameConfig = _config()
	config.game_duration = 1.0
	var session: GameSession = _session(config)
	assert_false(session.revive(10.0), "nothing to revive while playing")
	session.request_move(Vector2i.LEFT)
	_run(session, 1.5)
	assert_true(session.revive(10.0))
	assert_true(session.is_running())
	assert_near(session.remaining_time(), 10.0)
	assert_true(session.request_move(Vector2i.RIGHT), "moves accepted again")
	_run(session, 10.5)
	assert_eq(time_up_count, 2)


func test_timer_is_frame_rate_independent() -> void:
	var results: Array = []
	for fps: int in [30, 60, 120]:
		var session: GameSession = _session(_config(), _match_ready_board())
		session.request_move(Vector2i.UP)
		_run(session, 20.0, 1.0 / fps)
		results.append([session.remaining_time(), session.board.count_type(Board.CellType.SEED)])
		assert_eq(matches.size(), 1, "fps %d" % fps)
	assert_near(results[0][0], results[1][0], 1e-6, "30 vs 60 fps")
	assert_near(results[1][0], results[2][0], 1e-6, "60 vs 120 fps")
	assert_eq(results[0][1], results[2][1], "same refill state")
