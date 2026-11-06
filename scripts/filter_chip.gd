class_name FilterChip
extends Button
## 캐릭터 화면의 등급 필터 칩 ("전체", "희귀 2/4" …). 눌리면 chosen(grade), grade = ALL이면 전체.
## 선택 표시는 set_selected로만 바꾼다.

signal chosen(grade: int)

const ALL: int = -1

var grade: int = ALL


func setup(p_grade: int, label: String) -> void:
	grade = p_grade
	text = label


func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)


## pressed signal (filter_chip.tscn에서 연결).
func _on_pressed() -> void:
	chosen.emit(grade)
