extends SceneTree
## 디자인 토큰으로 프로젝트 테마를 다시 만든다 (기획서 7.3장):
##   godot --headless --path . -s tools/build_ui_theme.gd
## resources/design_tokens.tres(색) + resources/ui_theme_spec.tres(변형 설계) → resources/ui_theme.tres.
## 토큰·설계를 고친 뒤 실행한다 (test_design_tokens.gd가 테마가 최신인지 검사한다).


func _initialize() -> void:
	var tokens: DesignTokens = load(UiThemeBuilder.TOKENS_PATH) as DesignTokens
	var spec: UiThemeSpec = load(UiThemeBuilder.SPEC_PATH) as UiThemeSpec
	var errors: PackedStringArray = spec.validate(tokens) if tokens != null and spec != null else PackedStringArray(["tokens or spec missing"])
	if not errors.is_empty():
		printerr("build_ui_theme: %s" % "; ".join(errors))
		quit(1)
		return
	var theme: Theme = load(UiThemeBuilder.THEME_PATH) as Theme
	if theme == null:
		theme = Theme.new()
	UiThemeBuilder.build_into(theme, spec, tokens)
	var result: Error = ResourceSaver.save(theme, UiThemeBuilder.THEME_PATH)
	print("build_ui_theme: %s (%s)" % [UiThemeBuilder.THEME_PATH, error_string(result)])
	quit(0 if result == OK else 1)
