class_name TicketSelection
extends RefCounted
## 상점의 등급별 선택권 [사용] 상태 (기획서 8.5장, E37): 켜진 등급의 캐릭터 설명창은 구매 가격 대신 "선택권 사용"을 보인다.
## 다시 누르면 꺼지고, 선택권을 쓰거나 선택권이 없어지면 꺼진다.

var _on: Dictionary[int, bool] = {}


func is_on(grade: int) -> bool:
	return _on.get(grade, false)


## [사용]을 눌렀다. 선택권이 없으면 켜지지 않는다.
func toggle(grade: int, tickets: int) -> void:
	_on[grade] = not is_on(grade) and tickets > 0


func clear(grade: int) -> void:
	_on[grade] = false


## 선택권 수가 바뀌었다: 없어졌으면 끈다.
func sync(grade: int, tickets: int) -> void:
	if tickets <= 0:
		clear(grade)
