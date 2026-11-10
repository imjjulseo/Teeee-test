class_name BlockGesture
extends Control
## 아래 줄 가운데 캐릭터 블럭의 입력 (E38): 누르면 tapped, 위로 swipe_distance만큼 끌면 swiped_up (메인에서만 게임 시작).
## 끄는 동안 블럭(자식 %Block)이 손가락을 따라 올라온다. 무엇을 할지는 정하지 않고 signal로만 알린다.

signal tapped
signal swiped_up

## 게임 시작으로 치는 위쪽 거리(px, 1080 기준).
@export var swipe_distance: float = 120.0
## 이만큼 움직이면 탭이 아니다.
@export var tap_slop: float = 24.0

## 누르기를 받는다 (잠긴 동안 false).
var tap_enabled: bool = true
## 위로 끌기를 받는다 (메인에서만).
var swipe_enabled: bool = false
var _pressed: bool = false
var _moved: bool = false
var _fired: bool = false
var _start: Vector2 = Vector2.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_button((event as InputEventMouseButton).pressed, (event as InputEventMouseButton).position)
		accept_event()
	elif event is InputEventMouseMotion and _pressed:
		_on_drag((event as InputEventMouseMotion).position)
		accept_event()


func _on_button(down: bool, pos: Vector2) -> void:
	if down:
		_pressed = true
		_moved = false
		_fired = false
		_start = pos
		return
	if not _pressed:
		return
	_pressed = false
	if _fired:
		return
	_lift_block(0.0)
	if not _moved and tap_enabled:
		tapped.emit()


func _on_drag(pos: Vector2) -> void:
	var delta: Vector2 = pos - _start
	if delta.length() > tap_slop:
		_moved = true
	if not swipe_enabled or _fired:
		return
	var lift: float = clampf(-delta.y, 0.0, swipe_distance)
	_lift_block(lift)
	if lift >= swipe_distance:
		_fired = true
		swiped_up.emit()


func _lift_block(amount: float) -> void:
	(%Block as Control).position.y = _rest_y() - amount


## 블럭의 쉬는 자리 (가운데).
func _rest_y() -> float:
	return (size.y - (%Block as Control).size.y) / 2.0
