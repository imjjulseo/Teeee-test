class_name DisplayStyle
extends RefCounted
## 능력이 바꾸는 블록·족보 표시 방식 (순수 데이터). 실제 색은 View가 BoardTheme에서 고른다.
## - color_alias: 이 색 ID를 다른 색 ID의 색으로 칠한다 (색약: 두 번째 색이 첫 번째 색으로, 뱀파이어: 모두 빨강). 문양은 원래 색.
## - monochrome: 흑백으로 칠한다 (레트로 "흑백", 문양으로만 구분).
## - reveal_seeds: 씨앗이 자랄 색을 보여 준다 (예지안).
## - reversed_recipes: 족보 카드의 칸 순서를 거꾸로 보여 준다 (거울세계).

var color_alias: Dictionary[int, int] = {}
var monochrome: bool = false
var reveal_seeds: bool = false
var reversed_recipes: bool = false


## 칠할 색 ID (문양은 원래 color_id를 쓴다).
func fill_color_id(color_id: int) -> int:
	return color_alias.get(color_id, color_id)


func is_plain() -> bool:
	return color_alias.is_empty() and not monochrome and not reveal_seeds and not reversed_recipes
