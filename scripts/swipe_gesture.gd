class_name SwipeGesture
extends RefCounted
## 손가락 하나의 스와이프·탭 판정 (기획서 3.2장, E8). 순수 로직 — 위치와 손가락 번호만 받는다.
## - 첫 손가락만 추적한다 (멀티터치의 두 번째 손가락은 무시).
## - 손가락을 떼지 않아도 시작점에서 threshold를 넘게 움직이는 순간 큰 축 방향으로 한 번 이동한다. 한 번 닿을 때 1칸.
## - 움직이지 않고 떼면 탭이다 (옆 칸 탭 이동).

const NO_TOUCH: int = -1

var threshold: float

var _index: int = NO_TOUCH
var _start: Vector2 = Vector2.ZERO
var _fired: bool = false


func _init(p_threshold: float) -> void:
	threshold = p_threshold


func is_tracking() -> bool:
	return _index != NO_TOUCH


## 추적 중인 손가락이 이미 이동을 일으켰다 (그 뒤로 떼지 않고 있으면 그 방향을 누르고 있는 것).
func has_fired() -> bool:
	return is_tracking() and _fired


## 추적 중인 손가락이 닿은 위치.
func start_position() -> Vector2:
	return _start


## 손가락이 닿았다. 이미 다른 손가락을 추적 중이면 무시한다.
func press(index: int, position: Vector2) -> void:
	if is_tracking():
		return
	_index = index
	_start = position
	_fired = false


## 손가락이 움직였다. 이번에 이동이 정해지면 방향, 아니면 Vector2i.ZERO.
func drag(index: int, position: Vector2) -> Vector2i:
	if index != _index or _fired:
		return Vector2i.ZERO
	var delta: Vector2 = position - _start
	if delta.length() < threshold:
		return Vector2i.ZERO
	_fired = true
	return direction_of(delta)


## 손가락을 뗐다. 움직이지 않은 탭이면 true (취소된 터치는 탭이 아니다).
func release(index: int, canceled: bool = false) -> bool:
	if index != _index:
		return false
	var tap: bool = not _fired and not canceled
	reset()
	return tap


func reset() -> void:
	_index = NO_TOUCH
	_fired = false


## 더 크게 움직인 축의 방향.
static func direction_of(delta: Vector2) -> Vector2i:
	if absf(delta.x) > absf(delta.y):
		return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
