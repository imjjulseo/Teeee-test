class_name BomberAbility
extends Ability
## 폭파범 "점화": 발동할 때마다 폭발 1번이 쌓인다. 폭발이 있으면 다음 매치 1번이 깨진 칸과 이어진 같은 색 블록을
## 모두 연쇄 폭파한다 (가까운 순서, 상하좌우로 퍼짐). 블록 사이 간격은 first_gap초에서 블록마다 × gap_scale, 최소 min_gap초.
## 연쇄 중에는 남은 시간이 멈추고 입력을 받지 않는다 (조작 잠금, 리필은 계속).
## 터진 블록 1개마다 가장 많이 진행된 족보(진행 비율, 같으면 점수가 높은 쪽)가 색 무관 한 칸 진행한다.
## 폭발을 쌓은 매치(발동시킨 매치) 자체는 폭발하지 않는다 (세션이 on_match 뒤에 캐릭터 족보를 진행하므로).

@export var charges_per_trigger: int = 1
@export var first_gap: float = 0.07
@export var gap_scale: float = 0.85
@export var min_gap: float = 0.025

## 업적 지표: 한 번에 연쇄 폭파한 블록 수(가장 큰 값), 연쇄 폭파 누적.
const METRIC_CHAIN_ONCE: StringName = &"bomber_chain_once"
const METRIC_CHAIN_TOTAL: StringName = &"bomber_chain_total"
## 폭발 매치 한 번이 끝났다 (연쇄가 끝나거나 이어진 블록이 없을 때).
const MOMENT_END: StringName = &"bomber_end"

## 남은 폭발 횟수.
var charges: int = 0
## 이번 연쇄에서 터뜨릴 칸 (가까운 순서).
var chain: Array[Vector2i] = []
## 이번 연쇄에서 실제로 터진 블록 수.
var blasted: int = 0

## 다음에 꺼낼 chain 번호 (chain.size()에 닿은 다음 차례에 연쇄가 끝난다).
var _index: int = 0
var _next_in: float = 0.0
var _chaining: bool = false


func trigger(_session: GameSession) -> String:
	charges += charges_per_trigger
	return "점화: 다음 매치 %d회 폭발" % charges


func on_match(session: GameSession, color: int, cells: Array[Vector2i]) -> void:
	if charges <= 0 or _chaining:
		return
	charges -= 1
	chain = _connected(session.board, cells, color)
	blasted = 0
	_index = 0
	_next_in = first_gap
	_chaining = not chain.is_empty()  # 이어진 블록이 없으면 폭발만 쓰고 연쇄는 없다
	if not _chaining:
		session.notify_moment(MOMENT_END)


func advance(session: GameSession, delta: float) -> void:
	if not _chaining:
		return
	_next_in -= delta
	while _chaining and _next_in <= TimedSystem.EPSILON:
		_pop(session)


func time_to_next_event() -> float:
	return maxf(_next_in, 0.0) if _chaining else INF


func clock_rate(clock: TimedSystem.Clock) -> float:
	return 0.0 if clock == TimedSystem.Clock.TIMER and _chaining else 1.0


func locks_input() -> bool:
	return _chaining


func is_chaining() -> bool:
	return _chaining


func status_text() -> String:
	if _chaining:
		return "%d연쇄" % blasted
	return "폭발 %d" % charges if charges > 0 else ""


## 연쇄에서 한 칸을 꺼내 터뜨린다. 다 꺼낸 다음 차례에 연쇄가 끝난다.
func _pop(session: GameSession) -> void:
	if _index >= chain.size():
		_chaining = false
		if blasted > 0:
			session.announce("%d연쇄!" % blasted)
		session.notify_moment(MOMENT_END)
		return
	var pos: Vector2i = chain[_index]
	_index += 1
	_next_in += maxf(min_gap, first_gap * pow(gap_scale, _index))
	if not session.blast_cell(pos):
		return
	blasted += 1
	session.metrics.record_max(METRIC_CHAIN_ONCE, blasted)
	session.metrics.add(METRIC_CHAIN_TOTAL)
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	recipes.advance_slot(recipes.most_advanced_slot(true), outcome)
	session.apply_recipe_outcome(outcome)


## start 칸들에서 상하좌우로 퍼지며 이어진 color 블록 (start 제외, 가까운 순서).
static func _connected(board: Board, start: Array[Vector2i], color: int) -> Array[Vector2i]:
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = start.duplicate()
	for pos: Vector2i in start:
		seen[pos] = true
	var found: Array[Vector2i] = []
	var i: int = 0
	while i < queue.size():
		var pos: Vector2i = queue[i]
		i += 1
		for dir: Vector2i in Board.DIRECTIONS:
			var next: Vector2i = pos + dir
			if not board.is_inside(next) or seen.has(next):
				continue
			if board.get_cell_type(next) != Board.CellType.COLOR_BLOCK or board.get_color(next) != color:
				continue
			seen[next] = true
			queue.append(next)
			found.append(next)
	return found
