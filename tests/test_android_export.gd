extends "res://tests/framework/test_case.gd"
## 7c 안드로이드 내보내기 준비 (docs/mobile_build.md): 프리셋 값과 안드로이드에 필요한 프로젝트 설정.


func _preset() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	return config


func test_android_preset_values() -> void:
	var config: ConfigFile = _preset()
	assert_eq([config.get_value("preset.0", "name"), config.get_value("preset.0", "platform")], ["Android", "Android"])
	assert_eq(config.get_value("preset.0", "export_path"), "build/android/swap_match.apk")
	assert_true(String(config.get_value("preset.0", "exclude_filter")).contains("tests/*"), "tests are not shipped")
	var options: String = "preset.0.options"
	assert_eq(config.get_value(options, "package/unique_name"), "com.swapmatch.game")
	assert_eq(config.get_value(options, "package/name"), "Swap match")
	assert_eq([config.get_value(options, "architectures/arm64-v8a"), config.get_value(options, "architectures/armeabi-v7a")], [true, false])
	assert_false(config.get_value(options, "permissions/internet"), "no permissions")


func test_project_settings_for_android() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 1, "portrait")
	assert_false(ProjectSettings.get_setting("application/config/quit_on_go_back"), "back pauses instead of quitting")
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), "ETC2/ASTC textures")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")
