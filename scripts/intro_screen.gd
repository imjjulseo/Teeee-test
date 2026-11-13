class_name IntroScreen
extends Control
<<<<<<< HEAD
## 인트로 (기획서 8.1장): 로고와 "화면을 눌러 시작". 화면 어디를 눌러도, 아무 키나 눌러도 start_requested.
=======
## 인트로 (기획서 8.1장): 로고와 "탭하여 시작". 화면 어디를 눌러도, 아무 키나 눌러도 start_requested.
>>>>>>> Choi
## 씬 전환은 intro.tscn에서 SceneNavigator에 연결한다.

signal start_requested

## 로고 이미지 자리 (UiAssets.logo, 없으면 글자 로고).
@export var ui_assets: UiAssets

<<<<<<< HEAD
## "화면을 눌러 시작"이 숨 쉬듯 흐려졌다 돌아오는 주기(초, HTML breathe 1.8초 · 50%에 0.35)와 로고가 살짝 줄었다 커지는 주기(HTML bob 2.4초 · 0.86배).
=======
## "탭하여 시작"이 숨 쉬듯 흐려졌다 돌아오는 주기(초, HTML breathe 1.8초 · 50%에 0.35)와 로고가 살짝 줄었다 커지는 주기(HTML bob 2.4초 · 0.86배).
>>>>>>> Choi
@export var breathe_period: float = 1.8
@export var breathe_alpha: float = 0.35
@export var bob_period: float = 2.4
## (HTML은 로고 칸마다 0.86배 — 로고 한 장 전체에는 약하게.)
@export var bob_scale: float = 0.96

var _started: bool = false
var _reduce_motion: bool = false
var _time: float = 0.0


func _ready() -> void:
	var logo: Texture2D = ui_assets.logo if ui_assets != null else null
	(%LogoImage as TextureRect).texture = logo
	(%LogoImage as TextureRect).visible = logo != null
	(%Logo as Label).visible = logo == null
	_reduce_motion = OptionsStore.new().reduce_motion


func _process(delta: float) -> void:
	if _reduce_motion:
		return
	_time += delta
	var tap: Control = %TapLabel
	tap.modulate.a = lerpf(1.0, breathe_alpha, 0.5 - 0.5 * cos(_time / breathe_period * TAU))
	for logo: Control in [%LogoImage, %Logo]:
		logo.pivot_offset = logo.size / 2.0
		logo.scale = Vector2.ONE * lerpf(1.0, bob_scale, 0.5 - 0.5 * cos(_time / bob_period * TAU))


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
