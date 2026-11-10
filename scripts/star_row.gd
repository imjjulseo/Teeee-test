class_name StarRow
extends HBoxContainer
## 별점 3개. UiAssets에 별 이미지가 있으면 이미지, 없으면 글자 ★ ☆.

@export var assets: UiAssets


## stars = 채운 별 수 (0~3).
func show_stars(stars: int) -> void:
	var label: Label = %StarsLabel as Label
	label.text = StarRow.text_of(stars)
	var art: bool = assets != null and assets.star_on != null and assets.star_off != null
	label.visible = not art
	var images: Array[TextureRect] = [%Star0 as TextureRect, %Star1 as TextureRect, %Star2 as TextureRect]
	for i: int in images.size():
		images[i].visible = art
		if art:
			images[i].texture = assets.star_on if i < stars else assets.star_off


func shown_text() -> String:
	return (%StarsLabel as Label).text


## "★★☆"
static func text_of(stars: int) -> String:
	var filled: int = clampi(stars, 0, 3)
	return "★".repeat(filled) + "☆".repeat(3 - filled)
