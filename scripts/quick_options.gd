class_name QuickOptions
extends VBoxContainer
## 조작 방법, 마스터 볼륨, 효과 줄이기 (기획서 8.1장). 설정 화면(OptionsMenu)과 일시정지 화면(PauseOverlay, E40)이 같이 쓴다.
## 고르면 바로 저장하고(볼륨은 움직이는 동안 소리에만 반영, 손을 뗄 때·닫을 때 저장) signal로 알린다.
## 지금 판에 반영하는 일은 받는 쪽(GameController)이 한다.

signal control_mode_changed(mode: OptionsStore.ControlMode)
signal reduce_motion_changed(enabled: bool)

## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""
## 슬라이더 손잡이 지름, 스위치 크기 (1080×1920 기준 px, 엔진 기본 그림은 너무 작다).
@export var grabber_size: int = 84
@export var switch_size: Vector2i = Vector2i(168, 90)

var _store: OptionsStore
## 저장하지 않은 볼륨 변경이 있음.
var _volume_dirty: bool = false

@onready var _swipe_button: Button = %SwipeButton
@onready var _dpad_button: Button = %DpadButton
@onready var _master_slider: HSlider = %MasterVolumeSlider
@onready var _master_label: Label = %MasterVolumeLabel
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle


func _ready() -> void:
	_draw_controls()
	reload()


## 슬라이더 손잡이와 스위치를 화면 크기에 맞는 그림으로 바꾼다 (색은 디자인 토큰).
func _draw_controls() -> void:
	var on: Color = get_theme_color(&"selected", DesignTokens.THEME_TYPE)
	var off: Color = get_theme_color(&"control_track", DesignTokens.THEME_TYPE)
	var knob: Color = get_theme_color(&"outline", DesignTokens.THEME_TYPE)
	for slot: StringName in [&"grabber", &"grabber_highlight"]:
		_master_slider.add_theme_icon_override(slot, DrawnIcons.disc(grabber_size, knob))
	for slot: StringName in [&"checked", &"checked_disabled"]:
		_reduce_motion_toggle.add_theme_icon_override(slot, DrawnIcons.switch(switch_size, true, on, knob))
	for slot: StringName in [&"unchecked", &"unchecked_disabled"]:
		_reduce_motion_toggle.add_theme_icon_override(slot, DrawnIcons.switch(switch_size, false, off, knob))


func _exit_tree() -> void:
	save_pending()


## 저장된 값을 다시 읽어 보여 준다 (열 때마다: 설정 화면에서 바꾼 값이 있을 수 있다).
func reload() -> void:
	_store = OptionsStore.new(save_path)
	if _swipe_button == null:  # 아직 준비 전 (부모가 먼저 부름): _ready에서 다시 읽는다
		return
	_refresh()


func control_mode() -> OptionsStore.ControlMode:
	return _store.control_mode


## 지금 슬라이더 값 (저장 전일 수 있다).
func master_volume() -> int:
	return _store.master_volume


func reduce_motion() -> bool:
	return _store.reduce_motion


## 아직 저장하지 않은 볼륨을 저장한다 (닫을 때).
func save_pending() -> void:
	if _volume_dirty and _store != null:
		_store.save_master_volume()
		_volume_dirty = false


func _on_swipe_button_pressed() -> void:
	_select(OptionsStore.ControlMode.SWIPE)


func _on_dpad_button_pressed() -> void:
	_select(OptionsStore.ControlMode.DPAD)


func _on_master_volume_changed(value: float) -> void:
	_store.set_master_volume(roundi(value))
	_store.apply_audio()
	_master_label.text = str(_store.master_volume)
	_volume_dirty = true


func _on_master_volume_drag_ended(_value_changed: bool) -> void:
	save_pending()


func _on_reduce_motion_toggled(enabled: bool) -> void:
	_store.set_reduce_motion(enabled)
	_refresh()
	reduce_motion_changed.emit(enabled)


func _select(mode: OptionsStore.ControlMode) -> void:
	var changed: bool = mode != _store.control_mode
	_store.set_control_mode(mode)
	_refresh()
	if changed:
		control_mode_changed.emit(mode)


## 선택 표시는 저장된 값으로만 정한다 (토글 버튼 자체 동작에 맡기지 않음).
func _refresh() -> void:
	_swipe_button.set_pressed_no_signal(_store.control_mode == OptionsStore.ControlMode.SWIPE)
	_dpad_button.set_pressed_no_signal(_store.control_mode == OptionsStore.ControlMode.DPAD)
	_master_slider.set_value_no_signal(_store.master_volume)
	_master_label.text = str(_store.master_volume)
	_reduce_motion_toggle.set_pressed_no_signal(_store.reduce_motion)
