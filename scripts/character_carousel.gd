class_name CharacterCarousel
extends Control
## 캐릭터 화면의 좌우로 넘기는 판 (기획서 8.1장, E38). 한 번에 보이는 판은 많아야 둘이라 씬에 있는 CharacterInfo 3장을 돌려 쓴다.
## 손가락을 끄는 대로 따라오고, 놓으면 가까운 판으로 맞춘다. 빠르게 밀면 속도만큼 여러 장을 넘어간다.
## 판 안의 버튼 위에서 끌어도 넘어가고 버튼은 눌리지 않는다 (_input에서 먼저 본다). 내용은 render(info, 번호)로 주인이 채운다.

signal page_changed(index: int)

## 끌기로 치는 가로 거리(px).
@export var drag_threshold: float = 30.0
## 놓을 때 이 속도(px/초)마다 한 장 더 넘어간다.
@export var flick_speed_per_page: float = 1400.0
## 판이 제자리로 가는 시간, 판 좌우 여백 (화살표 자리).
@export var snap_time: float = 0.22
@export var page_margin: float = 66.0

## 지금 판 번호.
var index: int = 0
## 입력을 받는다 (안내가 떠 있으면 주인이 끈다).
var input_enabled: bool = true
var _count: int = 0
var _render: Callable
var _pages: Array[CharacterInfo] = []
## 각 판이 지금 보여 주는 번호.
var _bound: PackedInt32Array = PackedInt32Array([-1, -1, -1])
var _position: float = 0.0
var _tween: Tween
var _pressed: bool = false
var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _start_position: float = 0.0
var _last_x: float = 0.0
var _last_time: int = 0
var _velocity: float = 0.0


func _ready() -> void:
	clip_contents = true
	resized.connect(_layout)


## 판 수와 그리는 함수 (render(info: CharacterInfo, index: int)).
func setup(count: int, render: Callable, start_index: int = 0) -> void:
	_count = count
	_render = render
	_pages.clear()
	for node: Node in [%Page0, %Page1, %Page2]:
		_pages.append(node as CharacterInfo)
	index = clampi(start_index, 0, maxi(count - 1, 0))
	_position = float(index)
	_layout()


## 보이는 판을 다시 그린다 (장착 등 상태가 바뀐 뒤).
func refresh() -> void:
	_bound = PackedInt32Array([-1, -1, -1])
	_layout()


## 지금 판.
func current_page() -> CharacterInfo:
	return _pages[index % _pages.size()] if not _pages.is_empty() else null


## 그 판으로 간다.
func go_to(target: int, animate: bool = true) -> void:
	var clamped: int = clampi(target, 0, maxi(_count - 1, 0))
	var changed: bool = clamped != index
	index = clamped
	if _tween != null:
		_tween.kill()
	if animate and is_inside_tree():
		_tween = create_tween()
		_tween.tween_method(_set_scroll, _position, float(index), snap_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_set_scroll(float(index))
	if changed:
		page_changed.emit(index)


func _on_left_pressed() -> void:
	go_to(index - 1)


func _on_right_pressed() -> void:
	go_to(index + 1)


func _input(event: InputEvent) -> void:
	if not input_enabled or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_on_button((event as InputEventMouseButton).pressed, (event as InputEventMouseButton).position)
	elif event is InputEventMouseMotion and _pressed:
		_on_motion((event as InputEventMouseMotion).position)


func _on_button(down: bool, pos: Vector2) -> void:
	if down:
		_pressed = get_global_rect().has_point(pos)
		_dragging = false
		_press_pos = pos
		_last_x = pos.x
		_last_time = Time.get_ticks_msec()
		_velocity = 0.0
		return
	if _dragging:
		_release()
	_pressed = false
	_dragging = false


func _on_motion(pos: Vector2) -> void:
	if not _dragging:
		var moved: Vector2 = pos - _press_pos
		if absf(moved.x) < drag_threshold or absf(moved.x) < absf(moved.y):
			return
		_dragging = true
		_start_position = _position
		if _tween != null:
			_tween.kill()
		propagate_notification(NOTIFICATION_SCROLL_BEGIN)  # 판 안의 눌린 버튼을 취소한다
	var now: int = Time.get_ticks_msec()
	var elapsed: float = maxf(float(now - _last_time) / 1000.0, 0.001)
	_velocity = lerpf(_velocity, (pos.x - _last_x) / elapsed, 0.5)
	_last_x = pos.x
	_last_time = now
	_set_scroll(clampf(_start_position - (pos.x - _press_pos.x) / maxf(size.x, 1.0), 0.0, float(maxi(_count - 1, 0))))
	get_viewport().set_input_as_handled()


## 손을 뗐다: 가까운 판 + 속도만큼 더.
func _release() -> void:
	var extra: int = int(absf(_velocity) / flick_speed_per_page) * (-1 if _velocity > 0.0 else 1)
	var nearest: int = roundi(_position)
	if extra == 0 and absf(_velocity) > flick_speed_per_page * 0.25:  # 살짝 튕기면 한 장
		extra = -1 if _velocity > 0.0 else 1
		nearest = index
	go_to(nearest + extra)


func _set_scroll(value: float) -> void:
	_position = value
	_layout()


func _layout() -> void:
	if _pages.is_empty():
		return
	var low: int = floori(_position)
	var high: int = ceili(_position)
	for i: int in _pages.size():
		_pages[i].visible = false
	for k: int in [low, high]:
		if k < 0 or k >= _count:
			continue
		var page: CharacterInfo = _pages[k % _pages.size()]
		if _bound[k % _pages.size()] != k:
			_bound[k % _pages.size()] = k
			if _render.is_valid():
				_render.call(page, k)
		page.visible = true
		page.position = Vector2((float(k) - _position) * size.x + page_margin, 0.0)
		page.size = Vector2(size.x - page_margin * 2.0, size.y)
