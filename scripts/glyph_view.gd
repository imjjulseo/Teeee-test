class_name GlyphView
extends Control
## 색각 보조 문양 (기획서 7.3, B17). 색만으로 구분하지 않도록 색마다 다른 도형을 그린다.
## 이 Control의 영역 안에 꽉 차게 그린다.

enum Shape {
	NONE = -1,
	CIRCLE,
	TRIANGLE,
	SQUARE,
	DIAMOND,
}

var shape: Shape = Shape.NONE
var glyph_color: Color = Color(0, 0, 0, 0.35)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_glyph(p_shape: Shape, p_color: Color) -> void:
	shape = p_shape
	glyph_color = p_color
	queue_redraw()


func _draw() -> void:
	if shape == Shape.NONE:
		return
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0
	match shape:
		Shape.CIRCLE:
			draw_circle(c, r * 0.9, glyph_color)
		Shape.TRIANGLE:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.75), c + Vector2(-r * 0.95, r * 0.75),
			]), glyph_color)
		Shape.SQUARE:
			draw_rect(Rect2(c - Vector2.ONE * r * 0.75, Vector2.ONE * r * 1.5), glyph_color)
		Shape.DIAMOND:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0),
			]), glyph_color)
