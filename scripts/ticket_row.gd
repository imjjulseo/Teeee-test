class_name TicketRow
extends HBoxContainer
## 상점 탭의 선택권 한 줄: "희귀 선택권  n장" + 합성 버튼("5장 → 영웅", 다음 등급이 없으면 숨김).
## 합성 버튼은 fuse_requested(grade)로만 알린다.

signal fuse_requested(grade: int)

var grade: int = 0

@onready var _name_label: Label = %TicketName
@onready var _count_label: Label = %TicketCount
@onready var _fuse_button: Button = %FuseButton


## next_grade < 0이면 합성 버튼을 숨긴다.
func setup(p_grade: int, grade_color: Color, next_grade: int, fuse_count: int) -> void:
	grade = p_grade
	_name_label.text = "%s 선택권" % CharacterData.GRADE_NAMES[grade]
	_name_label.add_theme_color_override("font_color", grade_color)
	_fuse_button.visible = next_grade >= 0
	if next_grade >= 0:
		_fuse_button.text = "%d장 → %s" % [fuse_count, CharacterData.GRADE_NAMES[next_grade]]


func show_count(count: int, can_fuse: bool) -> void:
	_count_label.text = "%d장" % count
	_fuse_button.disabled = not can_fuse


func count_text() -> String:
	return _count_label.text


## 합성 버튼 (ticket_row.tscn에서 연결).
func _on_fuse_button_pressed() -> void:
	fuse_requested.emit(grade)
