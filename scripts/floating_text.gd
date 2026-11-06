class_name FloatingText
extends Label
## 떠올랐다 사라지는 짧은 숫자·문구 ("+2.5", "+10", "금화 2연속!"). 끝나면 스스로 사라진다 (기획서 7.2장).


## at(부모 기준 위치) 가운데에 text를 띄워 rise만큼 올리며 duration초 동안 사라지게 한다.
func rise(text_value: String, color: Color, at: Vector2, rise_distance: float, duration: float) -> void:
	text = text_value
	add_theme_color_override("font_color", color)
	reset_size()
	position = at - size / 2.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - rise_distance, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
