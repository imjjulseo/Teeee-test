class_name CaptionIcon
extends Control
## 튜토리얼 설명 칸 왼쪽 아이콘 (HTML #tspCap .ic): T(모을 색 ㅗ 모양) · 족보 점 · 금화 · 시계 · 씨앗.
## 색은 BoardTheme 블록 색, 그 밖은 디자인 토큰. 그리기만 한다.

enum Kind { NONE, SHAPE, DOTS, COIN, TIME, SEED }

@export var theme_data: BoardTheme

## 씬에 고정으로 둘 때(메뉴 로고): 시작 모양과 색.
@export var preset: Kind = Kind.NONE
@export var preset_colors: PackedInt32Array = PackedInt32Array()

var kind: Kind = Kind.NONE
var colors: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	if preset != Kind.NONE:
		show_icon(preset, preset_colors)


func show_icon(p_kind: Kind, p_colors: PackedInt32Array = PackedInt32Array()) -> void:
	kind = p_kind
	colors = p_colors
	visible = kind != Kind.NONE
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var origin: Vector2 = (size - Vector2.ONE * s) / 2.0
	match kind:
		Kind.SHAPE:
			_draw_shape(origin, s)
		Kind.DOTS:
			_draw_dots(origin, s)
		Kind.COIN:
			draw_circle(origin + Vector2.ONE * s / 2.0, s * 0.3, theme_data.coin_color)
			draw_circle(origin + Vector2.ONE * s / 2.0, s * 0.18, Color(theme_data.coin_color.darkened(0.25)), false, s * 0.05)
		Kind.TIME:
			var c: Vector2 = origin + Vector2.ONE * s / 2.0
			var ink: Color = get_theme_color(&"info", DesignTokens.THEME_TYPE)
			draw_arc(c, s * 0.32, 0.0, TAU, 40, ink, s * 0.07, true)
			draw_line(c, c + Vector2(0, -s * 0.2), ink, s * 0.07, true)
			draw_line(c, c + Vector2(s * 0.14, 0), ink, s * 0.07, true)
		Kind.SEED:
			var center: Vector2 = origin + Vector2.ONE * s / 2.0
			var leaf: Color = theme_data.block_colors[3] if theme_data.block_colors.size() > 3 else Color.WHITE
			draw_circle(center + Vector2(0, s * 0.12), s * 0.12, Color.WHITE)
			draw_circle(center + Vector2(-s * 0.1, -s * 0.06), s * 0.1, leaf)
			draw_circle(center + Vector2(s * 0.1, -s * 0.06), s * 0.1, leaf)


## HTML icoT: 내 칸(흰 테두리) 둘레 네 칸을 모을 색으로.
func _draw_shape(origin: Vector2, s: float) -> void:
	var cell: float = s / 3.0
	var pad: float = cell * 0.1
	var color: Color = _block(colors[0] if not colors.is_empty() else 1)
	for offset: Vector2 in [Vector2(1, 0), Vector2(0, 1), Vector2(2, 1), Vector2(1, 2)]:
		draw_rect(Rect2(origin + offset * cell + Vector2.ONE * pad, Vector2.ONE * (cell - pad * 2)), color)
	draw_rect(Rect2(origin + Vector2.ONE * cell + Vector2.ONE * pad * 1.5, Vector2.ONE * (cell - pad * 3)), Color.WHITE, false, s * 0.04)


## HTML icoDots: 족보 색 점 한 줄.
func _draw_dots(origin: Vector2, s: float) -> void:
	var count: int = maxi(colors.size(), 1)
	var dot: float = minf(s / count * 0.8, s * 0.42)
	var gap: float = dot * 0.2
	var total: float = dot * count + gap * (count - 1)
	var x: float = origin.x + (s - total) / 2.0
	for i: int in colors.size():
		draw_rect(Rect2(Vector2(x + i * (dot + gap), origin.y + (s - dot) / 2.0), Vector2.ONE * dot), _block(colors[i]))


func _block(color: int) -> Color:
	return theme_data.block_colors[color] if color >= 0 and color < theme_data.block_colors.size() else Color.WHITE
