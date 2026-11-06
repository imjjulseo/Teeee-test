class_name PuzzleMiniView
extends Control
## 퍼즐 판 모양 미리보기 (설정 > 블럭 모으기 목록): 모을 블록 칸·내 칸·나머지를 작은 칸으로 그린다.

@export var target_color: Color = Color("5b8def")
@export var player_color: Color = Color.WHITE
@export var other_color: Color = Color(1, 1, 1, 0.12)
@export var gap: float = 2.0

var _def: PuzzleDef


func show_def(def: PuzzleDef) -> void:
	_def = def
	queue_redraw()


func _draw() -> void:
	if _def == null or _def.size() == 0:
		return
	var n: int = _def.size()
	var step: float = minf(size.x, size.y) / n
	for y: int in n:
		for x: int in _def.rows[y].length():
			var mark: String = _def.rows[y][x]
			var color: Color = target_color if mark == PuzzleDef.TARGET else (player_color if mark == PuzzleDef.PLAYER else other_color)
			draw_rect(Rect2(Vector2(x, y) * step, Vector2.ONE * (step - gap)), color)
