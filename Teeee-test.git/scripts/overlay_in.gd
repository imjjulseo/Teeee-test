class_name OverlayIn
extends RefCounted
## 결과·일시정지·부활·퍼즐 결과·뽑기 결과 카드가 나타나는 연출 (HTML ovgIn 0.5초 cubic-bezier(.2,.9,.3,1.3): 0.85배·투명 → 원래).
## 효과 줄이기면 바로 보인다. 수치는 BoardTheme Overlay 그룹(없으면 HTML 값).

const DURATION: float = 0.5
const START_SCALE: float = 0.85
const CURVE: Vector4 = Vector4(0.2, 0.9, 0.3, 1.3)


## card를 가운데 기준으로 커지며 나타나게 한다.
static func play(card: Control, reduce_motion: bool = false) -> void:
	if card == null:
		return
	if reduce_motion or not card.is_inside_tree() or OptionsStore.new().reduce_motion:
		card.scale = Vector2.ONE
		card.modulate.a = 1.0
		return
	card.pivot_offset = card.size / 2.0
	KeyframeAnim.play(card, card, DURATION, [
		[0.0, {"scale": Vector2.ONE * START_SCALE, "modulate:a": 0.0}],
		[1.0, {"scale": Vector2.ONE, "modulate:a": 1.0}],
	], CURVE)
