class_name VirtualDpad
extends CanvasLayer
## 패드 (옵션 조작 방법 = 패드일 때만 표시). 게임 화면 판 아래 가운데 (기획서 3.2장, E8).
## 버튼을 누르는 순간 1칸, 누르고 있으면 pad_repeat_delay초 뒤부터 pad_repeat_interval초마다 반복.
## 반복할 때마다 버튼이 아직 눌려 있는지 확인한다 (손가락이 버튼 밖으로 미끄러지거나 뗀 신호를 놓쳐도 멈춘다).
## 게임 상태를 바꾸지 않고 direction_pressed로만 알린다 (InputRouter가 받음).

signal direction_pressed(dir: Vector2i)
## 버튼을 누르기 시작했다 (누르고 있기, direction_pressed보다 먼저) / 뗐다.
signal direction_held(dir: Vector2i)
signal direction_released

@export var config: GameConfig

## 누르고 있는 방향 (없으면 ZERO).
var _held: Vector2i = Vector2i.ZERO
var _held_button: BaseButton

@onready var _repeat_timer: Timer = $RepeatTimer


func _ready() -> void:
	visible = false


func _on_control_mode_ready(mode: OptionsStore.ControlMode) -> void:
	visible = mode == OptionsStore.ControlMode.DPAD
	release()


## 누르고 있는 방향 (테스트/디버그용).
func held_direction() -> Vector2i:
	return _held


## 버튼을 뗐다 (또는 반복을 멈춘다).
func release() -> void:
	if _held != Vector2i.ZERO:
		direction_released.emit()
	_held = Vector2i.ZERO
	_held_button = null
	if _repeat_timer != null:
		_repeat_timer.stop()


func _press(dir: Vector2i, button: BaseButton) -> void:
	_held = dir
	_held_button = button
	direction_held.emit(dir)
	direction_pressed.emit(dir)
	if _repeat_timer != null and _repeat_timer.is_inside_tree():
		_repeat_timer.start(_settings().pad_repeat_delay)


func _on_repeat_timer_timeout() -> void:
	if _held == Vector2i.ZERO:
		return
	if _held_button != null and not _held_button.is_pressed():
		release()
		return
	direction_pressed.emit(_held)
	_repeat_timer.start(_settings().pad_repeat_interval)


func _settings() -> GameConfig:
	return config if config != null else GameConfig.new()


func _on_up_down() -> void:
	_press(Vector2i.UP, $SafeArea/Content/Pad/Up)


func _on_down_down() -> void:
	_press(Vector2i.DOWN, $SafeArea/Content/Pad/Down)


func _on_left_down() -> void:
	_press(Vector2i.LEFT, $SafeArea/Content/Pad/Left)


func _on_right_down() -> void:
	_press(Vector2i.RIGHT, $SafeArea/Content/Pad/Right)


func _on_button_up() -> void:
	release()
