extends "res://tests/framework/test_case.gd"
## 7c iOS 내보내기 준비 (docs/mobile_build.md): 프리셋 값, 빌드 스크립트가 고치는 Team ID 줄이 하나뿐인지.


func _preset() -> ConfigFile:
	var config: ConfigFile = ConfigFile.new()
	assert_eq(config.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	return config


func test_ios_preset_values() -> void:
	var config: ConfigFile = _preset()
	assert_eq([config.get_value("preset.1", "name"), config.get_value("preset.1", "platform")], ["iOS", "iOS"])
	assert_eq(config.get_value("preset.1", "export_path"), "build/ios/swap_match.ipa")
	assert_true(String(config.get_value("preset.1", "exclude_filter")).contains("tests/*"), "tests are not shipped")
	var options: String = "preset.1.options"
	assert_eq(config.get_value(options, "application/bundle_identifier"), "com.swapmatch.game", "same id as Android")
	assert_eq(config.get_value(options, "application/short_version"), "1.0")
	assert_true(config.get_value(options, "architectures/arm64"))
	assert_eq(config.get_value(options, "application/targeted_device_family"), 2, "iPhone and iPad")
	assert_eq(config.get_value(options, "application/export_method_debug"), 1, "development signing for debug")


func test_team_id_line_is_unique() -> void:
	# tools/build_ios.sh --team이 sed로 이 줄을 바꾼다 (다른 프리셋에 같은 키가 생기면 함께 바뀐다)
	var count: int = 0
	for line: String in FileAccess.get_file_as_string("res://export_presets.cfg").split("\n"):
		if line.begins_with("application/app_store_team_id="):
			count += 1
	assert_eq(count, 1)
