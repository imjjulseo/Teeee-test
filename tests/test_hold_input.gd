extends "res://tests/framework/test_case.gd"
## 누르고 있기·꾹 누르기·손 구분 (4d 캐릭터용 입력): InputRouter가 키보드·스와이프·패드에서
## hold_started / hold_released / long_pressed와 손(hand: 0 왼손, 1 오른손)을 보낸다.

const SceneWiring = preload("res://tests/framework/scene_wiring.gd")


func _router() -> InputRouter:
	var router: InputRouter = InputRouter.new()
	router.config = make_config()
	return router


func _key(physical: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	event.echo = echo
	return event


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	return event


func _drag(pos: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.position = pos
	return event


## 라우터의 signal을 차례대로 기록한다: ["move", dir, hand] / ["hold", dir, hand] / ["release"] / ["long"] / ["tap"].
func _record(router: InputRouter) -> Array:
	var log: Array = []
	router.move_requested.connect(func(dir: Vector2i, hand: int) -> void: log.append(["move", dir, hand]))
	router.hold_started.connect(func(dir: Vector2i, hand: int) -> void: log.append(["hold", dir, hand]))
	router.hold_released.connect(func() -> void: log.append(["release"]))
	router.long_pressed.connect(func() -> void: log.append(["long"]))
	router.tap_requested.connect(func(_p: Vector2) -> void: log.append(["tap"]))
	return log


func test_keys_hold_until_released_and_arrows_are_the_right_hand() -> void:
	var router: InputRouter = _router()
	var log: Array = _record(router)
	router.handle_input(_key(KEY_D))
	router.handle_input(_key(KEY_D, true, true))  # 키 반복: 이동만
	router.handle_input(_key(KEY_D, false))
	router.handle_input(_key(KEY_UP))
	assert_eq(log, [
		["hold", Vector2i.RIGHT, 0], ["move", Vector2i.RIGHT, 0],
		["move", Vector2i.RIGHT, 0],
		["release"],
		["hold", Vector2i.UP, 1], ["move", Vector2i.UP, 1],
	])
	router.free()


func test_swipe_holds_until_the_finger_lifts_and_screen_half_picks_the_hand() -> void:
	var router: InputRouter = _router()
	var log: Array = _record(router)
	router.handle_input(_touch(Vector2(100, 600), true))
	router.handle_input(_drag(Vector2(140, 600)))
	router.handle_input(_touch(Vector2(140, 600), false))
	router.handle_input(_touch(Vector2(600, 600), true))  # 오른쪽 절반
	router.handle_input(_drag(Vector2(600, 560)))
	assert_eq(log, [
		["hold", Vector2i.RIGHT, 0], ["move", Vector2i.RIGHT, 0], ["release"],
		["hold", Vector2i.UP, 1], ["move", Vector2i.UP, 1],
	])
	router.free()


func test_long_press_fires_once_and_is_not_a_tap() -> void:
	var router: InputRouter = _router()
	var log: Array = _record(router)
	router.handle_input(_touch(Vector2(300, 600), true))
	router.tick(0.3)
	assert_eq(log.size(), 0)
	router.tick(0.25)
	router.tick(1.0)
	router.handle_input(_touch(Vector2(300, 600), false))
	assert_eq(log, [["long"]], "long press once, no tap afterwards")
	router.handle_input(_touch(Vector2(300, 600), true))
	router.tick(0.2)
	router.handle_input(_touch(Vector2(300, 600), false))
	assert_eq(log.back(), ["tap"], "a short touch is still a tap")
	router.free()


func test_space_key_is_the_keyboard_long_press() -> void:
	var router: InputRouter = _router()
	var log: Array = _record(router)
	router.handle_input(_key(KEY_SPACE))
	router.handle_input(_key(KEY_SPACE, true, true))  # 키 반복은 한 번으로
	assert_eq(log, [["long"]])
	router.free()


func test_moving_the_finger_cancels_the_long_press() -> void:
	var router: InputRouter = _router()
	var log: Array = _record(router)
	router.handle_input(_touch(Vector2(300, 600), true))
	router.handle_input(_drag(Vector2(322, 600)))  # 18px보다 움직임 (스와이프 33px에는 못 미침)
	router.tick(1.0)
	assert_eq(log.size(), 0)
	router.free()


func test_pad_hold_and_release_reach_the_router() -> void:
	var router: InputRouter = _router()
	var pad: VirtualDpad = (load("res://scenes/virtual_dpad.tscn") as PackedScene).instantiate() as VirtualDpad
	var flow: FlowChannel = FlowChannel.new()
	SceneWiring.connect_like("res://scenes/main.tscn", {"InputRouter": router, "VirtualDpad": pad, "GameController/FlowChannel": flow})
	flow.control_mode_ready.emit(OptionsStore.ControlMode.DPAD)
	var log: Array = _record(router)
	(pad.get_node("SafeArea/Content/Pad/Left") as Button).button_down.emit()
	(pad.get_node("SafeArea/Content/Pad/Left") as Button).button_up.emit()
	assert_eq(log, [["hold", Vector2i.LEFT, 0], ["move", Vector2i.LEFT, 0], ["release"]])
	for node: Node in [router, pad, flow]:
		node.free()


func test_flow_passes_hold_and_long_press_to_the_ability() -> void:
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var flow: GameFlow = GameFlow.new(make_config(), roster.find(&"pachy"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	flow.start_new_game(rng)
	flow.hold_direction(Vector2i.RIGHT)
	assert_true((flow.session.ability as PachyAbility).holding)
	flow.pause()
	flow.release_hold()
	assert_false((flow.session.ability as PachyAbility).holding, "release reaches the ability even while paused")
