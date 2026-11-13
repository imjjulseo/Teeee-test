class_name UiThemeSpec
extends Resource
## 프로젝트 테마의 설계 (기획서 7.3장): 어떤 변형이 어떤 토큰 색을 쓰는지. 실제 테마(ui_theme.tres)는
## UiThemeBuilder가 이 설계와 DesignTokens로 만든다 (tools/build_ui_theme.gd, test_design_tokens.gd가 맞는지 검사).

## 라벨 글자색 변형: 변형 이름 → 토큰 이름 (Label 바탕).
@export var label_variations: Dictionary[StringName, StringName] = {}
@export var styles: Array[UiStyle] = []
## 전체 UI 폰트 (비어 있으면 엔진 기본 폰트, 넣는 법은 assets/fonts/README.md).
@export var default_font: Font


func validate(tokens: DesignTokens) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for variation: StringName in label_variations:
		if not tokens.has_token(label_variations[variation]):
			errors.append("label %s: unknown token %s" % [variation, label_variations[variation]])
	for style: UiStyle in styles:
		if style == null or style.template == null or style.name == &"":
			errors.append("style without name or template")
			continue
		if not tokens.has_token(style.bg_token):
			errors.append("style %s: unknown bg token %s" % [style.name, style.bg_token])
		if style.border_token != &"" and not tokens.has_token(style.border_token):
			errors.append("style %s: unknown border token %s" % [style.name, style.border_token])
	return errors
