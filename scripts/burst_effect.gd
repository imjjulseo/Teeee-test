class_name BurstEffect
extends Node2D
## 색 파편 한 번 (기획서 7.2장, HTML burst/stepFx와 같은 움직임): 무작위 방향으로 튀어 위로 살짝 뜬 뒤 중력으로 떨어지고,
## 작아지며 사라지는 네모 조각. 다 사라지면 스스로 없어진다. 수치는 BoardTheme Feedback 그룹 (1080 기준 화면 px).
## 판 안처럼 축소된 곳에 붙일 때는 부모 배율을 되돌려(scale = 1 / 부모 배율) 화면 px 그대로 움직이게 한다.
## 연출용 난수는 이 노드의 RandomNumberGenerator만 쓴다 (판 seed와 무관한 화면 효과).

## HTML은 프레임(1/60초)마다 가로 속도에 drag를 곱한다.
const DRAG_FRAME: float = 1.0 / 60.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## 조각: 위치·속도·나이·수명·크기·색.
var _parts: Array[Dictionary] = []
var _gravity: float = 0.0
var _drag: float = 1.0


func _init() -> void:
	_rng.randomize()


## color 조각 count개를 speed(px/초)로 터뜨린다. size는 조각 한 변(px).
func play(color: Color, theme_data: BoardTheme, count: int = -1, speed: float = -1.0, size: float = -1.0) -> void:
	var n: int = count if count > 0 else theme_data.burst_count
	var spd: float = speed if speed > 0.0 else theme_data.burst_speed
	var side: float = size if size > 0.0 else theme_data.burst_size
	_gravity = theme_data.burst_gravity
	_drag = theme_data.burst_drag
	for _i: int in n:
		var angle: float = _rng.randf() * TAU
		var v: float = spd * _rng.randf_range(theme_data.burst_speed_min, theme_data.burst_speed_max)
		_parts.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle) * v, sin(angle) * v - spd * theme_data.burst_lift),
			"age": 0.0,
			"life": _rng.randf_range(theme_data.burst_life_min, theme_data.burst_life_max),
			"size": side * _rng.randf_range(0.6, 1.4),
			"color": color,
		})
	queue_redraw()


## 남은 조각 수 (테스트/디버그용).
func part_count() -> int:
	return _parts.size()


func _process(delta: float) -> void:
	if _parts.is_empty():
		queue_free()
		return
	var drag: float = pow(_drag, delta / DRAG_FRAME)
	for i: int in range(_parts.size() - 1, -1, -1):
		var part: Dictionary = _parts[i]
		part["age"] = float(part["age"]) + delta
		if float(part["age"]) >= float(part["life"]):
			_parts.remove_at(i)
			continue
		var vel: Vector2 = part["vel"]
		vel.y += _gravity * delta
		vel.x *= drag
		part["vel"] = vel
		part["pos"] = (part["pos"] as Vector2) + vel * delta
	queue_redraw()


func _draw() -> void:
	for part: Dictionary in _parts:
		var k: float = 1.0 - float(part["age"]) / float(part["life"])
		var side: float = float(part["size"]) * (0.5 + 0.5 * k)
		var color: Color = part["color"]
		color.a *= k
		draw_rect(Rect2((part["pos"] as Vector2) - Vector2.ONE * side / 2.0, Vector2.ONE * side), color)
