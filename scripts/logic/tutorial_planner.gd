class_name TutorialPlanner
extends RefCounted
## 규칙 튜토리얼 자유 매치의 "배운 모양" 계산 (HTML tutPlans · bestPlan · tutEnsure · tutAssist · makeShape).
## - 길 찾기: 되돌아가는 수 없이 최대 depth수, 처음 매치에서 멈춘다. built = 매치된 4블럭 중 내가 옮긴 적이 있는 블럭 수
##   (튜토리얼 동안 옮긴 기록 + 이번 길, 마지막 수에 가운데로 밀린 블럭은 빼고). 배운 모양 = built ≤ 단계(0: 있는 T로 들어가기).
## - 보장(ensure): 지금 필요한 색을 배운 모양으로 만들 수 있게 씨앗 색 → 가까운 모양의 블럭 색 → 새 T 모양 순서로 고친다.
## 판 칸(BoardCell)을 직접 바꾸는 곳은 ensure·make_shape·idle_plan뿐이고, 바뀐 칸 위치를 돌려준다 (화면이 다시 그린다).

## 길 하나.
class Plan:
	var path: Array[Vector2i] = []
	var built: int = 0
	var color: int = Board.NO_COLOR
	## 매치되는 4블럭 (그때 위치 기준 칸 객체).
	var cells: Array[BoardCell] = []
	## 매치하는 순간 내가 서는 칸.
	var center: Vector2i = Vector2i.ZERO

## 탐색 노드 한도 (HTML 60000).
const NODE_CAP: int = 60000

var board: Board
var color_count: int = 3
## 블럭(칸 객체) → 튜토리얼 동안 옮긴 횟수.
var moved: Dictionary = {}
## 배운 단계 (0 = 있는 T로 들어가기, 1 = 하나 당겨 T 만들기).
var level: int = 0
## 고를 색 조건 (color -> bool). 비어 있으면 아무 색.
var color_filter: Callable = Callable()
var pick: HtmlRng


func _init(p_board: Board, p_color_count: int, p_pick: HtmlRng) -> void:
	board = p_board
	color_count = p_color_count
	pick = p_pick


## 플레이어가 한 칸 움직였다: from 칸으로 밀려온 블럭을 옮긴 블럭으로 센다 (HTML tut.mv).
func note_move(from: Vector2i) -> void:
	var cell: BoardCell = board.get_cell(from)
	moved[cell] = int(moved.get(cell, 0)) + 1


## 블럭이 새로 생겼다 (매치로 깨진 칸·퍼즐로 깐 칸): 옮긴 기록을 지운다.
func forget(cells: Array[Vector2i]) -> void:
	for pos: Vector2i in cells:
		moved.erase(board.get_cell(pos))


## 지금 판에서 매치까지 가는 길 모두 (HTML tutPlans). seeds_grown이면 씨앗을 자랄 색 블럭으로 친다 (HTML seedsAs).
func plans(depth: int, seeds_grown: bool = false) -> Array[Plan]:
	var n: int = board.size
	var cells: Array[BoardCell] = []
	var colors: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in board.all_positions():
		var cell: BoardCell = board.get_cell(pos)
		cells.append(cell)
		var color: int = -1
		if cell.is_block() or (seeds_grown and cell.type == Board.CellType.SEED):
			color = cell.color
		colors.append(color)
	var state: Dictionary = {"nodes": 0, "out": [] as Array[Plan], "moved": moved.duplicate()}
	var path: Array[Vector2i] = []
	_search(cells, colors, n, board.player_pos, depth, -1, path, state)
	return state["out"]


## 가장 짧은 길 (HTML bestPlan): 색 조건 · 배운 모양(built ≤ level) · exact면 built == level인 것만.
func best(depth: int, exact: bool = false, seeds_grown: bool = false) -> Plan:
	var found: Plan = null
	for plan: Plan in plans(depth, seeds_grown):
		if not _passes(plan.color) or plan.built > level or (exact and plan.built != level):
			continue
		if found == null or plan.path.size() < found.path.size():
			found = plan
	return found


## 지금 판에서 가장 빨리 매치할 수 있는 배운 모양의 색 (HTML planColor). 없으면 무작위.
func plan_color() -> int:
	var found: Plan = null
	for plan: Plan in plans(7):
		if plan.built <= level and (found == null or plan.path.size() < found.path.size()):
			found = plan
	return found.color if found != null else pick.rnd(color_count)


## 필요한 색을 배운 모양으로 만들 수 있게 판을 고친다 (HTML tutEnsure). 바뀐 칸 위치.
func ensure() -> Array[Vector2i]:
	if best(9, true, true) != null:
		return []
	var changed: Array[Vector2i] = assist_seeds()
	if best(9, true, true) != null:
		return changed
	var all: Array[Plan] = _sorted(plans(8).filter(func(p: Plan) -> bool: return p.built == level))
	for plan: Plan in all:
		var color: int = _first_allowed_color()
		if color < 0:
			continue
		for cell: BoardCell in plan.cells:
			if cell.is_block() and cell.color != color:
				cell.color = color
				changed.append(_position_of(cell))
		return changed
	changed.append_array(make_shape())
	return changed


## 가까운 씨앗(최대 4개)의 자랄 색을 골라 배운 모양 길이가 3 + 단계에 가깝게 (HTML tutAssist). 바꾼 씨앗 위치.
func assist_seeds() -> Array[Vector2i]:
	var seeds: Array[Vector2i] = board.positions_of_type(Board.CellType.SEED)
	var from: Vector2i = board.player_pos
	seeds.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Board.distance(a, from) < Board.distance(b, from))
	seeds = seeds.slice(0, 4)
	if seeds.is_empty():
		return []
	var old: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in seeds:
		old.append(board.get_color(pos))
	var combos: int = int(pow(color_count, seeds.size()))
	var best_colors: PackedInt32Array = PackedInt32Array()
	var best_value: int = 1_000_000_000
	for m: int in combos:
		var colors: PackedInt32Array = PackedInt32Array()
		var x: int = m
		for _i: int in seeds.size():
			colors.append(x % color_count)
			x /= color_count
		if seeds.size() >= 4 and colors.count(colors[0]) == colors.size():  # 제자리 왕복 매치는 빼고
			continue
		for i: int in seeds.size():
			board.get_cell(seeds[i]).color = colors[i]
		var plan: Plan = best(8, true, true)
		if plan == null or plan.path.size() < 2:
			continue
		var value: int = absi(plan.path.size() - (3 + level)) * 10 + pick.rnd(10)
		if value < best_value:
			best_value = value
			best_colors = colors
	var use: PackedInt32Array = best_colors if not best_colors.is_empty() else old
	for i: int in seeds.size():
		board.get_cell(seeds[i]).color = use[i]
	return seeds if not best_colors.is_empty() else ([] as Array[Vector2i])


## 쓸 만한 모양이 아예 없을 때: 근처에 T를 만들고, 단계만큼 팔 블럭을 한 칸씩 밖으로 밀어 둔다 (HTML makeShape).
## 실제로 풀리는 것만 남긴다. 바꾼 칸 위치 (못 만들면 빈 배열).
func make_shape() -> Array[Vector2i]:
	var colors: Array[int] = []
	for color: int in color_count:
		if _passes(color):
			colors.append(color)
	if colors.is_empty():
		return []
	var n: int = board.size
	var player: Vector2i = board.player_pos
	var candidates: Array = []
	for y: int in range(1, n - 1):
		for x: int in range(1, n - 1):
			var d: int = Board.distance(Vector2i(x, y), player)
			if d >= 2 and d <= 5:
				candidates.append([d + pick.next_float(), Vector2i(x, y)])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in candidates.slice(0, 30):
		var center: Vector2i = entry[1]
		for k: int in 4:
			var shape_color: int = colors[pick.rnd(colors.size())]
			var arms: Array[Vector2i] = []
			for i: int in 4:
				if i != k:
					arms.append(center + TutorialStartBoard.DIRS[i])
			var shape: Array[Vector2i] = [center]
			shape.append_array(arms)
			var pushed: Array[Vector2i] = []
			for i: int in mini(level, arms.size()):
				shape[i + 1] = arms[i] + (arms[i] - center)
				pushed.append(arms[i])
			var touched: Array[Vector2i] = shape.duplicate()
			touched.append_array(pushed)
			if not touched.all(_usable):
				continue
			var old: PackedInt32Array = PackedInt32Array()
			for pos: Vector2i in touched:
				old.append(board.get_color(pos))
			for pos: Vector2i in shape:
				board.get_cell(pos).color = shape_color
			var not_shape: Array[int] = []
			for color: int in color_count:
				if color != shape_color:
					not_shape.append(color)
			for pos: Vector2i in pushed:
				board.get_cell(pos).color = not_shape[pick.rnd(not_shape.size())]
			if best(9, true) != null:
				return touched
			for i: int in touched.size():
				board.get_cell(touched[i]).color = old[i]
	return []


## 가만히 있을 때 보여 줄 길 (HTML tutFreeIdle): 배운 모양 → 없으면 새 모양 → 그래도 없으면 가장 가까운 모양의 색을 맞춘다.
## [길(없으면 null), 바뀐 칸 위치].
func idle_plan() -> Array:
	var changed: Array[Vector2i] = []
	var plan: Plan = best(8)
	if plan == null:
		changed.append_array(make_shape())
		plan = best(8)
	if plan == null:
		var all: Array[Plan] = _sorted(plans(6).filter(func(p: Plan) -> bool: return p.built <= level))
		for candidate: Plan in all:
			var color: int = _first_allowed_color()
			if color < 0:
				continue
			for cell: BoardCell in candidate.cells:
				if cell.is_block():
					cell.color = color
					changed.append(_position_of(cell))
			plan = best(8)
			break
	return [plan, changed]


## 이 길의 4블럭 지금 위치.
func plan_cells(plan: Plan) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: BoardCell in plan.cells:
		var pos: Vector2i = _position_of(cell)
		if pos.x >= 0:
			out.append(pos)
	return out


func _passes(color: int) -> bool:
	return not color_filter.is_valid() or color_filter.call(color)


func _first_allowed_color() -> int:
	for color: int in color_count:
		if _passes(color):
			return color
	return -1


func _usable(pos: Vector2i) -> bool:
	return board.is_inside(pos) and pos != board.player_pos and board.get_cell(pos).is_block()


func _position_of(cell: BoardCell) -> Vector2i:
	for pos: Vector2i in board.all_positions():
		if board.get_cell(pos) == cell:
			return pos
	return Vector2i(-1, -1)


static func _sorted(list: Array) -> Array[Plan]:
	var out: Array[Plan] = []
	out.assign(list)
	# 같은 길이면 찾은 순서 그대로 (HTML 정렬은 안정 정렬)
	var indexed: Array = []
	for i: int in out.size():
		indexed.append([out[i].path.size(), i, out[i]])
	indexed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	out.clear()
	for entry: Array in indexed:
		out.append(entry[2])
	return out


func _search(cells: Array[BoardCell], colors: PackedInt32Array, n: int, at: Vector2i, depth: int, last: int,
		path: Array[Vector2i], state: Dictionary) -> void:
	if depth <= 0 or int(state["nodes"]) > NODE_CAP:
		return
	var moved_now: Dictionary = state["moved"]
	for k: int in 4:
		if last >= 0 and (k ^ 1) == last:
			continue
		var dir: Vector2i = TutorialStartBoard.DIRS[k]
		var to: Vector2i = at + dir
		if to.x < 0 or to.y < 0 or to.x >= n or to.y >= n:
			continue
		state["nodes"] = int(state["nodes"]) + 1
		var a: int = at.y * n + at.x
		var b: int = to.y * n + to.x
		var moving: BoardCell = cells[b]
		var moving_color: int = colors[b]
		cells[a] = moving
		colors[a] = moving_color
		cells[b] = null
		colors[b] = -1
		moved_now[moving] = int(moved_now.get(moving, 0)) + 1
		path.append(dir)
		var color: int = -2
		var ok: bool = true
		var found: Array[BoardCell] = []
		for d: Vector2i in TutorialStartBoard.DIRS:
			var p: Vector2i = to + d
			if p.x < 0 or p.y < 0 or p.x >= n or p.y >= n:
				ok = false
				break
			var value: int = colors[p.y * n + p.x]
			if value < 0 or (color != -2 and value != color):
				ok = false
				break
			color = value
			found.append(cells[p.y * n + p.x])
		if ok:
			var plan: Plan = Plan.new()
			plan.path = path.duplicate()
			plan.color = color
			plan.cells = found
			plan.center = to
			for cell: BoardCell in found:
				if int(moved_now.get(cell, 0)) - (1 if cell == moving else 0) > 0:
					plan.built += 1
			(state["out"] as Array[Plan]).append(plan)
		else:
			_search(cells, colors, n, to, depth - 1, k, path, state)
		path.pop_back()
		moved_now[moving] = int(moved_now[moving]) - 1
		cells[b] = moving
		colors[b] = moving_color
		cells[a] = null
		colors[a] = -1
