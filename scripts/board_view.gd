class_name BoardView
extends Node2D
## 논리 Board를 따라 그리기만 하는 View (기획서 7.2). Board를 읽기만 하고 절대 변경하지 않는다.
## 보드는 이 노드의 원점을 중심으로 그려진다. 위치·크기는 board_area(레이아웃 Control)의 가운데에 맞추고,
## 영역보다 크면 영역 안에 들어가도록 축소한다 (화면 비율·안전 영역 대응).
## 매치하면 칸마다 색 파편(burst_scene)과 판 흔들림. 효과 줄이기 옵션이면 흔들림·파편을 끈다.

## 탭한 화면 위치가 판의 칸이면 알린다 (조작 해석만 하고 이동은 GameController가 판단).
signal cell_tapped(cell: Vector2i)

@export var config: GameConfig
@export var theme_data: BoardTheme
@export var cell_scene: PackedScene
## 매치 파편 연출 (칸마다 하나씩 만든다).
@export var burst_scene: PackedScene
## 보드를 배치할 영역 (main.tscn의 GameLayout/.../BoardArea). 비어 있으면 현재 위치/크기를 유지.
@export var board_area: Control

## 셀 좌표 → 그 칸을 표시하는 CellView. Board 이동 결과를 받을 때 함께 갱신한다.
var _views: Dictionary[Vector2i, CellView] = {}
## 읽기 전용 참조. 셀 표시를 갱신할 때 상태를 읽기만 한다.
var _board: Board
## 플레이어 외형에 쓸 캐릭터 (null이면 테마 기본값).
var _character: CharacterData
## 능력의 표시 방식 (null = 보통).
var _style: DisplayStyle
var _move_tween: Tween
var _shake_tween: Tween
var _board_shake_tween: Tween
## 효과 줄이기 옵션 (흔들림·파편 끔).
var _reduce_motion: bool = false

@onready var _cells: Node2D = $Cells
## 능력의 판 위 표시 (깃발·구역). 칸 위에 그린다.
@onready var _marks: BoardMarksView = $Marks


## 씨앗 칸의 자람 표시를 매 프레임 논리 Board에 맞춘다 (읽기만 함).
func _process(_delta: float) -> void:
	if _board == null:
		return
	for pos: Vector2i in _views:
		if _board.get_cell_type(pos) == Board.CellType.SEED:
			_views[pos].set_growth(_board.get_grow_progress(pos))


func _on_character_ready(character: CharacterData) -> void:
	_character = character


func _on_board_created(board: Board) -> void:
	_kill_tweens()
	for child: Node in _cells.get_children():
		child.queue_free()
	_views.clear()
	_board = board
	_cells.position = _cells_home()
	_marks.position = _cells_home()
	for y: int in board.size:
		for x: int in board.size:
			var pos: Vector2i = Vector2i(x, y)
			var view: CellView = cell_scene.instantiate() as CellView
			_cells.add_child(view)
			_views[pos] = view
			_draw_cell(pos)
			view.position = _to_pixel(pos)
	_fit_to_area()


## 화면(캔버스) 위치 → 칸 좌표. 판 밖이면 (-1, -1).
func cell_at(canvas_position: Vector2) -> Vector2i:
	if _board == null:
		return Vector2i(-1, -1)
	var local: Vector2 = _cells.to_local(canvas_position)
	var step: float = theme_data.cell_size + theme_data.cell_gap
	var cell: Vector2i = Vector2i(floori(local.x / step), floori(local.y / step))
	return cell if _board.is_inside(cell) else Vector2i(-1, -1)


## 칸들을 감싸는 화면(캔버스) 사각형 (튜토리얼 스포트라이트). 비어 있으면 크기 0.
func cells_rect(cells: Array[Vector2i]) -> Rect2:
	if cells.is_empty() or _cells == null:
		return Rect2()
	var step: float = theme_data.cell_size + theme_data.cell_gap
	var xform: Transform2D = _cells.get_global_transform_with_canvas()
	var low: Vector2i = cells[0]
	var high: Vector2i = cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var top_left: Vector2 = xform * (Vector2(low) * step)
	var bottom_right: Vector2 = xform * (Vector2(high + Vector2i.ONE) * step - Vector2.ONE * theme_data.cell_gap)
	return Rect2(top_left, bottom_right - top_left)


func _on_tap_requested(canvas_position: Vector2) -> void:
	var cell: Vector2i = cell_at(canvas_position)
	if cell != Vector2i(-1, -1):
		cell_tapped.emit(cell)


## BoardArea 크기가 바뀌면 (화면 회전·비율·안전 영역) 다시 맞춘다.
func _on_board_area_resized() -> void:
	_fit_to_area()


## 보드 가로·세로 크기(px, 배율 1 기준).
func board_extent() -> float:
	var size: int = _board.size if _board != null else config.board_size
	return size * theme_data.cell_size + (size - 1) * theme_data.cell_gap


func _fit_to_area() -> void:
	if board_area == null:
		return
	var area: Rect2 = board_area.get_global_rect()
	global_position = area.get_center()
	var fit: float = minf(area.size.x, area.size.y) / board_extent()
	scale = Vector2.ONE * clampf(fit, 0.0, 1.0)


func _on_move_started(result: Board.MoveResult) -> void:
	_kill_tweens()
	var player_view: CellView = _views[result.from]
	var displaced_view: CellView = _views[result.to]
	_views[result.to] = player_view
	_views[result.from] = displaced_view
	if result.is_jump():  # 판 끝 넘기·순간이동: 판을 가로지르지 않게 바로 옮긴다 (항해사·떠돌이)
		player_view.position = _to_pixel(result.to)
		displaced_view.position = _to_pixel(result.from)
		_refresh_with_pop([result.to] as Array[Vector2i], theme_data.refill_pop_scale, theme_data.refill_pop_duration)
		return

	var duration: float = config.move_animation_time
	_move_tween = create_tween().set_parallel(true)
	_move_tween.tween_property(player_view, "position", _to_pixel(result.to), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(displaced_view, "position", _to_pixel(result.from), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if result.displaced_type != Board.CellType.EMPTY:
		var squash: Vector2 = Vector2.ONE * theme_data.swap_block_scale
		_move_tween.tween_property(displaced_view, "scale", squash, duration / 2.0)
		_move_tween.tween_property(displaced_view, "scale", Vector2.ONE, duration / 2.0).set_delay(duration / 2.0)


func _on_move_blocked(result: Board.MoveResult) -> void:
	if not _views.has(result.from):
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var player_view: CellView = _views[result.from]
	var home: Vector2 = _to_pixel(result.from)
	var offset: Vector2 = Vector2(result.to - result.from).limit_length(1.0) * theme_data.wall_shake_distance
	if offset == Vector2.ZERO:
		return
	player_view.position = home
	var half: float = theme_data.wall_shake_duration / 2.0
	_shake_tween = create_tween()
	_shake_tween.tween_property(player_view, "position", home + offset, half)
	_shake_tween.tween_property(player_view, "position", home, half)


## 일시정지 중에는 공정성을 위해 보드를 숨긴다 (기획서 9장).
func _on_state_changed(state: GameFlow.GameState) -> void:
	visible = state != GameFlow.GameState.PAUSED


## 매치: 4칸을 동시에 강조(팝)하며 씨앗 표시로 바꾸고, 칸마다 색 파편 + 판 흔들림 (7.2장).
func _on_matched(_center: Vector2i, color: int, cells: Array[Vector2i]) -> void:
	_refresh_with_pop(cells, theme_data.clear_pop_scale, config.clear_animation_time)
	if _reduce_motion:
		return
	for pos: Vector2i in cells:
		_burst_at(pos, theme_data.display_color(color, _style))
	_shake_board()


func _on_reduce_motion_ready(enabled: bool) -> void:
	_reduce_motion = enabled


## 효과 줄이기가 켜져 있는지 (테스트/디버그용).
func is_reduce_motion() -> bool:
	return _reduce_motion


## 리필: 다 자란 씨앗을 색 블록으로 바꾼다.
func _on_cells_refilled(cells: Array[Vector2i]) -> void:
	_refresh_with_pop(cells, theme_data.refill_pop_scale, theme_data.refill_pop_duration)


## 능력의 판 위 표시 (마라토너 깃발, 탐험가 구역).
func _on_marks_changed(marks: Array[BoardMark]) -> void:
	_marks.show_marks(marks)


## 능력의 표시 방식 (색약 색 합치기, 레트로 흑백). 모든 칸을 다시 칠한다.
func _on_display_style_changed(style: DisplayStyle) -> void:
	_style = style
	if _board == null:
		return
	for pos: Vector2i in _views:
		_draw_cell(pos)


## 지금 표시 방식 (테스트/디버그용, null = 보통).
func display_style() -> DisplayStyle:
	return _style


## 폭파범 연쇄: 터진 칸을 씨앗으로 다시 그리고 파편 (판 흔들림은 매치보다 약하게 생략).
func _on_cells_blasted(cells: Array[Vector2i], color: int) -> void:
	_refresh_with_pop(cells, theme_data.clear_pop_scale, config.clear_animation_time)
	if _reduce_motion:
		return
	for pos: Vector2i in cells:
		_burst_at(pos, theme_data.display_color(color, _style))


## 능력(화가 "물감")으로 색이 바뀐 칸을 다시 그린다.
func _on_cells_changed(cells: Array[Vector2i]) -> void:
	_refresh_with_pop(cells, theme_data.clear_pop_scale, config.clear_animation_time)


## 금화가 붙거나 사라진 칸을 다시 그린다.
func _on_coins_changed(cells: Array[Vector2i]) -> void:
	for pos: Vector2i in cells:
		_draw_cell(pos)


func _refresh_with_pop(cells: Array[Vector2i], pop_scale: float, duration: float) -> void:
	for pos: Vector2i in cells:
		var view: CellView = _views[pos]
		_draw_cell(pos)
		view.scale = Vector2.ONE * pop_scale
		view.create_tween().tween_property(view, "scale", Vector2.ONE, duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _burst_at(pos: Vector2i, color: Color) -> void:
	if burst_scene == null:
		return
	var burst: BurstEffect = burst_scene.instantiate() as BurstEffect
	_cells.add_child(burst)
	burst.position = _to_pixel(pos) + Vector2.ONE * theme_data.cell_size / 2.0
	burst.play(color, theme_data)


## 판 전체를 살짝 흔든다 (매치 손맛).
func _shake_board() -> void:
	if _board_shake_tween != null and _board_shake_tween.is_valid():
		_board_shake_tween.kill()
	var home: Vector2 = _cells_home()
	var d: float = theme_data.match_shake_distance
	var step: float = theme_data.match_shake_duration / 4.0
	_board_shake_tween = create_tween()
	for offset: Vector2 in [Vector2(d, -d / 2.0), Vector2(-d, d / 2.0), Vector2(d / 2.0, d / 2.0), Vector2.ZERO]:
		_board_shake_tween.tween_property(_cells, "position", home + offset, step)


## 칸들의 기준 위치 (판 가운데가 이 노드의 원점).
func _cells_home() -> Vector2:
	return -Vector2.ONE * board_extent() / 2.0


## 칸 하나를 논리 Board 상태대로 그린다 (타입·색·금화, 능력의 표시 방식).
func _draw_cell(pos: Vector2i) -> void:
	var view: CellView = _views[pos]
	view.display(_board.get_cell_type(pos), _board.get_color(pos), theme_data, _character, _style)
	view.show_coin(_board.has_coin(pos), theme_data)


## 진행 중인 연출을 즉시 끝내고 모든 View를 논리 좌표에 맞춘다.
func _kill_tweens() -> void:
	for tween: Tween in [_move_tween, _shake_tween, _board_shake_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_cells.position = _cells_home()
	for pos: Vector2i in _views:
		var view: CellView = _views[pos]
		view.position = _to_pixel(pos)
		view.scale = Vector2.ONE


func _to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos) * (theme_data.cell_size + theme_data.cell_gap)
