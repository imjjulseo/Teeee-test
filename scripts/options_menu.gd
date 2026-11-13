class_name OptionsMenu
extends Control
## 설정 화면 (기획서 8.1장): 한 페이지에 조작 방법·마스터 볼륨·효과 줄이기(QuickOptions, 일시정지 화면과 같은 부품),
## 튜토리얼 다시 보기, 진행 초기화, 디버그.
## - 진행 초기화 (HTML resetMeta): 한 번 누르면 "한 번 더 누르면 초기화"로 바뀌고, reset_confirm_time초 안에 다시 누르면
##   설정만 남기고 진행을 지운 뒤 progress_reset (메뉴로). 그 시간이 지나면 처음 문구로 돌아간다.

## 진행을 초기화했다 (씬에서 메뉴로 가는 SceneNavigator에 연결).
signal progress_reset
## 규칙 튜토리얼을 다시 본다 (씬에서 게임 씬으로 가는 SceneNavigator에 연결).
signal tutorial_replay_requested

const RESET_TEXT: String = "진행 초기화"
const RESET_CONFIRM_TEXT: String = "한 번 더 누르면 초기화"

## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""
## 진행 초기화 버튼을 두 번째로 눌러야 하는 시간(초) (HTML 3초).
@export var reset_confirm_time: float = 3.0

## 진행 초기화: 첫 번째로 누른 뒤 남은 시간 (0 이하 = 대기 안 함).
var _reset_armed_left: float = 0.0

@onready var _quick: QuickOptions = %QuickOptions
@onready var _reset_button: Button = %ResetButton


func _ready() -> void:
	_quick.save_path = save_path
	_quick.reload()
	(%TopBar as TopBar).setup(save_path)
	(%BottomNav as BottomNav).setup(save_path)


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
	_quick.save_pending()
	SaveData.reset_progress(save_path)
	progress_reset.emit()


func control_mode() -> OptionsStore.ControlMode:
	return _quick.control_mode()


func master_volume() -> int:
	return _quick.master_volume()


func reduce_motion() -> bool:
	return _quick.reduce_motion()


## 규칙 튜토리얼 다시 보기: 다음 게임 씬을 튜토리얼 판으로 연다 (기록·보상 없음, 끝나면 메뉴로).
func _on_tutorial_button_pressed() -> void:
	_quick.save_pending()
	PlayRequest.replay_tutorial = true
	tutorial_replay_requested.emit()


## 디버그 패널이 진행을 바꿨다: 위·아래 줄(지갑, 잠금)을 다시 그린다.
func _on_debug_progress_changed() -> void:
	(%TopBar as TopBar).refresh()
	(%BottomNav as BottomNav).refresh()
