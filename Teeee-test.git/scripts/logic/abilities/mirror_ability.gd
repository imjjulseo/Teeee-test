class_name MirrorAbility
extends Ability
## 거울 (상시): 벽 밖으로 나가면 판이 뒤집히며 현실 ↔ 거울세계를 오간다 — 좌우 벽은 좌우반전, 위아래 벽은 상하반전
## (플레이어도 함께 뒤집혀 반대편 가장자리에 선다). 이 이동도 한 수로 세고, 도착 자리가 매치면 매치.
## 거울세계에서는 족보를 뒤에서부터 채우고 카드의 칸도 거꾸로 보인다. 앞뒤에서 채워 가운데서 만나 완성하면 × meet_multiplier.

@export var meet_multiplier: float = 2.0

## 업적 지표: 거울세계에서 완성한 족보 수, 세계 전환 횟수.
const METRIC_MIRROR_RECIPES: StringName = &"mirror_recipes"
const METRIC_SWITCHES: StringName = &"mirror_switches"

## 지금 거울세계인지.
var in_mirror: bool = false
## 세계를 바꾼 횟수.
var switches: int = 0


func pass_through_wall(session: GameSession, result: Board.MoveResult) -> bool:
	var horizontal: bool = (result.to - result.from).x != 0
	session.board.mirror(horizontal)
	in_mirror = not in_mirror
	switches += 1
	session.metrics.add(METRIC_SWITCHES)
	session.recipes.set_fill_from_back(in_mirror)
	session.notify_board_rearranged()
	session.notify_display_changed()
	session.recipes_updated.emit(session.recipes, RecipeSet.ClearOutcome.new())
	session.announce("거울세계" if in_mirror else "현실")
	return true


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if in_mirror:
		session.metrics.add(METRIC_MIRROR_RECIPES, outcome.completed_slots.size())
	for i: int in outcome.completed_recipes.size():
		if outcome.completed_recipes[i].met_in_middle():
			outcome.scale_completed_at(i, meet_multiplier)


func display_style() -> DisplayStyle:
	if not in_mirror:
		return null
	var style: DisplayStyle = DisplayStyle.new()
	style.reversed_recipes = true
	return style


func status_text() -> String:
	return "거울세계" if in_mirror else "현실"


## 거울세계에 있는 동안 배경을 은은하게 칠한다 (끝나는 시각 없음).
func effect_remaining() -> float:
	return INF if in_mirror else -1.0
