class_name WallAbility
extends Ability
## 벽 타는 자 (상시): 벽에 붙은 칸에서는 벽 쪽 1칸을 빼고 나머지 3칸만 같아도 매치. 모서리(벽 2개)는 불가.
## 3칸 매치로 얻는 시간은 × wall_time_scale. 벽 매치를 연달아 해도 된다.

@export var wall_time_scale: float = 0.5

## 판 밖으로 나가도 되는 이웃 수 (벽 1개).
const ALLOWED_OUTSIDE: int = 1

## 업적 지표: 벽 매치로만 완성한 족보 수, 벽 매치를 한 벽의 수(최대 4), 벽 매치 수.
const METRIC_PURE_RECIPES: StringName = &"wall_pure_recipes"
const METRIC_WALLS: StringName = &"wall_walls"
const METRIC_WALL_MATCHES: StringName = &"wall_matches"

## 이번 매치가 벽 매치였는지 (족보 진행 보정 때 쓴다).
var _wall_match: bool = false
## 족보 슬롯 → 지금 족보가 벽 매치가 아닌 매치로 진행된 적이 있는지.
var _tainted: Dictionary[int, bool] = {}
## 벽 매치를 한 벽 (위·아래·왼쪽·오른쪽 방향).
var _walls: Dictionary[Vector2i, bool] = {}


func match_rule() -> MatchRule:
	return MatchRule.new(ALLOWED_OUTSIDE)


func modify_match_time(_session: GameSession, seconds: float, found: MatchRule.Found) -> float:
	return seconds * wall_time_scale if WallAbility.is_wall_match(found.cells) else seconds


static func is_wall_match(cells: Array[Vector2i]) -> bool:
	return cells.size() < Board.DIRECTIONS.size()


func on_match(session: GameSession, _color: int, cells: Array[Vector2i]) -> void:
	_wall_match = WallAbility.is_wall_match(cells)
	if not _wall_match:
		return
	session.metrics.add(METRIC_WALL_MATCHES)
	var pos: Vector2i = session.board.player_pos
	var last: int = session.board.size - 1
	var wall: Vector2i = Vector2i.LEFT if pos.x == 0 else Vector2i.RIGHT if pos.x == last else Vector2i.UP if pos.y == 0 else Vector2i.DOWN
	_walls[wall] = true
	session.metrics.record_max(METRIC_WALLS, _walls.size())


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	for slot: int in outcome.advanced_slots:
		if not _wall_match:
			_tainted[slot] = true
	for slot: int in outcome.completed_slots:
		if not _tainted.get(slot, false):
			session.metrics.add(METRIC_PURE_RECIPES)
		_tainted[slot] = false  # 같은 자리에 새 족보


func status_text() -> String:
	return "벽 3방향 매치"
