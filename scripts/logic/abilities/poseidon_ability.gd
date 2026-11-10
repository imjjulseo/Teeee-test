class_name PoseidonAbility
extends Ability
## 포세이돈 "해일": 다 자란 sink_color(파랑) 블록이 전부 판 아래쪽에 평평하게 깔린다.
## 다 자란 블록 자리끼리 색만 다시 놓는다: 아래 줄부터(같은 줄은 왼쪽부터) 파랑 개수만큼 파랑, 나머지 자리는 위 줄부터
## 원래 파랑이 아닌 색을 원래 순서(위 → 아래, 왼쪽 → 오른쪽)대로. 색 개수는 그대로, 씨앗·플레이어·금화는 그대로.

@export var sink_color: int = 2

## 업적 지표: 해일 횟수, 파랑(sink_color) 매치 수.
const METRIC_TIDES: StringName = &"poseidon_tides"
const METRIC_BLUE_MATCHES: StringName = &"poseidon_blue_matches"


func on_match(session: GameSession, color: int, _cells: Array[Vector2i]) -> void:
	if color == sink_color:
		session.metrics.add(METRIC_BLUE_MATCHES)


func trigger(session: GameSession) -> String:
	session.metrics.add(METRIC_TIDES)
	var board: Board = session.board
	var blocks: Array[Vector2i] = board.positions_of_type(Board.CellType.COLOR_BLOCK)  # 위 → 아래, 왼쪽 → 오른쪽
	var others: Array[int] = []
	for pos: Vector2i in blocks:
		if board.get_color(pos) != sink_color:
			others.append(board.get_color(pos))
	var bottom_first: Array[Vector2i] = blocks.duplicate()
	bottom_first.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y or (a.y == b.y and a.x < b.x))
	var sunk: Dictionary[Vector2i, bool] = {}
	for i: int in blocks.size() - others.size():
		sunk[bottom_first[i]] = true
	var changed: Array[Vector2i] = []
	var next_other: int = 0
	for pos: Vector2i in blocks:
		var color: int = sink_color
		if not sunk.has(pos):
			color = others[next_other]
			next_other += 1
		if board.get_color(pos) != color:
			board.recolor_block(pos, color)
			changed.append(pos)
	if not changed.is_empty():
		session.cells_changed.emit(changed)
	return "해일: 파란 블록이 가라앉음"
