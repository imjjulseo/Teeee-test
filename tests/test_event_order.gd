extends "res://tests/framework/test_case.gd"
## 한 프레임 안의 시간 사건: 프레임을 크게 나누든 잘게 나누든 결과가 같아야 한다.
## (씨앗 대기·자람 끝 / 금화 수명 / 0초 도달 / 능력 타이머 종료가 한 프레임에 겹치는 경우)
## 시간에 따라 일어나는 일을 추가하면 TimedSystem으로 세션에 등록하고 여기에 검사를 더한다.

const FRAMES: Array[float] = [1.0 / 240.0, 1.0 / 30.0, 0.25, 7.0]


func _rng(seed_value: int = 9) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _config() -> GameConfig:
	var config: GameConfig = make_config()
	config.board_size = 5
	return config


func _board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	board.set_player(Vector2i(2, 2))
	return board


func _run(session: GameSession, total: float, step: float) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


## 첫 이동(벽 쪽으로 밀어 판은 그대로)으로 시계를 시작한 세션.
func _started(config: GameConfig, board: Board, character: CharacterData = null) -> GameSession:
	var session: GameSession = GameSession.new(config, _rng(), board, character)
	session.board.set_color_block(session.board.player_pos, 0)
	session.board.set_player(Vector2i(2, 0))
	session.request_move(Vector2i.UP)
	return session


func test_seed_stage_changes_happen_at_the_same_moment_for_any_frame_size() -> void:
	for frame: float in FRAMES:
		var board: Board = _board()
		board.set_seed(Vector2i(1, 1), 3, 1.3, 2.1)
		var session: GameSession = _started(_config(), board)
		var matured_at: Array[float] = [-1.0]
		var session_ref: WeakRef = weakref(session)
		session.cells_refilled.connect(func(_c: Array[Vector2i]) -> void:
			matured_at[0] = (session_ref.get_ref() as GameSession).elapsed)
		_run(session, 2.0, frame)
		assert_near(session.board.get_grow_progress(Vector2i(1, 1)), 0.7 / 2.1, 1e-6, "frame %.4f" % frame)
		_run(session, 2.0, frame)
		assert_near(matured_at[0], 3.4, 1e-6, "matured exactly at wait + grow (frame %.4f)" % frame)


func test_coin_expires_at_the_same_moment_for_any_frame_size() -> void:
	for frame: float in FRAMES:
		var board: Board = _board()
		board.get_cell(Vector2i(1, 1)).attach_coin(2.3)
		var session: GameSession = _started(_config(), board)
		var gone_at: Array[float] = [-1.0]
		var session_ref: WeakRef = weakref(session)
		session.coins_changed.connect(func(_c: Array[Vector2i]) -> void:
			gone_at[0] = (session_ref.get_ref() as GameSession).elapsed)
		_run(session, 5.0, frame)
		assert_near(gone_at[0], 2.3, 1e-6, "frame %.4f" % frame)


func test_time_up_moment_is_exact_with_a_clock_stop() -> void:
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	for frame: float in FRAMES:
		var config: GameConfig = _config()
		config.game_duration = 3.0
		var session: GameSession = _started(config, _board(), roster.find(&"clock"))
		var stop: TimeStopAbility = session.ability as TimeStopAbility
		_run(session, 1.0, frame)
		session.ability.trigger(session)  # 1초에 정지 → 남은 2초는 정지가 끝난 뒤 흐른다
		var at: Array[float] = [-1.0]
		var session_ref: WeakRef = weakref(session)
		session.time_up.connect(func() -> void: at[0] = (session_ref.get_ref() as GameSession).elapsed)
		_run(session, 20.0, frame)
		assert_near(at[0], 3.0 + stop.duration, 1e-6, "frame %.4f" % frame)


func test_whole_scripted_session_matches_across_frame_sizes() -> void:
	# 같은 시각에 같은 입력을 넣는 1분짜리 판을 서로 다른 프레임 크기로 돌린다 (씨앗·금화·족보가 얽힘).
	var results: Array = []
	for frame: float in [1.0 / 30.0, 1.0 / 120.0, 0.25]:
		var config: GameConfig = make_config()
		config.coin_chance = 0.5
		var session: GameSession = GameSession.new(config, _rng(21))
		var script_rng: RandomNumberGenerator = _rng(5)
		for _i: int in 240:
			session.request_move(Board.DIRECTIONS[script_rng.randi_range(0, 3)])
			_run(session, 0.25, frame)
		var cells: Array = []
		for pos: Vector2i in session.board.all_positions():
			var cell: BoardCell = session.board.get_cell(pos)
			cells.append([cell.type, cell.color, snappedf(cell.seed_remaining, 1e-6), snappedf(cell.coin_remaining, 1e-6)])
		results.append([session.match_count, session.score, session.collected_coins(),
			snappedf(session.remaining_time(), 1e-6), cells])
	assert_true(results[0][0] > 0, "the script makes matches")
	assert_eq(results[0], results[1], "whole state 30 vs 120 fps")
	assert_eq(results[1], results[2], "whole state 120 fps vs 0.25 s frames")
