class_name RewardRow
extends HBoxContainer
## 결과 화면 보상 목록의 한 줄: 이름 (왼쪽) · 내용 (오른쪽). 예: "레벨 3" · "● 100  ◆ 10".

@onready var _name_label: Label = %RewardNameLabel
@onready var _value_label: Label = %RewardValueLabel


func show_reward(title: String, value: String) -> void:
	_name_label.text = title
	_value_label.text = value


## 지금 보이는 이름·내용 (테스트/디버그용).
func texts() -> PackedStringArray:
	return PackedStringArray([_name_label.text, _value_label.text])
