class_name RecipeGenerator
extends RefCounted
## 족보 색 순서 만들기 (기획서 5.1장, E7).
## 색은 무작위(중복 허용)이되, 첫 색은 판에 first_color_min개 이상 있어야 하고 다른 족보와 완전히 같으면 다시 뽑는다.
## attempts번 안에 조건을 못 맞추면 마지막으로 뽑은 순서를 쓴다.

var _color_count: int
var _rng: RandomNumberGenerator
var _first_color_min: int
var _attempts: int
## 판의 색별 개수를 돌려주는 함수 () -> PackedInt32Array (씨앗은 자랄 색으로 센다).
var _color_counts: Callable


func _init(color_count: int, rng: RandomNumberGenerator, first_color_min: int, attempts: int, color_counts: Callable) -> void:
	_color_count = color_count
	_rng = rng
	_first_color_min = first_color_min
	_attempts = maxi(attempts, 1)
	_color_counts = color_counts


static func from_config(config: GameConfig, rng: RandomNumberGenerator, color_counts: Callable) -> RecipeGenerator:
	return RecipeGenerator.new(config.color_count, rng, config.recipe_first_color_min,
		config.recipe_generation_attempts, color_counts)


## length칸 족보의 색 순서. avoid에 있는 색 순서(지금 나와 있는 족보들)와 같으면 다시 뽑는다.
func make_colors(length: int, avoid: Array[PackedInt32Array] = []) -> PackedInt32Array:
	var counts: PackedInt32Array = _color_counts.call()
	var colors: PackedInt32Array = PackedInt32Array()
	for _try: int in _attempts:
		colors = random_colors(length)
		if counts[colors[0]] < _first_color_min:
			continue
		if avoid.has(colors):
			continue
		break
	return colors


## 조건 없이 무작위 색 length개.
func random_colors(length: int) -> PackedInt32Array:
	var colors: PackedInt32Array = PackedInt32Array()
	for _i: int in length:
		colors.append(_rng.randi_range(0, _color_count - 1))
	return colors
