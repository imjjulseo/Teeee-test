class_name AchievementRow
extends PanelContainer
<<<<<<< HEAD
## 업적 한 단계 줄 (업적 화면, E38 · E42): 이름, 조건, 진행 "3 / 8" 또는 "달성", 진행 바, 보상 칸.
## 보상 칸이 곧 받기 버튼이다: 달성 전에는 흐리고, 달성하면 또렷해져 누르면 받는다 (claim_requested). 받으면 "받음".
## 잠긴 단계(앞 단계 전, 미보유 캐릭터)는 줄 전체가 흐리다. 히든 업적도 같은 줄로 조건을 보여 준다.
=======
## 업적 한 단계 줄 (업적 화면, E38): 이름, 조건, 진행 "3 / 8" 또는 "달성", 진행 바, 보상 미리보기, [받기].
## 달성하면 [받기]가 켜지고, 받으면 "받음"이 된다. 받는 일은 claim_requested로 알린다.
## 잠긴 단계(앞 단계 전)는 흐리게 "앞 단계를 먼저". 히든 업적은 조건을 숨기고 버튼이 없다.
>>>>>>> Choi

signal claim_requested(status: AchievementTracker.TierStatus)

@export var locked_alpha: float = 0.45
<<<<<<< HEAD
## 아직 달성하지 못한 업적의 보상 칸 투명도.
@export var pending_alpha: float = 0.45
=======
>>>>>>> Choi
@export var done_color: Color = Color("6fbf5b")

var status: AchievementTracker.TierStatus

@onready var _name_label: Label = %AchName
@onready var _text_label: Label = %AchText
@onready var _value_label: Label = %AchValue
<<<<<<< HEAD
=======
@onready var _reward_label: Label = %AchReward
>>>>>>> Choi
@onready var _bar: Control = %AchBar
@onready var _fill: ColorRect = %AchFill
@onready var _claim_button: Button = %ClaimButton


func show_status(p_status: AchievementTracker.TierStatus) -> void:
	status = p_status
	_name_label.text = status.name
	_text_label.text = status.text
<<<<<<< HEAD
	_bar.visible = not status.done and status.open
	_fill.anchor_right = clampf(float(status.value) / maxi(status.goal, 1), 0.0, 1.0)
	_show_reward()
=======
	_reward_label.text = status.reward
	_bar.visible = not status.done and status.open
	_fill.anchor_right = clampf(float(status.value) / maxi(status.goal, 1), 0.0, 1.0)
	_claim_button.disabled = not status.can_claim()
	_claim_button.text = "받음" if status.claimed else "받기"
	_claim_button.theme_type_variation = &"HotButton" if status.can_claim() else &""
>>>>>>> Choi
	if status.done:
		_value_label.text = "달성"
		_value_label.add_theme_color_override("font_color", done_color)
	elif not status.open:
<<<<<<< HEAD
		_value_label.text = ""
=======
		_value_label.text = "앞 단계를 먼저"
>>>>>>> Choi
	else:
		_value_label.remove_theme_color_override("font_color")
		_value_label.text = "%s / %s" % [AchievementTracker.format_count(status.value), AchievementTracker.format_count(status.goal)]
	modulate.a = 1.0 if status.open or status.done else locked_alpha


<<<<<<< HEAD
## 보상 칸 = 받기 버튼 (E42): 달성 전에는 흐리게, 달성하면 또렷해지고 누르면 받는다. 받은 뒤에는 "받음".
func _show_reward() -> void:
	var waiting: bool = status.can_claim()
	_claim_button.disabled = not waiting
	_claim_button.text = "받음" if status.claimed else status.reward
	_claim_button.theme_type_variation = &"HotButton" if waiting else &""
	_claim_button.modulate.a = 1.0 if waiting or status.claimed else pending_alpha
	var diamond: bool = status.reward.begins_with("◆") and not status.claimed and not waiting
	if diamond:
		_claim_button.add_theme_color_override("font_disabled_color", get_theme_color(&"diamond", DesignTokens.THEME_TYPE))
	else:
		_claim_button.remove_theme_color_override("font_disabled_color")


## 보상 칸에 보이는 글 (테스트/디버그용).
func shown_reward() -> String:
	return _claim_button.text
=======
## 히든 업적: 이름·조건을 숨긴다.
func show_hidden(reward: String) -> void:
	_name_label.text = "???"
	_text_label.text = "조건은 비밀 · 달성하면 히든 캐릭터를 얻어요"
	_reward_label.text = reward
	_value_label.text = ""
	_bar.visible = false
	_claim_button.visible = false
>>>>>>> Choi


func shown_name() -> String:
	return _name_label.text


func shown_value() -> String:
	return _value_label.text


func can_claim() -> bool:
	return _claim_button.visible and not _claim_button.disabled


func claim_button() -> Button:
	return _claim_button


func _on_claim_button_pressed() -> void:
	claim_requested.emit(status)
