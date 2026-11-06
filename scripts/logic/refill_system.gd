class_name RefillSystem
extends TimedSystem
## 씨앗과 리필 (기획서 4.3장, E6). 리필 시계를 따른다.
## - plant: 깨진 칸에 씨앗을 심는다. 색은 분산 규칙(RefillColorPicker), 시간은 판 경과 시간에 따른 리필 총시간을
##   대기 : 자람으로 나눈 값 (심을 때 한 번 계산).
## - 씨앗은 대기 → 자람 → 다 자란 블록. 다 자라도 매치 판정은 하지 않는다 (C3).

## 대기가 끝나 자라기 시작한 칸.
signal seeds_growing(cells: Array[Vector2i])
## 다 자라 색 블록이 된 칸.
signal cells_matured(cells: Array[Vector2i])

## 심을 색을 능력이 바꾸는 함수 (colors: Array[int], cleared: int, rng) -> Array[int]. 비어 있으면 그대로 (방화광 불).
var color_filter: Callable = Callable()

var _board: Board
var _config: GameConfig
var _rng: RandomNumberGenerator


func _init(board: Board, config: GameConfig, rng: RandomNumberGenerator) -> void:
	_board = board
	_config = config
	_rng = rng


func clock() -> TimedSystem.Clock:
	return TimedSystem.Clock.REFILL


## cleared_color 매치로 깨진 cells에 씨앗을 심는다. elapsed는 판 경과 시간(리필 총시간 계산용).
func plant(cells: Array[Vector2i], cleared_color: int, elapsed: float) -> void:
	var counts: PackedInt32Array = _board.color_counts(_config.color_count)
	var target: float = float(_board.size * _board.size - 1) / _config.color_count
	var colors: Array[int] = RefillColorPicker.pick(cleared_color, cells.size(), _config.color_count, counts, target, _rng)
	if color_filter.is_valid():
		colors = color_filter.call(colors, cleared_color, _rng)
	var targets: Array[Vector2i] = cells.duplicate()
	GameRng.shuffle(targets, _rng)
	var total: float = _config.refill_total_at(elapsed)
	var wait: float = total * _config.refill_wait_share()
	for i: int in targets.size():
		_board.set_seed(targets[i], colors[i], wait, total - wait)


## 판 위 모든 씨앗을 즉시 다 자라게 한다 (정원사 "촉진" 등). 다 자란 칸 목록.
func mature_all() -> Array[Vector2i]:
	return mature_cells(_board.positions_of_type(Board.CellType.SEED))


## cells 중 씨앗인 칸을 즉시 다 자라게 한다 (묘수꾼: 방금 깨진 자리). 다 자란 칸 목록.
func mature_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var matured: Array[Vector2i] = []
	for pos: Vector2i in cells:
		if _board.get_cell_type(pos) == Board.CellType.SEED:
			_board.get_cell(pos).mature()
			matured.append(pos)
	if not matured.is_empty():
		cells_matured.emit(matured)
	return matured


func time_to_next_event() -> float:
	var soonest: float = INF
	for pos: Vector2i in _board.positions_of_type(Board.CellType.SEED):
		soonest = minf(soonest, maxf(_board.get_cell(pos).seed_remaining, 0.0))
	return soonest


func advance(dt: float) -> void:
	var growing: Array[Vector2i] = []
	var matured: Array[Vector2i] = []
	for pos: Vector2i in _board.positions_of_type(Board.CellType.SEED):
		var cell: BoardCell = _board.get_cell(pos)
		cell.seed_remaining -= dt
		if cell.seed_remaining > TimedSystem.EPSILON:
			continue
		if cell.seed_stage == BoardCell.SeedStage.WAITING:
			cell.start_growing(-cell.seed_remaining)
			growing.append(pos)
			if cell.seed_remaining > TimedSystem.EPSILON:
				continue
		cell.mature()
		matured.append(pos)
	if not growing.is_empty():
		seeds_growing.emit(growing)
	if not matured.is_empty():
		cells_matured.emit(matured)
