class_name CharacterRoster
extends Resource
## 선택 가능한 캐릭터 목록. 첫 번째 캐릭터가 기본값이다.

@export var characters: Array[CharacterData] = []


func default_character() -> CharacterData:
	return characters[0] if not characters.is_empty() else null


## id에 해당하는 캐릭터. 없으면 기본 캐릭터.
func find(id: StringName) -> CharacterData:
	for character: CharacterData in characters:
		if character.id == id:
			return character
	return default_character()
