class_name PuzzleBoardButton
extends Button
## 퍼즐 판 하나 (메뉴 > 퍼즐): 번호 + 판 모양 미리보기 + 아래 한 줄 — 푼 판은 별("★★☆"),
## 안 푼 판은 첫 클리어 보상("● 20"). 누르면 chosen(id).

signal chosen(id: String)

var board_id: String = ""

@onready var _number: Label = %Number
@onready var _mini: PuzzleMiniView = %Mini
@onready var _stars: Label = %Stars


## number = 목록 번호(1부터), reward = 아직 받지 않은 첫 클리어 코인 (PuzzleMenu).
func setup(def: PuzzleDef, number: int, stars: int, reward: int = 0) -> void:
	board_id = def.id
	_number.text = str(number)
	_mini.show_def(def)
	if stars > 0:
		_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	else:
		_stars.text = "● %d" % reward if reward > 0 else "☆☆☆"


func stars_text() -> String:
	return _stars.text


func number_text() -> String:
	return _number.text


## pressed (puzzle_board_button.tscn에서 연결).
func _on_pressed() -> void:
	chosen.emit(board_id)
