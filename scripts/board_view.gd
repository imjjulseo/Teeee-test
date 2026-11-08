class_name BoardView
extends Node2D
## 논리 Board를 따라 그리기만 하는 View (기획서 7.2). Board를 읽기만 하고 절대 변경하지 않는다.
## 보드는 이 노드의 원점을 중심으로 그려진다. 위치·크기는 board_area(레이아웃 Control)의 가운데에 맞추고,
## 영역보다 크면 영역 안에 들어가도록 축소한다 (화면 비율·안전 영역 대응).
## 연출은 HTML 판 연출과 같다 (E32, 수치는 BoardTheme Feedback 그룹): 이동 미끄러짐, 벽 튕김, 매치 = 깨진 블록이 커지며
## 밝아지고 사라짐 + 칸마다 색 파편 + 판 흔들림, 블록이 생기거나 색이 바뀌면 번쩍임(pop), 퍼즐을 깔면 내 칸에서 가까운 칸부터
## 튀어나옴. 효과 줄이기 옵션이면 흔들림·튕김·파편·번쩍임·튀어나옴을 모두 끄고 바로 그린다.

## 탭한 화면 위치가 판의 칸이면 알린다 (조작 해석만 하고 이동은 GameController가 판단).
signal cell_tapped(cell: Vector2i)
## 매치한 자리(첫 칸 가운데)의 화면(캔버스) 위치. HUD가 금화 "+10"을 이 자리에서 코인 쪽으로 날린다.
signal match_point(canvas_position: Vector2)

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
	_kill_tweens(true)
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
		_pop_cells([result.to] as Array[Vector2i])
		return
	if _reduce_motion:  # HTML: 효과 줄이기면 transition 없이 바로
		player_view.position = _to_pixel(result.to)
		displaced_view.position = _to_pixel(result.from)
		return
	# HTML .blk: transform .09s cubic-bezier(.3,.8,.4,1) — 두 칸이 같은 곡선으로 자리를 바꾼다.
	var player_frames: Array = [[0.0, {"position": player_view.position}], [1.0, {"position": _to_pixel(result.to)}]]
	var displaced_frames: Array = [[0.0, {"position": displaced_view.position}], [1.0, {"position": _to_pixel(result.from)}]]
	_move_tween = KeyframeAnim.play(self, player_view, config.move_animation_time, player_frames, theme_data.move_curve)
	_move_tween.parallel().tween_method(func(t: float) -> void: KeyframeAnim.apply(displaced_view, displaced_frames, t, theme_data.move_curve),
		0.0, 1.0, config.move_animation_time)


func _on_move_blocked(result: Board.MoveResult) -> void:
	if not _views.has(result.from):
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	var player_view: CellView = _views[result.from]
	var home: Vector2 = _to_pixel(result.from)
	player_view.position = home
	# HTML nudge: 6 CSS px 튕겼다 돌아옴, 0.17초 ease-out (화면 px → 판 안 px).
	var offset: Vector2 = Vector2(result.to - result.from).limit_length(1.0) * theme_data.wall_shake_distance / _screen_scale()
	if offset == Vector2.ZERO or _reduce_motion:
		return
	var frames: Array = [[0.0, {"position": home}], [0.5, {"position": home + offset}], [1.0, {"position": home}]]
	_shake_tween = KeyframeAnim.play(self, player_view, theme_data.wall_shake_duration, frames, KeyframeAnim.EASE_OUT, 0.0, true)


## 일시정지 중에는 공정성을 위해 보드를 숨긴다 (기획서 9장).
func _on_state_changed(state: GameFlow.GameState) -> void:
	visible = state != GameFlow.GameState.PAUSED


## 매치: 깨진 칸은 바로 씨앗으로 그리고, 그 위에서 원래 블록이 커지며 밝아지고 사라진다 (HTML .gone).
## 칸마다 색 파편 + 판 흔들림 (7.2장). 금화를 날릴 자리를 match_point로 알린다.
func _on_matched(_center: Vector2i, color: int, cells: Array[Vector2i]) -> void:
	_clear_cells(cells, color)
	if not cells.is_empty():
		match_point.emit(cell_center(cells[0]))
	if not _reduce_motion:
		_shake_board()


func _on_reduce_motion_ready(enabled: bool) -> void:
	_reduce_motion = enabled


## 효과 줄이기가 켜져 있는지 (테스트/디버그용).
func is_reduce_motion() -> bool:
	return _reduce_motion


## 리필: 다 자란 씨앗을 색 블록으로 바꾸며 번쩍인다 (HTML mature → pop).
func _on_cells_refilled(cells: Array[Vector2i]) -> void:
	_pop_cells(cells)


## 퍼즐을 깔았다 (튜토리얼 pzStamp): origin(내 칸)에서 가까운 칸부터 작게·투명하게 시작해 튀어나온다 (HTML flipIn).
func _on_cells_stamped(cells: Array[Vector2i], origin: Vector2i) -> void:
	for pos: Vector2i in cells:
		if not _views.has(pos):
			continue
		var view: CellView = _views[pos]
		_draw_cell(pos)
		if _reduce_motion:
			continue
		var distance: int = absi(pos.x - origin.x) + absi(pos.y - origin.y)
		var frames: Array = [
			[0.0, {"scale": Vector2.ONE * theme_data.stamp_start_scale, "modulate:a": 0.0}],
			[1.0, {"scale": Vector2.ONE, "modulate:a": 1.0}],
		]
		KeyframeAnim.play(view, view, theme_data.stamp_duration, frames, theme_data.stamp_curve, distance * theme_data.stamp_delay_step)


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


## 폭파범 연쇄: 터진 칸을 씨앗으로 다시 그리고 깨짐 연출 + 파편 (판 흔들림은 매치보다 약하게 생략).
func _on_cells_blasted(cells: Array[Vector2i], color: int) -> void:
	_clear_cells(cells, color)


## 능력(화가 "물감")·튜토리얼 판 고치기로 색이 바뀐 칸을 다시 그리며 번쩍인다 (HTML retrigger pop).
func _on_cells_changed(cells: Array[Vector2i]) -> void:
	_pop_cells(cells)


## 칸 가운데의 화면(캔버스) 위치 (HUD 떠오르는 글자·금화).
func cell_center(cell: Vector2i) -> Vector2:
	if _cells == null:
		return Vector2.ZERO
	return _cells.get_global_transform_with_canvas() * (_to_pixel(cell) + Vector2.ONE * theme_data.cell_size / 2.0)


## 금화가 붙거나 사라진 칸을 다시 그린다.
func _on_coins_changed(cells: Array[Vector2i]) -> void:
	for pos: Vector2i in cells:
		_draw_cell(pos)


## 칸들을 다시 그리고 번쩍인다 (HTML pop: brightness 2.1 · saturate .4 → 원래, 0.26초 ease-out).
func _pop_cells(cells: Array[Vector2i]) -> void:
	for pos: Vector2i in cells:
		if not _views.has(pos):
			continue
		var view: CellView = _views[pos]
		_draw_cell(pos)
		if _reduce_motion:
			continue
		# CSS처럼 filter 값(밝기·채도)을 보간하고 그때그때 색을 계산한다 (색 배율을 보간하면 하얗게 날아간 구간이 짧아진다).
		var base: Variant = _plain_color(pos)
		var b0: float = theme_data.pop_brightness
		var s0: float = theme_data.pop_saturation
		KeyframeAnim.run(view, theme_data.pop_duration, func(e: float) -> void:
			view.modulate = _filtered(base, lerpf(b0, 1.0, e), lerpf(s0, 1.0, e)), KeyframeAnim.EASE_OUT)


## 매치·폭파로 깨진 칸: 씨앗으로 다시 그리고, 그 자리에 원래 블록의 그림자를 띄워 커지며 밝아지고 사라지게 한다 (HTML .gone)
## + 칸마다 색 파편.
func _clear_cells(cells: Array[Vector2i], color: int) -> void:
	for pos: Vector2i in cells:
		if _views.has(pos):
			_draw_cell(pos)
	if _reduce_motion:
		return
	for pos: Vector2i in cells:
		_ghost_at(pos, color)
		_burst_at(pos, theme_data.display_color(color, _style))


## 깨진 블록의 그림자 한 장 (연출이 끝나면 사라진다).
func _ghost_at(pos: Vector2i, color: int) -> void:
	if cell_scene == null:
		return
	var ghost: CellView = cell_scene.instantiate() as CellView
	_cells.add_child(ghost)
	ghost.display(Board.CellType.COLOR_BLOCK, color, theme_data, _character, _style)
	ghost.position = _to_pixel(pos)
	# HTML .gone: 크기는 ease-out, 밝기는 ease, 투명은 ease-out (CSS transition마다 곡선이 다르다).
	var base: Color = theme_data.display_color(color, _style)
	var b1: float = theme_data.clear_brightness
	var grow: float = theme_data.clear_scale
	KeyframeAnim.run(ghost, config.clear_animation_time, func(t: float) -> void:
		var out: float = KeyframeAnim.bezier(KeyframeAnim.EASE_OUT, t)
		ghost.scale = Vector2.ONE * lerpf(1.0, grow, out)
		var lit: Color = BoardTheme.filter_modulate(base, lerpf(1.0, b1, KeyframeAnim.bezier(KeyframeAnim.EASE, t)))
		lit.a = 1.0 - out
		ghost.modulate = lit, KeyframeAnim.LINEAR).finished.connect(ghost.queue_free)


func _burst_at(pos: Vector2i, color: Color) -> void:
	if burst_scene == null:
		return
	var burst: BurstEffect = burst_scene.instantiate() as BurstEffect
	_cells.add_child(burst)
	burst.position = _to_pixel(pos) + Vector2.ONE * theme_data.cell_size / 2.0
	burst.scale = Vector2.ONE / _screen_scale()  # 파편 수치는 화면 px (판 배율과 무관하게 HTML과 같은 크기)
	burst.play(color, theme_data)


## 판 전체를 살짝 흔든다 (HTML #boardwrap.shake: 0.2초, 25% (2,-1) · 50% (-2,1) · 75% (1,1) CSS px, 구간마다 ease).
func _shake_board() -> void:
	if _board_shake_tween != null and _board_shake_tween.is_valid():
		_board_shake_tween.kill()
	var home: Vector2 = _cells_home()
	var d: float = theme_data.match_shake_distance / _screen_scale()
	var frames: Array = [
		[0.0, {"position": home}],
		[0.25, {"position": home + Vector2(d, -d / 2.0)}],
		[0.5, {"position": home + Vector2(-d, d / 2.0)}],
		[0.75, {"position": home + Vector2(d / 2.0, d / 2.0)}],
		[1.0, {"position": home}],
	]
	_board_shake_tween = KeyframeAnim.play(self, _cells, theme_data.match_shake_duration, frames, KeyframeAnim.EASE)


## 판의 화면 배율 (판 안 px 1 = 화면 px 몇). 화면 px로 적은 연출 수치를 판 안 px로 바꿀 때 나눈다.
func _screen_scale() -> float:
	return maxf(scale.x, 0.01)


## 그림 블록이면 그 표시 색, 이미지 칸이나 그 밖은 null (번쩍임 계산용).
func _plain_color(pos: Vector2i) -> Variant:
	if _board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK and theme_data.block_art(_board.get_color(pos), _style) == null:
		return theme_data.display_color(_board.get_color(pos), _style)
	return null


## CSS filter brightness·saturate를 건 modulate (색을 모르면 밝기 배율만).
static func _filtered(base: Variant, brightness: float, saturation: float) -> Color:
	if base is Color:
		return BoardTheme.filter_modulate(base, brightness, saturation)
	return Color(brightness, brightness, brightness)


## 칸들의 기준 위치 (판 가운데가 이 노드의 원점).
func _cells_home() -> Vector2:
	return -Vector2.ONE * board_extent() / 2.0


## 칸 하나를 논리 Board 상태대로 그린다 (타입·색·금화, 능력의 표시 방식).
func _draw_cell(pos: Vector2i) -> void:
	var view: CellView = _views[pos]
	view.display(_board.get_cell_type(pos), _board.get_color(pos), theme_data, _character, _style)
	view.show_coin(_board.has_coin(pos), theme_data)


## 진행 중인 이동 연출을 즉시 끝내고 모든 View를 논리 좌표에 맞춘다. with_board면 판 흔들림도 (새 판).
## (매치 흔들림은 이동해도 이어진다 — HTML과 같게.)
func _kill_tweens(with_board: bool = false) -> void:
	for tween: Tween in [_move_tween, _shake_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	if with_board:
		if _board_shake_tween != null and _board_shake_tween.is_valid():
			_board_shake_tween.kill()
		_cells.position = _cells_home()
	for pos: Vector2i in _views:
		var view: CellView = _views[pos]
		view.position = _to_pixel(pos)
		view.scale = Vector2.ONE


func _to_pixel(pos: Vector2i) -> Vector2:
	return Vector2(pos) * (theme_data.cell_size + theme_data.cell_gap)
