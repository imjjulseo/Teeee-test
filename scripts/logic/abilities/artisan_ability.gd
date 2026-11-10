class_name ArtisanAbility
extends Ability
## 장인 (상시): 족보가 lengths(3칸·4칸) 두 장만 나오는 대신, 완성한 족보 점수 × multiplier (족보마다 반올림).

@export var lengths: PackedInt32Array = PackedInt32Array([3, 4])
@export var multiplier: float = 1.5


func recipe_lengths(_lengths: PackedInt32Array) -> PackedInt32Array:
	return lengths


func modify_outcome(_session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	outcome.scale_completed(multiplier)


func status_text() -> String:
	return "족보 %d장 · ×%s" % [lengths.size(), Ability.format_number(multiplier)]
