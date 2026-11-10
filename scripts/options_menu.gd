class_name OptionsMenu
extends Control
## 설정 화면 (기획서 8.1장): 한 페이지에 조작 방법, 마스터 볼륨, 효과 줄이기.
## - 조작 방법(스와이프 / 패드)·효과 줄이기는 고르면 바로 user://에 저장된다.
## - 마스터 볼륨 0~100: 움직이는 동안 바로 소리에 반영하고, 손을 뗄 때(또는 화면을 나갈 때) 저장한다.
## - 진행 초기화 (HTML resetMeta): 한 번 누르면 "한 번 더 누르면 초기화"로 바뀌고, reset_confirm_time초 안에 다시 누르면
##   설정만 남기고 진행을 지운 뒤 progress_reset (메뉴로). 그 시간이 지나면 처음 문구로 돌아간다.

## 진행을 초기화했다 (씬에서 메뉴로 가는 SceneNavigator에 연결).
signal progress_reset

const RESET_TEXT: String = "진행 초기화"
const RESET_CONFIRM_TEXT: String = "한 번 더 누르면 초기화"

## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""
## 진행 초기화 버튼을 두 번째로 눌러야 하는 시간(초) (HTML 3초).
@export var reset_confirm_time: float = 3.0

var _store: OptionsStore
## 저장하지 않은 볼륨 변경이 있음 (슬라이더를 끄는 중, 마우스 휠 등).
var _volume_dirty: bool = false
## 진행 초기화: 첫 번째로 누른 뒤 남은 시간 (0 이하 = 대기 안 함).
var _reset_armed_left: float = 0.0

@onready var _swipe_button: Button = %SwipeButton
@onready var _dpad_button: Button = %DpadButton
@onready var _master_slider: HSlider = %MasterVolumeSlider
@onready var _master_label: Label = %MasterVolumeLabel
@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _reset_button: Button = %ResetButton


func _ready() -> void:
	_store = OptionsStore.new(save_path)
	(%TopBar as TopBar).setup(save_path)
	(%BottomNav as BottomNav).setup(save_path)
	_refresh()


func _exit_tree() -> void:
	_save_volume_if_dirty()


func _process(delta: float) -> void:
	tick(delta)


## 시간이 지남 (진행 초기화 대기). 엔진은 _process로, 테스트는 직접 부른다.
func tick(delta: float) -> void:
	if _reset_armed_left <= 0.0:
		return
	_reset_armed_left -= delta
	if _reset_armed_left <= 0.0:
		_reset_button.text = RESET_TEXT


## 진행 초기화를 한 번 눌러 확인을 기다리는 중인지 (테스트/디버그용).
func is_reset_armed() -> bool:
	return _reset_armed_left > 0.0


func _on_reset_button_pressed() -> void:
	if _reset_armed_left <= 0.0:
		_reset_armed_left = reset_confirm_time
		_reset_button.text = RESET_CONFIRM_TEXT
		return
	_reset_armed_left = 0.0
	_reset_button.text = RESET_TEXT
	_save_volume_if_dirty()
	SaveData.reset_progress(save_path)
	progress_reset.emit()


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
