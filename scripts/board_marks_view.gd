class_name BoardMarksView
extends Node2D
## 능력의 판 위 표시를 칸 위에 그린다 (마라토너 깃발, 탐험가 구역). 받은 BoardMark를 그대로 그릴 뿐 판정하지 않는다.
## 좌표는 칸 기준 (BoardView의 Cells와 같은 원점).
## 표시 종류에 디자인 이미지(BoardTheme.mark_textures)가 있으면 그 칸 범위에 이미지를 그린다 (화살표는 방향대로 돌림, 길은 늘 선).

@export var theme_data: BoardTheme

var _marks: Array[BoardMark] = []


func show_marks(marks: Array[BoardMark]) -> void:
	_marks = marks
	queue_redraw()


## 지금 그리는 표시 (테스트/디버그용).
func marks() -> Array[BoardMark]:
	return _marks


func _draw() -> void:
	var step: float = theme_data.cell_size + theme_data.cell_gap
	for mark: BoardMark in _marks:
		var rect: Rect2 = Rect2(Vector2(mark.rect.position) * step,
			Vector2(mark.rect.size) * step - Vector2.ONE * theme_data.cell_gap)
		var art: Texture2D = theme_data.mark_art(mark.kind) if mark.kind != BoardMark.Kind.PATH else null
		if art != null:
			_draw_art(art, rect, mark.direction if mark.kind == BoardMark.Kind.ARROW else Vector2i.RIGHT)
			continue
		match mark.kind:
			BoardMark.Kind.ZONE:
				_draw_dashed_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_zone_color)
			BoardMark.Kind.FLAG:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_color, false, theme_data.mark_line_width)
			BoardMark.Kind.FLAG_READY:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_ready_color, false, theme_data.mark_line_width * 1.5)
				_draw_pennant(rect, theme_data.mark_flag_ready_color)
			BoardMark.Kind.FLAG_NEXT:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_next_color, false, theme_data.mark_line_width)
			BoardMark.Kind.PATH:
				_draw_path(mark, step)
			BoardMark.Kind.WARN:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_warn_color, false, theme_data.mark_line_width)
			BoardMark.Kind.TARGET:
				draw_rect(rect.grow(-theme_data.mark_line_width), theme_data.puzzle_target_color, false, theme_data.mark_line_width)
			BoardMark.Kind.GOAL_CENTER:
				draw_circle(rect.get_center(), rect.size.x * 0.12, theme_data.puzzle_goal_color)
			BoardMark.Kind.GOAL_SLOT:
				_draw_dashed_rect(rect.grow(-theme_data.mark_line_width), theme_data.puzzle_goal_color)
			BoardMark.Kind.GOAL_SLOT_FILLED:
				_draw_dashed_rect(rect.grow(-theme_data.mark_line_width), theme_data.puzzle_filled_color)
			BoardMark.Kind.STAND:
				draw_circle(rect.get_center(), rect.size.x * 0.2, theme_data.puzzle_stand_color, false, theme_data.mark_line_width)
			BoardMark.Kind.PULL:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.puzzle_pull_color, false, theme_data.mark_line_width * 1.5)
			BoardMark.Kind.ARROW:
				_draw_arrow(rect, mark.direction)


## 이미지를 rect에 맞춰 그린다. 오른쪽을 향한 이미지를 direction 쪽으로 돌린다.
func _draw_art(art: Texture2D, rect: Rect2, direction: Vector2i) -> void:
	draw_set_transform(rect.get_center(), Vector2(direction).angle(), Vector2.ONE)
	draw_texture_rect(art, Rect2(-rect.size / 2.0, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 끈: 시작 칸 원 + 지나온 칸을 잇는 선 + 칸마다 점.
func _draw_path(mark: BoardMark, step: float) -> void:
	var half: float = theme_data.cell_size / 2.0
	var points: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in mark.cells:
		points.append(Vector2(cell) * step + Vector2.ONE * half)
	draw_arc(points[0], theme_data.cell_size * theme_data.trail_start_radius, 0.0, TAU, 32, theme_data.trail_color, theme_data.trail_width / 2.0)
	if points.size() > 1:
		draw_polyline(points, theme_data.trail_color, theme_data.trail_width, true)
	for point: Vector2 in points:
		draw_circle(point, theme_data.trail_width * 0.6, theme_data.trail_color)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, theme_data.mark_line_width, theme_data.mark_dash_length)


## 칸 가운데의 화살표 (direction 쪽).
func _draw_arrow(rect: Rect2, direction: Vector2i) -> void:
	var dir: Vector2 = Vector2(direction).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var c: Vector2 = rect.get_center()
	var s: float = rect.size.x * 0.3
	draw_colored_polygon(PackedVector2Array([c + dir * s, c - dir * s * 0.6 + side * s * 0.8, c - dir * s * 0.6 - side * s * 0.8]),
		theme_data.puzzle_arrow_color)


## 칸 왼쪽 위의 작은 깃발 (준비된 깃발).
func _draw_pennant(rect: Rect2, color: Color) -> void:
	var s: float = rect.size.x * 0.35
	var base: Vector2 = rect.position + Vector2.ONE * rect.size.x * 0.12
	draw_colored_polygon(PackedVector2Array([base, base + Vector2(s, s * 0.35), base + Vector2(0, s * 0.7)]), color)
