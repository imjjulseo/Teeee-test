class_name TwinsAbility
extends Ability
## 쌍둥이 (상시): 매치한 색으로 족보가 한 칸 진행될 때, 바로 다음 칸이 같은 색이면 이어서 진행한다
## (같은 색이 이어진 칸을 매치 한 번으로 모두 채움). 반복 보너스 점수는 그대로. 한 번에 더 진행하는 칸은 max_extra까지.

@export var max_extra: int = 6

## 업적 지표: 매치 한 번으로 이어진 칸을 더 진행한 횟수 (족보마다).
const METRIC_DOUBLES: StringName = &"twins_doubles"

## 이번 판에 이어서 더 진행한 칸 수.
var extra_steps: int = 0


func override_clear(session: GameSession, color: int) -> RecipeSet.ClearOutcome:
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	for slot: int in recipes.slot_count():
		if recipes.recipes[slot].next_color() != color:
			continue
		var completed: bool = recipes.advance_slot(slot, outcome)
		var extra: int = 0
		while not completed and extra < max_extra and _continues_same_color(recipes.recipes[slot]):
			completed = recipes.advance_slot(slot, outcome)
			extra += 1
		extra_steps += extra
		if extra > 0:
			session.metrics.add(METRIC_DOUBLES)
	return outcome


func status_text() -> String:
	return "두 칸 진행 %d" % extra_steps


## 방금 채운 칸과 다음 칸이 같은 색이다.
func _continues_same_color(recipe: RecipeSet.Recipe) -> bool:
	return recipe.progress > 0 and recipe.next_color() == recipe.colors[recipe.progress - 1]
