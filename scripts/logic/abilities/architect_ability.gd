class_name ArchitectAbility
extends Ability
## 건축가 "증축": 가장 많이 진행된 족보(진행 비율, 같으면 점수가 높은 쪽) 하나 끝에 무작위 색(능력 RNG) 한 칸을 붙이고
## 점수를 다시 계산한다. max_length칸인 족보는 더 늘리지 않는다. 완성되면 그 자리에 원래 길이의 족보가 나온다.

@export var max_length: int = 5

## 업적 지표: 늘린 족보를 완성한 수.
const METRIC_EXTENDED_RECIPES: StringName = &"architect_extended_recipes"

## 지금 족보를 늘린 슬롯 (완성되면 새 족보라 지운다).
var _extended: Dictionary[int, bool] = {}


func trigger(session: GameSession) -> String:
	var recipes: RecipeSet = session.recipes
	var slot: int = _target_slot(recipes)
	if slot < 0:
		return "증축: 더 늘릴 족보 없음"
	recipes.extend_slot(slot, session.get_rng().randi_range(0, session.get_config().color_count - 1))
	_extended[slot] = true
	session.recipes_updated.emit(recipes, RecipeSet.ClearOutcome.new())
	var recipe: RecipeSet.Recipe = recipes.recipes[slot]
	return "증축: 족보 한 장 +1칸 (%d칸 %d점)" % [recipe.length(), recipe.points]


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	for slot: int in outcome.completed_slots:
		if _extended.get(slot, false):
			session.metrics.add(METRIC_EXTENDED_RECIPES)
			_extended[slot] = false


## 늘릴 수 있는 족보 중 진행 비율이 가장 높은 슬롯 (같으면 점수가 높은 쪽). 없으면 -1.
func _target_slot(recipes: RecipeSet) -> int:
	var best: int = -1
	var best_ratio: float = -1.0
	for slot: int in recipes.slot_count():
		var recipe: RecipeSet.Recipe = recipes.recipes[slot]
		if recipe.length() >= max_length:
			continue
		var ratio: float = recipe.ratio()
		if ratio > best_ratio or (is_equal_approx(ratio, best_ratio) and recipe.points > recipes.recipes[best].points):
			best = slot
			best_ratio = ratio
	return best
