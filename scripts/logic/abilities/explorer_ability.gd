class_name ExplorerAbility
extends Ability
## 탐험가 (상시): 판에 3×3 탐험 구역이 있다 (플레이어가 없는 곳, 능력 RNG). 구역 안에서 매치하면
## 그 매치로 진행된 족보(완성된 것 제외)가 모두 한 칸 더 진행한다. 진행된 족보가 없으면 가장 많이 진행된 족보
## (진행 비율, 같으면 점수가 높은 쪽) 한 칸. 쓴 구역은 사라지고 respawn_delay초(판 경과) 뒤 다른 곳에 생긴다.

@export var zone_size: int = 3
@export var respawn_delay: float = 5.0

## 업적 지표: 구역 보너스 횟수.
const METRIC_BONUSES: StringName = &"explorer_bonuses"

## 지금 구역 (없으면 크기 0).
var zone: Rect2i = Rect2i()
## 다음 구역까지 남은 시간 (구역이 있으면 0).
var respawn_left: float = 0.0
## 구역 보너스 횟수.
var bonuses: int = 0

## 이번 매치가 구역 안이었다 (족보 처리에서 보너스).
var _bonus_pending: bool = false


func setup(session: GameSession) -> void:
	_spawn(session)


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if not has_zone() or not zone.has_point(session.board.player_pos):
		return
	_bonus_pending = true
	zone = Rect2i()
	respawn_left = respawn_delay
	session.notify_marks_changed()


func override_clear(session: GameSession, color: int) -> RecipeSet.ClearOutcome:
	if not _bonus_pending:
		return null
	_bonus_pending = false
	bonuses += 1
	session.metrics.add(METRIC_BONUSES)
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = recipes.apply_clear(color)
	var advanced: Array[int] = []
	for slot: int in outcome.advanced_slots:
		if not outcome.completed_slots.has(slot) and not advanced.has(slot):
			advanced.append(slot)
	if advanced.is_empty():
		advanced.append(recipes.most_advanced_slot(true))
	for slot: int in advanced:
		recipes.advance_slot(slot, outcome)
	return outcome


func advance(session: GameSession, delta: float) -> void:
	if has_zone():
		return
	respawn_left -= delta
	if respawn_left <= TimedSystem.EPSILON:
		_spawn(session)


func time_to_next_event() -> float:
	return INF if has_zone() else maxf(respawn_left, 0.0)


func has_zone() -> bool:
	return zone.size != Vector2i.ZERO


func status_text() -> String:
	return "구역 안에서 매치" if has_zone() else "새 구역까지 %s초" % Ability.format_seconds(respawn_left)


func board_marks() -> Array[BoardMark]:
	if not has_zone():
		return []
	return [BoardMark.new(BoardMark.Kind.ZONE, zone)]


## 플레이어가 들어 있지 않은 3×3 자리 중 하나에 구역을 만든다.
func _spawn(session: GameSession) -> void:
	var board: Board = session.board
	var options: Array[Rect2i] = []
	for y: int in board.size - zone_size + 1:
		for x: int in board.size - zone_size + 1:
			var rect: Rect2i = Rect2i(x, y, zone_size, zone_size)
			if not rect.has_point(board.player_pos):
				options.append(rect)
	if options.is_empty():  # 판이 너무 작다: 나중에 다시 시도
		respawn_left = respawn_delay
		return
	respawn_left = 0.0
	zone = options[session.get_rng().randi_range(0, options.size() - 1)]
	session.notify_marks_changed()


## 튜토리얼 힌트: 구역 안에서 하는 매치.
func prefers_hint(_session: GameSession, _color: int, center: Vector2i, _goal: int) -> bool:
	return has_zone() and zone.has_point(center)
