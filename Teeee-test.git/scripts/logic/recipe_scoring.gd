class_name RecipeScoring
extends RefCounted
## 족보 점수 (기획서 5.1장, E7): base × L(L−1)/2 × (1 + repeat_bonus × 반복 수).
## 반복 수 = 바로 앞 칸과 같은 색인 칸 수. 기본값이면 2칸 100 · 3칸 300 · 4칸 600, 같은 색이 이어지면 더 높다.

var base_score: int
var repeat_bonus: float


func _init(p_base_score: int, p_repeat_bonus: float) -> void:
	base_score = p_base_score
	repeat_bonus = p_repeat_bonus


static func from_config(config: GameConfig) -> RecipeScoring:
	return RecipeScoring.new(config.recipe_base_score, config.recipe_repeat_bonus)


## 색 순서 colors인 족보의 완성 점수.
func points_for(colors: PackedInt32Array) -> int:
	var length: int = colors.size()
	return roundi(base_score * length * (length - 1) / 2.0 * (1.0 + repeat_bonus * repeat_count(colors)))


## 바로 앞 칸과 같은 색인 칸 수.
static func repeat_count(colors: PackedInt32Array) -> int:
	var repeats: int = 0
	for i: int in range(1, colors.size()):
		if colors[i] == colors[i - 1]:
			repeats += 1
	return repeats
