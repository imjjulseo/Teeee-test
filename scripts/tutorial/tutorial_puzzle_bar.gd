class_name TutorialPuzzleBar
extends PanelContainer
<<<<<<< HEAD
## 튜토리얼 판의 블록 모으기 막대: 이름 · 판 번호 · 수 / 최소 수, 되돌리기 · 처음부터 · 힌트. 버튼은 signal로만 알린다.
=======
## 튜토리얼 판의 블럭 모으기 막대: 이름 · 판 번호 · 수 / 최소 수, 되돌리기 · 처음부터 · 힌트. 버튼은 signal로만 알린다.
>>>>>>> Choi

signal undo_pressed
signal reset_pressed
signal hint_pressed

@onready var _name: Label = %BarName
@onready var _count: Label = %BarCount
@onready var _undo: Button = %BarUndo
@onready var _reset: Button = %BarReset
@onready var _hint: Button = %BarHint


func _ready() -> void:
	visible = false


## runner의 지금 상태로 다시 그린다. quick 퍼즐은 힌트 버튼이 없다.
func show_runner(runner: PuzzleRunner, label: String, sub: String) -> void:
	var puzzle: BlockPuzzle = runner.puzzle
	visible = true
<<<<<<< HEAD
	_name.text = sub if label.is_empty() else label + (" / " + sub if not sub.is_empty() else "")
=======
	_name.text = sub if label.is_empty() else label + (" · " + sub if not sub.is_empty() else "")
>>>>>>> Choi
	_name.visible = not _name.text.is_empty()
	_count.text = "%d / %d수" % [runner.shown_moves(), puzzle.min_moves]
	var playing: bool = runner.is_playing()
	_undo.disabled = not playing or not puzzle.can_undo()
	_reset.disabled = not playing or puzzle.moves.is_empty()
	_hint.visible = not runner.quick
	_hint.disabled = not playing or puzzle.hint >= BlockPuzzle.Hint.ARROW


func _on_undo_pressed() -> void:
	undo_pressed.emit()


func _on_reset_pressed() -> void:
	reset_pressed.emit()


func _on_hint_pressed() -> void:
	hint_pressed.emit()
