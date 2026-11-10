class_name PuzzleBoardButton
extends Button
## 퍼즐 판 카드 하나 (메뉴 > 퍼즐, E38): 로마 숫자 + 판 모양 미리보기 + 별점 + 첫 클리어 보상. 다음 판과 선으로 이어진다.
## 앞 판을 풀기 전에는 어둡게 + 자물쇠, 누를 수 없다. 누르면 chosen(id).

signal chosen(id: String)

var board_id: String = ""

@onready var _number: Label = %Number
@onready var _mini: PuzzleMiniView = %Mini
@onready var _stars: StarRow = %Stars
@onready var _reward: Label = %RewardLabel
@onready var _lock: Control = %LockOverlay
@onready var _link: Control = %Link


## number = 목록 번호(1부터), reward = 아직 받지 않은 첫 클리어 코인, open = 풀 수 있다, has_next = 다음 판이 있다 (PuzzleMenu).
func setup(def: PuzzleDef, number: int, stars: int, reward: int, open: bool, has_next: bool) -> void:
	board_id = def.id
	_number.text = PuzzleMenu.roman(number)
	_mini.show_def(def)
	_stars.show_stars(stars)
	_reward.text = "첫 클리어 보상 ● %d" % reward if reward > 0 else ""
	_lock.visible = not open
	disabled = not open
	_link.visible = has_next


func stars_text() -> String:
	return _stars.shown_text()


func reward_text() -> String:
	return _reward.text


func number_text() -> String:
	return _number.text


func is_locked() -> bool:
	return disabled


## pressed (puzzle_board_button.tscn에서 연결).
func _on_pressed() -> void:
	chosen.emit(board_id)
