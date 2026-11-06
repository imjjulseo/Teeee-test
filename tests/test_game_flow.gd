extends "res://tests/framework/test_case.gd"
## 기획서 6장 상태 머신: WAITING → PLAYING ⇄ PAUSED, 0초 → (REVIVE →) RESULT → retry → WAITING (E5, E10, E20)

const S = GameFlow.GameState

var states: Array[int] = []
var time_ups: int = 0


## 부활을 항상 제안하는 테스트용 규칙. 받아들인 횟수를 센다.
class AlwaysRevive:
	extends RevivePolicy

	var consumed: int = 0

	func can_offer(_session: GameSession) -> bool:
		return true

	func consume(_session: GameSession) -> void:
		consumed += 1


func _config(duration: float = 60.0) -> GameConfig:
	var config: GameConfig = make_config()
	config.game_duration = duration
	return config


func _flow(config: GameConfig = null, policy: RevivePolicy = null) -> GameFlow:
	var flow: GameFlow = GameFlow.new(config if config != null else _config())
	if policy != null:
		flow.revive_policy = policy
	states.clear()
	time_ups = 0
	flow.state_changed.connect(func(s: GameFlow.GameState) -> void: states.append(s))
	flow.time_up.connect(func() -> void: time_ups += 1)
	flow.start_new_game(_rng(3))
	return flow


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run(flow: GameFlow, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		flow.advance(d)
		left -= d


## 첫 이동으로 판을 시작한다 (벽 쪽이 아닌 방향).
func _start(flow: GameFlow) -> void:
	flow.request_move(Vector2i.UP)


func test_starts_waiting_and_time_does_not_run() -> void:
	var flow: GameFlow = _flow()
	assert_eq(flow.state, S.WAITING)
	_run(flow, 5.0)
	assert_near(flow.session.remaining_time(), 60.0, 1e-9, "clock waits for the first move")


func test_first_move_starts_playing() -> void:
	var flow: GameFlow = _flow()
	var pos: Vector2i = flow.session.board.player_pos
	assert_true(flow.request_move(Vector2i.UP))
	assert_eq(flow.state, S.PLAYING)
	assert_eq(flow.session.board.player_pos, pos + Vector2i.UP)
	_run(flow, 1.0)
	assert_near(flow.session.remaining_time(), 59.0, 0.1)
	assert_eq(states, [S.WAITING, S.PLAYING] as Array[int])


func test_pause_freezes_time_and_blocks_input() -> void:
	var flow: GameFlow = _flow()
	_start(flow)
	_run(flow, 1.0)
	assert_true(flow.pause())
	assert_eq(flow.state, S.PAUSED)
	var remaining: float = flow.session.remaining_time()
	var pos: Vector2i = flow.session.board.player_pos
	assert_false(flow.request_move(Vector2i.UP))
	_run(flow, 10.0)
	assert_eq(flow.session.remaining_time(), remaining, "timer frozen")
	assert_eq(flow.session.board.player_pos, pos)
	assert_true(flow.resume())
	assert_eq(flow.state, S.PLAYING)
	_run(flow, 1.0)
	assert_true(flow.session.remaining_time() < remaining)


func test_pause_from_waiting_resumes_to_waiting() -> void:
	var flow: GameFlow = _flow()
	assert_true(flow.pause(), "can pause before the first move")
	assert_true(flow.resume())
	assert_eq(flow.state, S.WAITING)


func test_toggle_pause() -> void:
	var flow: GameFlow = _flow()
	_start(flow)
	flow.toggle_pause()
	assert_eq(flow.state, S.PAUSED)
	flow.toggle_pause()
	assert_eq(flow.state, S.PLAYING)


func test_time_up_goes_straight_to_result_without_revive() -> void:
	var flow: GameFlow = _flow(_config(2.0))
	_start(flow)
	_run(flow, 2.05)
	assert_eq(time_ups, 1)
	assert_eq(flow.state, S.RESULT)
	assert_false(flow.request_move(Vector2i.UP))
	assert_false(flow.pause(), "cannot pause after the game ended")
	assert_eq(states, [S.WAITING, S.PLAYING, S.RESULT] as Array[int])


func test_revive_offer_accept_continues_with_revive_time() -> void:
	var policy: AlwaysRevive = AlwaysRevive.new()
	var flow: GameFlow = _flow(_config(1.0), policy)
	_start(flow)
	_run(flow, 1.5)
	assert_eq(flow.state, S.REVIVE)
	assert_false(flow.request_move(Vector2i.UP), "no moves while asking")
	_run(flow, 5.0)
	assert_eq(flow.state, S.REVIVE, "waits for the answer")
	assert_true(flow.accept_revive())
	assert_eq(policy.consumed, 1)
	assert_eq(flow.state, S.PLAYING)
	assert_near(flow.session.remaining_time(), 10.0)
	assert_true(flow.request_move(Vector2i.DOWN))


func test_revive_offer_decline_goes_to_result() -> void:
	var flow: GameFlow = _flow(_config(1.0), AlwaysRevive.new())
	_start(flow)
	_run(flow, 1.5)
	assert_eq(flow.state, S.REVIVE)
	assert_true(flow.decline_revive())
	assert_eq(flow.state, S.RESULT)
	assert_false(flow.accept_revive(), "only from REVIVE")


func test_retry_only_from_result_and_resets() -> void:
	var flow: GameFlow = _flow(_config(1.0))
	assert_false(flow.retry(_rng(4)), "no retry while waiting")
	var old_session: GameSession = flow.session
	_start(flow)
	old_session.score = 1234
	_run(flow, 1.5)
	assert_eq(flow.state, S.RESULT)
	assert_true(flow.retry(_rng(4)))
	assert_eq(flow.state, S.WAITING)
	assert_true(flow.session != old_session, "new session")
	assert_eq(flow.session.score, 0)
	assert_near(flow.session.remaining_time(), 1.0)
	assert_eq(flow.session.board.player_pos, flow.session.board.center())


func test_restart_from_pause_starts_a_fresh_game() -> void:
	var flow: GameFlow = _flow()
	assert_false(flow.restart(_rng(5)), "only from PAUSED")
	_start(flow)
	var old: GameSession = flow.session
	old.score = 900
	flow.pause()
	assert_true(flow.restart(_rng(5)))
	assert_eq(flow.state, S.WAITING)
	assert_true(flow.session != old)
	assert_eq(flow.session.score, 0)
	assert_false(states.has(S.RESULT), "restart gives no result")


## 재시작 후 이전 판의 점수·시간·보드·족보·씨앗·금화 상태가 남지 않는다 (12장 재시작).
func test_retry_leaves_no_previous_state() -> void:
	var flow: GameFlow = _flow(_config(3.0))
	var old: GameSession = flow.session
	_start(flow)
	old.score = 5000
	old.recipes.recipes[2].progress = 3
	old.board.set_seed(Vector2i(0, 0), 1, 2.0, 2.0)
	old.board.get_cell(Vector2i(1, 0)).attach_coin(10.0)
	_run(flow, 10.0)
	assert_eq(flow.state, S.RESULT)
	assert_true(old.elapsed > 0.0)

	assert_true(flow.retry(_rng(6)))
	var fresh: GameSession = flow.session
	assert_true(fresh != old)
	assert_eq(fresh.phase, GameSession.Phase.WAITING)
	assert_eq(fresh.score, 0)
	assert_eq(fresh.match_count, 0)
	assert_eq(fresh.collected_coins(), 0)
	assert_near(fresh.elapsed, 0.0)
	assert_near(fresh.remaining_time(), 3.0)
	assert_eq(fresh.board.player_pos, fresh.board.center())
	assert_eq(fresh.board.count_type(Board.CellType.SEED), 0)
	assert_eq(fresh.board.coin_count(), 0)
	assert_eq(fresh.board.count_type(Board.CellType.PLAYER), 1)
	for color: int in 4:
		assert_eq(fresh.board.count_color_blocks(color), 20)
	for recipe: RecipeSet.Recipe in fresh.recipes.recipes:
		assert_eq(recipe.progress, 0)
	# 이전 판의 signal이 새 판 상태를 바꾸지 않는다
	old.time_up.emit()
	old.started.emit()
	assert_eq(flow.state, S.WAITING, "stale session signals ignored")


# --- 일시정지에서 메뉴로 나가기 (판 포기) ---------------------------------------

func test_abandon_only_from_pause_and_is_terminal() -> void:
	var flow: GameFlow = _flow()
	_start(flow)
	assert_false(flow.abandon(), "not from PLAYING")
	flow.pause()
	flow.session.score = 1234
	assert_true(flow.abandon())
	assert_eq(flow.state, S.ABANDONED)
	_run(flow, 100.0, 1.0)
	assert_eq(flow.state, S.ABANDONED, "never reaches RESULT → score not recorded")
	assert_false(flow.request_move(Vector2i.UP))
	assert_false(flow.resume())
	assert_false(flow.pause())
	assert_false(flow.retry(_rng(4)))
	assert_false(states.has(S.RESULT))

# --- 옆 칸 탭 (E8) ----------------------------------------------------------------

func test_tapping_a_neighbor_cell_moves_there() -> void:
	var flow: GameFlow = _flow()
	var start: Vector2i = flow.session.board.player_pos
	assert_false(flow.request_move_toward(start + Vector2i(2, 0)), "two cells away: no move")
	assert_false(flow.request_move_toward(start + Vector2i(1, 1)), "diagonal: no move")
	assert_false(flow.request_move_toward(start), "own cell: no move")
	assert_eq(flow.state, S.WAITING, "no move, clock still waiting")
	assert_true(flow.request_move_toward(start + Vector2i.LEFT))
	assert_eq(flow.session.board.player_pos, start + Vector2i.LEFT)
	assert_eq(flow.state, S.PLAYING)
	flow.pause()
	assert_false(flow.request_move_toward(start), "not while paused")
