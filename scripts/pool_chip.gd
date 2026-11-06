class_name PoolChip
extends Panel
## 뽑기 화면의 "나오는 캐릭터" 작은 칩: 캐릭터 색 + 이름 첫 글자, 테두리는 등급 색. 아직 없는 캐릭터는 흐리게.

@export var missing_alpha: float = 0.35

var character: CharacterData

@onready var _letter: Label = %Letter
@onready var _portrait: PortraitRect = %Portrait


func show_character(data: CharacterData, grade_color: Color, owned: bool) -> void:
	character = data
	_letter.text = data.display_name.left(1)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = data.accent_color
	style.border_color = grade_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	if _portrait.show_character(data):  # 이미지가 있으면 첫 글자 대신
		style.bg_color = Color.TRANSPARENT
		_letter.visible = false
	add_theme_stylebox_override("panel", style)
	set_owned(owned)


func set_owned(owned: bool) -> void:
	modulate.a = 1.0 if owned else missing_alpha
