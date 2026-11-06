class_name SpotlightRings
extends Control
## 스포트라이트 구멍 둘레의 테두리.

@export var ring_color: Color = Color("ffd23f")
@export var ring_width: float = 4.0

var _rects: Array[Rect2] = []


func show_rects(rects: Array[Rect2]) -> void:
	_rects = rects
	queue_redraw()


func _draw() -> void:
	for rect: Rect2 in _rects:
		draw_rect(rect, ring_color, false, ring_width)
