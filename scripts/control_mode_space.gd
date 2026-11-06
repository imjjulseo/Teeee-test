class_name ControlModeSpace
extends Control
## 판 아래 빈 자리 (main.tscn Column/DpadSpace): 패드 모드면 방향키 높이, 스와이프 모드면 설명·안내 줄만큼 (HTML은 판이 화면 폭을 채운다).

@export var pad_height: float = 360.0
@export var swipe_height: float = 200.0


## FlowChannel.control_mode_ready (main.tscn에서 연결).
func _on_control_mode_ready(mode: OptionsStore.ControlMode) -> void:
	custom_minimum_size.y = pad_height if mode == OptionsStore.ControlMode.DPAD else swipe_height
