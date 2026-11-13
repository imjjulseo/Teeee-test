class_name ArsonAbility
extends Ability
## 방화광 (상시): 빨강(fire_color) = 불. 판의 블록 하나에 불씨를 붙이고 시작한다 (플레이어와 거리 min_ignite_distance 이상,
## 탈 수 있는 이웃이 2칸 이상인 블록 중 무작위). 빨강은 리필되지 않는다 — 다른 색을 깨서 심는 씨앗에 빨강이 나오면 다른 색으로,
## 빨강을 깨면 그 자리는 잔불(빨강 씨앗)이 되어 다시 불이 된다.
## spread_interval초마다 불길 가장자리의 탈 수 있는 블록(다 자란, 빨강·파랑이 아닌) spread_count칸이 불이 된다 (warn_time초 전 예고).
## 족보 다음 칸이 빨강일 때 빨강으로 매치하면 그 족보가 2칸 전진. 파랑(water_color) 매치마다 물방울 +1 (최대 water_max).
## 꾹 누르면 물방울 water_cost개로 불 절반을 끈다 (불이 2칸 이상일 때). 불과 잔불이 다 꺼지면 reignite_delay초 뒤 플레이어와
## 가장 먼 블록에 다시 불이 붙는다.

@export var fire_color: int = 1
@export var water_color: int = 2
@export var spread_interval: float = 4.0
@export var spread_count: int = 3
@export var warn_time: float = 1.0
@export var reignite_delay: float = 3.0
@export var water_max: int = 6
@export var water_cost: int = 2
@export var min_ignite_distance: int = 3

## 지표 (캐릭터 튜토리얼 목표): 물방울을 얻은 수, 소화한 수.
const METRIC_WATER: StringName = &"arson_water"
const METRIC_DOUSES: StringName = &"arson_douses"

var water: int = 0
## 다음 번짐까지 남은 시간.
var spread_left: float = 4.0
## 이번 번짐으로 예고된 칸.
var warned: Array[Vector2i] = []
## 다시 불이 붙을 때까지 남은 시간 (불이 남아 있으면 음수).
var reignite_left: float = -1.0
## 소화로 끈 칸 수.
var doused: int = 0

var _warn_done: bool = false
var _color_count: int = 4
## 판 위 불(다 자란 빨강) 수 (카드 표시용, 시간이 흐를 때마다 다시 센다).
var _fire_count: int = 0


func setup(session: GameSession) -> void:
	_color_count = session.get_config().color_count
	spread_left = spread_interval
	_clear_fire_from_board(session)
	_ignite_start(session)


## 판은 빨강 없이 시작한다 (불은 불씨 하나뿐): 빨강 블록을 나머지 색으로 번갈아 바꿔 색 개수를 고르게 하고,
## 플레이어 주변에 생긴 매치 형태를 다시 없앤다.
func _clear_fire_from_board(session: GameSession) -> void:
	var board: Board = session.board
	var others: Array[int] = _non_fire_colors()
	var next: int = 0
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if board.get_color(pos) == fire_color:
			board.recolor_block(pos, others[next % others.size()])
			next += 1
	board.break_match_at(board.player_pos, session.get_rng(), session.get_config().initial_match_fix_attempts)


## 빨강은 리필되지 않는다: 빨강을 깨면 모두 잔불(빨강 씨앗), 그 밖에는 빨강 대신 다른 색.
func refill_colors(colors: Array[int], cleared: int, rng: RandomNumberGenerator) -> Array[int]:
	var result: Array[int] = []
	for color: int in colors:
		if cleared == fire_color:
			result.append(fire_color)
		elif color == fire_color:
			result.append(_non_fire_colors()[rng.randi_range(0, _non_fire_colors().size() - 1)])
		else:
			result.append(color)
	return result


## 다음 칸이 빨강인 족보를 빨강으로 매치하면 한 칸 더.
func override_clear(session: GameSession, color: int) -> RecipeSet.ClearOutcome:
	if color != fire_color:
		return null
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	for slot: int in recipes.slot_count():
		if recipes.recipes[slot].next_color() == fire_color and not recipes.advance_slot(slot, outcome):
			recipes.advance_slot(slot, outcome)
	return outcome


func on_match(session: GameSession, color: int, _cells: Array[Vector2i]) -> void:
	if color == water_color and water < water_max:
		water += 1
		session.metrics.add(METRIC_WATER)


func on_long_press(session: GameSession) -> void:
	if water < water_cost:
		session.announce("물방울 %d/%d" % [water, water_cost])
		return
	var fires: Array[Vector2i] = _fires(session.board)
	if fires.size() <= 1:
		session.announce("불이 1칸뿐")
		return
	water -= water_cost
	var rng: RandomNumberGenerator = session.get_rng()
	GameRng.shuffle(fires, rng)
	var put_out: Array[Vector2i] = fires.slice(0, floori(fires.size() / 2.0))
	for pos: Vector2i in put_out:
		session.board.recolor_block(pos, _non_fire_colors()[rng.randi_range(0, _non_fire_colors().size() - 1)])
	doused += put_out.size()
	session.metrics.add(METRIC_DOUSES)
	session.cells_changed.emit(put_out)
	session.announce("소화 %d칸" % put_out.size())


func advance(session: GameSession, delta: float) -> void:
	var had_reignite: bool = reignite_left >= 0.0
	spread_left -= delta
	if not _warn_done and spread_left <= warn_time + TimedSystem.EPSILON:
		_warn(session)
	if spread_left <= TimedSystem.EPSILON:
		_spread(session)
	_check_reignite(session, delta if had_reignite else 0.0)


func time_to_next_event() -> float:
	var next: float = spread_left if _warn_done else spread_left - warn_time
	if reignite_left >= 0.0:
		next = minf(next, reignite_left)
	return maxf(next, 0.0)


func status_text() -> String:
<<<<<<< HEAD
	return "물 %d/%d / 불 %d" % [water, water_max, _fire_count]
=======
	return "물 %d/%d · 불 %d" % [water, water_max, _fire_count]
>>>>>>> Choi


func board_marks() -> Array[BoardMark]:
	var marks: Array[BoardMark] = []
	for pos: Vector2i in warned:
		marks.append(BoardMark.at_cell(BoardMark.Kind.WARN, pos))
	return marks



func _ignite_start(session: GameSession) -> void:
	var board: Board = session.board
	var candidates: Array[Vector2i] = []
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if Board.distance(pos, board.player_pos) < min_ignite_distance:
			continue
		var burnable_neighbors: int = 0
		for dir: Vector2i in Board.DIRECTIONS:
			if board.is_inside(pos + dir) and _burnable(board, pos + dir):
				burnable_neighbors += 1
		if burnable_neighbors >= 2:
			candidates.append(pos)
	var blocks: Array[Vector2i] = board.positions_of_type(Board.CellType.COLOR_BLOCK)
	if candidates.is_empty() and blocks.is_empty():
		return
	var start: Vector2i = candidates[session.get_rng().randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else blocks[0]
	board.recolor_block(start, fire_color)
	_fire_count = _fires(board).size()


## 예고: 불길 가장자리 중 spread_count칸을 무작위로.
func _warn(session: GameSession) -> void:
	_warn_done = true
	var front: Array[Vector2i] = _fire_front(session.board)
	var rng: RandomNumberGenerator = session.get_rng()
	while warned.size() < spread_count and not front.is_empty():
		warned.append(front.pop_at(rng.randi_range(0, front.size() - 1)))
	session.notify_marks_changed()


func _spread(session: GameSession) -> void:
	var board: Board = session.board
	var lit: Array[Vector2i] = []
	for pos: Vector2i in warned:
		if _burnable(board, pos):
			board.recolor_block(pos, fire_color)
			lit.append(pos)
	warned.clear()
	_warn_done = false
	spread_left += spread_interval
	if not lit.is_empty():
		session.cells_changed.emit(lit)
	session.notify_marks_changed()


## 불과 잔불이 다 꺼졌으면 reignite_delay초 뒤 다시 붙인다. elapsed는 이미 세고 있던 동안 지난 시간.
func _check_reignite(session: GameSession, elapsed: float) -> void:
	var board: Board = session.board
	_fire_count = _fires(board).size()
	var embers: int = 0
	for pos: Vector2i in board.positions_of_type(Board.CellType.SEED):
		if board.get_color(pos) == fire_color:
			embers += 1
	if _fire_count > 0 or embers > 0:
		reignite_left = -1.0
		return
	if reignite_left < 0.0:
		reignite_left = reignite_delay
		return
	reignite_left -= elapsed
	if reignite_left <= TimedSystem.EPSILON:
		reignite_left = -1.0
		_reignite(session)


## 플레이어와 가장 먼 다 자란 블록(파랑 제외)에 불을 붙인다.
func _reignite(session: GameSession) -> void:
	var board: Board = session.board
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if board.get_color(pos) == water_color:
			continue
		var d: int = Board.distance(pos, board.player_pos)
		if d > best_distance:
			best_distance = d
			best = pos
	if best_distance < 0:
		return
	board.recolor_block(best, fire_color)
	_fire_count = 1
	session.cells_changed.emit([best] as Array[Vector2i])
	session.announce("불씨가 다시 붙었어요")


func _fires(board: Board) -> Array[Vector2i]:
	var fires: Array[Vector2i] = []
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if board.get_color(pos) == fire_color:
			fires.append(pos)
	return fires


## 불 옆의 탈 수 있는 칸 (겹치지 않게).
func _fire_front(board: Board) -> Array[Vector2i]:
	var front: Array[Vector2i] = []
	for pos: Vector2i in _fires(board):
		for dir: Vector2i in Board.DIRECTIONS:
			var next: Vector2i = pos + dir
			if board.is_inside(next) and not front.has(next) and _burnable(board, next):
				front.append(next)
	return front


## 다 자란 블록이고 빨강·파랑이 아니다 (플레이어 칸은 블록이 아니라 빠진다).
func _burnable(board: Board, pos: Vector2i) -> bool:
	if board.get_cell_type(pos) != Board.CellType.COLOR_BLOCK:
		return false
	var color: int = board.get_color(pos)
	return color != fire_color and color != water_color


func _non_fire_colors() -> Array[int]:
	var colors: Array[int] = []
	for color: int in _color_count:
		if color != fire_color:
			colors.append(color)
	return colors
