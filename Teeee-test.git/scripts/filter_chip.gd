class_name FilterChip
extends Button
## 캐릭터 화면의 등급 필터 칩 ("전체", "희귀 2/4" …). 눌리면 chosen(grade), grade = ALL이면 전체.
## 선택 표시는 set_selected로만 바꾼다.

signal chosen(grade: int)

const ALL: int = -1

## 씬에서 칩마다 정한다 (CharacterData.Grade, ALL = 전체).
@export var grade: int = ALL


func show_label(label: String) -> void:
	text = label


func set_selected(selected: bool) -> void:
	set_pressed_no_signal(selected)


## pressed signal (filter_chip.tscn에서 연결).
func _on_pressed() -> void:
	chosen.emit(grade)
