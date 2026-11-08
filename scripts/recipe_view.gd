class_name RecipeView
extends PanelContainer
## 족보 1개 표시 (D9, HTML .rc.tint): 카드 바탕·테두리를 다음에 깰 색으로 은은하게 물들이고, 칸마다 색 순서를 문양과 함께
## 왼쪽부터 보여 준다. 아직 안 깬 칸은 어둡게, 깬 칸은 또렷하게, 다음 칸만 흰 고리로 강조. 아래 줄은 "+점수". 로직(RecipeSet)을 읽기만 한다.
## 캐릭터 카드에도 쓴다 (is_ability: 캐릭터 색 테두리, 둘째 줄은 상태 문구 또는 능력 이름).
## 연출 (HTML, E32): 칸이 채워지면 그 점이 커지며 번쩍(dotHit), 완성되면 카드가 번쩍이며 작아져 빠지고(cardBreak) 새 카드가
## 위에서 내려온다(cardIn). 효과 줄이기면 바로 바꾼다. 수치는 BoardTheme Recipe 그룹.

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
## 마지막으로 그린 족보의 칸별 완료 여부 (같은 족보에서 새로 채워진 칸만 dotHit).
var _done_flags: Array[bool] = []
## 효과 줄이기 (연출 없이 바로 바꾼다).
var _reduce_motion: bool = false
## 완성 연출 중: 새 족보는 연출이 끝난 뒤 그린다 (그 사이에 온 것은 가장 마지막 것만).
var _breaking: bool = false
var _pending: RecipeSet.Recipe
var _card_tween: Tween

@onready var _steps: HBoxContainer = %Steps
@onready var _points_label: Label = %PointsLabel


func _ready() -> void:
	_panel_style = StyleBoxFlat.new()
	_panel_style.set_corner_radius_all(theme_data.recipe_card_radius)
	_panel_style.set_content_margin_all(18)
	_panel_style.bg_color = theme_data.recipe_card_bg
	_panel_style.set_border_width_all(theme_data.ability_border_width if is_ability else theme_data.recipe_card_border)
	_panel_style.border_color = _border_color if is_ability else theme_data.recipe_card_bg
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


## 효과 줄이기 (칸 번쩍임·카드 깨짐·등장 연출을 끈다).
func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled


## 완성 연출 중인지 (테스트/디버그용).
func is_breaking() -> bool:
	return _breaking


## 지금 보이는 족보의 색 (완성 파편 색, 깨지기 전 족보).
func shown_colors() -> PackedInt32Array:
	return _recipe.colors if _recipe != null else PackedInt32Array()


## 족보 완성: 지금 카드가 번쩍이며 깨진 뒤 next를 그리고 위에서 내려오게 한다 (HTML breakCard → cardBreak → cardIn).
func break_and_replace(next: RecipeSet.Recipe) -> void:
	if _reduce_motion or _recipe == null or not is_visible_in_tree():
		_stop_card_tween()
		show_recipe(next, _caption)
		return
	_stop_card_tween()
	_pending = next
	_breaking = true
	_mark_all_done()
	var home_y: float = position.y
	pivot_offset = size / 2.0
	var b0: float = theme_data.card_break_brightness
	var b1: float = theme_data.card_break_end_brightness
	# HTML cardBreak: 30%에 커지며 밝아지고, 끝에 작아지며 위로·더 밝게. 투명은 30%에 적지 않아 처음부터 끝까지 한 구간.
	var frames: Array = [
		[0.0, {"scale": Vector2.ONE, "modulate:r": 1.0, "modulate:g": 1.0, "modulate:b": 1.0, "modulate:a": 1.0, "position:y": home_y}],
		[0.3, {"scale": Vector2.ONE * theme_data.card_break_peak_scale, "modulate:r": b0, "modulate:g": b0, "modulate:b": b0,
			"position:y": home_y}],
		[1.0, {"scale": Vector2.ONE * theme_data.card_break_end_scale, "modulate:r": b1, "modulate:g": b1, "modulate:b": b1,
			"modulate:a": 0.0, "position:y": home_y - theme_data.card_break_rise}],
	]
	_card_tween = create_tween()
	_card_tween.tween_interval(theme_data.card_break_delay)
	_card_tween.tween_method(func(t: float) -> void: KeyframeAnim.apply(self, frames, t, KeyframeAnim.EASE_IN),
		0.0, 1.0, theme_data.card_break_duration)
	_card_tween.tween_callback(_finish_break.bind(home_y))


## 새 카드가 위에서 내려온다 (HTML cardIn: 새 판 시작·완성 뒤).
func play_enter() -> void:
	if _reduce_motion or not is_visible_in_tree():
		return
	_stop_card_tween()
	_enter_from(position.y)


## caption이 비어 있으면 족보 점수를 표시한다.
func show_recipe(recipe: RecipeSet.Recipe, caption: String = "") -> void:
	if _breaking:  # 깨지는 중: 끝나면 가장 마지막 족보를 그린다
		_pending = recipe
		_caption = caption
		return
	var same: bool = recipe == _recipe
	_recipe = recipe
	if not is_ability:
		var tint: Color = theme_data.display_color(recipe.next_color(), _display)
		_panel_style.bg_color = theme_data.recipe_card_bg.lerp(tint, theme_data.recipe_tint)
		_panel_style.border_color = theme_data.recipe_card_bg.lerp(tint, theme_data.recipe_border_tint)
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
		var alpha: float = theme_data.recipe_done_alpha if recipe.is_step_done(i) else (1.0 if i == next else theme_data.recipe_pending_alpha)
		color.a *= alpha
		glyph_color.a *= alpha
		style.bg_color = color
		_step_glyphs[slot_index].set_glyph(theme_data.glyph_for(recipe.colors[i]), glyph_color)
		var art: Texture2D = theme_data.block_art(recipe.colors[i], _display)
		_step_arts[slot_index].texture = art
		_step_arts[slot_index].visible = art != null
		_step_arts[slot_index].modulate.a = alpha
		if art != null:  # 이미지에 색·문양이 다 있다 (테두리는 다음 칸 표시로 남긴다)
			style.bg_color = Color.TRANSPARENT
			_step_glyphs[slot_index].set_glyph(GlyphView.Shape.NONE, glyph_color)
		_set_ring(style, i == next)
	_hit_new_steps(recipe, same)


## 능력 발동 연출 (캐릭터 카드).
func play_complete() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * theme_data.recipe_complete_pop_scale
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 현재 칸 크기 (테스트/디버그용).
func step_size() -> float:
	return _step_size


## 같은 족보에서 새로 채워진 칸만 커지며 번쩍인다 (HTML dotHit).
func _hit_new_steps(recipe: RecipeSet.Recipe, same: bool) -> void:
	var flags: Array[bool] = []
	for i: int in recipe.length():
		flags.append(recipe.is_step_done(i))
	if same and not _reduce_motion and _done_flags.size() == flags.size():
		for i: int in flags.size():
			if flags[i] and not _done_flags[i]:
				_hit_step(_display_index(recipe, i))
	_done_flags = flags


## 족보 칸 i가 화면에서 몇 번째 칸인지 (거울세계는 거꾸로).
func _display_index(recipe: RecipeSet.Recipe, i: int) -> int:
	return recipe.length() - 1 - i if _display != null and _display.reversed_recipes else i


func _hit_step(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _steps_list.size():
		return
	var step: Panel = _steps_list[slot_index]
	step.pivot_offset = step.size / 2.0
	var b: float = theme_data.dot_hit_brightness
	var frames: Array = [
		[0.0, {"scale": Vector2.ONE * theme_data.dot_hit_scale, "modulate": Color(b, b, b, 1.0)}],
		[1.0, {"scale": Vector2.ONE, "modulate": Color.WHITE}],
	]
	KeyframeAnim.play(step, step, theme_data.dot_hit_duration, frames, theme_data.dot_hit_curve)


## 완성: 모든 칸을 채운 모양으로 바꾸고 함께 번쩍인다 (HTML: 점 전부 'got hit').
func _mark_all_done() -> void:
	for slot_index: int in _steps_list.size():
		var style: StyleBoxFlat = _step_styles[slot_index]
		style.bg_color.a = 1.0 if not _step_arts[slot_index].visible else 0.0
		_step_arts[slot_index].modulate.a = 1.0
		var glyph_color: Color = theme_data.glyph_color
		_step_glyphs[slot_index].set_glyph(_step_glyphs[slot_index].shape, glyph_color)
		_set_ring(style, false)
		_hit_step(slot_index)


func _finish_break(home_y: float) -> void:
	_breaking = false
	scale = Vector2.ONE
	modulate = Color.WHITE
	if _pending != null:
		var next: RecipeSet.Recipe = _pending
		_pending = null
		show_recipe(next, _caption)
	_enter_from(home_y)


func _enter_from(home_y: float) -> void:
	pivot_offset = size / 2.0
	var frames: Array = [
		[0.0, {"position:y": home_y - theme_data.card_enter_drop, "scale": Vector2.ONE * theme_data.card_enter_scale, "modulate:a": 0.0}],
		[1.0, {"position:y": home_y, "scale": Vector2.ONE, "modulate:a": 1.0}],
	]
	_card_tween = KeyframeAnim.play(self, self, theme_data.card_enter_duration, frames, theme_data.card_enter_curve)
	_card_tween.finished.connect(_settle)


## 연출이 끝나면 컨테이너가 자리를 다시 잡게 한다.
func _settle() -> void:
	scale = Vector2.ONE
	modulate = Color.WHITE
	var parent: Container = get_parent() as Container
	if parent != null:
		parent.queue_sort()


func _stop_card_tween() -> void:
	if _card_tween != null and _card_tween.is_valid():
		_card_tween.kill()
	_card_tween = null
	if _breaking:
		_breaking = false
		if _pending != null:
			var next: RecipeSet.Recipe = _pending
			_pending = null
			show_recipe(next, _caption)
	_settle()


func _refresh_caption() -> void:
	if not _status.is_empty():
		_points_label.text = _status
	elif not _caption.is_empty():
		_points_label.text = _caption
	else:
		_points_label.text = "+%d" % _points


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


## 다음 칸: 칸 바깥으로 흰 고리 (HTML box-shadow 0 0 0 3px).
func _set_ring(style: StyleBoxFlat, on: bool) -> void:
	var ring: int = theme_data.recipe_next_ring if on else 0
	style.set_border_width_all(ring)
	style.set_expand_margin_all(ring)
	style.border_color = theme_data.recipe_next_border


func _apply_step_size(step: Panel, glyph: GlyphView) -> void:
	step.custom_minimum_size = Vector2.ONE * _step_size
	var style: StyleBoxFlat = step.get_theme_stylebox(&"panel") as StyleBoxFlat
	if style != null:
		style.set_corner_radius_all(int(_step_size * 0.2))
	var inset: float = _step_size * 0.25
	glyph.offset_left = inset
	glyph.offset_top = inset
	glyph.offset_right = -inset
	glyph.offset_bottom = -inset
