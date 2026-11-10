class_name TicketRow
extends HBoxContainer
## 상점 등급 구역의 선택권 한 줄 (E37): "희귀 선택권  n장" + [사용](켜고 끔) + [합성](다음 등급이 없으면 숨김).
## 버튼은 use_toggled / fuse_requested로만 알린다.

signal use_toggled(grade: int)
signal fuse_requested(grade: int)

var grade: int = 0

@onready var _name_label: Label = %TicketName
@onready var _count_label: Label = %TicketCount
@onready var _use_button: Button = %UseButton
@onready var _fuse_button: Button = %FuseButton


## next_grade < 0이면 합성 버튼을 숨긴다.
func setup(p_grade: int, grade_color: Color, next_grade: int) -> void:
	grade = p_grade
	_name_label.text = "%s 선택권" % CharacterData.GRADE_NAMES[grade]
	_name_label.add_theme_color_override("font_color", grade_color)
	_fuse_button.visible = next_grade >= 0


func show_count(count: int, can_fuse: bool, use_on: bool) -> void:
	_count_label.text = "%d장" % count
	_use_button.disabled = count <= 0
	_use_button.set_pressed_no_signal(use_on)
	_fuse_button.disabled = not can_fuse


func count_text() -> String:
	return _count_label.text


func _on_use_button_pressed() -> void:
	use_toggled.emit(grade)


## 합성 버튼 (ticket_row.tscn에서 연결).
func _on_fuse_button_pressed() -> void:
	fuse_requested.emit(grade)
