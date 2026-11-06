extends "res://tests/framework/test_case.gd"
## 기획서 3.2 스와이프 (E8): 손가락을 떼지 않아도 22px를 넘는 순간 큰 축 방향으로 1칸, 한 번 닿을 때 1칸,
## 첫 손가락만, 움직이지 않고 떼면 탭(옆 칸 이동). SwipeGesture(판정)와 InputRouter(이벤트 → signal).


func _router() -> InputRouter:
	var router: InputRouter = InputRouter.new()
	router.config = make_config()
	return router


func _touch(pos: Vector2, pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	event.index = index
	return event


func _drag(pos: Vector2, index: int = 0) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.position = pos
	event.index = index
	return event


## 이벤트를 차례로 넣고 { moves, taps }를 반환한다.
func _feed(router: InputRouter, events: Array[InputEvent]) -> Dictionary:
	var moves: Array[Vector2i] = []
	var taps: Array[Vector2] = []
	var on_move: Callable = func(dir: Vector2i, _hand: int) -> void: moves.append(dir)
	var on_tap: Callable = func(pos: Vector2) -> void: taps.append(pos)
	router.move_requested.connect(on_move)
	router.tap_requested.connect(on_tap)
	for event: InputEvent in events:
		router.handle_input(event)
	router.move_requested.disconnect(on_move)
	router.tap_requested.disconnect(on_tap)
	return {"moves": moves, "taps": taps}


## start에서 offset만큼 끌었다 떼는 한 번의 스와이프에서 나온 이동.
func _swipe(router: InputRouter, offset: Vector2) -> Array[Vector2i]:
	var c: Vector2 = Vector2(360, 640)
	return _feed(router, [_touch(c, true), _drag(c + offset), _touch(c + offset, false)])["moves"]


# --- SwipeGesture ---------------------------------------------------------------

func test_gesture_fires_once_when_crossing_the_threshold() -> void:
	var gesture: SwipeGesture = SwipeGesture.new(22.0)
	gesture.press(0, Vector2(100, 100))
	assert_eq(gesture.drag(0, Vector2(121, 100)), Vector2i.ZERO, "21px: not yet")
	assert_eq(gesture.drag(0, Vector2(122, 100)), Vector2i.RIGHT, "22px: move now, finger still down")
	assert_eq(gesture.drag(0, Vector2(200, 100)), Vector2i.ZERO, "one move per touch")
	assert_false(gesture.release(0), "a swipe is not a tap")


func test_gesture_tap_and_cancel() -> void:
	var gesture: SwipeGesture = SwipeGesture.new(22.0)
	gesture.press(0, Vector2(100, 100))
	gesture.drag(0, Vector2(105, 103))
	assert_true(gesture.release(0), "small wobble then release = tap")
	gesture.press(0, Vector2(100, 100))
	assert_false(gesture.release(0, true), "canceled touch is not a tap")


func test_gesture_ignores_a_second_finger() -> void:
	var gesture: SwipeGesture = SwipeGesture.new(22.0)
	gesture.press(0, Vector2(100, 100))
	gesture.press(1, Vector2(300, 300))
	assert_eq(gesture.drag(1, Vector2(400, 300)), Vector2i.ZERO)
	assert_false(gesture.release(1))
	assert_eq(gesture.drag(0, Vector2(100, 150)), Vector2i.DOWN)


func test_direction_uses_the_larger_axis() -> void:
	assert_eq(SwipeGesture.direction_of(Vector2(90, 60)), Vector2i.RIGHT)
	assert_eq(SwipeGesture.direction_of(Vector2(-50, -80)), Vector2i.UP, "screen y up = board up")
	assert_eq(SwipeGesture.direction_of(Vector2(-30, 10)), Vector2i.LEFT)
	assert_eq(SwipeGesture.direction_of(Vector2(5, 40)), Vector2i.DOWN)


# --- InputRouter -------------------------------------------------------------------

func test_four_directions() -> void:
	var router: InputRouter = _router()
	assert_eq(_swipe(router, Vector2(120, 10)), [Vector2i.RIGHT] as Array[Vector2i])
	assert_eq(_swipe(router, Vector2(-120, 10)), [Vector2i.LEFT] as Array[Vector2i])
	assert_eq(_swipe(router, Vector2(10, -120)), [Vector2i.UP] as Array[Vector2i])
	assert_eq(_swipe(router, Vector2(10, 120)), [Vector2i.DOWN] as Array[Vector2i])
	router.free()


func test_move_happens_during_the_drag_not_on_release() -> void:
	var router: InputRouter = _router()
	var c: Vector2 = Vector2(100, 100)
	var during: Dictionary = _feed(router, [_touch(c, true), _drag(c + Vector2(30, 0))])
	assert_eq(during["moves"], [Vector2i.RIGHT] as Array[Vector2i], "moved while the finger is down")
	var after: Dictionary = _feed(router, [_drag(c + Vector2(90, 0)), _touch(c + Vector2(90, 0), false)])
	assert_eq((after["moves"] as Array).size(), 0, "no second move and no tap for the same touch")
	assert_eq((after["taps"] as Array).size(), 0)
	router.free()


func test_short_drag_is_a_tap_with_its_position() -> void:
	var router: InputRouter = _router()
	var c: Vector2 = Vector2(360, 640)
	var got: Dictionary = _feed(router, [_touch(c, true), _drag(c + Vector2(10, 0)), _touch(c + Vector2(10, 0), false)])
	assert_eq((got["moves"] as Array).size(), 0, "below 22px")
	assert_eq(got["taps"], [c + Vector2(10, 0)] as Array[Vector2])
	router.free()

