class_name AchievementGradeSection
extends VBoxContainer
## 업적 화면 캐릭터 탭의 등급 구역 (E38): 등급 제목 + 그 등급 캐릭터 업적. 업적이 없는 등급(일반 · 히든)은 "준비 중".
## 구역은 achievements.tscn에 등급마다 놓여 있고, 캐릭터 수만 데이터로 정해져 코드에서 인스턴스화한다.

## CharacterData.Grade (achievements.tscn에서 구역마다 정한다).
@export var grade: int = CharacterData.Grade.RARE
## 제목 (비어 있으면 등급 이름).
@export var title: String = ""


func show_title(grade_color: Color) -> void:
	var label: Label = %SectionTitle as Label
	label.text = title if not title.is_empty() else CharacterData.GRADE_NAMES[grade]
	label.add_theme_color_override("font_color", grade_color)


func add_group(group: CharacterChainGroup) -> void:
	(%Groups as Control).add_child(group)


## 그 등급에 캐릭터 업적이 없으면 "준비 중" (만든 뒤 부른다).
func show_preparing_if_empty() -> void:
	(%PreparingLabel as Control).visible = (%Groups as Control).get_child_count() == 0


func is_preparing() -> bool:
	return (%PreparingLabel as Control).visible
