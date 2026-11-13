class_name PlaytestLog
extends RefCounted
## 플레이 기록 (기획서 10.1): 판이 끝날 때마다 user://playtest_log.csv에 한 줄을 추가한다.
## - 개발 빌드에서만, GameConfig.playtest_logging이 켜져 있을 때만 기록한다.
## - 테스트·스모크는 path_override로 다른 파일을 쓴다 (사용자 기록을 건드리지 않음).
## - 첫 줄은 헤더. 열을 추가할 때는 COLUMNS 끝에만 추가한다 (기존 기록과 열 위치가 어긋나지 않게).
## - final_rate는 v0.9.3의 시간 배속 열이다. v1.0에는 배속이 없어 빈 값으로 남긴다 (열 위치 유지).
## - 7b 열 (10.1장): 매치 1회당 이동 수 구간(1~4 / 5~7 / 8~)과 평균, 주운 금화, 계정 레벨·보드 단계, 조작 방법, 부활 수,
##   족보 점수·족보 밖 점수. 판 밖의 값(레벨·단계·조작)은 Context로 받는다.
## - 기존 파일의 헤더가 지금 열과 다르면 그 파일을 <이름>_old_<시각>.csv로 옮기고 새 파일을 시작한다 (열이 섞이지 않게).

## 판 밖에서 정해지는 값 (GameController가 채운다).
class Context:
	var account_level: int = 0
	var board_stage: int = 0
	## 조작 방법 (OptionsStore.ControlMode 이름 소문자: "swipe" / "dpad").
	var control: String = ""

const DEFAULT_PATH: String = "user://playtest_log.csv"
## end 값: 결과 화면까지 간 판 / 일시정지에서 메뉴로 나간 판.
const END_RESULT: String = "result"
const END_ABANDONED: String = "abandoned"
const COLUMNS: PackedStringArray = [
	"timestamp", "seed", "character", "end", "score", "play_seconds", "moves", "blocked_moves",
	"matches", "recipes_completed", "ability_triggers", "max_remaining", "final_rate",
	"score_0_30", "score_30_60", "score_60_plus",
	"match_moves_1_4", "match_moves_5_7", "match_moves_8_plus", "match_moves_avg", "coins",
	"account_level", "board_stage", "control", "revives", "recipe_points", "bonus_points",
]

## 비어 있지 않으면 경로를 주지 않은 PlaytestLog가 이 파일을 쓴다 (테스트·스모크용).
static var path_override: String = ""


static func resolve_path(p_path: String = "") -> String:
	if not p_path.is_empty():
		return p_path
	return path_override if not path_override.is_empty() else DEFAULT_PATH


## 이 빌드·설정에서 기록하는지.
static func is_enabled(config: GameConfig) -> bool:
	return config != null and config.playtest_logging and OS.is_debug_build()


## 판 하나의 기록 행 (COLUMNS 순서).
static func row_for(session: GameSession, character_id: StringName, end: String, timestamp: String = "",
		context: Context = null) -> PackedStringArray:
	var stats: SessionStats = session.stats
	var run: Context = context if context != null else Context.new()
	return PackedStringArray([
		timestamp if not timestamp.is_empty() else Time.get_datetime_string_from_system(false, true),
		str(session.base_seed),
		String(character_id) if not String(character_id).is_empty() else "none",
		end,
		str(session.score),
		"%.2f" % stats.play_time,
		str(stats.moves),
		str(stats.blocked_moves),
		str(stats.matches),
		str(stats.recipes_completed),
		str(stats.ability_triggers),
		"%.2f" % stats.max_remaining,
		"",  # final_rate: v1.0에는 시간 배속이 없다
		str(stats.score_by_time[0]),
		str(stats.score_by_time[1]),
		str(stats.score_by_time[2]),
		str(stats.match_moves[0]),
		str(stats.match_moves[1]),
		str(stats.match_moves[2]),
		"%.2f" % stats.average_match_moves(),
		str(session.collected_coins()),
		str(run.account_level),
		str(run.board_stage),
		run.control,
		str(stats.revives),
		str(stats.recipe_points),
		str(stats.bonus_points),
	])


## 행을 파일 끝에 추가한다 (파일이 없으면 헤더부터). 성공하면 true.
static func append(row: PackedStringArray, p_path: String = "") -> bool:
	var path: String = resolve_path(p_path)
	PlaytestLog._retire_if_header_changed(path)
	var is_new: bool = not FileAccess.file_exists(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE if is_new else FileAccess.READ_WRITE)
	if file == null:
		push_warning("PlaytestLog: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.seek_end()
	if is_new:
		file.store_line(",".join(COLUMNS))
	file.store_line(",".join(row))
	file.close()
	return true


## 헤더가 지금 열과 다른 기존 파일을 <이름>_old_<시각>.csv로 옮긴다 (지우지 않는다). 옮겼으면 그 경로.
static func _retire_if_header_changed(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var header: String = file.get_line()
	file.close()
	if header == ",".join(COLUMNS):
		return ""
	var stamp: String = Time.get_datetime_string_from_system(false, false).replace(":", "").replace("-", "").replace("T", "_")
	var retired: String = "%s_old_%s.csv" % [path.get_basename(), stamp]
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(retired))
	return retired