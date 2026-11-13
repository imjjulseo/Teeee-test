extends "res://tests/framework/test_case.gd"
## 최고 점수 로컬 저장 (user://). 테스트 전용 파일을 쓰고 끝나면 지운다.

const TEST_PATH: String = "user://test_best_score.cfg"


func _clean() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_missing_file_means_zero() -> void:
	_clean()
	assert_eq(BestScoreStore.new(TEST_PATH).best, 0)


func test_higher_score_is_saved_and_persists() -> void:
	_clean()
	var store: BestScoreStore = BestScoreStore.new(TEST_PATH)
	assert_true(store.submit(800))
	assert_eq(store.best, 800)
	assert_true(FileAccess.file_exists(TEST_PATH), "file written under user://")
	assert_eq(BestScoreStore.new(TEST_PATH).best, 800, "reloaded from disk")
	_clean()


func test_lower_or_equal_score_does_not_overwrite() -> void:
	_clean()
	var store: BestScoreStore = BestScoreStore.new(TEST_PATH)
	store.submit(1000)
	assert_false(store.submit(600))
	assert_false(store.submit(1000), "equal score is not a new best")
	assert_eq(BestScoreStore.new(TEST_PATH).best, 1000)
	_clean()


func test_zero_score_does_not_create_record() -> void:
	_clean()
	assert_false(BestScoreStore.new(TEST_PATH).submit(0))
	assert_false(FileAccess.file_exists(TEST_PATH))


func test_other_keys_in_save_file_are_kept() -> void:
	_clean()
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "version", SaveData.CURRENT_VERSION)
	file.set_value("player", "character", "fox")
	file.save(TEST_PATH)
	BestScoreStore.new(TEST_PATH).submit(200)
	var reloaded: ConfigFile = ConfigFile.new()
	reloaded.load(TEST_PATH)
	assert_eq(reloaded.get_value("player", "character", ""), "fox")
	assert_eq(reloaded.get_value("score", "best", 0), 200)
	_clean()


func test_invalid_value_is_treated_as_zero() -> void:
	_clean()
	var file: ConfigFile = ConfigFile.new()
	file.set_value("meta", "version", SaveData.CURRENT_VERSION)
	file.set_value("score", "best", "not a number")
	file.save(TEST_PATH)
	assert_eq(BestScoreStore.new(TEST_PATH).best, 0)
	_clean()
