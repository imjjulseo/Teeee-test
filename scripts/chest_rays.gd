class_name ChestRays
extends Control
## 뽑기 상자가 열린 뒤 뒤에서 도는 빛줄기 (HTML .chest .rays: repeating-conic-gradient 8° 빛 · 14° 빈칸, 3초에 한 바퀴).
## 색은 결과 최고 등급 색 (show_rays). 효과 줄이기면 돌지 않는다.

@export var period: float = 3.0
@export var ray_degrees: float = 8.0
@export var gap_degrees: float = 14.0
@export_range(0.0, 1.0) var ray_alpha: float = 0.55

var _color: Color = Color.WHITE
var _spin: bool = true


## 빛줄기를 color로 보인다. spin이 false면 멈춘 채.
func show_rays(color: Color, spin: bool) -> void:
	_color = color
	_spin = spin
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible or not _spin:
		return
	pivot_offset = size / 2.0
	rotation = fmod(rotation + delta / period * TAU, TAU)


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = maxf(size.x, size.y) * 0.5
	var step: float = deg_to_rad(ray_degrees + gap_degrees)
	var width: float = deg_to_rad(ray_degrees)
	var a: float = 0.0
	while a < TAU:
		var points: PackedVector2Array = [center, center + Vector2.from_angle(a) * radius, center + Vector2.from_angle(a + width) * radius]
		draw_colored_polygon(points, Color(_color, ray_alpha))
		a += step
