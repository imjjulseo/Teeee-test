extends "res://tests/framework/test_case.gd"
## 기획서 12장 QA 체크리스트 중 다른 테스트로 덮이지 않는 항목 (전체 세션 단위).
## 연속 입력 / 타이머·시작 / 종료 순간 / 프레임 독립성

const S = GameFlow.GameState


func _rng(seed_value: int) -> RandomNumberGenerator:
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


func _snapshot(board: Board) -> Array:
	var cells: Array = []
	for pos: Vector2i in board.all_positions():
		cells.append([board.get_cell_type(pos), board.get_color(pos)])
	return cells


func _run(session: GameSession, total: float, step: float) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


# --- 연속 입력 ----------------------------------------------------------------

func test_rapid_input_keeps_player_and_grid_in_sync() -> void:
	var config: GameConfig = make_config()
	config.game_duration = 10000.0
	var session: GameSession = GameSession.new(config, _rng(77))
	var input_rng: RandomNumberGenerator = _rng(5)
	var prev: Vector2i = session.board.player_pos
	for frame: int in 60 * 60:  # 60초 분량, 매 프레임 1~3개 입력 (연타 + 동시 입력)
		for _k: int in input_rng.randi_range(1, 3):
			var before: Vector2i = session.board.player_pos
			session.request_move(Board.DIRECTIONS[input_rng.randi_range(0, 3)])
			var after: Vector2i = session.board.player_pos
			if absi(after.x - before.x) + absi(after.y - before.y) > 1:
				failures.append("frame %d: jumped more than 1 cell %s → %s" % [frame, before, after])
				return
		session.advance(1.0 / 60.0)
		var board: Board = session.board
		var pos: Vector2i = board.player_pos
		if board.get_cell_type(pos) != Board.CellType.PLAYER or board.count_type(Board.CellType.PLAYER) != 1:
			failures.append("frame %d: player cache %s out of sync with grid" % [frame, pos])
			return
		var blocks: int = board.count_type(Board.CellType.COLOR_BLOCK) + board.count_type(Board.CellType.SEED)
		if blocks != 80:
			failures.append("frame %d: block count %d != 80" % [frame, blocks])
			return
		prev = pos
	assert_true(session.match_count > 0, "random input makes some matches")


# --- 타이머·시작 (E5) -----------------------------------------------------------

func test_timer_is_exactly_60s_after_the_first_move() -> void:
	var session: GameSession = GameSession.new(make_config(), _rng(1))
	_run(session, 10.0, 1.0 / 60.0)  # 첫 이동 전: 흐르지 않음
	session.request_move(Vector2i.ZERO)  # 판은 그대로, 시계만 시작
	var hit: Array[bool] = [false]
	session.time_up.connect(func() -> void: hit[0] = true)
	var at: float = -1.0
	for _i: int in 60 * 70:
		session.advance(1.0 / 60.0)
		if hit[0]:
			at = session.elapsed
			break
	assert_near(at, 60.0, 1e-6, "time up exactly at 60 s after the first move")


func test_pause_and_waiting_do_not_count_toward_timer() -> void:
	var flow: GameFlow = GameFlow.new(make_config())
	flow.start_new_game(_rng(2))
	for _i: int in 120:
		flow.advance(1.0 / 60.0)  # 2초 대기 (첫 이동 전)
	flow.request_move(Vector2i.ZERO)
	assert_eq(flow.state, S.PLAYING)
	for _i: int in 600:
		flow.advance(1.0 / 60.0)  # 10초 플레이
	flow.pause()
	for _i: int in 1800:
		flow.advance(1.0 / 60.0)  # 30초 일시정지
	flow.resume()
	assert_near(flow.session.remaining_time(), 50.0, 1e-6)
	assert_near(flow.session.elapsed, 10.0, 1e-6)


# --- 종료 순간 -------------------------------------------------------------------

func test_input_after_zero_is_rejected_in_same_frame() -> void:
	var config: GameConfig = make_config()
	config.board_size = 5
	config.game_duration = 1.0
	var session: GameSession = GameSession.new(config, _rng(1), _match_ready_board())
	session.start()
	session.advance(0.99)
	session.advance(0.02)  # 이 프레임에서 0초 도달 (시간 판정 우선)
	assert_false(session.request_move(Vector2i.UP), "input at the 0s frame is rejected")
	assert_eq(session.board.player_pos, Vector2i(2, 3))
	assert_eq(session.match_count, 0)


func test_move_just_before_zero_scores_exactly_once() -> void:
	var config: GameConfig = make_config()
	config.board_size = 5
	config.game_duration = 0.05
	var session: GameSession = GameSession.new(config, _rng(1), _match_ready_board())
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	var matched_count: Array[int] = [0]
	var score_events: Array[int] = []
	session.matched.connect(func(_c: Vector2i, _col: int, _cells: Array[Vector2i]) -> void: matched_count[0] += 1)
	session.score_changed.connect(func(s: int) -> void: score_events.append(s))
	session.start()
	session.advance(0.04)
	assert_true(session.request_move(Vector2i.UP), "0.01 s left: still accepted and judged at once")
	assert_near(session.remaining_time(), 0.01 + 2.5, 1e-9, "the match time keeps the game going")
	var moves_at_zero: Array[int] = [-1]
	var stats: SessionStats = session.stats
	session.time_up.connect(func() -> void: moves_at_zero[0] = stats.moves + stats.blocked_moves)
	for _i: int in 300:
		session.advance(1.0 / 60.0)
		session.request_move(Vector2i.DOWN if _i % 2 == 0 else Vector2i.UP)  # 종료 전후로 계속 연타
	assert_eq(matched_count[0], 1, "one match")
	assert_eq(score_events, [125] as Array[int], "score added exactly once")
	assert_eq(session.phase, GameSession.Phase.TIMED_OUT)
	assert_true(moves_at_zero[0] > 0, "moves were accepted until 0 s")
	assert_eq(stats.moves + stats.blocked_moves, moves_at_zero[0], "no move after 0 s")


func test_controller_advances_time_before_input_each_frame() -> void:
	# 같은 프레임에서 시간 판정이 입력보다 먼저 실행되어야 0초 프레임의 입력이 거절된다 (기획서 9장).
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var controller: Node = main.get_node("GameController")
	var router: Node = main.get_node("InputRouter")
	assert_true(controller.process_priority < router.process_priority,
		"GameController.process_priority (%d) must be lower than InputRouter (%d)" % [controller.process_priority, router.process_priority])
	main.free()


# --- 프레임 독립성 -----------------------------------------------------------------

func test_full_session_same_result_at_30_60_120_fps() -> void:
	var results: Array = []
	for fps: int in [30, 60, 120]:
		var config: GameConfig = make_config()
		config.game_duration = 1000.0
		var session: GameSession = GameSession.new(config, _rng(2024))
		var script_rng: RandomNumberGenerator = _rng(99)
		for _i: int in 200:  # 0.2초마다 입력 1개, 총 40초
			session.request_move(Board.DIRECTIONS[script_rng.randi_range(0, 3)])
			_run(session, 0.2, 1.0 / fps)
		results.append([_snapshot(session.board), session.board.player_pos, session.match_count, session.score,
			snappedf(session.remaining_time(), 1e-6)])
	assert_eq(results[0], results[1], "30 vs 60 fps")
	assert_eq(results[1], results[2], "60 vs 120 fps")
