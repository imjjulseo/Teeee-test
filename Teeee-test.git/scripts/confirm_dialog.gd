class_name ConfirmDialog
extends Control
## 정말 할지 묻는 창 (상점의 합성·구매·선택권 사용, E37). 무엇을 물을지는 부르는 쪽이 정하고, 받아들이면 accepted로만 알린다.

signal accepted

@onready var _message: Label = %Message
@onready var _accept_button: Button = %AcceptButton
@onready var _card: Control = %Card


func _ready() -> void:
	visible = false


func ask(message: String, accept_text: String) -> void:
	_message.text = message
	_accept_button.text = accept_text
	visible = true
	OverlayIn.play(_card)


## 보이는 질문 (테스트/디버그용).
func message() -> String:
	return _message.text


func _on_accept_button_pressed() -> void:
	visible = false
	accepted.emit()


func _on_cancel_button_pressed() -> void:
	visible = false
