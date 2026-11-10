class_name SewerAbility
extends Ability
## 수선사 "바늘": duration초(판 경과) 동안 끈(rope칸)이 플레이어를 따라온다. min_loop칸 이상 움직여 시작 칸으로 돌아오면
## 폐곡선 안쪽(판 가장자리에서 끈을 넘지 않고 닿을 수 없는 칸)의 다 자란 블록이 모두 뽑히며 매치 1회(매치 시간).
## 뽑힌 색들로 족보를 하나씩 진행하는데, 점수가 높은 족보부터 (완성 여부, 채운 칸)이 가장 좋아지는 순서를 고른다
## (색이 max_permute개 이하일 때 모든 순서를 시험). 시간 초과·끈 소진·안쪽 블록 없음 = 실패.
## 끈이 있는 동안과 수선 매치의 색은 캐릭터 족보를 진행하지 않는다.

@export var duration: float = 3.0
@export var rope: int = 12
@export var min_loop: int = 4
@export var max_permute: int = 6

## 업적 지표: 수선 성공 횟수.
const METRIC_CLOSES: StringName = &"sewer_closes"
## 수선 실패 (시간 초과·끈 소진·안쪽 블록 없음).
const MOMENT_FAIL: StringName = &"sewer_fail"

var armed: bool = false
## 끈이 지나온 칸 (시작 칸부터).
var path: Array[Vector2i] = []
## 쓴 끈 칸 수.
var used: int = 0
var time_left: float = 0.0
## 수선 성공 횟수.
var closes: int = 0

var _visited: Dictionary[Vector2i, bool] = {}


func trigger(session: GameSession) -> String:
	armed = true
	path = [session.board.player_pos]
	_visited = {session.board.player_pos: true}
	used = 0
	time_left = duration
	session.notify_marks_changed()
	return "끈 %d칸: %s초 안에 감싸고 시작점으로" % [rope, Ability.format_seconds(duration)]


func condition_frozen() -> bool:
	return armed


func on_move(session: GameSession, result: Board.MoveResult) -> void:
	if not armed:
		return
	path.append(result.to)
	_visited[result.to] = true
	used += 1
	session.notify_marks_changed()


func after_move(session: GameSession, _matched: bool) -> void:
	if not armed:
		return
	if used >= min_loop and session.board.player_pos == path[0]:
		_close(session)
	elif used >= rope:
		_fail(session, "끈이 모자라요")


func advance(session: GameSession, delta: float) -> void:
	if not armed:
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		_fail(session, "시간 끝")


func time_to_next_event() -> float:
	return maxf(time_left, 0.0) if armed else INF


func status_text() -> String:
	return "%d칸 · %s초" % [rope - used, Ability.format_seconds(time_left)] if armed else ""


func board_marks() -> Array[BoardMark]:
	var marks: Array[BoardMark] = []  # 조건식 안의 배열 리터럴은 타입이 붙지 않으므로 타입 있는 변수에 담는다
	if armed:
		marks.append(BoardMark.path(path))
	return marks


## 끈 안쪽 칸: 판 가장자리의 끈이 아닌 칸에서 상하좌우로 퍼져 닿지 못하는 칸.
func inside_cells(board: Board) -> Array[Vector2i]:
	var outside: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for pos: Vector2i in board.all_positions():
		var on_edge: bool = pos.x == 0 or pos.y == 0 or pos.x == board.size - 1 or pos.y == board.size - 1
		if on_edge and not _visited.has(pos):
			outside[pos] = true
			queue.append(pos)
	var i: int = 0
	while i < queue.size():
		var pos: Vector2i = queue[i]
		i += 1
		for dir: Vector2i in Board.DIRECTIONS:
			var next: Vector2i = pos + dir
			if board.is_inside(next) and not _visited.has(next) and not outside.has(next):
				outside[next] = true
				queue.append(next)
	var inside: Array[Vector2i] = []
	for pos: Vector2i in board.all_positions():
		if not _visited.has(pos) and not outside.has(pos):
			inside.append(pos)
	return inside


## 뽑힌 색들을 족보에 넣을 순서 (점수가 높은 족보부터 완성 여부·채운 칸이 가장 좋아지는 순서).
func best_order(colors: Array[int], recipes: RecipeSet, canonical: Callable) -> Array[int]:
	if colors.size() > max_permute:
		return colors
	var by_points: Array[int] = []
	for slot: int in recipes.slot_count():
		by_points.append(slot)
	by_points.sort_custom(func(a: int, b: int) -> bool:
		return recipes.recipes[a].points > recipes.recipes[b].points or (recipes.recipes[a].points == recipes.recipes[b].points and a < b))
	var best: Array[int] = colors
	var best_key: Array[int] = []
	for order: Array[int] in _permutations(colors):
		var key: Array[int] = _simulate(order, recipes, by_points, canonical)
		if best_key.is_empty() or _better(key, best_key):
			best_key = key
			best = order
	return best


func _close(session: GameSession) -> void:
	var board: Board = session.board
	var blocks: Array[Vector2i] = []
	for pos: Vector2i in inside_cells(board):
		if board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK:
			blocks.append(pos)
	if blocks.is_empty():
		_fail(session, "안에 블록이 없어요")
		return
	_disarm(session)
	var canonical: Callable = canonical_color
	var colors: Array[int] = []
	for pos: Vector2i in blocks:
		colors.append(canonical.call(board.get_color(pos)))
		session.blast_cell(pos)
	session.award_match_time()
	closes += 1
	session.metrics.add(METRIC_CLOSES)
	for color: int in best_order(colors, session.recipes, canonical):
		session.apply_clear_to_recipes(color)
	session.announce("수선: 블록 %d개" % blocks.size())


func _fail(session: GameSession, why: String) -> void:
	_disarm(session)
	session.announce(why)
	session.notify_moment(MOMENT_FAIL)


func _disarm(session: GameSession) -> void:
	armed = false
	path.clear()
	_visited.clear()
	session.notify_marks_changed()


## 순서대로 넣었을 때 by_points 순서의 [완성 여부, 채운 칸, …] (사본으로 시험).
static func _simulate(order: Array[int], recipes: RecipeSet, by_points: Array[int], canonical: Callable) -> Array[int]:
	var copies: Array[RecipeSet.Recipe] = []
	for recipe: RecipeSet.Recipe in recipes.recipes:
		copies.append(recipe.copy())
	for color: int in order:
		for recipe: RecipeSet.Recipe in copies:
			if not recipe.is_complete() and canonical.call(recipe.next_color()) == color:
				recipe.advance()
	var key: Array[int] = []
	for slot: int in by_points:
		key.append(1 if copies[slot].is_complete() else 0)
		key.append(copies[slot].filled())
	return key


static func _better(key: Array[int], best_key: Array[int]) -> bool:
	for i: int in key.size():
		if key[i] != best_key[i]:
			return key[i] > best_key[i]
	return false


static func _permutations(items: Array[int]) -> Array[Array]:
	if items.size() <= 1:
		return [items.duplicate()]
	var result: Array[Array] = []
	for i: int in items.size():
		var rest: Array[int] = items.duplicate()
		rest.remove_at(i)
		for tail: Array in _permutations(rest):
			var order: Array[int] = [items[i]]
			order.append_array(tail)
			result.append(order)
	return result
