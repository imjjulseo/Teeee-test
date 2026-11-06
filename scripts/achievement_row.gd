class_name AchievementRow
extends PanelContainer
## 업적 한 단계 줄 (업적 화면·캐릭터 상세 시트): 이름, 조건, 진행 "3 / 8" 또는 "달성", 진행 바, 보상.
## 잠긴 단계(앞 단계 전)는 흐리게 "앞 단계를 먼저". 히든 업적은 조건을 숨긴다.

@export var locked_alpha: float = 0.45
@export var done_color: Color = Color("6fbf5b")

@onready var _name_label: Label = %AchName
@onready var _text_label: Label = %AchText
@onready var _value_label: Label = %AchValue
@onready var _reward_label: Label = %AchReward
@onready var _bar: Control = %AchBar
@onready var _fill: ColorRect = %AchFill


func show_status(status: AchievementTracker.TierStatus) -> void:
	_name_label.text = status.name
	_text_label.text = status.text
	_reward_label.text = status.reward
	_bar.visible = not status.done and status.open
	_fill.anchor_right = clampf(float(status.value) / maxi(status.goal, 1), 0.0, 1.0)
	if status.done:
		_value_label.text = "달성"
		_value_label.add_theme_color_override("font_color", done_color)
	elif not status.open:
		_value_label.text = "앞 단계를 먼저"
	else:
		_value_label.text = "%s / %s" % [AchievementTracker.format_count(status.value), AchievementTracker.format_count(status.goal)]
	modulate.a = 1.0 if status.open or status.done else locked_alpha


## 히든 업적: 이름·조건을 숨긴다.
func show_hidden(reward: String) -> void:
	_name_label.text = "???"
	_text_label.text = "조건은 비밀 · 달성하면 히든 캐릭터를 얻어요"
	_reward_label.text = reward
	_value_label.text = ""
	_bar.visible = false


func shown_name() -> String:
	return _name_label.text


func shown_value() -> String:
	return _value_label.text
