class_name OptionsStore
extends RefCounted
## 옵션 (기획서 8.1장 설정). 저장 파일 입출력은 SaveData가 한다 ([options] control_mode, master_volume, reduce_motion).

enum ControlMode {
	SWIPE,  ## 화면 전체 스와이프 (기본)
	DPAD,  ## 패드 (판 아래 가운데)
}

const SECTION: String = "options"
const KEY_CONTROL_MODE: String = "control_mode"
const KEY_MASTER_VOLUME: String = "master_volume"
const KEY_REDUCE_MOTION: String = "reduce_motion"
## 저장 파일의 문자열 값 ↔ ControlMode.
const CONTROL_MODE_NAMES: Dictionary[ControlMode, String] = {
	ControlMode.SWIPE: "swipe",
	ControlMode.DPAD: "dpad",
}
const MAX_VOLUME: int = 100
const MASTER_BUS: StringName = &"Master"

var path: String
var control_mode: ControlMode = ControlMode.SWIPE
## 마스터 볼륨 0~100. 모든 버스(SFX, BGM)가 Master로 모이므로 게임의 모든 소리에 적용된다.
var master_volume: int = MAX_VOLUME
## 효과 줄이기: 흔들림·파편·떠오르는 숫자를 끈다.
var reduce_motion: bool = false


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	var value: Variant = data.get_value(SECTION, KEY_CONTROL_MODE, "")
	for mode: ControlMode in CONTROL_MODE_NAMES:
		if typeof(value) == TYPE_STRING and value == CONTROL_MODE_NAMES[mode]:
			control_mode = mode
	var volume: Variant = data.get_value(SECTION, KEY_MASTER_VOLUME, MAX_VOLUME)
	if typeof(volume) == TYPE_INT or typeof(volume) == TYPE_FLOAT:
		master_volume = clampi(roundi(volume), 0, MAX_VOLUME)
	var reduce: Variant = data.get_value(SECTION, KEY_REDUCE_MOTION, false)
	reduce_motion = typeof(reduce) == TYPE_BOOL and reduce


func set_control_mode(mode: ControlMode) -> void:
	control_mode = mode
	SaveData.write_value(path, SECTION, KEY_CONTROL_MODE, CONTROL_MODE_NAMES[mode])


func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled
	SaveData.write_value(path, SECTION, KEY_REDUCE_MOTION, enabled)


## 값만 바꾼다 (0~100으로 자름). 저장은 save_master_volume(), 소리 반영은 apply_audio().
func set_master_volume(volume: int) -> void:
	master_volume = clampi(volume, 0, MAX_VOLUME)


func save_master_volume() -> void:
	SaveData.write_value(path, SECTION, KEY_MASTER_VOLUME, master_volume)


## 저장된 오디오 옵션을 오디오 버스에 반영한다.
func apply_audio() -> void:
	apply_master_volume(master_volume)


## 0이면 Master 버스를 음소거, 아니면 볼륨^2 곡선(귀에 고르게 들리도록)으로 dB를 정한다. 50 → 약 -12 dB.
static func apply_master_volume(volume: int) -> void:
	var bus: int = AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0:
		push_warning("OptionsStore: audio bus '%s' not found" % MASTER_BUS)
		return
	AudioServer.set_bus_mute(bus, volume <= 0)
	AudioServer.set_bus_volume_db(bus, volume_to_db(volume))


static func volume_to_db(volume: int) -> float:
	if volume <= 0:
		return -80.0
	var ratio: float = float(mini(volume, MAX_VOLUME)) / MAX_VOLUME
	return linear_to_db(ratio * ratio)
