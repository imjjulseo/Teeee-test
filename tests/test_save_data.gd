extends "res://tests/framework/test_case.gd"
## 저장 통합(SaveData): 버전 기록, 옛 버전 초기화(설정만 남김), 경로 우선순위, 항목 간 보존.

const TEST_PATH: String = "user://test_save_data.cfg"
const OVERRIDE_PATH: String = "user://test_save_override.cfg"


func _clean() -> void:
	for path: String in [TEST_PATH, OVERRIDE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_save_writes_current_version() -> void:
	_clean()
	SaveData.write_value(TEST_PATH, "score", "best", 300)
	var raw: ConfigFile = ConfigFile.new()
	raw.load(TEST_PATH)
	assert_eq(raw.get_value("meta", "version", 0), SaveData.CURRENT_VERSION)
	assert_eq(raw.get_value("score", "best", 0), 300)
	assert_eq(SaveData.new(TEST_PATH).loaded_version(), SaveData.CURRENT_VERSION)
	_clean()


## version 4 미만 저장(0 = 버전 기록 전)은 처음 읽을 때 설정만 남기고 초기화한다 (팀 결정 11/04, E26).
func test_old_saves_are_reset_except_options() -> void:
	for version: int in [0, 1, 2, 3]:
		_clean()
		var old: ConfigFile = ConfigFile.new()
		if version > 0:
			old.set_value("meta", "version", version)
		old.set_value("score", "best", 5200)
		old.set_value("player", "character", "gardener")
		old.set_value("progress", "level", 12)
		old.set_value("tutorial", "done", true)
		old.set_value("options", "control_mode", "dpad")
		old.set_value("options", "master_volume", 40)
		old.save(TEST_PATH)
		assert_eq(SaveData.new(TEST_PATH).loaded_version(), version)
		assert_eq(BestScoreStore.new(TEST_PATH).best, 0, "v%d: best score reset" % version)
		assert_eq(CharacterStore.new(TEST_PATH).selected_id, &"", "v%d: character reset" % version)
		assert_eq(ProgressStore.new(TEST_PATH).level, 1, "v%d: progress reset" % version)
		assert_false(TutorialStore.new(TEST_PATH).done, "v%d: tutorial again" % version)
		var options: OptionsStore = OptionsStore.new(TEST_PATH)
		assert_eq([options.control_mode, options.master_volume], [OptionsStore.ControlMode.DPAD, 40], "v%d: options kept" % version)
		BestScoreStore.new(TEST_PATH).submit(300)  # 다음 저장에 초기화가 기록된다
		var raw: ConfigFile = ConfigFile.new()
		raw.load(TEST_PATH)
		assert_eq(raw.get_value("meta", "version", 0), SaveData.CURRENT_VERSION)
		assert_false(raw.has_section("progress") or raw.has_section("player"), "v%d: old sections gone from the file" % version)
		assert_eq(raw.get_value("options", "master_volume", 0), 40)
	_clean()


func test_current_version_file_is_kept() -> void:
	_clean()
	BestScoreStore.new(TEST_PATH).submit(900)
	ProgressStore.new(TEST_PATH).add_currency(100, 0)
	assert_eq([BestScoreStore.new(TEST_PATH).best, ProgressStore.new(TEST_PATH).coins], [900, 100], "no reset at version 4")
	_clean()

func test_path_resolution_order() -> void:
	SaveData.path_override = ""
	assert_eq(SaveData.resolve_path(""), SaveData.DEFAULT_PATH)
	SaveData.path_override = OVERRIDE_PATH
	assert_eq(SaveData.resolve_path(""), OVERRIDE_PATH, "override used when no path given")
	assert_eq(SaveData.resolve_path(TEST_PATH), TEST_PATH, "explicit path wins over override")
	SaveData.path_override = ""


func test_stores_without_path_follow_override() -> void:
	_clean()
	SaveData.path_override = OVERRIDE_PATH
	BestScoreStore.new().submit(900)
	CharacterStore.new().select(&"fever")
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.DPAD)
	SaveData.path_override = ""
	assert_eq(BestScoreStore.new(OVERRIDE_PATH).best, 900)
	assert_eq(CharacterStore.new(OVERRIDE_PATH).selected_id, &"fever")
	assert_eq(OptionsStore.new(OVERRIDE_PATH).control_mode, OptionsStore.ControlMode.DPAD)
	_clean()


func test_missing_file_gives_defaults_and_version_zero() -> void:
	_clean()
	assert_eq(SaveData.new(TEST_PATH).loaded_version(), 0)
	assert_eq(SaveData.new(TEST_PATH).get_value("score", "best", -1), -1)
	assert_false(FileAccess.file_exists(TEST_PATH), "reading does not create the file")
