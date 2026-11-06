class_name AchievementStore
extends RefCounted
## 업적 진행·달성과 누적 통계 (기획서 8.9장). 저장 파일 입출력은 SaveData가 한다
## ([achievements] done · progress, [stats] games · blocks · recipes · coins). 바꿀 때마다 전체를 한 번에 저장한다.

const SECTION: String = "achievements"
const KEY_DONE: String = "done"
const KEY_PROGRESS: String = "progress"
const STATS_SECTION: String = "stats"
## 누적 통계 이름 (CommonAchievement.stat과 같은 이름).
const STAT_KEYS: PackedStringArray = ["games", "blocks", "recipes", "coins"]

var path: String
## 달성한 업적 id.
var done: Dictionary[String, bool] = {}
## 업적 id → 지금까지 가장 큰 진행 값 (달성 전).
var progress: Dictionary[String, int] = {}
## 누적 통계.
var stats: Dictionary[String, int] = {}


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	var saved_done: Variant = data.get_value(SECTION, KEY_DONE, PackedStringArray())
	if saved_done is PackedStringArray or saved_done is Array:
		for id: Variant in saved_done:
			if typeof(id) == TYPE_STRING:
				done[id] = true
	var saved_progress: Variant = data.get_value(SECTION, KEY_PROGRESS, {})
	if saved_progress is Dictionary:
		for id: Variant in saved_progress:
			if typeof(id) == TYPE_STRING and typeof(saved_progress[id]) == TYPE_INT:
				progress[id] = saved_progress[id]
	for key: String in STAT_KEYS:
		var value: Variant = data.get_value(STATS_SECTION, key, 0)
		stats[key] = maxi(value, 0) if typeof(value) == TYPE_INT else 0


func is_done(id: String) -> bool:
	return done.has(id)


func progress_of(id: String) -> int:
	return progress.get(id, 0)


func stat(key: String) -> int:
	return stats.get(key, 0)


func add_stat(key: String, amount: int) -> void:
	stats[key] = stat(key) + amount


## 진행 값은 가장 큰 값만 남긴다.
func record_progress(id: String, value: int) -> void:
	progress[id] = maxi(progress_of(id), value)


func mark_done(id: String) -> void:
	done[id] = true


func save() -> void:
	var data: SaveData = SaveData.new(path)
	data.set_value(SECTION, KEY_DONE, PackedStringArray(done.keys()))
	data.set_value(SECTION, KEY_PROGRESS, progress.duplicate())
	for key: String in STAT_KEYS:
		data.set_value(STATS_SECTION, key, stat(key))
	data.save()
