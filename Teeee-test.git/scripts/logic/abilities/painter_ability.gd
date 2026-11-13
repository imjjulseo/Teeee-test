class_name PainterAbility
extends Ability
## 화가 "물감": 가장 많이 진행된 족보(진행 비율, 같으면 앞 슬롯)의 다음 색으로 블록을 최대 count개 칠한다.
## 지나온 길(최근 trail_length칸, 최근 것부터)의 다 자란 블록을 먼저, 모자라면 플레이어와 가까운 블록(같은 거리면 위·왼쪽부터).
## 이미 그 색인 블록·씨앗·플레이어는 건너뛴다. 금화는 그대로. 칠한 뒤 자동 판정 없음.

@export var count: int = 5
@export var trail_length: int = 12

## 업적 지표: 칠하기 횟수, 칠한 블록 누적.
const METRIC_PAINTS: StringName = &"painter_paints"
const METRIC_PAINTED: StringName = &"painter_painted"
## 칠한 색으로 매치한 수 (캐릭터 튜토리얼 목표).
const METRIC_PAINT_MATCHES: StringName = &"painter_paint_matches"

## 지나온 칸 (오래된 것부터).
var trail: Array[Vector2i] = []
## 마지막으로 칠한 색 (칠한 적 없으면 NO_COLOR).
var paint_color: int = Board.NO_COLOR


func on_move(_session: GameSession, result: Board.MoveResult) -> void:
	trail.append(result.from)
	if trail.size() > trail_length:
		trail.pop_front()


func on_match(session: GameSession, color: int, _cells: Array[Vector2i]) -> void:
	if color == paint_color:
		session.metrics.add(METRIC_PAINT_MATCHES)


## 튜토리얼 힌트: 칠한 색이나 캐릭터 족보 다음 색으로 하는 매치.
func prefers_hint(session: GameSession, color: int, _center: Vector2i, _goal: int) -> bool:
	return color == paint_color or Ability.needs_for_condition(session, color)


func trigger(session: GameSession) -> String:
	var recipes: RecipeSet = session.recipes
	var target: int = recipes.recipes[recipes.most_advanced_slot()].next_color()
	var picked: Array[Vector2i] = _pick_cells(session.board, target)
	for pos: Vector2i in picked:
		session.board.recolor_block(pos, target)
	paint_color = target
	if not picked.is_empty():
		session.metrics.add(METRIC_PAINTS)
		session.metrics.add(METRIC_PAINTED, picked.size())
		session.cells_changed.emit(picked)
	return "칠하기: 블록 %d개" % picked.size()


func _pick_cells(board: Board, target: int) -> Array[Vector2i]:
	var picked: Array[Vector2i] = []
	for i: int in range(trail.size() - 1, -1, -1):
		_try_pick(board, trail[i], target, picked)
	for pos: Vector2i in _by_distance(board):
		_try_pick(board, pos, target, picked)
	return picked


func _try_pick(board: Board, pos: Vector2i, target: int, picked: Array[Vector2i]) -> void:
	if picked.size() >= count or picked.has(pos):
		return
	if board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK and board.get_color(pos) != target:
		picked.append(pos)


## 플레이어를 뺀 칸을 플레이어와 가까운 순서로 (같은 거리면 위 줄·왼쪽부터).
func _by_distance(board: Board) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pos: Vector2i in board.all_positions():
		if pos != board.player_pos:
			cells.append(pos)
	var center: Vector2i = board.player_pos
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = Board.distance(a, center)
		var db: int = Board.distance(b, center)
		return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
	return cells
