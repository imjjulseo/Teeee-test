class_name PuzzleResultPanel
extends Control
## 블럭 모으기 결과 카드 (연습 화면·튜토리얼): 별, 제목, 수·안내, 정답 보기 / 다시 해 보기 / 다음. 버튼은 signal로만 알린다.

signal replay_pressed
signal retry_pressed
signal next_pressed

@onready var _stars: Label = %ResultStars
@onready var _head: Label = %ResultHead
@onready var _detail: Label = %ResultDetail
@onready var _replay_button: Button = %ReplayButton
@onready var _retry_button: Button = %RetryButton
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	visible = false


## note가 있으면 설명 아래 한 줄 더 (첫 클리어 보상).
func show_result(info: PuzzleRunner.ResultInfo, next_text: String, note: String = "") -> void:
	_stars.text = "★".repeat(info.stars) + "☆".repeat(3 - info.stars)
	_head.text = info.head
	_detail.text = info.detail if note.is_empty() else "%s\n%s" % [info.detail, note]
	_replay_button.visible = info.show_replay
	_replay_button.text = info.replay_text
	_retry_button.visible = info.show_retry
	_next_button.text = next_text
	visible = true


func _on_replay_button_pressed() -> void:
	visible = false
	replay_pressed.emit()


func _on_retry_button_pressed() -> void:
	visible = false
	retry_pressed.emit()


func _on_next_button_pressed() -> void:
	visible = false
	next_pressed.emit()
