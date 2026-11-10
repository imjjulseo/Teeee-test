class_name LevelRewardRow
extends HBoxContainer
## 레벨 탑의 한 층 (기획서 8.1장, E38): 왼쪽 "Lv.N", 보상 칸(선택권이 있는 레벨은 큰 칸), 그 아래 기둥(아래 레벨로 이어짐, 경험치만큼 찬다).
## 오른 레벨의 보상 칸을 누르면 받는다 (claim_requested, E36). 상태(지난 / 지금 / 다음 / 아직)에 따라 문구·밝기만 바꾼다.

signal claim_requested(level: int)

enum State { REACHED, CURRENT, NEXT, AHEAD }

## 상태별 밝기.
const TEXT_ALPHA: PackedFloat32Array = [0.55, 1.0, 1.0, 0.75]
## 큰 보상 칸의 최소 높이.
const BIG_NODE_HEIGHT: float = 210.0

var level: int = 0
var state: State = State.AHEAD
var _claimable: bool = false

@onready var _level_label: Label = %LevelLabel
@onready var _rewards_label: Label = %RewardsLabel
@onready var _state_label: Label = %StateLabel
@onready var _claim_label: Label = %ClaimLabel
@onready var _node_button: Button = %NodeButton
@onready var _stem: Control = %Stem
@onready var _stem_fill: Control = %StemFill


## stem_ratio = 아래 레벨로 이어지는 기둥이 찬 비율 (지난 레벨 1, 다음 레벨은 지금 경험치 비율). big = 선택권이 있는 큰 칸.
func show_level(p_level: int, rewards: PackedStringArray, p_state: State, stem_ratio: float, claimable: bool = false, big: bool = false) -> void:
	level = p_level
	state = p_state
	_level_label.text = "Lv.%d" % level
	_rewards_label.text = "\n".join(rewards) if not rewards.is_empty() else "—"
	_stem.visible = level > 1
	_stem_fill.anchor_top = 1.0 - clampf(stem_ratio, 0.0, 1.0)
	if big:
		_node_button.theme_type_variation = &"LevelBigNodeButton"
		_node_button.custom_minimum_size.y = BIG_NODE_HEIGHT
	show_claim(claimable)


## 받을 보상이 있으면 눌러서 받는다.
func show_claim(claimable: bool) -> void:
	_claimable = claimable
	_node_button.disabled = not claimable
	_claim_label.visible = claimable
	_state_label.visible = not claimable and not LevelRewardRow.state_text(state, level).is_empty()
	_state_label.text = LevelRewardRow.state_text(state, level)
	modulate.a = 1.0 if claimable else TEXT_ALPHA[state]


func is_claimable() -> bool:
	return _claimable


## 보상 칸 (스모크가 누른다).
func node_button() -> Button:
	return _node_button


func is_big() -> bool:
	return _node_button.theme_type_variation == &"LevelBigNodeButton"


## 기둥이 찬 비율 (테스트/디버그용).
func stem_ratio() -> float:
	return 1.0 - _stem_fill.anchor_top


func _on_node_button_pressed() -> void:
	claim_requested.emit(level)


## Lv1은 보상이 없어 지난 뒤에도 "받음"이 아니다.
static func state_text(p_state: State, p_level: int = 2) -> String:
	match p_state:
		State.REACHED:
			return "받음" if p_level >= ProgressStore.FIRST_REWARD_LEVEL else ""
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
