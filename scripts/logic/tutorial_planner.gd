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

# 탐색 중 판 (칸 번호 배열)과 이웃 표·결과.
var _cells: Array[BoardCell] = []
var _colors: PackedInt32Array = PackedInt32Array()
var _moved_at: PackedInt32Array = PackedInt32Array()
var _step: PackedInt32Array = PackedInt32Array()
var _steps_size: int = -1
var _count: int = 0
## 지금 길의 방향 번호 (DIRS 순).
var _ks: PackedInt32Array = PackedInt32Array()
var _out: Array[Plan] = []
var _nodes: int = 0
# 씨앗 색 조합 탐색 (assist_seeds): 칸에 있는 씨앗 번호, 조합 마스크 단어 수, (씨앗·색) → 그 색인 조합 마스크, 조합별 가장 짧은 길.
var _var_at: PackedInt32Array = PackedInt32Array()
var _words: int = 1
var _eq: PackedInt64Array = PackedInt64Array()
var _combo_best: Array = []


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
	var count: int = n * n
	_ensure_steps(n)
	_cells.resize(count)
	_colors.resize(count)
	_moved_at.resize(count)
	var index: int = 0
	for pos: Vector2i in board.all_positions():
		var cell: BoardCell = board.get_cell(pos)
		_cells[index] = cell
		var color: int = -1
		if cell.is_block() or (seeds_grown and cell.type == Board.CellType.SEED):
			color = cell.color
		_colors[index] = color
		_moved_at[index] = int(moved.get(cell, 0))
		index += 1
	_nodes = 0
	_out = []
	_ks.clear()
	_search(board.player_pos.y * n + board.player_pos.x, depth, -1)
	var out: Array[Plan] = _out
	_out = []
	_cells.fill(null)
	return out


## 가장 짧은 길 (HTML bestPlan): 색 조건 · 배운 모양(built ≤ level) · exact면 built == level인 것만.
## 깊이를 1수씩 늘려 가며 찾는다: 가장 짧은 길이 d수면 d수까지만 탐색한다 (깊이 우선 순서는 같으므로 같은 길이 중 먼저 찾는 길도 같다).
## 매치 뒤마다 부르므로 깊이 9 전체 탐색(수만 노드)을 피한다 — 튜토리얼 중 끊김 수정.
func best(depth: int, exact: bool = false, seeds_grown: bool = false) -> Plan:
	for d: int in range(1, depth + 1):
		for plan: Plan in plans(d, seeds_grown):
			if plan.path.size() == d and _passes(plan.color) and plan.built <= level and (not exact or plan.built == level):
				return plan
	return null


## 지금 판에서 가장 빨리 매치할 수 있는 배운 모양의 색 (HTML planColor). 없으면 무작위.
func plan_color() -> int:
	for d: int in range(1, 8):
		for plan: Plan in plans(d):
			if plan.path.size() == d and plan.built <= level:
				return plan.color
	return pick.rnd(color_count)


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
	# 조합마다 따로 찾지 않고 한 번의 탐색으로 모든 조합의 가장 짧은 길을 구한다 (결과는 조합마다 best(8, true, true)와 같다).
	var per_combo: Array[Plan] = _best_per_seed_combo(seeds, combos, 8)
	for m: int in combos:
		var colors: PackedInt32Array = _combo_colors(m, seeds.size())
		if seeds.size() >= 4 and colors.count(colors[0]) == colors.size():  # 제자리 왕복 매치는 빼고
			continue
		var plan: Plan = per_combo[m]
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


## 조합 번호 m의 씨앗 색 (첫 씨앗이 가장 낮은 자리).
func _combo_colors(m: int, k: int) -> PackedInt32Array:
	var colors: PackedInt32Array = PackedInt32Array()
	var x: int = m
	for _i: int in k:
		colors.append(x % color_count)
		x /= color_count
	return colors


## 씨앗 색 조합마다 best(depth, exact = true, seeds_grown = true)의 결과 (조합 번호 순, 없으면 null).
## 테스트 비교용 느린 방법: 조합마다 판을 칠해 따로 찾는다.
func best_per_seed_combo_reference(seeds: Array[Vector2i], depth: int) -> Array[Plan]:
	var combos: int = int(pow(color_count, seeds.size()))
	var old: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in seeds:
		old.append(board.get_color(pos))
	var out: Array[Plan] = []
	for m: int in combos:
		var colors: PackedInt32Array = _combo_colors(m, seeds.size())
		for i: int in seeds.size():
			board.get_cell(seeds[i]).color = colors[i]
		out.append(best(depth, true, true))
	for i: int in seeds.size():
		board.get_cell(seeds[i]).color = old[i]
	return out


## best_per_seed_combo_reference와 같은 결과를 탐색 한 번으로 (씨앗 색을 정하지 않은 채 조합 묶음(비트 마스크)으로 들고 다닌다).
func best_per_seed_combo(seeds: Array[Vector2i], depth: int) -> Array[Plan]:
	return _best_per_seed_combo(seeds, int(pow(color_count, seeds.size())), depth)


func _best_per_seed_combo(seeds: Array[Vector2i], combos: int, depth: int) -> Array[Plan]:
	plans(0, true)  # 칸 번호 배열(_cells · _colors · _moved_at)과 이웃 표만 채운다 (깊이 0 = 탐색 없음)
	var n: int = board.size
	_cells.clear()
	for pos: Vector2i in board.all_positions():
		_cells.append(board.get_cell(pos))
	_var_at.resize(_count)
	_var_at.fill(-1)
	for i: int in seeds.size():
		_var_at[seeds[i].y * n + seeds[i].x] = i
		_colors[seeds[i].y * n + seeds[i].x] = -1  # 색은 조합이 정한다 (블럭으로 친다)
	_words = (combos + 63) / 64
	_eq.resize(seeds.size() * color_count * _words)
	_eq.fill(0)
	for m: int in combos:
		var colors: PackedInt32Array = _combo_colors(m, seeds.size())
		for i: int in seeds.size():
			var at: int = (i * color_count + colors[i]) * _words + m / 64
			_eq[at] = _eq[at] | (1 << (m % 64))
	_combo_best = []
	_combo_best.resize(combos)
	var alive: PackedInt64Array = PackedInt64Array()
	alive.resize(_words)
	for m: int in combos:
		alive[m / 64] = alive[m / 64] | (1 << (m % 64))
	_ks.clear()
	_search_combos(board.player_pos.y * n + board.player_pos.x, depth, -1, alive)
	var out: Array[Plan] = []
	out.assign(_combo_best)
	_combo_best = []
	_cells.fill(null)
	return out


## _search와 같은 순서의 탐색. alive = 이 길에서 아직 매치하지 않은 조합들 (매치한 조합은 그 길에서 멈춘다).
func _search_combos(at: int, depth: int, last: int, alive: PackedInt64Array) -> void:
	if depth <= 0:
		return
	var count: int = _count
	for k: int in 4:
		if last >= 0 and (k ^ 1) == last:
			continue
		var to: int = _step[k * count + at]
		if to < 0:
			continue
		var moving: BoardCell = _cells[to]
		var moving_color: int = _colors[to]
		var moving_var: int = _var_at[to]
		var moving_count: int = _moved_at[to] + 1
		_cells[at] = moving
		_colors[at] = moving_color
		_var_at[at] = moving_var
		_moved_at[at] = moving_count
		_cells[to] = null
		_colors[to] = -1
		_var_at[to] = -1
		_moved_at[to] = 0
		_ks.append(k)
		var rest: PackedInt64Array = _record_combos(to, at, alive)
		if not _is_empty(rest):
			_search_combos(to, depth - 1, k, rest)
		_ks.remove_at(_ks.size() - 1)
		_cells[to] = moving
		_colors[to] = moving_color
		_var_at[to] = moving_var
		_moved_at[to] = moving_count - 1
		_cells[at] = null
		_colors[at] = -1
		_var_at[at] = -1
		_moved_at[at] = 0


## 칸 center에 섰을 때 매치하는 조합에 길을 남기고, 매치하지 않은 조합(alive 중)을 돌려준다.
func _record_combos(center: int, pushed: int, alive: PackedInt64Array) -> PackedInt64Array:
	var fixed: int = -1
	var vars: PackedInt32Array = PackedInt32Array()
	for k: int in 4:
		var p: int = _step[k * _count + center]
		if p < 0:
			return alive
		var v: int = _var_at[p]
		if v >= 0:
			vars.append(v)
			continue
		var c: int = _colors[p]
		if c < 0 or (fixed >= 0 and c != fixed):
			return alive
		fixed = c
	var rest: PackedInt64Array = alive.duplicate()
	var plan: Plan = null
	for c: int in color_count:
		if fixed >= 0 and c != fixed:
			continue
		var hit: PackedInt64Array = alive.duplicate()
		for v: int in vars:
			for w: int in _words:
				hit[w] = hit[w] & _eq[(v * color_count + c) * _words + w]
		if _is_empty(hit):
			continue
		for w: int in _words:
			rest[w] = rest[w] & ~hit[w]
		if plan == null:
			plan = _make_plan(center, pushed)
		if not _passes(c) or plan.built != level:  # best(exact): 배운 단계와 같은 모양만, 색 조건
			continue
		var colored: Plan = _with_color(plan, c)
		for w: int in _words:
			var bits: int = hit[w]
			while bits != 0:
				var low: int = bits & -bits
				var m: int = w * 64 + _bit_index(low)
				var held: Plan = _combo_best[m]
				if held == null or colored.path.size() < held.path.size():
					_combo_best[m] = colored
				bits &= bits - 1
	return rest


func _make_plan(center: int, pushed: int) -> Plan:
	var plan: Plan = Plan.new()
	for k: int in _ks:
		plan.path.append(TutorialStartBoard.DIRS[k])
	plan.center = Vector2i(center % _steps_size, center / _steps_size)
	for k: int in 4:
		var p: int = _step[k * _count + center]
		plan.cells.append(_cells[p])
		if _moved_at[p] - (1 if p == pushed else 0) > 0:
			plan.built += 1
	return plan


static func _with_color(plan: Plan, color: int) -> Plan:
	if plan.color == color:
		return plan
	if plan.color == Board.NO_COLOR:
		plan.color = color
		return plan
	var copy: Plan = Plan.new()
	copy.path = plan.path
	copy.cells = plan.cells
	copy.center = plan.center
	copy.built = plan.built
	copy.color = color
	return copy


static func _is_empty(mask: PackedInt64Array) -> bool:
	for word: int in mask:
		if word != 0:
			return false
	return true


static func _bit_index(single_bit: int) -> int:
	var i: int = 0
	var b: int = single_bit
	while b != 1 and b != 0:
		b = b >> 1 if b > 0 else (b >> 1) & 0x7FFFFFFFFFFFFFFF
		i += 1
	return i


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


## 판 크기 n의 이웃 칸 표 (_step[k * n² + 칸] = DIRS[k] 쪽 칸 번호, 판 밖이면 -1). 같은 크기면 다시 만들지 않는다.
func _ensure_steps(n: int) -> void:
	if _steps_size == n:
		return
	_steps_size = n
	_count = n * n
	_step.resize(4 * _count)
	for k: int in 4:
		var dir: Vector2i = TutorialStartBoard.DIRS[k]
		for y: int in n:
			for x: int in n:
				var to: Vector2i = Vector2i(x, y) + dir
				_step[k * _count + y * n + x] = to.y * n + to.x if to.x >= 0 and to.y >= 0 and to.x < n and to.y < n else -1


## 깊이 우선 탐색 (HTML tutPlans와 같은 순서: 방향 DIRS 순, 바로 되돌아가는 수 없음, 매치하면 그 길에서 멈춤, 노드 NODE_CAP까지).
## 판은 칸 번호 배열로 (_cells · _colors · 칸에 있는 블럭이 옮겨진 횟수 _moved_at) — 매치 뒤마다 여러 번 돌아서
## 사전·Vector2i 계산·함수 호출을 피한다 (튜토리얼 판 고치기 때 화면이 끊기던 원인).
func _search(at: int, depth: int, last: int) -> void:
	if depth <= 0 or _nodes > NODE_CAP:
		return
	var count: int = _count
	for k: int in 4:
		if last >= 0 and (k ^ 1) == last:
			continue
		var to: int = _step[k * count + at]
		if to < 0:
			continue
		_nodes += 1
		var moving_color: int = _colors[to]
		var moving_count: int = _moved_at[to] + 1
		_colors[at] = moving_color
		_moved_at[at] = moving_count
		_colors[to] = -1
		_moved_at[to] = 0
		_ks.append(k)
		# 매치 판정: to의 4이웃이 모두 같은 색 블럭
		var c0: int = -1
		var n0: int = _step[to]
		if n0 >= 0:
			c0 = _colors[n0]
			if c0 >= 0:
				var n1: int = _step[count + to]
				var n2: int = _step[2 * count + to]
				var n3: int = _step[3 * count + to]
				if n1 < 0 or n2 < 0 or n3 < 0 or _colors[n1] != c0 or _colors[n2] != c0 or _colors[n3] != c0:
					c0 = -1
		if c0 >= 0:
			_cells[at] = _cells[to]
			_record(to, c0, at)
			_cells[at] = null
		else:
			var moving: BoardCell = _cells[to]
			_cells[at] = moving
			_cells[to] = null
			_search(to, depth - 1, k)
			_cells[to] = moving
			_cells[at] = null
		_ks.remove_at(_ks.size() - 1)
		_colors[to] = moving_color
		_moved_at[to] = moving_count - 1
		_colors[at] = -1
		_moved_at[at] = 0


## 찾은 길 하나를 남긴다. built = 4블럭 중 옮긴 적이 있는 블럭 수 (마지막 수에 가운데로 밀린 블럭 = pushed는 이번 한 번을 뺀다).
func _record(center: int, color: int, pushed: int) -> void:
	var plan: Plan = Plan.new()
	for k: int in _ks:
		plan.path.append(TutorialStartBoard.DIRS[k])
	plan.color = color
	plan.center = Vector2i(center % _steps_size, center / _steps_size)
	for k: int in 4:
		var p: int = _step[k * _count + center]
		plan.cells.append(_cells[p])
		if _moved_at[p] - (1 if p == pushed else 0) > 0:
			plan.built += 1
	_out.append(plan)
