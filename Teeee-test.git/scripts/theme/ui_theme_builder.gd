class_name UiThemeBuilder
extends RefCounted
## 프로젝트 테마를 만든다 (기획서 7.3장, E14): DesignTokens(색) + UiThemeSpec(변형 설계) → Theme.
## - 토큰마다 DesignTokens.THEME_TYPE 색 (TokenRect·스크립트가 get_theme_color로 읽는다)
## - 라벨 변형의 font_color, 판넬·버튼·슬라이더 변형의 스타일 (template 복사 + 토큰 색)
## 결과는 tools/build_ui_theme.gd가 resources/ui_theme.tres로 저장한다.

const TOKENS_PATH: String = "res://resources/design_tokens.tres"
const SPEC_PATH: String = "res://resources/ui_theme_spec.tres"
const THEME_PATH: String = "res://resources/ui_theme.tres"


## theme을 비우고 다시 채운다 (저장된 테마의 uid를 지키려고 새로 만들지 않는다).
static func build_into(theme: Theme, spec: UiThemeSpec, tokens: DesignTokens) -> void:
	theme.clear()
	theme.default_font = spec.default_font
	for token: StringName in tokens.names():
		theme.set_color(token, DesignTokens.THEME_TYPE, tokens.color_of(token))
	for variation: StringName in spec.label_variations:
		theme.set_type_variation(variation, &"Label")
		theme.set_color(&"font_color", variation, tokens.color_of(spec.label_variations[variation]))
	for style: UiStyle in spec.styles:
		if style.name != style.base_type:  # 이름이 바탕 타입과 같으면 그 타입 전체의 기본 모양 (모든 Button 등)
			theme.set_type_variation(style.name, style.base_type)
		var box: StyleBox = UiThemeBuilder.style_box(style, tokens)
		for slot: String in style.slots:
			theme.set_stylebox(slot, style.name, box)
		if style.font_token != &"":
			for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color"]:
				theme.set_color(key, style.name, tokens.color_of(style.font_token))


## 모양 하나: 이미지가 있으면 9분할 이미지 판넬, 없으면 template 복사 + 토큰 색.
static func style_box(style: UiStyle, tokens: DesignTokens) -> StyleBox:
	if style.texture != null:
		var image_box: StyleBoxTexture = StyleBoxTexture.new()
		image_box.texture = style.texture
		image_box.texture_margin_left = style.texture_margins.x
		image_box.texture_margin_top = style.texture_margins.y
		image_box.texture_margin_right = style.texture_margins.z
		image_box.texture_margin_bottom = style.texture_margins.w
		for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			image_box.set_content_margin(side, style.template.get_content_margin(side))
		return image_box
	var box: StyleBoxFlat = style.template.duplicate() as StyleBoxFlat
	box.bg_color = tokens.color_of(style.bg_token)
	if style.border_token != &"":
		box.border_color = tokens.color_of(style.border_token)
	return box


static func build(spec: UiThemeSpec, tokens: DesignTokens) -> Theme:
	var theme: Theme = Theme.new()
	UiThemeBuilder.build_into(theme, spec, tokens)
	return theme
