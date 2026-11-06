class_name PortraitRect
extends TextureRect
## 캐릭터 이미지 자리 (CharacterData.portrait, 한 장). 미리보기 판넬 안에 깔리고, 이미지가 없거나 정체를 숨길 때(veiled)는 숨는다.
## 이미지가 보이면 주인은 판넬 채움색을 지우고 테두리만 남긴다.


## 캐릭터 이미지를 보인다. 보였으면 true.
func show_character(data: CharacterData, veiled: bool = false) -> bool:
	texture = data.portrait if data != null and not veiled else null
	visible = texture != null
	return visible
