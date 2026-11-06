class_name AllInAbility
extends Ability
## 도박사 "올인": 발동할 때마다 기회 1번(최대 max_charges번 누적). 기회가 있으면 다음에 족보가 완성되는 매치에서
## 기회 1번을 써서 그 매치로 완성된 족보 점수를 모두 × multiplier.
## 발동시킨 매치 자체에는 적용되지 않는다 (세션이 족보 처리 후 캐릭터 족보를 진행하므로).

@export var multiplier: int = 2
@export var max_charges: int = 2

## 업적 지표: ×2로 완성한 길이 4 이상 족보 수, ×2 동시 완성 수(가장 큰 값), ×2로 더 얻은 점수.
const METRIC_LONG_RECIPES: StringName = &"gambler_long_recipes"
const METRIC_AT_ONCE: StringName = &"gambler_at_once"
const METRIC_BONUS: StringName = &"gambler_bonus"
## "길이 4 족보" 업적이 보는 길이.
const LONG_RECIPE: int = 4

var charges: int = 0


func trigger(_session: GameSession) -> String:
	charges = mini(max_charges, charges + 1)
	if charges > 1:
		return "올인: 다음 완성 ×%d (%d회)" % [multiplier, charges]
	return "올인: 다음 완성 족보 ×%d" % multiplier


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if charges > 0 and not outcome.completed_slots.is_empty():
		charges -= 1
		session.metrics.add(METRIC_BONUS, outcome.points * (multiplier - 1))
		outcome.points *= multiplier
		session.metrics.record_max(METRIC_AT_ONCE, outcome.completed_slots.size())
		for recipe: RecipeSet.Recipe in outcome.completed_recipes:
			if recipe.length() >= LONG_RECIPE:
				session.metrics.add(METRIC_LONG_RECIPES)


func status_text() -> String:
	if charges <= 0:
		return ""
	return "×%d (%d)" % [multiplier, charges] if charges > 1 else "×%d" % multiplier
