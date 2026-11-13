class_name PuzzleResultPanel
extends Control
<<<<<<< HEAD
## 블록 모으기 결과 카드 (퍼즐 화면·튜토리얼): 별, 제목, 수·안내, 정답 보기 / 다음(강조) / 다시 하기 · 나가기. 버튼은 signal로만 알린다.
## 퍼즐 화면(with_exit)은 다시 하기와 나가기를 늘 보이고, 튜토리얼은 별 3개가 아닐 때만 다시 하기를 보인다.
=======
## 블럭 모으기 결과 카드 (연습 화면·튜토리얼): 별, 제목, 수·안내, 정답 보기 / 다시 해 보기 / 다음. 버튼은 signal로만 알린다.
>>>>>>> Choi
## 다음 문구가 비어 있으면 "다음" 버튼 대신 화면 아무 곳이나 누르면 다음 (튜토리얼: 다른 설명 칸처럼 탭으로 넘김).

signal replay_pressed
signal retry_pressed
signal next_pressed
<<<<<<< HEAD
signal exit_pressed
=======
>>>>>>> Choi

@onready var _stars: Label = %ResultStars
@onready var _head: Label = %ResultHead
@onready var _detail: Label = %ResultDetail
@onready var _replay_button: Button = %ReplayButton
@onready var _retry_button: Button = %RetryButton
@onready var _next_button: Button = %NextButton
<<<<<<< HEAD
@onready var _exit_button: Button = %ExitButton
=======
>>>>>>> Choi
@onready var _tap_hint: Label = %TapHint


func _ready() -> void:
	visible = false


## note가 있으면 설명 아래 한 줄 더 (첫 클리어 보상).
<<<<<<< HEAD
func show_result(info: PuzzleRunner.ResultInfo, next_text: String, note: String = "", with_exit: bool = false) -> void:
=======
func show_result(info: PuzzleRunner.ResultInfo, next_text: String, note: String = "") -> void:
>>>>>>> Choi
	_stars.text = "★".repeat(info.stars) + "☆".repeat(3 - info.stars)
	_head.text = info.head
	_detail.text = info.detail if note.is_empty() else "%s\n%s" % [info.detail, note]
	_replay_button.visible = info.show_replay
	_replay_button.text = info.replay_text
<<<<<<< HEAD
	_retry_button.visible = info.show_retry or with_exit
	_exit_button.visible = with_exit
	_next_button.text = next_text
	_next_button.visible = not next_text.is_empty()
	_tap_hint.visible = next_text.is_empty() and not with_exit
=======
	_retry_button.visible = info.show_retry
	_next_button.text = next_text
	_next_button.visible = not next_text.is_empty()
	_tap_hint.visible = next_text.is_empty()
>>>>>>> Choi
	visible = true
	_animate_in()


## 화면을 누르면 다음인지 (다음 버튼이 없을 때).
func taps_to_continue() -> bool:
<<<<<<< HEAD
	return visible and not _next_button.visible and not _exit_button.visible
=======
	return visible and not _next_button.visible
>>>>>>> Choi


## 카드가 커지며 나타난다 (HTML ovgIn).
func _animate_in() -> void:
	var card: Control = $Card
	OverlayIn.play(card)


func _on_tap_area_input(event: InputEvent) -> void:
	if not taps_to_continue():
		return
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		get_viewport().set_input_as_handled()
		_on_next_button_pressed()


func _on_replay_button_pressed() -> void:
	visible = false
	replay_pressed.emit()


func _on_retry_button_pressed() -> void:
	visible = false
	retry_pressed.emit()


<<<<<<< HEAD
func _on_exit_button_pressed() -> void:
	visible = false
	exit_pressed.emit()


=======
>>>>>>> Choi
func _on_next_button_pressed() -> void:
	visible = false
	next_pressed.emit()
