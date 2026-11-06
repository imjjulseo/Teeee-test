class_name LevelRewardRow
extends PanelContainer
## 레벨 보상 화면의 한 줄: "Lv N", 그 레벨 보상 목록, 다음 레벨이면 경험치 바.
## 상태(이미 받음 / 지금 레벨 / 다음 레벨 / 아직)에 따라 밝기·테두리만 바꾼다.

enum State { REACHED, CURRENT, NEXT, AHEAD }

## 상태별 테두리 색과 글자 밝기.
const BORDER_COLORS: Array[Color] = [Color(1, 1, 1, 0.1), Color(0.560784, 0.890196, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.08)]
const TEXT_ALPHA: PackedFloat32Array = [0.55, 1.0, 1.0, 0.75]

var level: int = 0
var state: State = State.AHEAD

@onready var _level_label: Label = %LevelLabel
@onready var _rewards_label: Label = %RewardsLabel
@onready var _state_label: Label = %StateLabel
@onready var _exp_bar: Control = %ExpBar
@onready var _exp_fill: ColorRect = %ExpFill


## exp_ratio는 다음 레벨 줄에서만 쓴다 (지금 레벨에서 모은 경험치 비율).
func show_level(p_level: int, rewards: PackedStringArray, p_state: State, exp_ratio: float) -> void:
	level = p_level
	state = p_state
	_level_label.text = "Lv %d" % level
	_rewards_label.text = "\n".join(rewards) if not rewards.is_empty() else "—"
	_state_label.text = LevelRewardRow.state_text(state)
	_exp_bar.visible = state == State.NEXT
	_exp_fill.anchor_right = clampf(exp_ratio, 0.0, 1.0)
	modulate.a = TEXT_ALPHA[state]
	var box: StyleBox = get_theme_stylebox("panel")
	if box is StyleBoxFlat:  # 상태 색 테두리 (이미지 판넬이면 그대로)
		var style: StyleBoxFlat = box.duplicate() as StyleBoxFlat
		style.border_color = BORDER_COLORS[state]
		add_theme_stylebox_override("panel", style)


static func state_text(p_state: State) -> String:
	match p_state:
		State.REACHED:
			return "받음"
		State.CURRENT:
			return "지금"
		State.NEXT:
			return "다음"
	return ""


## level 줄의 상태 (current = 지금 계정 레벨).
static func state_for(p_level: int, current: int) -> State:
	if p_level < current:
		return State.REACHED
	if p_level == current:
		return State.CURRENT
	return State.NEXT if p_level == current + 1 else State.AHEAD


## 보이는 보상 문구 (테스트/디버그용).
func rewards_text() -> String:
	return _rewards_label.text
