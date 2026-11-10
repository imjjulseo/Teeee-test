class_name CharacterBlockView
extends Panel
## 캐릭터 블럭 그림 하나 (아래 줄 가운데, 메인, 설명창, 상점 카드, 올라오는 연출). 판 위 플레이어와 같은 색 · 테두리에 첫 글자,
## CharacterData.portrait가 있으면 이미지. 얻기 전 히든 캐릭터는 "?"로 가린다.

@export var theme_data: BoardTheme
@export var corner_radius: int = 18
@export var veiled_color: Color = Color(0.2, 0.22, 0.25, 1)
## 첫 글자 색 (바탕이 밝으면 dark, 어두우면 light).
@export var dark_letter: Color = Color(0.0470588, 0.121569, 0.14902, 1)
@export var light_letter: Color = Color(1, 1, 1, 1)


## 주인이 _ready보다 먼저 불러도 되게 자식은 그때그때 찾는다.
func show_character(data: CharacterData, veiled: bool = false) -> void:
	if data == null:
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = veiled_color if veiled else data.player_fill
	style.border_color = style.bg_color if veiled else data.player_border
	style.set_border_width_all(int(theme_data.player_border_width) if theme_data != null else 6)
	style.set_corner_radius_all(corner_radius)
	var portrait: PortraitRect = %Portrait as PortraitRect
	var has_art: bool = portrait.show_character(data, veiled)
	if has_art:
		style.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("panel", style)
	var letter: Label = %Letter as Label
	letter.visible = not has_art
	letter.add_theme_color_override("font_color", dark_letter if style.bg_color.get_luminance() > 0.5 else light_letter)
	letter.text = "?" if veiled else data.display_name.left(1)


func shown_letter() -> String:
	return (%Letter as Label).text
