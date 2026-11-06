class_name PauseOverlay
extends CanvasLayer
## 일시정지 화면. 공정성을 위해 보드를 완전히 가린다 (기획서 9장).
## 버튼: 계속 / 다시 시작 / 메뉴 (E20). signal로만 알린다 (다시 시작·메뉴는 판 포기, 점수 미반영).

signal resume_requested
signal restart_requested
signal main_menu_requested


func _ready() -> void:
	visible = false


func _on_state_changed(state: GameFlow.GameState) -> void:
	visible = state == GameFlow.GameState.PAUSED


func _on_resume_button_pressed() -> void:
	resume_requested.emit()


func _on_restart_button_pressed() -> void:
	restart_requested.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
