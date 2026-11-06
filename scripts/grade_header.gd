class_name GradeHeader
extends Label
## 다이아 상점의 등급 머리줄: "희귀 · ◆ 80" 또는 아직 열리지 않았으면 "영웅 · Lv 8에 열림".

var grade: int = 0


func setup(p_grade: int, grade_color: Color) -> void:
	grade = p_grade
	add_theme_color_override("font_color", grade_color)


func show_shop(open: bool, price: int, open_level: int) -> void:
	var grade_name: String = CharacterData.GRADE_NAMES[grade]
	text = "%s · ◆ %d" % [grade_name, price] if open else "%s · Lv %d에 열림" % [grade_name, open_level]
