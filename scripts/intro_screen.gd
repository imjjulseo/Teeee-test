class_name IntroScreen
extends Control
## 인트로 (기획서 8.1장): 로고와 "탭하여 시작". 화면 어디를 눌러도, 아무 키나 눌러도 start_requested.
## 씬 전환은 intro.tscn에서 SceneNavigator에 연결한다.

signal start_requested

## 로고 이미지 자리 (UiAssets.logo, 없으면 글자 로고).
@export var ui_assets: UiAssets

var _started: bool = false


func _ready() -> void:
	var logo: Texture2D = ui_assets.logo if ui_assets != null else null
	(%LogoImage as TextureRect).texture = logo
	(%LogoImage as TextureRect).visible = logo != null
	(%Logo as Label).visible = logo == null


## 화면 전체를 덮는 버튼 (intro.tscn에서 연결).
func _on_tap_area_pressed() -> void:
	_start()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_start()


## 한 번만 알린다 (탭과 키가 같은 프레임에 들어와도 씬 전환은 한 번).
func _start() -> void:
	if _started:
		return
	_started = true
	start_requested.emit()
