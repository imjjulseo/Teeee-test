class_name PuzzleGenerator
extends RefCounted
## 블록 모으기 연습 문제 만들기 (HTML pzGen): 5×5 창에 모을 블록 4개와 나를 무작위로 놓고, 최소 수가 난이도 구간에
## 들어오면 그 문제를 쓴다. 한 번에 한 번만 시도한다(try_once) — 화면이 프레임마다 몇 번씩 불러 멈추지 않게.
## 속 빈 모양: 바탕 모양(4×4, 가운데 (1,1)이 다른 색)을 돌리고 뒤집어 창 안에 놓는다 (나는 그 가운데에 서지 않는다).

## 판 크기 = 창 + 둘레 한 칸 (연습 판과 같은 모양으로 푼다).
const MARGIN: int = 1


## 한 번 시도한다. 구간에 맞는 문제면 PuzzleDef, 아니면 null.
static func try_once(difficulty: PuzzleDifficulty, book: PuzzleBook, rng: RandomNumberGenerator) -> PuzzleDef:
	var size: int = book.window_size
	var targets: Array[Vector2i] = []
	var hole: Vector2i = Vector2i(-1, -1)
	if difficulty.hollow and not book.hollow_shapes.is_empty():
		var placed: Dictionary = _place_hollow(book.hollow_shapes[rng.randi_range(0, book.hollow_shapes.size() - 1)], size, rng)
		targets = placed["targets"]
		hole = placed["hole"]
	else:
		targets = _scatter(size, rng)
	var player: Vector2i = Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
	while targets.has(player) or player == hole:
		player = Vector2i(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1))
	var offset: Vector2i = Vector2i.ONE * MARGIN
	var board_targets: Array[Vector2i] = []
	for cell: Vector2i in targets:
		board_targets.append(cell + offset)
	var board_size: int = size + MARGIN * 2
	var solution: PuzzleSolver.Solution = PuzzleSolver.solve(Rect2i(Vector2i.ZERO, Vector2i.ONE * board_size), board_size,
		player + offset, board_targets, difficulty.max_moves, book.solve_nodes)
	if solution == null or solution.depth < difficulty.min_moves:
		return null
	var def: PuzzleDef = PuzzleDef.new()
	def.rows = PuzzleGenerator.rows_for(size, targets, player)
	def.tip = difficulty.tip
	return def


## 한 판의 최소 수 (생성·연습 판과 같은 창 + 둘레 한 칸 판에서). 풀 수 없으면 -1.
static func min_moves_of(def: PuzzleDef, book: PuzzleBook) -> int:
	var offset: Vector2i = Vector2i.ONE * MARGIN
	var targets: Array[Vector2i] = []
	for cell: Vector2i in def.target_cells():
		targets.append(cell + offset)
	var board_size: int = def.size() + MARGIN * 2
	var solution: PuzzleSolver.Solution = PuzzleSolver.solve(Rect2i(Vector2i.ZERO, Vector2i.ONE * board_size), board_size,
		def.player_cell() + offset, targets, book.solve_depth_cap, book.solve_nodes)
	return solution.depth if solution != null else -1


## 문제를 끝내 못 만들었을 때 대신 쓸 튜토리얼 판: 최소 수가 난이도 구간 안인 판, 없으면 구간에 가장 가까운 판.
static func fallback(difficulty: PuzzleDifficulty, book: PuzzleBook) -> PuzzleDef:
	var best: PuzzleDef = null
	var best_gap: int = 1 << 30
	for level: PuzzleLevel in book.levels:
		for def: PuzzleDef in level.boards:
			var moves: int = PuzzleGenerator.min_moves_of(def, book)
			if moves < 0:
				continue
			var gap: int = maxi(difficulty.min_moves - moves, moves - difficulty.max_moves)
			if gap < best_gap:
				best = def
				best_gap = gap
			if gap <= 0:
				return best
	return best


## 창 모양 문자열 (T = 모을 블록, P = 나, . = 다른 색).
static func rows_for(size: int, targets: Array[Vector2i], player: Vector2i) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in size:
		var row: String = ""
		for x: int in size:
			var cell: Vector2i = Vector2i(x, y)
			row += PuzzleDef.TARGET if targets.has(cell) else (PuzzleDef.PLAYER if cell == player else ".")
		rows.append(row)
	return rows


## 4×4 안의 서로 다른 4칸을 창 안 무작위 위치(0~1칸 밀기)에.
static func _scatter(size: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var shift: Vector2i = Vector2i(rng.randi_range(0, size - 4), rng.randi_range(0, size - 4))
	var cells: Array[Vector2i] = []
	while cells.size() < 4:
		var cell: Vector2i = Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3)) + shift
		if not cells.has(cell):
			cells.append(cell)
	return cells


## 속 빈 바탕 모양을 무작위로 돌리고 뒤집어 창 안에 놓는다: {targets, hole}.
static func _place_hollow(shape: PackedVector2Array, size: int, rng: RandomNumberGenerator) -> Dictionary:
	var flip: int = rng.randi_range(0, 7)
	var cells: Array[Vector2i] = []
	for point: Vector2 in shape:
		cells.append(_transform(Vector2i(point), flip))
	var hole: Vector2i = _transform(Vector2i(1, 1), flip)
	var low: Vector2i = cells[0]
	var high: Vector2i = cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var shift: Vector2i = Vector2i(rng.randi_range(0, size - 1 - (high.x - low.x)), rng.randi_range(0, size - 1 - (high.y - low.y))) - low
	var placed: Array[Vector2i] = []
	for cell: Vector2i in cells:
		placed.append(cell + shift)
	return {"targets": placed, "hole": hole + shift}


## 4×4 안에서 flip % 4번 90도 돌리고, flip ≥ 4면 좌우로 뒤집는다.
static func _transform(cell: Vector2i, flip: int) -> Vector2i:
	var out: Vector2i = cell
	for _i: int in flip % 4:
		out = Vector2i(3 - out.y, out.x)
	if flip >= 4:
		out.x = 3 - out.x
	return out
