class_name FloatingText
extends Label
## 떠올랐다 사라지는 짧은 숫자·문구 ("+2.5", "+10", "금화 2연속!", "Great!"). 끝나면 스스로 사라진다 (기획서 7.2장).
## HTML .float와 같은 두 가지 움직임 (E32):
## - rise (0.8초): 작게(0.7) 나타나 1.15배로 튀어 오른 뒤, 제 높이의 1.4배만큼 더 오르며 사라진다.
## - fly (0.75초): 살짝 떠올라(1.3배) 목표(HUD 점수·코인)로 빨려 들어가며 작아진다. 도착하면 arrived.

## fly가 목표에 닿았다 (HTML onArrive: 점수·코인 숫자를 올리고 통통 튄다).
signal arrived

## 키프레임 모양은 HTML 그대로 두고, 시간·글자 크기는 부르는 쪽이 BoardTheme에서 준다.
## HTML rise: ease-out, 0% 위치 -30%·0.7배·투명 → 20% -70%·1.15배 → 100% -170%·1배·투명 (위치는 제 높이 비율).
## HTML fly: cubic-bezier(.55,0,.75,.35).
const FLY_CURVE: Vector4 = Vector4(0.55, 0.0, 0.75, 0.35)


## at(부모 기준 위치)을 기준점으로 text를 띄워 올리며 사라지게 한다. font_size가 0보다 크면 글자 크기.
func rise(text_value: String, color: Color, at: Vector2, font_size: float = 0.0, duration: float = 0.8) -> void:
	_prepare(text_value, color, font_size)
	var h: float = size.y
	var frames: Array = [
		[0.0, {"position": at + Vector2(-size.x / 2.0, -0.3 * h), "scale": Vector2.ONE * 0.7, "modulate:a": 0.0}],
		[0.2, {"position": at + Vector2(-size.x / 2.0, -0.7 * h), "scale": Vector2.ONE * 1.15, "modulate:a": 1.0}],
		[1.0, {"position": at + Vector2(-size.x / 2.0, -1.7 * h), "scale": Vector2.ONE, "modulate:a": 0.0}],
	]
	KeyframeAnim.play(self, self, duration, frames, KeyframeAnim.EASE_OUT).finished.connect(queue_free)


## from(부모 기준)에서 to(부모 기준)로 날아간다. 도착하면 arrived를 보내고 사라진다.
func fly(text_value: String, color: Color, from: Vector2, to: Vector2, font_size: float = 0.0, duration: float = 0.75) -> void:
	_prepare(text_value, color, font_size)
	var half: Vector2 = size / 2.0
	var frames: Array = [
		[0.0, {"position": from - half, "scale": Vector2.ONE * 0.8, "modulate:a": 0.0}],
		[0.22, {"position": from - Vector2(half.x, 1.1 * size.y), "scale": Vector2.ONE * 1.3, "modulate:a": 1.0}],
		[1.0, {"position": to - half, "scale": Vector2.ONE * 0.6, "modulate:a": 0.3}],
	]
	var tween: Tween = KeyframeAnim.play(self, self, duration, frames, FLY_CURVE)
	tween.finished.connect(arrived.emit)
	tween.finished.connect(queue_free)


func _prepare(text_value: String, color: Color, font_size: float) -> void:
	text = text_value
	add_theme_color_override("font_color", color)
	if font_size > 0.0:
		add_theme_font_size_override("font_size", roundi(font_size))
	reset_size()
	size = get_combined_minimum_size()
	pivot_offset = size / 2.0
