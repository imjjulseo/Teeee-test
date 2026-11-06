class_name OptionsMenu
extends Control
## 설정 화면 (기획서 8.1장): 한 페이지에 조작 방법, 마스터 볼륨, 효과 줄이기.
## - 조작 방법(스와이프 / 패드)·효과 줄이기는 고르면 바로 user://에 저장된다.
## - 마스터 볼륨 0~100: 움직이는 동안 바로 소리에 반영하고, 손을 뗄 때(또는 화면을 나갈 때) 저장한다.

## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var _store: OptionsStore
## 저장하지 않은 볼륨 변경이 있음 (슬라이더를 끄는 중, 마우스 휠 등).
var _volume_dirty: bool = false

@onready var _swipe_button: Button = %SwipeButton
@onready var _dpad_button: Button = %DpadButton
@onready var _master_slider: HSlider = %MasterVolumeSlider
@onready var _master_label: Label = %MasterVolumeLabel
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle


func _ready() -> void:
	_store = OptionsStore.new(save_path)
	_refresh()


func _exit_tree() -> void:
	_save_volume_if_dirty()


func control_mode() -> OptionsStore.ControlMode:
	return _store.control_mode


func master_volume() -> int:
	return _store.master_volume


func reduce_motion() -> bool:
	return _store.reduce_motion


func _on_master_volume_changed(value: float) -> void:
	_store.set_master_volume(roundi(value))
	_store.apply_audio()
	_master_label.text = str(_store.master_volume)
	_volume_dirty = true


func _on_master_volume_drag_ended(_value_changed: bool) -> void:
	_save_volume_if_dirty()


func _save_volume_if_dirty() -> void:
	if _volume_dirty and _store != null:
		_store.save_master_volume()
		_volume_dirty = false


func _on_swipe_button_pressed() -> void:
	_select(OptionsStore.ControlMode.SWIPE)


func _on_dpad_button_pressed() -> void:
	_select(OptionsStore.ControlMode.DPAD)


func _on_reduce_motion_toggled(enabled: bool) -> void:
	_store.set_reduce_motion(enabled)
	_refresh()


func _select(mode: OptionsStore.ControlMode) -> void:
	_store.set_control_mode(mode)
	_refresh()


## 선택 표시는 저장된 값으로만 정한다 (토글 버튼 자체 동작에 맡기지 않음).
func _refresh() -> void:
	_swipe_button.set_pressed_no_signal(_store.control_mode == OptionsStore.ControlMode.SWIPE)
	_dpad_button.set_pressed_no_signal(_store.control_mode == OptionsStore.ControlMode.DPAD)
	_master_slider.set_value_no_signal(_store.master_volume)
	_master_label.text = str(_store.master_volume)
	_reduce_motion_toggle.set_pressed_no_signal(_store.reduce_motion)
