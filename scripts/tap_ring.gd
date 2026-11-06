class_name TapRing
extends Control
## "눌러서 계속" 표시 (HTML #tspCap .tp): 노란 고리가 1초마다 작아졌다 커지며 안쪽이 두꺼워진다 (@keyframes tapHint).

@export var period: float = 1.0

var _time: float = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time = fmod(_time + delta, period)
	queue_redraw()


func _draw() -> void:
	var k: float = 0.5 - 0.5 * cos(_time / period * TAU)  # 0 → 1 → 0
	var accent: Color = get_theme_color(&"accent", DesignTokens.THEME_TYPE)
	var s: float = minf(size.x, size.y)
	var radius: float = s / 2.0 * lerpf(1.0, 0.7, k)
	var width: float = s * lerpf(0.1, 0.27, k)
	draw_arc(size / 2.0, radius - width / 2.0, 0.0, TAU, 48, Color(accent, lerpf(0.8, 0.5, k)), width, true)
