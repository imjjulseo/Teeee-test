class_name EffectWindowMetrics
extends RefCounted
## 지속 효과 "한 번 동안"의 업적 지표를 세는 부품 (별첨 B: 정지 한 번 동안 매치 3회, 피의 시간 한 번에 족보 2개 …).
## 능력이 구성으로 갖고, 효과가 시작되면 begin(), 효과 중 매치·족보 완성을 알리면 RunMetrics에 남긴다:
## 한 번 동안의 매치 수·완성 수는 가장 큰 값(record_max), 효과 중 얻은 점수·매치는 판 누적(add).
## 쓰지 않는 지표는 이름을 비워 둔다.

var matches_key: StringName
var recipes_key: StringName
var points_key: StringName
var total_matches_key: StringName
var _matches: int = 0
var _recipes: int = 0


func _init(p_matches_key: StringName = &"", p_recipes_key: StringName = &"", p_points_key: StringName = &"", p_total_matches_key: StringName = &"") -> void:
	matches_key = p_matches_key
	recipes_key = p_recipes_key
	points_key = p_points_key
	total_matches_key = p_total_matches_key


## 효과가 새로 시작됐다 (이어 붙는 재발동이면 부르지 않는다).
func begin() -> void:
	_matches = 0
	_recipes = 0


func on_match(metrics: RunMetrics) -> void:
	_matches += 1
	if matches_key != &"":
		metrics.record_max(matches_key, _matches)
	if total_matches_key != &"":
		metrics.add(total_matches_key)


func on_outcome(metrics: RunMetrics, outcome: RecipeSet.ClearOutcome) -> void:
	if outcome.completed_slots.is_empty():
		return
	_recipes += outcome.completed_slots.size()
	if recipes_key != &"":
		metrics.record_max(recipes_key, _recipes)
	if points_key != &"":
		metrics.add(points_key, outcome.points)
