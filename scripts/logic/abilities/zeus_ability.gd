class_name ZeusAbility
extends Ability
## 제우스 "낙뢰": 판의 다 자란 absorb_color(노랑) 블록을 모두 흡수한다 (그 자리는 씨앗). 그동안 시간·리필이 멈추고 조작할 수 없다.
## first_delay초 뒤부터 strike_interval초마다 낙뢰가 족보 하나를 색 무관 한 칸씩 채운다 — strike_order(4칸 → 3칸 → 2칸 족보)
## 순서로, 그 족보가 완성되면 다음 족보로. 흡수한 수만큼 내리치면(마지막 낙뢰 한 간격 뒤) 끝난다.
## 흡수할 노랑이 없으면 empty_delay초 뒤에 끝난다.

@export var absorb_color: int = 0
@export var first_delay: float = 1.0
@export var strike_interval: float = 0.5
@export var empty_delay: float = 0.6
## 낙뢰를 받을 족보 슬롯 순서 (없는 슬롯은 건너뛴다).
@export var strike_order: PackedInt32Array = PackedInt32Array([2, 1, 0])

## 낙뢰가 끝났다 (시간이 다시 흐른다).
const MOMENT_END: StringName = &"zeus_end"
## 업적 지표: 낙뢰 한 번에 흡수한 노랑 수, 한 판에 흡수한 노랑 수.
const METRIC_ABSORBED_ONCE: StringName = &"zeus_absorbed_once"
const METRIC_ABSORBED: StringName = &"zeus_absorbed"

var active: bool = false
## 남은 낙뢰 수.
var strikes_left: int = 0
## 흡수한 블록 수 (판 전체).
var absorbed: int = 0

var _order_index: int = 0
var _next_in: float = 0.0


func trigger(session: GameSession) -> String:
	var board: Board = session.board
	var cells: Array[Vector2i] = []
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if board.get_color(pos) == absorb_color:
			cells.append(pos)
	for pos: Vector2i in cells:
		session.blast_cell(pos)
	active = true
	strikes_left = cells.size()
	absorbed += cells.size()
	session.metrics.record_max(METRIC_ABSORBED_ONCE, cells.size())
	session.metrics.add(METRIC_ABSORBED, cells.size())
	_order_index = 0
	_next_in = first_delay if not cells.is_empty() else empty_delay
	if cells.is_empty():
		return "낙뢰: 노랑이 없어요"
	return "낙뢰: 노랑 %d개 흡수" % cells.size()


func advance(session: GameSession, delta: float) -> void:
	if not active:
		return
	_next_in -= delta
	while active and _next_in <= TimedSystem.EPSILON:
		_strike(session)


func time_to_next_event() -> float:
	return maxf(_next_in, 0.0) if active else INF


func clock_rate(clock: TimedSystem.Clock) -> float:
	return 0.0 if active and (clock == TimedSystem.Clock.TIMER or clock == TimedSystem.Clock.REFILL) else 1.0


func locks_input() -> bool:
	return active


func status_text() -> String:
	return "낙뢰 %d" % strikes_left if active else ""


## 낙뢰 중에는 배경을 칠한다 (끝나는 시각이 정해져 있지 않다).
func effect_remaining() -> float:
	return INF if active else -1.0


## 지금 낙뢰를 받을 족보 슬롯.
func target_slot(recipes: RecipeSet) -> int:
	var slots: Array[int] = []
	for slot: int in strike_order:
		if slot < recipes.slot_count():
			slots.append(slot)
	return slots[_order_index % slots.size()] if not slots.is_empty() else 0


func _strike(session: GameSession) -> void:
	if strikes_left <= 0:
		active = false
		session.announce("낙뢰 끝")
		session.notify_moment(MOMENT_END)
		return
	strikes_left -= 1
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	if recipes.advance_slot(target_slot(recipes), outcome):
		_order_index += 1
	session.apply_recipe_outcome(outcome)
	_next_in += strike_interval
