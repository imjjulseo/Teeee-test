class_name GachaChest
extends Button
## 뽑기 상자 (기획서 8.5장 연출): 누르면 pressed (뽑기는 ShopScreen이 한다). play_open은 결과의 최고 등급 색으로
## 흔들리며 빛나다가 뚜껑이 열리고 opened를 보낸다. 시간은 BoardTheme, 효과 줄이기면 0초로 바로 열린다.
## 연출일 뿐 결과는 이미 정해져 있다.
## 상자 이미지(BoardTheme.chest_closed_texture · chest_open_texture)가 있으면 판넬 그림(몸통·뚜껑·자물쇠) 대신 그 이미지를 쓰고,
## 열리는 순간 열린 이미지로 바꾼다. 빛(Glow)은 그대로 쓴다.

signal opened

## 흔들림 반 번(초)과 각도(라디안), 열릴 때 커지는 비율 (HTML chestShake 0.09초 · ±2°).
@export var wiggle_step: float = 0.045
@export var wiggle_angle: float = 0.035
## 기다리는 동안 둥실거림 (HTML chestBob 2.6초 · 5 CSS px)과 자물쇠 반짝임 (HTML lockGlint 밝기 1.35).
@export var bob_period: float = 2.6
@export var bob_height: float = 13.0
@export var lock_glint: float = 1.35
@export var open_scale: float = 1.15
## 상자 이미지 자리 (Art 그룹).
@export var theme_data: BoardTheme

var _tween: Tween
var _idle_time: float = 0.0
## 지금 그림 부품에 더해 둔 둥실 높이 (다음 프레임에 차이만큼 옮긴다).
var _bob_applied: float = 0.0
## 효과 줄이기 (화면이 열릴 때 읽는다).
var _reduce_motion: bool = false

@onready var _lid: Control = %Lid
@onready var _glow: Panel = %Glow
@onready var _art: TextureRect = %Art
@onready var _rays: ChestRays = %Rays
@onready var _lock: Panel = $Lock


func _ready() -> void:
	_reduce_motion = OptionsStore.new().reduce_motion
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
	_rays.visible = false
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
		_rays.show_rays(color, false)
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
	_tween.parallel().tween_callback(_rays.show_rays.bind(color, true))
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


## 기다리는 동안(누를 수 있을 때): 둥실거리고 자물쇠가 반짝인다. 효과 줄이기면 멈춘다.
func _process(delta: float) -> void:
	var idle: bool = not disabled and not _reduce_motion
	var wave: float = 0.0
	if idle:
		_idle_time = fmod(_idle_time + delta, bob_period)
		wave = 0.5 - 0.5 * cos(_idle_time / bob_period * TAU)  # 0 → 1(50%) → 0, ease-in-out에 가깝게
	_set_bob(-bob_height * wave)
	var glint: float = lerpf(1.0, lock_glint, wave)
	_lock.modulate = Color(glint, glint, glint, 1.0)


func _set_bob(offset: float) -> void:
	var change: float = offset - _bob_applied
	if is_zero_approx(change):
		return
	_bob_applied = offset
	for part: Control in [$Body, $LidAnchor, $Lock, _art]:
		part.offset_top += change
		part.offset_bottom += change


func _center_pivot() -> void:
	pivot_offset = size / 2.0
