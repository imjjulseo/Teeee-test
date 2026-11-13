extends "res://tests/framework/test_case.gd"
## 기획서 3.2 키보드 (E8): 방향키 + WASD, 누르고 있으면 OS 키 반복으로 연속 이동, 입력은 들어오는 즉시 보낸다.


func _key(physical: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = pressed
	event.echo = echo
	return event


## events를 차례로 넣고 발생한 move_requested 목록을 반환한다.
func _moves(router: InputRouter, events: Array[InputEventKey]) -> Array[Vector2i]:
	var got: Array[Vector2i] = []
	var record: Callable = func(dir: Vector2i, _hand: int) -> void: got.append(dir)
	router.move_requested.connect(record)
	for event: InputEventKey in events:
		router.handle_input(event)
	router.move_requested.disconnect(record)
	return got


func test_arrow_keys_and_wasd_map_to_directions() -> void:
	var router: InputRouter = InputRouter.new()
	var cases: Array = [
		[KEY_UP, Vector2i.UP], [KEY_W, Vector2i.UP],
		[KEY_DOWN, Vector2i.DOWN], [KEY_S, Vector2i.DOWN],
		[KEY_LEFT, Vector2i.LEFT], [KEY_A, Vector2i.LEFT],
		[KEY_RIGHT, Vector2i.RIGHT], [KEY_D, Vector2i.RIGHT],
	]
	for case: Array in cases:
		var got: Array[Vector2i] = _moves(router, [_key(case[0])])
		assert_eq(got, [case[1]] as Array[Vector2i], "key %s" % OS.get_keycode_string(case[0]))
	router.free()


func test_holding_a_key_repeats_but_release_does_not_move() -> void:
	var router: InputRouter = InputRouter.new()
	assert_eq(_moves(router, [_key(KEY_W), _key(KEY_W, true, true), _key(KEY_W, true, true)]),
		[Vector2i.UP, Vector2i.UP, Vector2i.UP] as Array[Vector2i], "OS key repeat (echo) keeps moving")
	assert_eq(_moves(router, [_key(KEY_W, false)]).size(), 0, "key up ignored")
	router.free()


func test_every_input_is_sent_immediately_in_order() -> void:
	var router: InputRouter = InputRouter.new()
	var got: Array[Vector2i] = _moves(router, [_key(KEY_UP), _key(KEY_LEFT), _key(KEY_D)])
	assert_eq(got, [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i], "nothing is merged (E4)")
	router.free()


func test_pause_key() -> void:
	var router: InputRouter = InputRouter.new()
	var paused: Array[int] = [0]
	router.pause_requested.connect(func() -> void: paused[0] += 1)
	var esc: InputEventKey = _key(KEY_ESCAPE)
	assert_true(router.handle_input(esc))
	assert_eq(paused[0], 1)
	router.free()
