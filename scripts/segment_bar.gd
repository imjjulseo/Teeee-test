class_name SegmentBar
extends Control
## 몇 번째 판인지 (HTML 11/06 .pseg): n칸 중 index + 1칸을 노랗게. 단계 번호·구분자 없음.

@export var segment_size: Vector2 = Vector2(32, 9)
@export var gap: float = 7.0

var index: int = 0
var count: int = 0


func show_progress(p_index: int, p_count: int) -> void:
	index = p_index
	count = p_count
	visible = count > 0
	custom_minimum_size = Vector2(count * segment_size.x + maxf(count - 1, 0) * gap, segment_size.y)
	queue_redraw()


func _draw() -> void:
	var on: Color = get_theme_color(&"accent", DesignTokens.THEME_TYPE)
	var off: Color = get_theme_color(&"track", DesignTokens.THEME_TYPE)
	for i: int in count:
		var rect: Rect2 = Rect2(Vector2(i * (segment_size.x + gap), 0), segment_size)
		draw_style_box(_box(on if i <= index else off), rect)


func _box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(segment_size.y / 2.0))
	return box
