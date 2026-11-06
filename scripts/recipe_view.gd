class_name RecipeView
extends PanelContainer
## 족보 1개 표시 (D9). 박스 배경 = 다음에 제거해야 하는 색. 칸마다 색 순서를 문양과 함께 보여주고,
## 제거한 칸은 흐리게, 다음 칸은 흰 테두리로 강조한다. 로직(RecipeSet)을 읽기만 한다.
## 캐릭터 카드에도 쓴다 (is_ability: 캐릭터 색 테두리, 둘째 줄은 상태 문구 또는 능력 이름).

## 표시할 족보 슬롯 번호 (RecipeSet.recipes 인덱스). 능력 박스는 사용하지 않음.
@export var slot: int = 0
@export var theme_data: BoardTheme
## 캐릭터 능력 조건 박스로 표시한다.
@export var is_ability: bool = false

var _panel_style: StyleBoxFlat
var _steps_list: Array[Panel] = []
var _step_styles: Array[StyleBoxFlat] = []
var _step_glyphs: Array[GlyphView] = []
## 칸마다 블록 이미지 (BoardTheme.block_textures, 없으면 숨김).
var _step_arts: Array[TextureRect] = []
var _step_size: float = 0.0
## 둘째 줄: 상태 문구가 있으면 상태, 없으면 caption (능력 이름), caption도 없으면 족보 점수.
var _caption: String = ""
var _status: String = ""
var _points: int = 0
var _border_color: Color = Color.WHITE
## 능력의 표시 방식 (색약·레트로, null = 보통)과 마지막으로 보인 족보 (방식이 바뀌면 다시 칠한다).
var _display: DisplayStyle
var _recipe: RecipeSet.Recipe

@onready var _steps: HBoxContainer = %Steps
@onready var _points_label: Label = %PointsLabel


func _ready() -> void:
	_panel_style = StyleBoxFlat.new()
	_panel_style.set_corner_radius_all(10)
	_panel_style.set_content_margin_all(10)
	if is_ability:
		_panel_style.set_border_width_all(theme_data.ability_border_width)
		_panel_style.border_color = _border_color
	add_theme_stylebox_override("panel", _panel_style)
	if _step_size <= 0.0:
		_step_size = theme_data.recipe_step_size


## 족보 칸 크기(px)를 바꾼다. 족보 박스가 4개일 때 작게 한다.
func set_step_size(step_size: float) -> void:
	_step_size = step_size
	for i: int in _steps_list.size():
		_apply_step_size(_steps_list[i], _step_glyphs[i])


## 캐릭터 카드 테두리 색 (캐릭터 색).
func set_border_color(color: Color) -> void:
	_border_color = color
	if _panel_style != null:
		_panel_style.border_color = color


## 캐릭터 카드 둘째 줄 상태 (남은 초·스택). 비어 있으면 능력 이름으로 돌아간다.
func show_status(text: String) -> void:
	_status = text
	_refresh_caption()


## 상시형 캐릭터 카드: 족보 칸 없이 상태 문구(없으면 caption)만.
func show_passive(caption: String) -> void:
	_recipe = null
	_panel_style.bg_color = theme_data.passive_card_color
	_caption = caption
	_ensure_steps(0)
	_steps.visible = false
	_refresh_caption()


## 능력의 표시 방식을 바꾸고 보이던 족보를 다시 칠한다.
func set_display_style(style: DisplayStyle) -> void:
	_display = style
	if _recipe != null:
		show_recipe(_recipe, _caption)


## 지금 둘째 줄에 보이는 문구 (테스트/디버그용).
func caption_text() -> String:
	return _points_label.text


## caption이 비어 있으면 족보 점수를 표시한다.
func show_recipe(recipe: RecipeSet.Recipe, caption: String = "") -> void:
	_recipe = recipe
	_panel_style.bg_color = theme_data.display_color(recipe.next_color(), _display)
	_caption = caption
	_points = recipe.points
	_steps.visible = true
	_refresh_caption()
	_ensure_steps(recipe.length())
	var reversed: bool = _display != null and _display.reversed_recipes
	var next: int = recipe.next_index() if not recipe.is_complete() else -1
	for slot_index: int in recipe.length():
		# 거울세계에서는 칸 순서를 거꾸로 보여 준다 (뒤에서부터 채우는 칸이 왼쪽에 온다).
		var i: int = recipe.length() - 1 - slot_index if reversed else slot_index
		var style: StyleBoxFlat = _step_styles[slot_index]
		var color: Color = theme_data.display_color(recipe.colors[i], _display)
		var glyph_color: Color = theme_data.glyph_color
		if recipe.is_step_done(i):
			color.a = theme_data.recipe_done_alpha
			glyph_color.a *= theme_data.recipe_done_alpha
		style.bg_color = color
		_step_glyphs[slot_index].set_glyph(theme_data.glyph_for(recipe.colors[i]), glyph_color)
		var art: Texture2D = theme_data.block_art(recipe.colors[i], _display)
		_step_arts[slot_index].texture = art
		_step_arts[slot_index].visible = art != null
		_step_arts[slot_index].modulate.a = theme_data.recipe_done_alpha if recipe.is_step_done(i) else 1.0
		if art != null:  # 이미지에 색·문양이 다 있다 (테두리는 다음 칸 표시로 남긴다)
			style.bg_color = Color.TRANSPARENT
			_step_glyphs[slot_index].set_glyph(GlyphView.Shape.NONE, glyph_color)
		style.border_color = theme_data.recipe_next_border if i == next else theme_data.recipe_step_border


## 족보 완성 / 능력 발동 연출.
func play_complete() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * theme_data.recipe_complete_pop_scale
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 현재 칸 크기 (테스트/디버그용).
func step_size() -> float:
	return _step_size


func _refresh_caption() -> void:
	if not _status.is_empty():
		_points_label.text = _status
	elif not _caption.is_empty():
		_points_label.text = _caption
	else:
		_points_label.text = str(_points)


## 족보 길이만큼 칸(Panel)을 맞춘다. 길이는 데이터로 정해지므로 코드에서 만든다.
func _ensure_steps(count: int) -> void:
	if _steps_list.size() == count:
		return
	for step: Panel in _steps_list:
		_steps.remove_child(step)
		step.queue_free()
	_steps_list.clear()
	_step_styles.clear()
	_step_glyphs.clear()
	_step_arts.clear()
	for _i: int in count:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.set_border_width_all(3)
		style.set_corner_radius_all(4)
		var step: Panel = Panel.new()
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step.add_theme_stylebox_override("panel", style)
		var art: TextureRect = TextureRect.new()
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.visible = false
		step.add_child(art)
		var glyph: GlyphView = GlyphView.new()
		glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		step.add_child(glyph)
		_apply_step_size(step, glyph)
		_steps.add_child(step)
		_steps_list.append(step)
		_step_styles.append(style)
		_step_glyphs.append(glyph)
		_step_arts.append(art)


func _apply_step_size(step: Panel, glyph: GlyphView) -> void:
	step.custom_minimum_size = Vector2.ONE * _step_size
	var inset: float = _step_size * 0.25
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
