class_name GachaChest
extends Button
## 뽑기 상자 (기획서 8.5장 연출): 누르면 pressed (뽑기는 ShopScreen이 한다). play_open은 결과의 최고 등급 색으로
## 흔들리며 빛나다가 뚜껑이 열리고 opened를 보낸다. 시간은 BoardTheme, 효과 줄이기면 0초로 바로 열린다.
## 연출일 뿐 결과는 이미 정해져 있다.
## 상자 이미지(BoardTheme.chest_closed_texture · chest_open_texture)가 있으면 판넬 그림(몸통·뚜껑·자물쇠) 대신 그 이미지를 쓰고,
## 열리는 순간 열린 이미지로 바꾼다. 빛(Glow)은 그대로 쓴다.

signal opened

## 흔들림 한 번(초)과 각도(라디안), 열릴 때 커지는 비율.
@export var wiggle_step: float = 0.06
@export var wiggle_angle: float = 0.09
@export var open_scale: float = 1.15
## 상자 이미지 자리 (Art 그룹).
@export var theme_data: BoardTheme

var _tween: Tween

@onready var _lid: Control = %Lid
@onready var _glow: Panel = %Glow
@onready var _art: TextureRect = %Art


func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	reset()


## 다시 누를 수 있는 처음 모습으로.
func reset() -> void:
	if _tween != null:
		_tween.kill()
	rotation = 0.0
	scale = Vector2.ONE
	_lid.position.y = 0.0
	_glow.modulate = Color(1, 1, 1, 0)
	disabled = false
	_show_art(false)


## color = 최고 등급 색, charge = 흔들리는 시간, open_time = 열린 뒤 opened까지.
func play_open(color: Color, charge: float, open_time: float) -> void:
	disabled = true
	if _tween != null:
		_tween.kill()
	_glow.self_modulate = color
	if charge <= 0.0 and open_time <= 0.0:
		_glow.modulate.a = 1.0
		_show_art(true)
		opened.emit()
		return
	_tween = create_tween()
	_tween.tween_property(_glow, "modulate:a", 1.0, maxf(charge, 0.01))
	var wiggles: int = int(charge / wiggle_step)
	var shake: Tween = create_tween()
	for i: int in wiggles:
		shake.tween_property(self, "rotation", wiggle_angle * (1.0 if i % 2 == 0 else -1.0) * (0.5 + 0.5 * float(i) / maxi(wiggles, 1)), wiggle_step)
	shake.tween_property(self, "rotation", 0.0, wiggle_step)
	_tween.tween_property(self, "scale", Vector2.ONE * open_scale, 0.12)
	_tween.parallel().tween_property(_lid, "position:y", -_lid.size.y * 0.8, 0.12)
	_tween.parallel().tween_callback(_show_art.bind(true))
	_tween.tween_interval(open_time)
	_tween.tween_callback(opened.emit)


## 상자 이미지를 쓰는지 (테스트/디버그용).
func uses_art() -> bool:
	return _art.visible


## 이미지가 있으면 그 모습(닫힘/열림)을 보이고 판넬 그림을 숨긴다.
func _show_art(open: bool) -> void:
	var texture: Texture2D = null
	if theme_data != null:
		texture = theme_data.chest_open_texture if open and theme_data.chest_open_texture != null else theme_data.chest_closed_texture
	_art.texture = texture
	_art.visible = texture != null
	for part: CanvasItem in [$Body, $LidAnchor, $Lock]:
		part.visible = texture == null


func _center_pivot() -> void:
	pivot_offset = size / 2.0
