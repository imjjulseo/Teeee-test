class_name MenuUnlocks
extends RefCounted
## 메뉴 버튼 단계 잠금 (기획서 8.1장): 튜토리얼 흐름에 따라 시작 → 레벨 → 상점 → 캐릭터 → 업적 → 퍼즐 순서로 연다.
## 설정은 처음부터 열려 있고, 한 번 열린 버튼은 다시 잠기지 않는다.
## 튜토리얼 흐름은 6단계에서 연결한다 — 그 전까지는 모두 열린 상태(opened = ORDER.size())로 쓴다.

enum Entry { START, LEVEL, SHOP, CHARACTERS, ACHIEVEMENTS, OPTIONS, PUZZLES }

## 여는 순서. 여기 없는 버튼(설정)은 늘 열려 있다.
const ORDER: Array[Entry] = [Entry.START, Entry.LEVEL, Entry.SHOP, Entry.CHARACTERS, Entry.ACHIEVEMENTS, Entry.PUZZLES]

## ORDER에서 앞에서부터 몇 개가 열렸는지.
var opened: int


func _init(p_opened: int = ORDER.size()) -> void:
	opened = clampi(p_opened, 0, ORDER.size())


func is_open(entry: Entry) -> bool:
	var index: int = ORDER.find(entry)
	return index < 0 or index < opened


## 다음 버튼을 연다 (모두 열렸으면 그대로).
func open_next() -> void:
	opened = mini(opened + 1, ORDER.size())
