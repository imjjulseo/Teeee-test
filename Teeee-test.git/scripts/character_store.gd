class_name CharacterStore
extends RefCounted
## 선택한 캐릭터. 저장 파일 입출력은 SaveData가 한다 ([player] character).

const SECTION: String = "player"
const KEY_CHARACTER: String = "character"

var path: String
var selected_id: StringName = &""


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var value: Variant = SaveData.new(path).get_value(SECTION, KEY_CHARACTER, "")
	if typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		selected_id = StringName(value)


func select(id: StringName) -> void:
	selected_id = id
	SaveData.write_value(path, SECTION, KEY_CHARACTER, String(id))
