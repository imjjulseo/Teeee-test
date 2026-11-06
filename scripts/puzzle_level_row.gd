class_name PuzzleLevelRow
extends VBoxContainer
## 블럭 모으기 단계 한 줄 (설정 > 블럭 모으기): "Lv.2 두 개 모으기 · 첫 클리어 ● 50" + 판 버튼들. 판을 누르면 board_chosen(id).

signal board_chosen(id: String)

## 판 버튼 (데이터로 개수가 정해지는 반복 노드).
@export var board_button_scene: PackedScene

var _buttons: Array[PuzzleBoardButton] = []

@onready var _title: Label = %LevelTitle
@onready var _boards: HFlowContainer = %Boards


func setup(level: PuzzleLevel, store: PuzzleStore, unlocks: PuzzleUnlocks) -> void:
	var notes: String = " · 목표 모양 숨김" if level.hide_goal else ""
	if level.clear_coins > 0:
		notes += " · 첫 클리어 ● %d" % level.clear_coins
	_title.text = "Lv.%d %s%s" % [level.level, level.name, notes]
	for def: PuzzleDef in level.boards:
		var button: PuzzleBoardButton = board_button_scene.instantiate() as PuzzleBoardButton
		_boards.add_child(button)
		button.setup(def, store.stars_of(def.id), unlocks.is_open(def.id), unlocks.pending_reward(def.id))
		button.chosen.connect(board_chosen.emit)
		_buttons.append(button)


func buttons() -> Array[PuzzleBoardButton]:
	return _buttons
