class_name PauseOverlay
extends CanvasLayer
## 일시정지 화면. 공정성을 위해 보드를 완전히 가린다 (기획서 9장).
<<<<<<< HEAD
## 버튼: 계속 / 다시 시작 / 설정 / 메뉴 (E20, E40). signal로만 알린다 (다시 시작·메뉴는 판 포기, 점수 미반영).
## 설정을 누르면 같은 자리에서 QuickOptions(조작·소리·효과 줄이기)로 바뀌고, 바꾼 값은 signal로 알려 지금 판에 바로 반영된다.
=======
## 버튼: 계속 / 다시 시작 / 메뉴 (E20). signal로만 알린다 (다시 시작·메뉴는 판 포기, 점수 미반영).
>>>>>>> Choi

signal resume_requested
signal restart_requested
signal main_menu_requested
<<<<<<< HEAD
## 일시정지 중에 설정을 바꿨다 (GameController가 지금 판에 반영).
signal control_mode_changed(mode: OptionsStore.ControlMode)
signal reduce_motion_changed(enabled: bool)

@onready var _menu: Control = $Center
@onready var _options: Control = %Options
@onready var _quick: QuickOptions = %QuickOptions
=======
>>>>>>> Choi


func _ready() -> void:
	visible = false


<<<<<<< HEAD
## 설정 칸이 열려 있는지 (테스트/디버그용).
func is_options_open() -> bool:
	return _options.visible


=======
>>>>>>> Choi
func _on_state_changed(state: GameFlow.GameState) -> void:
	var was_visible: bool = visible
	visible = state == GameFlow.GameState.PAUSED
	if visible and not was_visible:
<<<<<<< HEAD
		_show_options(false)
		OverlayIn.play(_menu)  # 카드가 커지며 나타남 (HTML ovgIn)
	elif was_visible and not visible:
		_quick.save_pending()
=======
		OverlayIn.play(get_node_or_null("Center") as Control)  # 카드가 커지며 나타남 (HTML ovgIn)
>>>>>>> Choi


func _on_resume_button_pressed() -> void:
	resume_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
<<<<<<< HEAD


func _on_options_button_pressed() -> void:
	_quick.reload()
	_show_options(true)


func _on_back_button_pressed() -> void:
	_quick.save_pending()
	_show_options(false)


func _on_control_mode_changed(mode: OptionsStore.ControlMode) -> void:
	control_mode_changed.emit(mode)


func _on_reduce_motion_changed(enabled: bool) -> void:
	reduce_motion_changed.emit(enabled)


func _show_options(on: bool) -> void:
	_options.visible = on
	_menu.visible = not on
=======
>>>>>>> Choi
