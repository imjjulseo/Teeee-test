extends "res://tests/framework/test_case.gd"
## 7a 디자인 토큰 (기획서 7.3장, E14): 설계가 토큰과 맞는지, 저장된 테마가 최신인지(tools/build_ui_theme.gd),
## 씬에 팔레트 색이 직접 남지 않았는지, 씬이 쓰는 변형·토큰이 테마에 있는지, TokenRect가 토큰 색을 칠하는지.

## 팔레트가 아닌 색으로 남겨 두는 것: 판 칸 테두리(BoardTheme 영역), 상자 그림, 처음 투명한 연출 시작값, 검은 글자 외곽선.
const ALLOWED_FILES: PackedStringArray = ["cell_view.tscn", "gacha_chest.tscn"]
const ALLOWED_PROPERTIES: PackedStringArray = ["theme_override_colors/font_outline_color", "modulate"]
const ALLOWED_VALUES: PackedStringArray = ["Color(1, 1, 1, 0)"]
const COLOR_PROPERTIES: PackedStringArray = ["color", "bg_color", "border_color", "shadow_color", "modulate",
	"theme_override_colors/font_color", "theme_override_colors/font_outline_color"]


func _tokens() -> DesignTokens:
	return load(UiThemeBuilder.TOKENS_PATH) as DesignTokens


func _spec() -> UiThemeSpec:
	return load(UiThemeBuilder.SPEC_PATH) as UiThemeSpec


func _saved_theme() -> Theme:
	return load(UiThemeBuilder.THEME_PATH) as Theme


## 씬 파일마다 줄 목록.
func _scenes() -> Dictionary[String, PackedStringArray]:
	var scenes: Dictionary[String, PackedStringArray] = {}
	for file: String in DirAccess.get_files_at("res://scenes"):
		if file.ends_with(".tscn"):
			scenes[file] = FileAccess.get_file_as_string("res://scenes/" + file).split("\n")
	return scenes


func test_spec_uses_known_tokens() -> void:
	assert_eq(_spec().validate(_tokens()), PackedStringArray())
	assert_true(_tokens().names().size() >= 20, "tokens listed (%d)" % _tokens().names().size())


func test_saved_theme_is_built_from_the_tokens() -> void:
	var built: Theme = UiThemeBuilder.build(_spec(), _tokens())
	var saved: Theme = _saved_theme()
	var hint: String = " — run: godot --headless --path . -s tools/build_ui_theme.gd"
	assert_eq(saved.default_font, built.default_font, "default font" + hint)
	for token: StringName in _tokens().names():
		assert_eq(saved.get_color(token, DesignTokens.THEME_TYPE), built.get_color(token, DesignTokens.THEME_TYPE), "token %s%s" % [token, hint])
	for variation: StringName in _spec().label_variations:
		assert_eq(saved.get_type_variation_base(variation), &"Label", "%s is a Label variation%s" % [variation, hint])
		assert_eq(saved.get_color(&"font_color", variation), built.get_color(&"font_color", variation), "%s font color%s" % [variation, hint])
	for style: UiStyle in _spec().styles:
		for slot: String in style.slots:
			var saved_box: StyleBox = saved.get_stylebox(slot, style.name)
			var built_box: StyleBox = built.get_stylebox(slot, style.name)
			assert_true(saved_box != null and saved_box.get_class() == built_box.get_class(), "%s/%s saved%s" % [style.name, slot, hint])
			if saved_box is StyleBoxTexture:
				assert_eq((saved_box as StyleBoxTexture).texture, (built_box as StyleBoxTexture).texture, "%s/%s image%s" % [style.name, slot, hint])
				continue
			var a: StyleBoxFlat = saved_box as StyleBoxFlat
			var b: StyleBoxFlat = built_box as StyleBoxFlat
			if a == null:
				continue
			assert_eq([a.bg_color, a.border_color, a.border_width_top, a.corner_radius_top_left, a.content_margin_left, a.content_margin_top],
				[b.bg_color, b.border_color, b.border_width_top, b.corner_radius_top_left, b.content_margin_left, b.content_margin_top],
				"%s/%s%s" % [style.name, slot, hint])

func test_scenes_have_no_palette_colors() -> void:
	var found: PackedStringArray = PackedStringArray()
	var scenes: Dictionary[String, PackedStringArray] = _scenes()
	for file: String in scenes:
		if ALLOWED_FILES.has(file):
			continue
		for line: String in scenes[file]:
			var parts: PackedStringArray = line.split(" = ", false, 1)
			if parts.size() < 2 or not COLOR_PROPERTIES.has(parts[0]) or not parts[1].begins_with("Color("):
				continue
			if ALLOWED_PROPERTIES.has(parts[0]) or ALLOWED_VALUES.has(parts[1]):
				continue
			found.append("%s: %s" % [file, line])
	assert_eq(found, PackedStringArray(), "use a theme variation or TokenRect token instead")


func test_scene_variations_and_tokens_exist() -> void:
	var theme: Theme = _saved_theme()
	var missing: PackedStringArray = PackedStringArray()
	var scenes: Dictionary[String, PackedStringArray] = _scenes()
	for file: String in scenes:
		for line: String in scenes[file]:
			if line.begins_with("theme_type_variation = &\""):
				var variation: StringName = StringName(line.get_slice("\"", 1))
				if theme.get_type_variation_base(variation) == &"":
					missing.append("%s: variation %s" % [file, variation])
			elif line.begins_with("token = &\""):
				var token: StringName = StringName(line.get_slice("\"", 1))
				if not _tokens().has_token(token):
					missing.append("%s: token %s" % [file, token])
	assert_eq(missing, PackedStringArray())


func test_token_rect_paints_the_token_color() -> void:
	var rect: TokenRect = TokenRect.new()
	rect.theme = _saved_theme()
	rect.token = &"info"
	rect.notification(Node.NOTIFICATION_READY)
	assert_eq(rect.color, _tokens().info)
	rect.free()
