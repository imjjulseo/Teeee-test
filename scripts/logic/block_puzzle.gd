class_name BlockPuzzle
extends RefCounted
## 블록 모으기 퍼즐 한 판 (기획서 8.8장, HTML 블록 모으기 엔진). 판(Board) 위의 퍼즐 창(window)에 모양을 깔고,
## 모을 색 블록 4개(칸 객체로 따라간다)를 내 주변 4칸으로 모으면 풀린다. 순수 로직 — 화면은 결과만 그린다.
## - 수마다 판정: 남은 최소 수가 1 줄면 좋은 수, break_jump 이상 늘면 모양 깨짐, 그 밖은 헛수.
##   (한 수는 반대 수로 되돌릴 수 있어 보통 많아야 1 는다 — 깨짐은 풀이기 한도 안에서 못 풀 때·우연한 매치로 색이 바뀔 때.)
## - 힌트 3단계: 0 목표 모양(점선, hide_goal이면 숨김) → 1 당길 블록과 그 전에 설 칸 + 안내 강조 → 2 첫 수 화살표.
##   가만히 idle_hint초 또는 헛수 waste_hint번이면 한 단계 오른다 (quick이면 힌트 없음).
## - 별점 (HTML 11/04): 최소 수면 힌트·되돌리기와 상관없이 ★★★, 최소 + star_extra수 이내 ★★, 그 밖 ★.
## - 다른 색이 우연히 매치되면 모을 블록이 아닌 칸의 색만 바꾸고 이어 간다.
## - 규칙 튜토리얼(HTML pzStamp)은 stamp()로 판은 그대로 두고 내 주변 5×5에만 모양을 깐다 (회전·뒤집기로 P가 지금 칸에 오게).
## - 정답 다시 보기: 처음 판에서 내 좋은 수를 따라가다 처음 벗어난 곳부터 최소 수 길.

enum Judgment { GOOD, WASTE, BREAK }
enum Hint { GOAL, PULL, ARROW }

## 한 수의 결과.
class StepResult:
	var accepted: bool = false
	var move: Board.MoveResult
	var judgment: Judgment = Judgment.GOOD
	var solved: bool = false
	## 다른 색이 우연히 매치돼 색을 바꾼 칸들.
	var recolored: Array[Vector2i] = []


## 판 상태 저장 (되돌리기·처음부터): 칸마다 종류·색·금화, 내 위치, 모을 블록 위치.
class Snapshot:
	var types: Array[int] = []
	var colors: PackedInt32Array = PackedInt32Array()
	var coins: PackedFloat32Array = PackedFloat32Array()
	var player: Vector2i
	var targets: Array[Vector2i] = []


var def: PuzzleDef
var book: PuzzleBook
var board: Board
var target_color: int = 0
## 퍼즐 창 (판 좌표).
var window: Rect2i
## 풀이기 탐색 범위 (창 둘레 한 칸, 판 안).
var region: Rect2i
var hide_goal: bool = false
## 목표 모양(가운데·점선 자리)을 그린다 (규칙 튜토리얼은 그리지 않는다 — HTML pzDraw).
var show_goal: bool = true
## 힌트·결과 없이 (튜토리얼 빠른 퍼즐).
var quick: bool = false
var targets: Array[BoardCell] = []
var min_moves: int = 0
## 지금 남은 최소 수 (풀 수 없으면 99).
var distance: int = 0
var solution: PuzzleSolver.Solution
var moves: Array[Vector2i] = []
var judgments: Array[Judgment] = []
var undos: int = 0
var hint: int = Hint.GOAL
var max_hint: int = Hint.GOAL
var finished: bool = false
var replayed: bool = false

const UNSOLVABLE: int = 99

var _rng: RandomNumberGenerator
var _color_count: int = 4
var _start: Snapshot
var _undo: Array[Snapshot] = []
var _waste: int = 0
var _idle: float = 0.0


## board 위 window_origin에 def를 깔고 시작한다. fill_real이면 창 둘레 밖은 실제 판처럼 아무 색.
## keep_board면 판을 칠하지 않는다 (stamp()로 이미 깔았다).
func _init(p_board: Board, p_def: PuzzleDef, p_target: int, window_origin: Vector2i, p_book: PuzzleBook,
		color_count: int, rng: RandomNumberGenerator, fill_real: bool = false, keep_board: bool = false) -> void:
	board = p_board
	def = p_def
	book = p_book
	target_color = p_target
	_color_count = color_count
	_rng = rng
	window = Rect2i(window_origin, Vector2i.ONE * def.size())
	region = window.grow(1).intersection(Rect2i(Vector2i.ZERO, Vector2i.ONE * board.size))
	if keep_board:
		_take_targets()
	else:
		_build(fill_real)
	_start = snapshot()
	_resolve()
	min_moves = distance


# --- 조작 ------------------------------------------------------------------------

func step(dir: Vector2i) -> StepResult:
	var result: StepResult = StepResult.new()
	if finished:
		return result
	var before: Snapshot = snapshot()
	result.move = board.try_move(dir)
	if not result.move.is_accepted():
		return result
	result.accepted = true
	_undo.append(before)
	moves.append(dir)
	_idle = 0.0
	var color: int = board.find_match(board.player_pos)
	if color == target_color:
		judgments.append(Judgment.GOOD)
		distance = 0
		finished = true
		result.solved = true
		return result
	if color != Board.NO_COLOR:
		result.recolored = _recolor_accidental(color)
	var before_distance: int = distance
	_resolve()
	result.judgment = _judge(before_distance, distance)
	judgments.append(result.judgment)
	_after_judgment(result.judgment)
	return result


## 판 기준 시간 delta만큼 (가만히 있으면 힌트).
func advance(delta: float) -> void:
	if finished or quick or hint >= Hint.ARROW:
		return
	_idle += delta
	if _idle >= book.idle_hint:
		raise_hint()


func raise_hint() -> void:
	if finished or hint >= Hint.ARROW:
		return
	hint += 1
	max_hint = maxi(max_hint, hint)
	_idle = 0.0


func can_undo() -> bool:
	return not finished and not _undo.is_empty()


func undo() -> void:
	if not can_undo():
		return
	restore(_undo.pop_back())
	moves.pop_back()
	judgments.pop_back()
	undos += 1
	_waste = 0
	_resolve()


## 처음 판으로 (기록은 남기고 수만 처음부터).
func reset() -> void:
	if finished:
		return
	restore(_start)
	moves.clear()
	judgments.clear()
	_undo.clear()
	undos = 0
	_waste = 0
	_resolve()


## 결과 뒤 "다시 해 보기": 힌트·별점까지 처음부터.
func restart() -> void:
	finished = false
	replayed = false
	hint = Hint.GOAL
	max_hint = Hint.GOAL
	_idle = 0.0
	reset()


# --- 결과 ------------------------------------------------------------------------

func stars() -> int:
	if moves.size() <= min_moves:
		return 3
	if moves.size() <= min_moves + book.star_extra:
		return 2
	return 1


## 정답 다시 보기 길.
class Replay:
	## 처음 판부터 둘 수들 (내 좋은 수 + 그 뒤 최소 수 길).
	var path: Array[Vector2i] = []
	## 내가 처음 벗어난 수 번호 (path에서 이 수부터가 더 나은 길). 벗어난 적이 없으면 -1.
	var diverge: int = -1
	## diverge 자리에서 내가 실제로 둔 수.
	var my_move: Vector2i = Vector2i.ZERO


## 처음 판에서 내 좋은 수(처음 벗어나기 전까지)를 따라간 뒤 최소 수 길. 판은 처음 상태로 되돌려 둔다 —
## 화면은 replay_move로 한 수씩 따라 움직인다.
func replay_plan() -> Replay:
	var plan: Replay = Replay.new()
	var diverge: int = _first_not_good()
	var prefix: Array[Vector2i] = moves.slice(0, diverge) if diverge >= 0 else ([] as Array[Vector2i])
	restore(_start)
	for dir: Vector2i in prefix:
		board.try_move(dir)
	var rest: PuzzleSolver.Solution = _solve()
	if rest == null:  # 따라간 자리에서 못 풀면 처음부터 최소 수
		restore(_start)
		prefix = []
		diverge = -1
		rest = _solve()
	restore(_start)
	plan.path = prefix.duplicate()
	if rest != null:
		plan.path.append_array(rest.path)
	if diverge >= 0:
		plan.diverge = diverge
		plan.my_move = moves[diverge]
	replayed = true
	return plan


func _first_not_good() -> int:
	for i: int in judgments.size():
		if judgments[i] != Judgment.GOOD:
			return i
	return -1


## 정답 다시 보기용 이동 (판정·기록 없음).
func replay_move(dir: Vector2i) -> Board.MoveResult:
	return board.try_move(dir)


# --- 힌트 표시 데이터 --------------------------------------------------------------

func goal_visible() -> bool:
	return show_goal and not finished and solution != null and (not hide_goal or hint >= Hint.PULL)


## 목표 모양: 가운데 칸 + 상·하·좌·우 4칸.
func goal_center() -> Vector2i:
	return solution.center if solution != null else board.player_pos


## 힌트 1: 다음에 당길 블록 칸과 그 전에 설 칸 [설 칸, 당길 칸]. 없으면 빈 배열.
func pull_hint() -> Array[Vector2i]:
	if finished or solution == null or hint < Hint.PULL:
		return []
	var at: Vector2i = board.player_pos
	var target_cells: Array[Vector2i] = target_positions()
	for dir: Vector2i in solution.path:
		var next: Vector2i = at + dir
		if target_cells.has(next):
			return [at, next]
		at = next
	return []


## 힌트 2: 첫 수 방향 (없으면 ZERO).
func arrow_hint() -> Vector2i:
	if finished or solution == null or hint < Hint.ARROW or solution.path.is_empty():
		return Vector2i.ZERO
	return solution.path[0]


## 모을 블록 4개의 지금 위치.
func target_positions() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for pos: Vector2i in board.all_positions():
		if targets.has(board.get_cell(pos)):
			cells.append(pos)
	return cells


## 안내 문구를 강조할 때 (힌트를 하나 이상 봤다).
func tip_emphasized() -> bool:
	return hint >= Hint.PULL


# --- 판 상태 --------------------------------------------------------------------

func snapshot() -> Snapshot:
	var shot: Snapshot = Snapshot.new()
	for pos: Vector2i in board.all_positions():
		var cell: BoardCell = board.get_cell(pos)
		shot.types.append(cell.type)
		shot.colors.append(cell.color)
		shot.coins.append(cell.coin_remaining)
	shot.player = board.player_pos
	shot.targets = target_positions()
	return shot


## 저장한 상태로 판을 되돌린다 (씨앗은 자랄 색의 블록으로). 모을 블록은 그 자리의 칸 객체로 다시 잡는다.
func restore(shot: Snapshot) -> void:
	var positions: Array[Vector2i] = board.all_positions()
	for i: int in positions.size():
		var pos: Vector2i = positions[i]
		if pos == shot.player:
			continue
		board.set_color_block(pos, shot.colors[i])
		if shot.coins[i] != BoardCell.NO_COIN:
			board.get_cell(pos).attach_coin(shot.coins[i])
	board.set_player(shot.player)
	targets.clear()
	for pos: Vector2i in shot.targets:
		targets.append(board.get_cell(pos))


func _build(fill_real: bool) -> void:
	var others: Array[int] = []
	for color: int in _color_count:
		if color != target_color:
			others.append(color)
	var even: Array[int] = others.slice(0, 2) if others.size() >= 3 else others.slice(0, 1)
	var odd: int = others[others.size() - 1]
	var near: Rect2i = window.grow(1)
	for pos: Vector2i in board.all_positions():
		var color: int = odd
		if fill_real:
			color = others[_rng.randi_range(0, others.size() - 1)] if near.has_point(pos) else _rng.randi_range(0, _color_count - 1)
		elif (pos.x + pos.y) % 2 == 0:
			color = even[_rng.randi_range(0, even.size() - 1)]
		board.set_color_block(pos, color)
	for cell: Vector2i in def.target_cells():
		board.set_color_block(window.position + cell, target_color)
	board.set_player(window.position + def.player_cell())
	_take_targets()


func _take_targets() -> void:
	targets.clear()
	for cell: Vector2i in def.target_cells():
		targets.append(board.get_cell(window.position + cell))


func _solve() -> PuzzleSolver.Solution:
	var depth: int = mini(book.solve_depth_cap, maxi(book.solve_depth, distance + book.solve_slack))
	var prefer: Vector2i = solution.center if solution != null else Vector2i(-1, -1)
	return PuzzleSolver.solve(region, board.size, board.player_pos, target_positions(), depth, book.solve_nodes, prefer)


func _resolve() -> void:
	solution = _solve()
	distance = solution.depth if solution != null else UNSOLVABLE


func _judge(before: int, after: int) -> Judgment:
	if after == before - 1:
		return Judgment.GOOD
	if after >= before + book.break_jump:
		return Judgment.BREAK
	return Judgment.WASTE


func _after_judgment(judgment: Judgment) -> void:
	if judgment == Judgment.GOOD:
		_waste = 0
	elif judgment == Judgment.WASTE:
		_waste += 1
		if _waste >= book.waste_hint:
			_waste = 0
			raise_hint()


## 다른 색이 우연히 매치됐다: 그 칸들을 모을 색·그 색이 아닌 색으로 바꾼다.
func _recolor_accidental(color: int) -> Array[Vector2i]:
	var choices: Array[int] = []
	for c: int in _color_count:
		if c != target_color and c != color:
			choices.append(c)
	var cells: Array[Vector2i] = []
	for pos: Vector2i in board.neighbors(board.player_pos):
		if board.is_inside(pos) and not choices.is_empty() and not targets.has(board.get_cell(pos)):
			board.recolor_block(pos, choices[_rng.randi_range(0, choices.size() - 1)])
			cells.append(pos)
	return cells


# --- 규칙 튜토리얼: 내 주변 5×5에만 깔기 (HTML pzStamp) -----------------------------------

## 깐 결과: 회전·뒤집기한 모양(id·tip은 원래 판 것)과 창 위치.
class Stamp:
	var def: PuzzleDef
	var origin: Vector2i


## 판은 그대로 두고, 지금 플레이어 자리에 P가 오도록 회전·뒤집기(8가지 중 플레이어를 가장 덜 옮기는 것)한 모양을
## 그 주변 창에 깐다: T = target, 나머지는 체크무늬 다른 색. 창 둘레 한 칸의 target 색 블록·씨앗은 다른 색으로 바꾼다.
## 난수는 HTML과 같은 순서로 pick에서 꺼낸다. 깐 뒤 BlockPuzzle.new(..., keep_board = true)로 시작한다.
static func stamp(board: Board, source: PuzzleDef, target: int, color_count: int, pick: HtmlRng) -> Stamp:
	var n: int = board.size
	var span: int = source.size()
	var player: Vector2i = board.player_pos
	var best_rows: PackedStringArray
	var best_origin: Vector2i
	var best_p: Vector2i
	var best_cost: int = -1
	for f: int in 8:
		var rows: PackedStringArray = BlockPuzzle.sym_rows(source.rows, f)
		var p: Vector2i = Vector2i(span / 2, span / 2)
		for y: int in span:
			var x: int = rows[y].find(PuzzleDef.PLAYER)
			if x >= 0:
				p = Vector2i(x, y)
		var origin: Vector2i = Vector2i(clampi(player.x - p.x, 0, n - span), clampi(player.y - p.y, 0, n - span))
		var cost: int = Board.distance(origin + p, player)
		if best_cost < 0 or cost < best_cost:
			best_rows = rows
			best_origin = origin
			best_p = p
			best_cost = cost
		if cost == 0:
			break
	var to: Vector2i = best_origin + best_p
	if to != player:
		board.set_player(to)
		board.set_color_block(player, pick.rnd(color_count))
	var others: Array[int] = []
	for color: int in color_count:
		if color != target:
			others.append(color)
	var even: Array[int] = others.slice(0, 2) if others.size() >= 3 else others.slice(0, 1)
	var odd: int = others[others.size() - 1]
	for y: int in span:
		for x: int in span:
			var pos: Vector2i = best_origin + Vector2i(x, y)
			if pos == board.player_pos:
				continue
			var ch: String = best_rows[y][x]
			var color: int = target
			if ch != PuzzleDef.TARGET and ch != "A":
				color = even[pick.rnd(even.size())] if (pos.x + pos.y) % 2 == 0 else odd
			board.set_color_block(pos, color)
	var window: Rect2i = Rect2i(best_origin, Vector2i.ONE * span)
	for y: int in range(best_origin.y - 1, best_origin.y + span + 1):
		for x: int in range(best_origin.x - 1, best_origin.x + span + 1):
			var pos: Vector2i = Vector2i(x, y)
			if not board.is_inside(pos) or window.has_point(pos):
				continue
			var cell: BoardCell = board.get_cell(pos)
			if (cell.is_block() or cell.type == Board.CellType.SEED) and cell.color == target:
				cell.color = others[pick.rnd(others.size())]
	var stamp_result: Stamp = Stamp.new()
	stamp_result.def = source.duplicate() as PuzzleDef
	stamp_result.def.rows = best_rows
	stamp_result.origin = best_origin
	return stamp_result


## 모양을 f번째 대칭으로 (HTML symRows: f % 4번 시계 방향으로 돌린 뒤 f >= 4면 좌우 뒤집기).
static func sym_rows(rows: PackedStringArray, f: int) -> PackedStringArray:
	var span: int = rows.size()
	var out: Array[PackedStringArray] = []
	for y: int in span:
		var line: PackedStringArray = PackedStringArray()
		line.resize(span)
		line.fill(".")
		out.append(line)
	for r: int in span:
		for c: int in span:
			var a: int = r
			var b: int = c
			for _i: int in f % 4:
				var t: int = a
				a = b
				b = span - 1 - t
			if f >= 4:
				b = span - 1 - b
			out[a][b] = rows[r][c]
	var result: PackedStringArray = PackedStringArray()
	for line: PackedStringArray in out:
		result.append("".join(line))
	return result
