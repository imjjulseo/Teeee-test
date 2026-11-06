class_name BestScoreStore
extends RefCounted
## 최고 점수 (기획서 5장, B15). 저장 파일 입출력은 SaveData가 한다 ([score] best).

const SECTION: String = "score"
const KEY_BEST: String = "best"

var path: String
var best: int = 0


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var value: Variant = SaveData.new(path).get_value(SECTION, KEY_BEST, 0)
	best = maxi(value as int, 0) if typeof(value) == TYPE_INT else 0


## 점수를 제출한다. 최고 점수를 넘으면 저장하고 true를 반환한다.
func submit(score: int) -> bool:
	if score <= best:
		return false
	best = score
	SaveData.write_value(path, SECTION, KEY_BEST, best)
	return true
