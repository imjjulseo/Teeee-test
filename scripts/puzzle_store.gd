class_name PuzzleStore
extends RefCounted
<<<<<<< HEAD
## 블록 모으기 기록 (기획서 8.8 · 8.9장 연습 별점). 저장 파일 입출력은 SaveData가 한다
=======
## 블럭 모으기 기록 (기획서 8.8 · 8.9장 연습 별점). 저장 파일 입출력은 SaveData가 한다
>>>>>>> Choi
## ([puzzle] stars · solved · star_total · perfect · difficulty · rewarded).
## 튜토리얼 판(id 있음)은 판마다 가장 좋은 별, 연습 문제는 푼 수·모은 별·최소 수 성공 수를 센다.

const SECTION: String = "puzzle"
const KEY_STARS: String = "stars"
const KEY_SOLVED: String = "solved"
const KEY_STAR_TOTAL: String = "star_total"
const KEY_PERFECT: String = "perfect"
const KEY_DIFFICULTY: String = "difficulty"
const KEY_REWARDED: String = "rewarded"
const PERFECT_STARS: int = 3

var path: String
## 판 id → 가장 좋은 별 (1~3).
var stars: Dictionary[String, int] = {}
var solved: int = 0
var star_total: int = 0
var perfect: int = 0
## 마지막으로 고른 연습 난이도.
var difficulty: StringName = &"easy"
## 첫 클리어 보상을 받은 판 id (보상 퍼즐, E27).
var rewarded: PackedStringArray = PackedStringArray()


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	var saved: Variant = data.get_value(SECTION, KEY_STARS, {})
	if saved is Dictionary:
		for id: Variant in saved:
			if typeof(id) == TYPE_STRING and typeof(saved[id]) == TYPE_INT:
				stars[id] = clampi(saved[id], 1, PERFECT_STARS)
	solved = _int(data, KEY_SOLVED)
	star_total = _int(data, KEY_STAR_TOTAL)
	perfect = _int(data, KEY_PERFECT)
	var saved_rewarded: Variant = data.get_value(SECTION, KEY_REWARDED, PackedStringArray())
	if saved_rewarded is PackedStringArray:
		rewarded = saved_rewarded
	var saved_difficulty: Variant = data.get_value(SECTION, KEY_DIFFICULTY, "easy")
	if typeof(saved_difficulty) == TYPE_STRING or typeof(saved_difficulty) == TYPE_STRING_NAME:
		difficulty = StringName(saved_difficulty)


func stars_of(id: String) -> int:
	return stars.get(id, 0)


## 튜토리얼 판 결과 (더 좋을 때만 바꾼다).
func record_board(id: String, earned: int) -> void:
	if id.is_empty():
		return
	stars[id] = maxi(stars_of(id), clampi(earned, 1, PERFECT_STARS))
	save()


## 연습 문제 결과.
func record_practice(earned: int) -> void:
	solved += 1
	star_total += earned
	if earned >= PERFECT_STARS:
		perfect += 1
	save()


func is_rewarded(id: String) -> bool:
	return rewarded.has(id)


## 첫 클리어 보상을 받았다고 적는다.
func mark_rewarded(id: String) -> void:
	if not id.is_empty() and not rewarded.has(id):
		rewarded.append(id)
		save()


func set_difficulty(id: StringName) -> void:
	difficulty = id
	save()


func save() -> void:
	var data: SaveData = SaveData.new(path)
	data.set_value(SECTION, KEY_STARS, stars.duplicate())
	data.set_value(SECTION, KEY_SOLVED, solved)
	data.set_value(SECTION, KEY_STAR_TOTAL, star_total)
	data.set_value(SECTION, KEY_PERFECT, perfect)
	data.set_value(SECTION, KEY_DIFFICULTY, String(difficulty))
	data.set_value(SECTION, KEY_REWARDED, rewarded)
	data.save()


static func _int(data: SaveData, key: String) -> int:
	var value: Variant = data.get_value(SECTION, key, 0)
	return maxi(value, 0) if typeof(value) == TYPE_INT else 0
