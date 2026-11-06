class_name PuzzleBoardButton
extends Button
## 블럭 모으기 단계 판 하나 (설정 > 블럭 모으기): 판 모양 미리보기 + 아래 한 줄 — 푼 판은 별("★★☆"),
## 안 푼 판은 첫 클리어 보상("● 50") 또는 "안 함", 아직 안 열린 판은 "잠김"(누를 수 없음). 누르면 chosen(id).

signal chosen(id: String)

var board_id: String = ""

@onready var _mini: PuzzleMiniView = %Mini
@onready var _stars: Label = %Stars


## open = 열렸는지, reward = 아직 받지 않은 첫 클리어 코인 (PuzzleUnlocks).
func setup(def: PuzzleDef, stars: int, open: bool = true, reward: int = 0) -> void:
	board_id = def.id
	_mini.show_def(def)
	disabled = not open
	if not open:
		_stars.text = "잠김"
	elif stars > 0:
		_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	else:
		_stars.text = "● %d" % reward if reward > 0 else "안 함"


func stars_text() -> String:
	return _stars.text


## pressed (puzzle_board_button.tscn에서 연결).
func _on_pressed() -> void:
	chosen.emit(board_id)
