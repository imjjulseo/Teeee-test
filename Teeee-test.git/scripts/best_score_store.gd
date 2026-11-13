class_name BestScoreStore
extends RefCounted
## 최고 점수 (기획서 5장, B15): 전체 최고점과 캐릭터별 최고점 (E38). 저장 파일 입출력은 SaveData가 한다 ([score] best · characters).

const SECTION: String = "score"
const KEY_BEST: String = "best"
const KEY_CHARACTERS: String = "characters"

var path: String
var best: int = 0
var _characters: Dictionary = {}


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	var value: Variant = data.get_value(SECTION, KEY_BEST, 0)
	best = maxi(value as int, 0) if typeof(value) == TYPE_INT else 0
	var saved: Variant = data.get_value(SECTION, KEY_CHARACTERS, {})
	if saved is Dictionary:
		_characters = saved


## 점수를 제출한다. 최고 점수를 넘으면 저장하고 true를 반환한다.
func submit(score: int) -> bool:
	if score <= best:
		return false
	best = score
	SaveData.write_value(path, SECTION, KEY_BEST, best)
	return true


## 그 캐릭터의 최고 점수 (없으면 0).
func best_of(character_id: StringName) -> int:
	var value: Variant = _characters.get(String(character_id), 0)
	return maxi(value as int, 0) if typeof(value) == TYPE_INT else 0


## 그 캐릭터로 낸 점수를 제출한다. 넘으면 저장하고 true.
func submit_character(character_id: StringName, score: int) -> bool:
	if score <= best_of(character_id):
		return false
	_characters[String(character_id)] = score
	SaveData.write_value(path, SECTION, KEY_CHARACTERS, _characters)
	return true
