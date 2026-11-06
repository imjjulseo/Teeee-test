class_name MatchRule
extends RefCounted
## 매치 판정 규칙 (기획서 4.1장). 기본: 플레이어 상·하·좌·우 칸이 모두 판 안의 다 자란 블록이고 색이 같으면 매치.
## 판 밖으로 나간 이웃을 allowed_outside개까지 빼고 볼 수 있다 (벽 타는 자 = 1, 모서리는 2개라 불가).
## 판 끝이 이어진 판(Board.wraps_edges, 항해사)에서는 반대편 칸이 이웃이다.
## 캐릭터 능력이 다른 규칙을 쓰면 이 클래스를 상속해 find를 덮어쓴다 (Ability.match_rule).


## 매치 결과: 깬 색과 깨지는 칸들.
class Found:
	extends RefCounted

	var color: int
	var cells: Array[Vector2i]

	func _init(p_color: int, p_cells: Array[Vector2i]) -> void:
		color = p_color
		cells = p_cells


## 판 밖으로 나가도 되는 이웃 수.
var allowed_outside: int = 0
## 색을 비교하기 전에 바꾸는 함수 (color: int) -> int. 비어 있으면 그대로 (색약이 두 색을 같은 색으로 본다).
## 매치 결과의 색도 바꾼 색이다.
var canonical: Callable = Callable()


func _init(p_allowed_outside: int = 0) -> void:
	allowed_outside = p_allowed_outside


## center를 중심으로 매치를 찾는다. 없으면 null.
func find(board: Board, center: Vector2i) -> Found:
	var color: int = Board.NO_COLOR
	var cells: Array[Vector2i] = []
	var outside: int = 0
	for dir: Vector2i in Board.DIRECTIONS:
		var pos: Vector2i = board.step_from(center, dir)
		if not board.is_inside(pos):
			outside += 1
			continue
		if board.get_cell_type(pos) != Board.CellType.COLOR_BLOCK:
			return null
		var cell_color: int = color_of(board.get_color(pos))
		if color == Board.NO_COLOR:
			color = cell_color
		elif cell_color != color:
			return null
		cells.append(pos)
	if outside > allowed_outside or cells.is_empty():
		return null
	return Found.new(color, cells)


## 비교에 쓰는 색 (canonical이 있으면 바꾼 색).
func color_of(color: int) -> int:
	return canonical.call(color) if canonical.is_valid() else color
