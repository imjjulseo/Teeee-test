class_name Board
extends RefCounted
## 논리 보드. 게임 상태의 Source of Truth. Node/화면 코드에 의존하지 않는다.
## 칸은 BoardCell 객체로 Grid[y][x] 순서의 1차원 배열(index = y * size + x)에 둔다.
## 이동은 칸 객체째로 자리를 바꾸므로 씨앗 진행·금화가 블록과 함께 움직인다.
## 씨앗이 자라는 시간 처리는 RefillSystem, 금화는 CoinSystem이 맡는다 (Board는 상태와 규칙 판정만).

enum CellType {
	PLAYER,
	COLOR_BLOCK,  ## 다 자란 색 블록
	SEED,  ## 깨진 자리에 심어진 씨앗. 다음 색은 숨겨져 있고 매치되지 않는다 (4.3장).
	EMPTY,  ## 상태만 둔다. 일반 판에서는 생기지 않는다 (B3).
}

enum MoveOutcome {
	SWAPPED,  ## COLOR_BLOCK / SEED와 위치 교환
	MOVED,  ## EMPTY로 단순 이동 (이전 칸은 EMPTY)
	BLOCKED_BY_WALL,  ## 목표가 보드 밖. 보드 변화 없음
	BLOCKED_BY_PLAYER,  ## 목표에 다른 플레이어가 있다 (양손잡이). 보드 변화 없음
	INVALID_DIRECTION,  ## 상하좌우 1칸이 아닌 입력. 보드 변화 없음
}

## 색이 없는 칸(PLAYER, EMPTY)의 color 값.
const NO_COLOR: int = -1
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## 색 ID의 이름 (E16). 능력 문구에 쓴다.
const COLOR_NAMES: PackedStringArray = ["노랑", "빨강", "파랑", "초록"]
## 시작 판의 매치 형태를 없앨 때 교환 상대는 플레이어와 이 거리(맨해튼) 이상 떨어진 블록 (E3).
const INITIAL_SWAP_MIN_DISTANCE: int = 2


## try_move의 결과.
class MoveResult:
	extends RefCounted

	var outcome: MoveOutcome
	## 이동 전 플레이어 위치.
	var from: Vector2i
	## 이동 요청 목표 위치 (거절된 경우에도 계산된 값).
	var to: Vector2i
	## 플레이어와 자리를 바꿔 from으로 옮겨간 칸의 타입 (거절 시 의미 없음).
	var displaced_type: CellType = CellType.EMPTY
	## 판 끝을 넘어 반대편으로 나왔다 (wraps_edges, 항해사).
	var wrapped: bool = false
	## 이웃이 아닌 칸으로 순간이동했다 (떠돌이).
	var teleported: bool = false

	## 이웃 칸으로 미끄러지는 이동이 아니다 (View가 애니메이션 없이 바로 옮긴다).
	func is_jump() -> bool:
		return wrapped or teleported

	func _init(p_outcome: MoveOutcome, p_from: Vector2i, p_to: Vector2i) -> void:
		outcome = p_outcome
		from = p_from
		to = p_to

	func is_accepted() -> bool:
		return outcome == MoveOutcome.SWAPPED or outcome == MoveOutcome.MOVED


var size: int
## 지금 움직이는 플레이어의 위치. 플레이어가 둘이면(양손잡이) select_player로 바꾼다.
var player_pos: Vector2i
## 지금 움직이는 플레이어 번호.
var active_player: int = 0

## 플레이어별 위치 (active_player 칸은 player_pos가 최신).
var _players: Array[Vector2i] = []
## 판 끝과 끝이 이어져 있다 (항해사): 판 밖으로 나가는 이동·이웃은 반대편 칸이 된다.
var wraps_edges: bool = false

var _cells: Array[BoardCell] = []


func _init(board_size: int) -> void:
	size = board_size
	for _i: int in board_size * board_size:
		_cells.append(BoardCell.new())
	player_pos = center()


## 시작 판 생성 (기획서 2.3): 중앙에 플레이어, 나머지 칸에 색 목록(i mod 색 수)을 셔플해 채운 뒤
## 플레이어 주변의 매치 형태를 없앤다 (E3).
static func generate(p_config: GameConfig, rng: RandomNumberGenerator) -> Board:
	var config: GameConfig = GameConfig.ensure_valid(p_config)  # 잘못된 설정이면 기본값 (배포 빌드에서도)
	var board: Board = Board.new(config.board_size)
	var start: Vector2i = board.center()
	board.set_player(start)

	var colors: Array[int] = []
	for i: int in board.size * board.size - 1:
		colors.append(i % config.color_count)
	GameRng.shuffle(colors, rng)

	var next: int = 0
	for pos: Vector2i in board.all_positions():
		if pos == start:
			continue
		board.set_color_block(pos, colors[next])
		next += 1
	board.break_match_at(start, rng, config.initial_match_fix_attempts)
	return board


## center에 매치 형태가 있으면, 위쪽 이웃 블록의 색을 멀리 있는(INITIAL_SWAP_MIN_DISTANCE 이상) 다른 색 블록과
## 맞바꾸기를 매치 형태가 없어질 때까지(최대 attempts번) 반복한다. 색 개수는 그대로다.
func break_match_at(center_pos: Vector2i, rng: RandomNumberGenerator, attempts: int) -> void:
	var tries: int = 0
	while find_match(center_pos) != NO_COLOR and tries < attempts:
		tries += 1
		var up: Vector2i = center_pos + Vector2i.UP
		var up_color: int = get_color(up)
		var candidates: Array[Vector2i] = []
		for pos: Vector2i in all_positions():
			var far: bool = absi(pos.x - center_pos.x) + absi(pos.y - center_pos.y) >= INITIAL_SWAP_MIN_DISTANCE
			if far and get_cell_type(pos) == CellType.COLOR_BLOCK and get_color(pos) != up_color:
				candidates.append(pos)
		if candidates.is_empty():
			return
		var other: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		set_color_block(up, get_color(other))
		set_color_block(other, up_color)


## 플레이어를 dir 방향으로 1칸 이동한다. 목표가 COLOR_BLOCK/SEED면 칸째로 교환(씨앗 진행·금화 유지),
## EMPTY면 단순 이동. 보드 밖이거나 잘못된 방향이면 아무것도 바꾸지 않는다. 매치 판정은 하지 않는다.
func try_move(dir: Vector2i) -> MoveResult:
	var from: Vector2i = player_pos
	if not DIRECTIONS.has(dir):
		return MoveResult.new(MoveOutcome.INVALID_DIRECTION, from, from + dir)
	var to: Vector2i = step_from(from, dir)
	if not is_inside(to):
		return MoveResult.new(MoveOutcome.BLOCKED_BY_WALL, from, to)
	if get_cell_type(to) == CellType.PLAYER:
		return MoveResult.new(MoveOutcome.BLOCKED_BY_PLAYER, from, to)

	var target_type: CellType = get_cell_type(to)
	var outcome: MoveOutcome = MoveOutcome.MOVED if target_type == CellType.EMPTY else MoveOutcome.SWAPPED
	_swap(from, to)
	player_pos = to

	var result: MoveResult = MoveResult.new(outcome, from, to)
	result.displaced_type = target_type
	result.wrapped = to != from + dir
	return result


## 플레이어를 to 칸과 맞바꾼다 (이웃이 아니어도 됨, 떠돌이 순간이동). to의 칸은 플레이어가 있던 자리로 간다.
## to가 판 밖이거나 플레이어 자리면 아무것도 바꾸지 않고 거절된 결과.
func teleport_player(to: Vector2i) -> MoveResult:
	var from: Vector2i = player_pos
	if not is_inside(to) or to == from:
		return MoveResult.new(MoveOutcome.INVALID_DIRECTION, from, to)
	var target_type: CellType = get_cell_type(to)
	_swap(from, to)
	player_pos = to
	var result: MoveResult = MoveResult.new(MoveOutcome.MOVED if target_type == CellType.EMPTY else MoveOutcome.SWAPPED, from, to)
	result.displaced_type = target_type
	result.teleported = true
	return result


## 판 전체를 뒤집는다 (거울): horizontal이면 좌우(x → size-1-x), 아니면 상하(y → size-1-y). 플레이어도 함께.
func mirror(horizontal: bool) -> void:
	var flipped: Array[BoardCell] = []
	flipped.resize(_cells.size())
	for i: int in _cells.size():
		flipped[_index(_mirrored(_position(i), horizontal))] = _cells[i]
	_cells = flipped
	player_pos = _mirrored(player_pos, horizontal)


func _mirrored(pos: Vector2i, horizontal: bool) -> Vector2i:
	return Vector2i(size - 1 - pos.x, pos.y) if horizontal else Vector2i(pos.x, size - 1 - pos.y)


## 기획서 4.1 기본 규칙(MatchRule): center의 상·하·좌·우 4칸이 모두 보드 안의 다 자란 블록이고 같은 색이면 그 색,
## 아니면 NO_COLOR. 씨앗·플레이어·EMPTY가 끼면 실패. 대각선은 보지 않는다.
func find_match(center_pos: Vector2i) -> int:
	var found: MatchRule.Found = MatchRule.new().find(self, center_pos)
	return found.color if found != null else NO_COLOR


## pos에서 dir로 한 칸 간 좌표. 판 끝이 이어져 있으면 반대편으로 돌아오고, 아니면 판 밖일 수 있다.
func step_from(pos: Vector2i, dir: Vector2i) -> Vector2i:
	var next: Vector2i = pos + dir
	if wraps_edges:
		next = Vector2i(posmod(next.x, size), posmod(next.y, size))
	return next


## center의 상·하·좌·우 좌표 (DIRECTIONS 순서, 판 끝이 이어져 있지 않으면 보드 밖일 수 있음).
func neighbors(center_pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir: Vector2i in DIRECTIONS:
		result.append(step_from(center_pos, dir))
	return result


## 다 자란 블록의 색만 바꾼다 (금화는 그대로). 능력으로 칠할 때 쓴다 (화가).
func recolor_block(pos: Vector2i, color: int) -> void:
	var cell: BoardCell = get_cell(pos)
	if cell.is_block():
		cell.color = color


## 두 칸의 맨해튼 거리.
static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 플레이어 바로 옆(상하좌우) 칸 cell로 가는 방향. 옆 칸이 아니면 Vector2i.ZERO (옆 칸 탭 이동, 3.2장).
func direction_toward(cell: Vector2i) -> Vector2i:
	return direction_from(player_pos, cell)


## from 바로 옆(상하좌우) 칸 cell로 가는 방향. 옆 칸이 아니면 Vector2i.ZERO.
static func direction_from(from: Vector2i, cell: Vector2i) -> Vector2i:
	var dir: Vector2i = cell - from
	return dir if DIRECTIONS.has(dir) else Vector2i.ZERO


## 모든 칸 좌표 (y, x 순서).
func all_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i: int in _cells.size():
		result.append(_position(i))
	return result


## type인 칸 좌표 (y, x 순서).
func positions_of_type(type: CellType) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i: int in _cells.size():
		if _cells[i].type == type:
			result.append(_position(i))
	return result


func center() -> Vector2i:
	var mid: int = (size - 1) / 2
	return Vector2i(mid, mid)


func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < size and pos.y < size


## 칸 객체. 상태를 바꾸는 쪽(RefillSystem, CoinSystem, 능력)만 직접 고친다. View는 읽기만 한다.
func get_cell(pos: Vector2i) -> BoardCell:
	return _cells[_index(pos)]


func get_cell_type(pos: Vector2i) -> CellType:
	return get_cell(pos).type


## 블록 색. 씨앗이면 자랄 색(화면에는 숨김), 색이 없는 칸이면 NO_COLOR.
func get_color(pos: Vector2i) -> int:
	return get_cell(pos).color


## 씨앗의 자람 진행도 0~1 (대기 중이면 0). 씨앗이 아니면 0.
func get_grow_progress(pos: Vector2i) -> float:
	return get_cell(pos).grow_progress()


func has_coin(pos: Vector2i) -> bool:
	return get_cell(pos).has_coin()


## 플레이어 하나를 pos에 둔다 (플레이어는 이것 하나가 된다).
func set_player(pos: Vector2i) -> void:
	get_cell(pos).make_player()
	player_pos = pos
	active_player = 0
	_players = [pos]


## 플레이어를 하나 더 pos에 둔다 (양손잡이). 그 칸의 블록은 없어진다. 새 플레이어 번호.
func add_player(pos: Vector2i) -> int:
	_sync_active()
	get_cell(pos).make_player()
	_players.append(pos)
	return _players.size() - 1


func player_count() -> int:
	return maxi(_players.size(), 1)


## i번 플레이어의 위치.
func player_position(i: int) -> Vector2i:
	_sync_active()
	return _players[i] if i < _players.size() else player_pos


## 움직일 플레이어를 고른다 (없는 번호면 그대로).
func select_player(i: int) -> void:
	if i < 0 or i >= _players.size() or i == active_player:
		return
	_sync_active()
	active_player = i
	player_pos = _players[i]


func _sync_active() -> void:
	if _players.is_empty():
		_players = [player_pos]
	_players[active_player] = player_pos


func set_color_block(pos: Vector2i, color: int) -> void:
	get_cell(pos).make_block(color)


## pos에 씨앗을 심는다: wait초 대기 후 grow초 동안 자라 next_color 블록이 된다 (리필 시계 기준).
func set_seed(pos: Vector2i, next_color: int, wait: float, grow: float) -> void:
	get_cell(pos).make_seed(next_color, wait, grow)


func set_empty(pos: Vector2i) -> void:
	get_cell(pos).make_empty()


## 지정한 색의 다 자란 블록 개수.
func count_color_blocks(color: int) -> int:
	var total: int = 0
	for cell: BoardCell in _cells:
		if cell.is_block() and cell.color == color:
			total += 1
	return total


## 색별 개수 (인덱스 = 색 ID). 씨앗은 자랄 색으로 센다 — 판에 곧 있을 색의 분포 (족보 생성·리필 색 분산용).
func color_counts(color_count: int) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(color_count)
	counts.fill(0)
	for cell: BoardCell in _cells:
		if (cell.is_block() or cell.is_seed()) and cell.color >= 0 and cell.color < color_count:
			counts[cell.color] += 1
	return counts


func count_type(type: CellType) -> int:
	var total: int = 0
	for cell: BoardCell in _cells:
		if cell.type == type:
			total += 1
	return total


## 판 위 금화 수.
func coin_count() -> int:
	var total: int = 0
	for cell: BoardCell in _cells:
		if cell.has_coin():
			total += 1
	return total



func _swap(a: Vector2i, b: Vector2i) -> void:
	var ia: int = _index(a)
	var ib: int = _index(b)
	var cell_a: BoardCell = _cells[ia]
	_cells[ia] = _cells[ib]
	_cells[ib] = cell_a


func _index(pos: Vector2i) -> int:
	assert(is_inside(pos), "Board: position out of bounds %s" % pos)
	return pos.y * size + pos.x


func _position(index: int) -> Vector2i:
	return Vector2i(index % size, index / size)
