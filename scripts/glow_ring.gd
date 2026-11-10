class_name GlowRing
extends Control
## 지금 누를 버튼을 노랗게 빛낸다 (HTML .glow: 0 0 0 3px rgba(255,210,63,.55) + 0 0 16px rgba(255,210,63,.35), 1.8초마다 맥박).
## 화면 전체를 덮는 투명 Control로 두고(입력은 통과), follow(대상)로 대상 버튼 둘레에 그린다. 색은 디자인 토큰 accent.

@export var period: float = 1.8
## 고리 두께·빛 번짐(px, 1080 기준)과 모서리 반지름.
@export var ring_width: float = 7.5
@export var blur: float = 42.0
@export var radius: float = 27.0

var target: Control
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 빛낼 버튼 (null이면 끈다).
func follow(control: Control) -> void:
	target = control
	_time = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if target == null:
		return
	_time = fmod(_time + delta, period)
	queue_redraw()


func _draw() -> void:
	if target == null or not target.is_visible_in_tree():
		return
	var accent: Color = get_theme_color(&"accent", DesignTokens.THEME_TYPE)
	var k: float = 0.5 - 0.5 * cos(_time / period * TAU)  # 0 → 1 → 0 (HTML 50%에서 가장 밝게)
	var rect: Rect2 = Rect2(target.global_position - global_position, target.size)
	var steps: int = 8
	for i: int in steps:
		var t: float = float(i + 1) / steps
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.draw_center = false
		box.set_border_width_all(int(ceil(blur / steps)) + 1)
		box.border_color = Color(accent, 0.35 * k * pow(1.0 - t, 2.0) * 2.5 / steps * 4.0)
		box.set_corner_radius_all(int(radius + blur * t))
		draw_style_box(box, rect.grow(ring_width + blur * t - blur / steps))
	var ring: StyleBoxFlat = StyleBoxFlat.new()
	ring.draw_center = false
	ring.set_border_width_all(int(ring_width))
	ring.border_color = Color(accent, 0.55 * k)
	ring.set_corner_radius_all(int(radius + ring_width))
	draw_style_box(ring, rect.grow(ring_width))
