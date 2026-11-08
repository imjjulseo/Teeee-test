class_name InputRouter
extends Node
## 입력을 게임 의도 signal로 모은다 (기획서 3.2장, E8). 입력은 들어오는 즉시 보낸다 (이동·판정이 즉시라 모으지 않음, E4).
## - 키보드: 방향키·WASD. 누르고 있으면 OS 키 반복으로 연속 이동.
## - 스와이프(조작 방법 = 스와이프): 화면 어디서든. 손가락을 떼지 않아도 swipe_threshold를 넘는 순간 1칸 (SwipeGesture).
##   움직이지 않고 뗀 탭은 tap_requested(화면 위치) → 보드가 칸으로 바꿔 옆 칸이면 이동.
##   움직이지 않고 long_press_time초 누르고 있으면 long_pressed (방화광 소화), 그 터치는 탭이 아니다.
##   버튼이 먹은 터치는 _unhandled_input까지 오지 않는다.
## - 패드(조작 방법 = 패드): VirtualDpad.direction_pressed / direction_released를 연결받는다 (반복은 패드가 맡는다).
## - 방향을 누르고 있음: 키를 누른 채, 스와이프한 손가락을 뗀 채, 패드 버튼을 누른 채면 hold_started → 떼면 hold_released
##   (파키케팔로사우르스 돌진).
## - 손(hand): 0 = 왼손(WASD, 화면 왼쪽 절반, 패드), 1 = 오른손(방향키, 화면 오른쪽 절반). 양손잡이만 구분해서 쓴다.
## - 일시정지: pause 액션(ESC).

signal move_requested(dir: Vector2i, hand: int)
## 방향 입력을 누르고 있기 시작했다 (이동은 move_requested로 따로 온다).
signal hold_started(dir: Vector2i, hand: int)
## 누르고 있던 방향 입력을 뗐다.
signal hold_released
## 화면을 움직이지 않고 오래 누르고 있다 (스와이프 모드).
signal long_pressed
signal pause_requested
## 스와이프 모드에서 움직이지 않고 뗀 탭의 화면(뷰포트) 위치.
signal tap_requested(position: Vector2)

const ACTION_DIRECTIONS: Dictionary[StringName, Vector2i] = {
	&"move_up": Vector2i.UP,
	&"move_down": Vector2i.DOWN,
	&"move_left": Vector2i.LEFT,
	&"move_right": Vector2i.RIGHT,
}
const PAUSE_ACTION: StringName = &"pause"
const LEFT_HAND: int = 0
const RIGHT_HAND: int = 1
## 오른손 키 (양손잡이: 방향키 = 오른손, WASD = 왼손).
const RIGHT_HAND_KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
## 키보드의 꾹 누르기.
const LONG_PRESS_KEY: Key = KEY_SPACE

@export var config: GameConfig
## 옵션의 조작 방법. FlowChannel.control_mode_ready로 설정된다.
var control_mode: OptionsStore.ControlMode = OptionsStore.ControlMode.SWIPE

## 스와이프 판정. 처음 쓸 때 만든다 (_ensure_gesture).
var _gesture: SwipeGesture
## 지금 터치의 손 (화면 왼쪽/오른쪽 절반).
var _touch_hand: int = LEFT_HAND
## 꾹 누르기: 남은 시간(초, 음수면 꺼짐)과 이미 보냈는지.
var _long_press_left: float = -1.0
var _long_press_fired: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if handle_input(event) and is_inside_tree():
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	tick(delta)


## 입력 이벤트 1개를 처리한다 (키보드·일시정지·스와이프). 이 라우터가 사용한 이벤트면 true.
## 엔진은 _unhandled_input으로, 테스트는 직접 부른다.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return control_mode == OptionsStore.ControlMode.SWIPE and _handle_touch(event)
	if event.is_action_pressed(PAUSE_ACTION, false):
		pause_requested.emit()
		return true
	if event is InputEventKey and (event as InputEventKey).physical_keycode == LONG_PRESS_KEY and event.is_pressed() and not event.is_echo():
		long_pressed.emit()  # 키보드에서는 스페이스 = 꾹 누르기 (방화광 소화)
		return true
	for action: StringName in ACTION_DIRECTIONS:
		var hand: int = _key_hand(event)
		if event.is_action_pressed(action, true):  # 키 반복(echo) 허용
			if not event.is_echo():
				hold_started.emit(ACTION_DIRECTIONS[action], hand)
			move_requested.emit(ACTION_DIRECTIONS[action], hand)
			return true
		if event.is_action_released(action):
			hold_released.emit()
			return true
	return false


## 시간이 지남 (꾹 누르기 판정). 엔진은 _process로, 테스트는 직접 부른다.
func tick(delta: float) -> void:
	if _long_press_left < 0.0 or _long_press_fired:
		return
	_long_press_left -= delta
	if _long_press_left <= 0.0:
		_long_press_fired = true
		long_pressed.emit()


func _on_control_mode_ready(mode: OptionsStore.ControlMode) -> void:
	control_mode = mode
	_ensure_gesture().reset()
	_long_press_left = -1.0


## 패드 입력. 패드 모드에서만 받는다. 패드는 왼손.
func _on_virtual_direction_pressed(dir: Vector2i) -> void:
	if control_mode == OptionsStore.ControlMode.DPAD:
		move_requested.emit(dir, LEFT_HAND)


## 패드 버튼을 누르기 시작했다 / 뗐다 (누르고 있기).
func _on_virtual_direction_held(dir: Vector2i) -> void:
	if control_mode == OptionsStore.ControlMode.DPAD:
		hold_started.emit(dir, LEFT_HAND)


func _on_virtual_direction_released() -> void:
	if control_mode == OptionsStore.ControlMode.DPAD:
		hold_released.emit()


func _handle_touch(event: InputEvent) -> bool:
	var gesture: SwipeGesture = _ensure_gesture()
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if gesture.is_tracking() and drag.position.distance_to(gesture.start_position()) > _long_press_slop():
			_long_press_left = -1.0  # 움직이면 꾹 누르기가 아니다
		var dir: Vector2i = gesture.drag(drag.index, drag.position)
		if dir == Vector2i.ZERO:
			return false
		hold_started.emit(dir, _touch_hand)  # 손가락을 떼지 않고 있는 동안 그 방향을 누르고 있다
		move_requested.emit(dir, _touch_hand)
		return true
	var touch: InputEventScreenTouch = event
	if touch.pressed:
		if not gesture.is_tracking():
			_touch_hand = RIGHT_HAND if touch.position.x >= _screen_width() / 2.0 else LEFT_HAND
			_long_press_left = _long_press_time()
			_long_press_fired = false
		gesture.press(touch.index, touch.position)
		return false
	var held: bool = gesture.has_fired()
	var tap: bool = gesture.release(touch.index, touch.canceled)
	if gesture.is_tracking():
		return false  # 다른 손가락
	_long_press_left = -1.0
	if held:
		hold_released.emit()
	if tap and not _long_press_fired:
		tap_requested.emit(touch.position)
		return true
	return held


## 키 이벤트의 손: 방향키 = 오른손, 그 밖(WASD) = 왼손.
static func _key_hand(event: InputEvent) -> int:
	if event is InputEventKey and RIGHT_HAND_KEYS.has((event as InputEventKey).physical_keycode):
		return RIGHT_HAND
	return LEFT_HAND


func _screen_width() -> float:
	if is_inside_tree():
		return get_viewport().get_visible_rect().size.x
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))


func _long_press_time() -> float:
	return _settings().long_press_time


func _long_press_slop() -> float:
	return _settings().long_press_slop


func _settings() -> GameConfig:
	return config if config != null else GameConfig.new()


## _ready 전에 쓰여도(테스트) 동작하도록 필요할 때 만든다.
func _ensure_gesture() -> SwipeGesture:
	if _gesture == null:
		_gesture = SwipeGesture.new(_settings().swipe_threshold)
	return _gesture
