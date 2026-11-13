class_name WildAbility
extends Ability
## 조커 "와일드": 발동하면 와일드 charges_per_trigger번이 쌓인다 (누적 가능). 와일드가 있으면 다음 매치 1번이
## 색과 무관하게 모든 족보를 한 칸씩 진행시킨다. 캐릭터 족보는 평소처럼 깬 색으로 진행한다.

@export var charges_per_trigger: int = 2

## 업적 지표: 와일드 한 번에 완성한 족보 수 (가장 큰 값).
const METRIC_WILD_RECIPES: StringName = &"joker_wild_recipes"

var charges: int = 0


func trigger(_session: GameSession) -> String:
	charges += charges_per_trigger
	return "와일드 %d회 준비" % charges


func override_clear(session: GameSession, _color: int) -> RecipeSet.ClearOutcome:
	if charges <= 0:
		return null
	charges -= 1
	var outcome: RecipeSet.ClearOutcome = session.recipes.apply_wild()
	session.metrics.record_max(METRIC_WILD_RECIPES, outcome.completed_slots.size())
	return outcome


func status_text() -> String:
	if charges <= 0:
		return ""
	return "와일드 %d" % charges if charges > 1 else "와일드"
