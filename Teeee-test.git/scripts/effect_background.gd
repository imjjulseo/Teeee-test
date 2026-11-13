class_name EffectBackground
extends CanvasLayer
## 능력 배경 효과 (기획서 5.2장 공통 규칙): 지속 효과가 켜져 있으면 판 뒤 화면을 효과 색으로 은은하게 칠하고,
## 끝나기 effect_blink_window초 전부터 점점 빠르게(effect_blink_start_hz → end_hz) 깜빡인다.
## HudChannel.effect_updated만 따른다. 남은 시간이 멈춰 있으면(일시정지) 깜빡임도 멈춘다.

@export var theme_data: BoardTheme

## 효과 남은 시간 (꺼져 있으면 음수, 끝없이 켜져 있으면 INF).
var _remaining: float = -1.0
## 깜빡이기 시작하는 남은 초 (능력이 정함, 음수면 테마 기본).
var _blink_window: float = -1.0
## 지난 프레임에 본 남은 시간 (바뀌었으면 시간이 흐르는 중).
var _seen_remaining: float = -1.0
## 지금 진하기 0~1 (× effect_alpha).
var _level: float = 0.0
var _phase: float = 0.0
## 맥박 주기(초, 0 = 없음)와 그 시계 (뱀파이어 피의 시간: 가장자리가 붉게 진해졌다 옅어짐).
var _pulse_period: float = 0.0
var _pulse_time: float = 0.0
## 효과 줄이기 (맥박을 끈다).
var _reduce_motion: bool = false

@onready var _glow: CanvasItem = $Glow  # TextureRect


func _ready() -> void:
	if theme_data.effect_background_texture != null:  # 디자인 이미지 (없으면 씬의 은은한 원형 그라데이션)
		(_glow as TextureRect).texture = theme_data.effect_background_texture
	_apply_level()


## accent = 캐릭터 색, block_color = 블록 색 ID(현상금, 없으면 NO_COLOR → 캐릭터 색).
func _on_effect_updated(accent: Color, block_color: int, remaining: float, blink_window: float) -> void:
	_remaining = remaining
	_blink_window = blink_window
	if remaining < 0.0:
		return
	var color: Color = theme_data.color_for(block_color) if block_color != Board.NO_COLOR else accent
	_glow.modulate = Color(color.r, color.g, color.b, _glow.modulate.a)


func _on_effect_pulse_changed(period: float) -> void:
	_pulse_period = period
	_pulse_time = 0.0


func _on_reduce_motion_ready(enabled: bool) -> void:
	_reduce_motion = enabled


func _process(delta: float) -> void:
	var window: float = _blink_window if _blink_window >= 0.0 else theme_data.effect_blink_window
	if _remaining >= 0.0 and _remaining < window:
		if _remaining != _seen_remaining:
			var hz: float = lerpf(theme_data.effect_blink_start_hz, theme_data.effect_blink_end_hz, 1.0 - _remaining / window)
			_phase += delta * hz * TAU
		_level = 0.25 + 0.75 * (0.5 + 0.5 * cos(_phase))
	else:
		_phase = 0.0
		var target: float = 1.0 if _remaining >= 0.0 else 0.0
		_level += (target - _level) * minf(1.0, delta * theme_data.effect_fade_speed)
	_seen_remaining = _remaining
	_apply_level()


## 효과가 켜져 있는지 (테스트/디버그용).
func is_effect_on() -> bool:
	return _remaining >= 0.0


## 지금 효과 색 (테스트/디버그용).
func effect_color() -> Color:
	return Color(_glow.modulate.r, _glow.modulate.g, _glow.modulate.b)


func _apply_level() -> void:
	var pulse: float = 1.0
	if _pulse_period > 0.0 and not _reduce_motion:
		_pulse_time = fmod(_pulse_time + get_process_delta_time(), _pulse_period)
		pulse = 1.0 + theme_data.effect_pulse_boost * (0.5 - 0.5 * cos(_pulse_time / _pulse_period * TAU))
	_glow.modulate.a = _level * theme_data.effect_alpha * pulse
