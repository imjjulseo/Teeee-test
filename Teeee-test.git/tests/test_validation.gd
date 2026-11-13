extends "res://tests/framework/test_case.gd"
## 배포 빌드에서도 동작하는 검증 (assert 대신 push_error + 대체 동작).
## 이 테스트는 일부러 잘못된 설정을 넣으므로 실행 중 "ERROR: ... using defaults" 로그가 나오는 것이 정상이다.

const SceneWiring = preload("res://tests/framework/scene_wiring.gd")


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	return rng


func test_valid_config_is_kept_as_is() -> void:
	var config: GameConfig = make_config()
	config.game_duration = 45.0
	assert_true(GameConfig.ensure_valid(config) == config, "same instance")


func test_invalid_or_missing_config_falls_back_to_defaults() -> void:
	var invalid: GameConfig = make_config()
	invalid.board_size = 6
	var fixed: GameConfig = GameConfig.ensure_valid(invalid)
	assert_true(fixed != invalid)
	assert_true(fixed.validate().is_empty(), "fallback is valid")
	assert_eq(fixed.board_size, 9)
	assert_true(GameConfig.ensure_valid(null).validate().is_empty(), "null → defaults")


func test_session_with_invalid_config_still_plays() -> void:
	var config: GameConfig = make_config()
	config.board_size = 6  # 짝수: 중앙이 없음
	var session: GameSession = GameSession.new(config, _rng())
	assert_eq(session.board.size, 9, "default board used")
	assert_eq(session.board.count_type(Board.CellType.PLAYER), 1)
	assert_true(session.request_move(Vector2i.UP))
	session.advance(1.0)
	assert_true(session.remaining_time() > 0.0)


func test_board_generate_with_invalid_config_uses_defaults() -> void:
	var config: GameConfig = make_config()
	config.color_count = 0
	var board: Board = Board.generate(config, _rng())
	assert_eq(board.size, 9)
	for color: int in 4:
		assert_eq(board.count_color_blocks(color), 20)


func test_flow_with_invalid_config_uses_default_timer() -> void:
	var config: GameConfig = make_config()
	config.game_duration = -5.0
	var flow: GameFlow = GameFlow.new(config)
	flow.start_new_game(_rng())
	assert_near(flow.session.remaining_time(), 60.0)


func test_session_with_invalid_recipe_lengths_uses_default_recipes() -> void:
	var config: GameConfig = make_config()
	config.recipe_lengths = PackedInt32Array([2, 0])
	var session: GameSession = GameSession.new(config, _rng())
	assert_eq(session.recipes.slot_count(), 3)
	session.apply_clear_to_recipes(session.recipes.recipes[0].next_color())  # 진행해도 범위 오류 없음


func test_controller_without_channels_does_not_start_or_crash() -> void:
	var controller: GameController = GameController.new()
	controller.config = make_config()
	controller.notification(Node.NOTIFICATION_READY)  # 씬 트리에 들어간 것처럼 _ready 실행
	assert_false(controller.is_running())
	assert_false(controller.is_processing())
	assert_eq(controller.missing_channels(), PackedStringArray(["board_channel", "hud_channel", "flow_channel"]))
	# main.tscn처럼 입력·버튼을 연결하고 원래 signal을 보내도 죽지 않는다
	var router: InputRouter = InputRouter.new()
	var hud: Hud = Hud.new()
	var pause: PauseOverlay = PauseOverlay.new()
	var result: ResultPanel = ResultPanel.new()
	var wired: int = SceneWiring.connect_like("res://scenes/main.tscn", {
		"GameController": controller, "InputRouter": router, "Hud": hud, "PauseOverlay": pause, "ResultPanel": result,
	})
	assert_true(wired >= 6, "inputs and buttons wired to the controller (%d)" % wired)
	router.move_requested.emit(Vector2i.UP, 0)
	router.pause_requested.emit()
	hud.pause_requested.emit()
	pause.resume_requested.emit()
	pause.main_menu_requested.emit()
	result.retry_requested.emit()
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	for node: Node in [router, hud, pause, result, controller]:
		node.free()
