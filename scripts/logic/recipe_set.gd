class_name RecipeSet
extends RefCounted
## 족보 시스템 (기획서 5.1, B6~B8, B10, E7). 순수 로직.
## - 슬롯마다 길이가 정해진 족보(색 순서)가 하나씩 있다. 기본 2 · 3 · 4칸.
## - 매치 1회 = 족보 1칸. 다음에 필요한 색을 깨면 진행하고, 다른 색은 무시한다(진행 유지).
## - 모든 슬롯은 독립적으로 진행하며, 동시에 완성되면 점수를 합산한다.
## - 완성된 슬롯에는 같은 길이의 새 족보가 생긴다 (RecipeGenerator). 점수는 RecipeScoring.


class Recipe:
	extends RefCounted

	var colors: PackedInt32Array
	var points: int
	## 앞에서부터 채운 칸 수. 보통은 colors[progress]가 다음에 필요한 색.
	var progress: int = 0
	## 뒤에서부터 채운 칸 수 (거울세계).
	var back_progress: int = 0
	## 뒤에서부터 채운다 (거울세계). 앞뒤가 만나면 완성.
	var from_back: bool = false

	func _init(p_colors: PackedInt32Array, p_points: int) -> void:
		colors = p_colors
		points = p_points

	func length() -> int:
		return colors.size()

	## 채운 칸 수 (앞 + 뒤).
	func filled() -> int:
		return progress + back_progress

	## 채운 비율 0~1 (화가·탐험가·건축가의 "가장 많이 진행된 족보").
	func ratio() -> float:
		return float(filled()) / length()

	func is_complete() -> bool:
		return filled() >= colors.size()

	## 다음에 채울 칸 번호 (완성 상태면 의미 없음).
	func next_index() -> int:
		return length() - 1 - back_progress if from_back else progress

	## 다음에 깨야 하는 색. 완성 상태면 Board.NO_COLOR.
	func next_color() -> int:
		return Board.NO_COLOR if is_complete() else colors[next_index()]

	## 한 칸 채운다 (앞에서, 또는 거울세계면 뒤에서).
	func advance() -> void:
		if from_back:
			back_progress += 1
		else:
			progress += 1

	## k번 칸을 이미 채웠다.
	func is_step_done(k: int) -> bool:
		return k < progress or k >= length() - back_progress

	## 앞뒤 양쪽에서 채워 가운데서 만났다 (거울 ×2).
	func met_in_middle() -> bool:
		return progress > 0 and back_progress > 0

	## 진행까지 같은 사본 (진행을 미리 시험해 볼 때, 수선사).
	func copy() -> Recipe:
		var other: Recipe = Recipe.new(colors.duplicate(), points)
		other.progress = progress
		other.back_progress = back_progress
		other.from_back = from_back
		return other


## apply_clear의 결과.
class ClearOutcome:
	extends RefCounted

	## 이번 매치로 얻은 점수 합.
	var points: int = 0
	## 진행된 슬롯 (완성 포함).
	var advanced_slots: Array[int] = []
	## 완성되어 새 족보로 교체된 슬롯.
	var completed_slots: Array[int] = []
	## completed_slots와 같은 순서로, 완성된 족보 각각의 점수 (배율을 족보마다 적용할 때 쓴다).
	var completed_points: Array[int] = []
	## completed_slots와 같은 순서로, 완성된 족보 (교체되기 전 객체: 어떻게 완성됐는지 볼 때).
	var completed_recipes: Array[Recipe] = []

	## 완성된 족보마다 점수 × multiplier를 반올림해 points를 다시 계산한다 (장인·떠돌이 ×1.5).
	func scale_completed(multiplier: float) -> void:
		for i: int in completed_points.size():
			completed_points[i] = roundi(completed_points[i] * multiplier)
		_recount()

	## i번째로 완성된 족보만 × multiplier (거울: 앞뒤가 만난 족보 ×2).
	func scale_completed_at(i: int, multiplier: float) -> void:
		completed_points[i] = roundi(completed_points[i] * multiplier)
		_recount()

	func _recount() -> void:
		points = 0
		for value: int in completed_points:
			points += value


var recipes: Array[Recipe] = []

var _lengths: PackedInt32Array
var _generator: RecipeGenerator
var _scoring: RecipeScoring
## 새 족보도 뒤에서부터 채운다 (거울세계).
var _from_back: bool = false


func _init(lengths: PackedInt32Array, generator: RecipeGenerator, scoring: RecipeScoring) -> void:
	_lengths = lengths
	_generator = generator
	_scoring = scoring
	for slot: int in _lengths.size():
		recipes.append(_make(slot))


## color_counts: 판의 색별 개수를 돌려주는 함수 () -> PackedInt32Array (족보 첫 색 조건용).
## lengths를 주면 설정의 슬롯 길이 대신 쓴다 (능력이 족보 구성을 바꿀 때, 장인).
static func from_config(config: GameConfig, rng: RandomNumberGenerator, color_counts: Callable,
		lengths: PackedInt32Array = PackedInt32Array()) -> RecipeSet:
	return RecipeSet.new(lengths if not lengths.is_empty() else config.recipe_lengths,
		RecipeGenerator.from_config(config, rng, color_counts), RecipeScoring.from_config(config))


func slot_count() -> int:
	return recipes.size()


## color 블록 매치 1회로 모든 족보를 진행시키고 결과를 반환한다.
## canonical (color: int) -> int를 주면 족보의 다음 색을 그 함수로 바꿔 비교한다 (색약: 두 색을 같은 색으로).
func apply_clear(color: int, canonical: Callable = Callable()) -> ClearOutcome:
	var outcome: ClearOutcome = ClearOutcome.new()
	for slot: int in recipes.size():
		var next: int = recipes[slot].next_color()
		if (canonical.call(next) if canonical.is_valid() else next) == color:
			advance_slot(slot, outcome)
	return outcome


## 조커 "와일드": 색과 무관하게 모든 족보를 한 칸 진행시킨다.
func apply_wild() -> ClearOutcome:
	var outcome: ClearOutcome = ClearOutcome.new()
	for slot: int in recipes.size():
		advance_slot(slot, outcome)
	return outcome


## slot 족보를 한 칸 진행해 outcome에 기록한다. 완성되면 새 족보로 바꾸고 true.
## 능력이 족보 진행을 직접 정할 때 쓴다 (쌍둥이·탐험가).
func advance_slot(slot: int, outcome: ClearOutcome) -> bool:
	var recipe: Recipe = recipes[slot]
	recipe.advance()
	outcome.advanced_slots.append(slot)
	if not recipe.is_complete():
		return false
	outcome.points += recipe.points
	outcome.completed_slots.append(slot)
	outcome.completed_points.append(recipe.points)
	outcome.completed_recipes.append(recipe)
	recipes[slot] = _make(slot)
	return true


## slot 족보 끝(뒤에서 채운 칸이 있으면 그 앞)에 color 한 칸을 붙이고 점수를 다시 계산한다 (건축가 "증축").
## 진행은 그대로. 완성되어 새로 나오는 족보는 원래 길이다.
func extend_slot(slot: int, color: int) -> void:
	var recipe: Recipe = recipes[slot]
	var colors: PackedInt32Array = recipe.colors  # 배열 값을 바꿔 다시 넣는다 (Packed 배열은 값 복사)
	colors.insert(recipe.length() - recipe.back_progress, color)
	recipe.colors = colors
	recipe.points = _scoring.points_for(colors)


## 진행 비율(채운 칸 ÷ 길이)이 가장 높은 슬롯 (화가·탐험가의 "가장 많이 진행된 족보").
## 같으면 앞 슬롯, tie_by_points면 점수가 높은 슬롯.
func most_advanced_slot(tie_by_points: bool = false) -> int:
	var best: int = 0
	for slot: int in range(1, recipes.size()):
		var a: float = recipes[slot].ratio()
		var b: float = recipes[best].ratio()
		if a > b or (tie_by_points and is_equal_approx(a, b) and recipes[slot].points > recipes[best].points):
			best = slot
	return best


## 진행이 가장 많은 슬롯. 같으면 완성까지 남은 칸이 적은 슬롯, 그다음 앞 슬롯.
func best_progress_slot() -> int:
	var best: int = 0
	for slot: int in range(1, recipes.size()):
		var a: Recipe = recipes[slot]
		var b: Recipe = recipes[best]
		if a.filled() > b.filled() or (a.filled() == b.filled() and a.length() - a.filled() < b.length() - b.filled()):
			best = slot
	return best


## 다음 색이 같은 (아직 안 끝난) 족보 슬롯들 — 그런 색이 여러 개면 앞 슬롯의 색. 없으면 빈 배열.
## 처음 볼 때 안내 "족보 동시 진행" (8.8장). canonical은 색 비교 변환 (색약).
func slots_waiting_same_color(canonical: Callable = Callable()) -> Array[int]:
	var by_color: Dictionary[int, Array] = {}
	for slot: int in recipes.size():
		if recipes[slot].is_complete():
			continue
		var color: int = recipes[slot].next_color()
		if canonical.is_valid():
			color = canonical.call(color)
		if not by_color.has(color):
			by_color[color] = []
		by_color[color].append(slot)
	for slot: int in recipes.size():
		if recipes[slot].is_complete():
			continue
		var color: int = recipes[slot].next_color()
		if canonical.is_valid():
			color = canonical.call(color)
		if by_color[color].size() >= 2:
			var slots: Array[int] = []
			slots.assign(by_color[color])
			return slots
	return [] as Array[int]


## 테스트/디버그용: 슬롯의 족보 색 순서를 직접 지정한다 (진행도 0, 점수는 규칙대로).
func set_recipe_colors(slot: int, colors: PackedInt32Array) -> void:
	recipes[slot] = Recipe.new(colors, _scoring.points_for(colors))
	recipes[slot].from_back = _from_back


## 족보 카드를 통째로 바꾼다 (튜토리얼: 원하는 색 순서·진행). 카드 수 = colors_list 크기 (0이면 카드 없음).
## 완성되면 같은 자리에 같은 길이로 새 족보가 나온다.
func replace_all(colors_list: Array[PackedInt32Array], progress: PackedInt32Array = PackedInt32Array()) -> void:
	recipes.clear()
	_lengths = PackedInt32Array()
	for i: int in colors_list.size():
		var colors: PackedInt32Array = colors_list[i]
		_lengths.append(colors.size())
		var recipe: Recipe = Recipe.new(colors.duplicate(), _scoring.points_for(colors))
		recipe.progress = progress[i] if i < progress.size() else 0
		recipe.from_back = _from_back
		recipes.append(recipe)


## 색 순서 colors의 족보 점수 (규칙대로).
func points_for(colors: PackedInt32Array) -> int:
	return _scoring.points_for(colors)


## 거울세계: 모든 족보(이후 새로 나오는 것 포함)를 뒤에서부터 채운다. 이미 채운 칸은 그대로.
func set_fill_from_back(enabled: bool) -> void:
	_from_back = enabled
	for recipe: Recipe in recipes:
		recipe.from_back = enabled


func is_filling_from_back() -> bool:
	return _from_back


func _make(slot: int) -> Recipe:
	var colors: PackedInt32Array = _generator.make_colors(_lengths[slot], _current_colors())
	var recipe: Recipe = Recipe.new(colors, _scoring.points_for(colors))
	recipe.from_back = _from_back
	return recipe


## 지금 나와 있는 족보들의 색 순서 (새 족보가 같은 순서가 되지 않게).
func _current_colors() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for recipe: Recipe in recipes:
		result.append(recipe.colors)
	return result
