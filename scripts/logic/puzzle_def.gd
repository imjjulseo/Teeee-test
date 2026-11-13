class_name PuzzleDef
extends Resource
<<<<<<< HEAD
## 블록 모으기 판 하나 (기획서 8.8장): 판 가운데 5×5 창의 모양. T = 모을 색 블록(4개), P = 나, . = 다른 색.
=======
## 블럭 모으기 판 하나 (기획서 8.8장): 판 가운데 5×5 창의 모양. T = 모을 색 블록(4개), P = 나, . = 다른 색.
>>>>>>> Choi
## 튜토리얼·연습 퍼즐 엔진(BlockPuzzle)이 이 모양으로 판을 깐다.

## 별점 기록의 키 (자동 생성 문제는 비어 있음).
@export var id: String = ""
@export var rows: PackedStringArray = PackedStringArray()
## 판 아래 안내 문구 (힌트를 쓰면 강조).
@export var tip: String = ""

const TARGET: String = "T"
const PLAYER: String = "P"


func size() -> int:
	return rows.size()


## 창 안 좌표에서 모을 블록 칸들.
func target_cells() -> Array[Vector2i]:
	return _cells_of(TARGET)


## 창 안 좌표의 내 칸 (없으면 가운데).
func player_cell() -> Vector2i:
	var found: Array[Vector2i] = _cells_of(PLAYER)
	return found[0] if not found.is_empty() else Vector2i(size() / 2, size() / 2)


func _cells_of(mark: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in rows.size():
		for x: int in rows[y].length():
			if rows[y][x] == mark:
				cells.append(Vector2i(x, y))
	return cells
