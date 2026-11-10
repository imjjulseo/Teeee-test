class_name MatchPlanner
extends RefCounted
## 지금 판에서 매치까지 가는 이동 순서를 찾는다 (HTML tutPlans, 튜토리얼 자유 매치 힌트·"만들 자리"):
## 되돌아가는 수 없이 최대 depth수까지 깊이 우선으로 둬 보고, 처음 매치가 나는 곳에서 멈춘다. 씨앗은 매치되지 않는다.
## 판은 바꾸지 않는다 (색 배열 사본으로 둔다).

## 매치 하나까지의 길.
class Plan:
	var path: Array[Vector2i] = []
	var color: int = Board.NO_COLOR
	## 매치하는 순간 내가 서는 칸.
	var center: Vector2i = Vector2i.ZERO

const SEED: int = -1
const PLAYER: int = -2


## 찾은 길 모두 (노드가 node_cap을 넘으면 거기까지). canonical: 색 비교 변환 (색약 등).
static func find(board: Board, depth: int, node_cap: int, canonical: Callable = Callable()) -> Array[Plan]:
	var n: int = board.size
	var grid: PackedInt32Array = PackedInt32Array()
	grid.resize(n * n)
	for pos: Vector2i in board.all_positions():
		var type: Board.CellType = board.get_cell_type(pos)
		var value: int = SEED
		if type == Board.CellType.PLAYER:
			value = PLAYER
		elif type == Board.CellType.COLOR_BLOCK:
			var color: int = board.get_color(pos)
			value = canonical.call(color) if canonical.is_valid() else color
		grid[pos.y * n + pos.x] = value
	var state: Dictionary = {"nodes": 0, "plans": [] as Array[Plan]}
	var path: Array[Vector2i] = []
	_search(grid, n, board.player_pos, depth, Vector2i.ZERO, path, node_cap, state)
	return state["plans"]


## 가장 짧은 길 (filter: (Plan) -> bool 을 통과하는 것 중). 없으면 null.
static func best(board: Board, depth: int, node_cap: int, filter: Callable = Callable(), canonical: Callable = Callable()) -> Plan:
	var found: Plan = null
	for plan: Plan in find(board, depth, node_cap, canonical):
		if filter.is_valid() and not filter.call(plan):
			continue
		if found == null or plan.path.size() < found.path.size():
			found = plan
	return found


static func _search(grid: PackedInt32Array, n: int, at: Vector2i, depth: int, last: Vector2i, path: Array[Vector2i],
		node_cap: int, state: Dictionary) -> void:
	if depth <= 0 or state["nodes"] > node_cap:
		return
	for dir: Vector2i in Board.DIRECTIONS:
		if dir == -last and last != Vector2i.ZERO:
			continue
		var to: Vector2i = at + dir
		if to.x < 0 or to.y < 0 or to.x >= n or to.y >= n:
			continue
		state["nodes"] += 1
		var moved: int = grid[to.y * n + to.x]
		grid[at.y * n + at.x] = moved
		grid[to.y * n + to.x] = PLAYER
		path.append(dir)
		var color: int = _match_color(grid, n, to)
		if color != Board.NO_COLOR:
			var plan: Plan = Plan.new()
			plan.path = path.duplicate()
			plan.color = color
			plan.center = to
			(state["plans"] as Array[Plan]).append(plan)
		else:
			_search(grid, n, to, depth - 1, dir, path, node_cap, state)
		path.pop_back()
		grid[to.y * n + to.x] = moved
		grid[at.y * n + at.x] = PLAYER


static func _match_color(grid: PackedInt32Array, n: int, center: Vector2i) -> int:
	var color: int = Board.NO_COLOR
	for dir: Vector2i in Board.DIRECTIONS:
		var cell: Vector2i = center + dir
		if cell.x < 0 or cell.y < 0 or cell.x >= n or cell.y >= n:
			return Board.NO_COLOR
		var value: int = grid[cell.y * n + cell.x]
		if value < 0 or (color != Board.NO_COLOR and value != color):
			return Board.NO_COLOR
		color = value
	return color
