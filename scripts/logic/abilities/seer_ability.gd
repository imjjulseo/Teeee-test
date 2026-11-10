class_name SeerAbility
extends Ability
## 예지안. 상시: 씨앗이 자랄 색이 보인다. "예언"(발동): 판에서 같은 색 ㅗ·ㅜ·ㅓ·ㅏ 모양(가운데 + 팔 3칸)을 모두 매치한다.
## 씨앗은 자랄 색으로 보고, 플레이어 칸은 빠진다. 한 블록은 한 모양에만 — 다른 모양과 칸이 덜 겹치는 모양부터 고른다.
## 모양마다 매치 1회(매치 시간), 모양 수만큼 일반 족보가 모두 색 무관하게 전진한다. 캐릭터 족보는 진행하지 않는다.

## 모양의 팔 (가운데 기준): ㅗ, ㅜ, ㅓ, ㅏ.
const ARMS: Array[Array] = [
	[Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT],
	[Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT],
	[Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT],
	[Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT],
]

## 지표: 예언 한 번에 매치한 모양 수 (캐릭터 튜토리얼 목표).
const METRIC_SHAPES_ONCE: StringName = &"seer_shapes_once"

## 예언으로 매치한 모양 수 (판 전체).
var shapes_matched: int = 0


func trigger(session: GameSession) -> String:
	var shapes: Array[MatchRule.Found] = find_shapes(session.board)
	if shapes.is_empty():
		return "예언: 맞는 모양이 없어요"
	for shape: MatchRule.Found in shapes:
		for pos: Vector2i in shape.cells:
			session.blast_cell(pos, true)
		session.award_match_time()
	shapes_matched += shapes.size()
	session.metrics.record_max(METRIC_SHAPES_ONCE, shapes.size())
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	for slot: int in recipes.slot_count():
		for _i: int in shapes.size():
			recipes.advance_slot(slot, outcome)
	session.apply_recipe_outcome(outcome)
	return "예언 실현: 모양 %d개 / 족보 모두 %d칸" % [shapes.size(), shapes.size()]


func display_style() -> DisplayStyle:
	var style: DisplayStyle = DisplayStyle.new()
	style.reveal_seeds = true
	return style


## 겹치지 않는 모양들 (가운데부터 팔 순서의 칸, 색). 다른 후보와 칸이 덜 겹치는 모양부터 고른다.
static func find_shapes(board: Board) -> Array[MatchRule.Found]:
	var candidates: Array[MatchRule.Found] = []
	for pos: Vector2i in board.all_positions():
		var color: int = _color_at(board, pos)
		if color == Board.NO_COLOR:
			continue
		for arms: Array in ARMS:
			var cells: Array[Vector2i] = [pos]
			for arm: Vector2i in arms:
				if _color_at(board, pos + arm) != color:
					cells.clear()
					break
				cells.append(pos + arm)
			if not cells.is_empty():
				candidates.append(MatchRule.Found.new(color, cells))
	var use: Dictionary[Vector2i, int] = {}
	for shape: MatchRule.Found in candidates:
		for cell: Vector2i in shape.cells:
			use[cell] = use.get(cell, 0) + 1
	var order: Array[int] = []
	var weight: Array[int] = []
	for i: int in candidates.size():
		order.append(i)
		var w: int = 0
		for cell: Vector2i in candidates[i].cells:
			w += use[cell]
		weight.append(w)
	order.sort_custom(func(a: int, b: int) -> bool: return weight[a] < weight[b] or (weight[a] == weight[b] and a < b))
	var taken: Dictionary[Vector2i, bool] = {}
	var chosen: Array[MatchRule.Found] = []
	for i: int in order:
		var shape: MatchRule.Found = candidates[i]
		if shape.cells.any(func(cell: Vector2i) -> bool: return taken.has(cell)):
			continue
		for cell: Vector2i in shape.cells:
			taken[cell] = true
		chosen.append(shape)
	return chosen


## 모양 판정에 쓰는 색: 다 자란 블록은 그 색, 씨앗은 자랄 색. 판 밖·플레이어·빈칸은 NO_COLOR.
static func _color_at(board: Board, pos: Vector2i) -> int:
	if not board.is_inside(pos):
		return Board.NO_COLOR
	var type: Board.CellType = board.get_cell_type(pos)
	return board.get_color(pos) if type == Board.CellType.COLOR_BLOCK or type == Board.CellType.SEED else Board.NO_COLOR
