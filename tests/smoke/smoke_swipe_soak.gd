extends "res://tests/smoke/smoke_base.gd"
## 스와이프 오래 하기 (E33 버그 확인): 실제 판에서 실제 터치 이벤트로 스와이프를 수백 번 넣고, 판 안쪽으로 민 스와이프는 매번
## 플레이어가 그 방향으로 한 칸 움직이는지 본다. 매치·리필·족보 완성이 섞이고, 중간중간 다른 손가락(손바닥)이 화면 가장자리에
## 닿아 있는 채로 스와이프하거나, 앞 손가락을 떼기 전에 다음 손가락으로 미는 경우(두 엄지 번갈아)를 넣는다.
## 모드: run

const SWIPES: int = 240
## 한 스와이프에 쓰는 프레임 (누름 → 끌기 → 뗌).
const FRAMES_PER_SWIPE: int = 3

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _done: int = 0
var _missed: int = 0
var _phase: int = 0
var _dir: Vector2i = Vector2i.ZERO
var _from: Vector2i = Vector2i.ZERO
var _resting: bool = false
var _overlap: bool = false
var _index: int = 0
var _start: Vector2 = Vector2.ZERO


func _setup() -> void:
	_rng.seed = 7
	config.game_duration = 100000.0
	CharacterStore.new().select(&"basic")
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.SWIPE)
	change_scene_to_file("res://scenes/main.tscn")


func _tick() -> void:
	match step:
		0:
			if playing(0.5):
				next_step()
		1:
			_swipe_frame()
			if _done >= SWIPES:
				_finger(_index, _start, false)
				if _resting:
					_finger(9, Vector2(20, 1000), false)
				expect(_missed == 0, "every swipe moved the player (%d missed of %d)" % [_missed, _done])
				expect(session().match_count > 0, "matches happened along the way (%d)" % session().match_count)
				finish()


func _swipe_frame() -> void:
	step_time = 0.0  # 오래 돌므로 시간 제한은 스와이프 단위로
	match _phase:
		0:
			_check_last()
			_from = session().board.player_pos
			_dir = _pick_direction()
			if _done % 40 == 10 and not _resting:  # 손바닥이 화면 가장자리에 닿음
				_resting = true
				_finger(9, Vector2(20, 1000), true)
			elif _done % 40 == 25 and _resting:
				_resting = false
				_finger(9, Vector2(20, 1000), false)
			var previous: int = _index
			_index = (_index + 1) % 4 if _done % 7 == 3 else _index
			_overlap = _index != previous  # 앞 손가락을 아직 떼지 않고 다음 손가락으로
			if not _overlap and _done > 0:
				_finger(previous, _start, false)
			_start = Vector2(540, 1050) + Vector2(_rng.randf_range(-200, 200), _rng.randf_range(-200, 200))
			_finger(_index, _start, true)
			_phase = 1
		1:
			_drag(_index, _start + Vector2(_dir) * 120.0)
			_phase = 2
		2:
			if _overlap:
				_finger((_index + 3) % 4, _start, false)  # 늦게 뗀 앞 손가락
			_done += 1
			_phase = 0


## 바로 앞 스와이프가 판 안쪽이었다면 움직였어야 한다.
func _check_last() -> void:
	if _done == 0 or _dir == Vector2i.ZERO:
		return
	if not session().board.is_inside(_from + _dir):
		return
	if flow().state != S.PLAYING and flow().state != S.WAITING:
		return
	if session().board.player_pos != _from + _dir:
		_missed += 1
		print("  missed swipe #%d %s from %s (now %s)" % [_done, _dir, _from, session().board.player_pos])


func _pick_direction() -> Vector2i:
	var me: Vector2i = session().board.player_pos
	var options: Array[Vector2i] = []
	for dir: Vector2i in Board.DIRECTIONS:
		if session().board.is_inside(me + dir):
			options.append(dir)
	return options[_rng.randi_range(0, options.size() - 1)]


func _finger(index: int, pos: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = root.get_final_transform() * pos
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, pos: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = root.get_final_transform() * pos
	Input.parse_input_event(event)
