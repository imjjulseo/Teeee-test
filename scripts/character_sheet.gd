class_name CharacterSheet
extends Control
## 상점의 캐릭터 설명창 (기획서 8.5장, E37·E38): 어두운 막 + 닫기 + 캐릭터 정보(CharacterInfo, 캐릭터 화면과 같은 내용).
## 장착 자리에 구매 가격 · 선택권 사용 · 보유. 무엇을 할지는 정하지 않고 signal로만 알린다 (ShopScreen이 처리).

signal purchase_requested(character: CharacterData)
signal lesson_requested(character: CharacterData)
signal closed

var character: CharacterData:
	get:
		return info().character


func _ready() -> void:
	visible = false


## action은 CharacterCollection.purchase_action. has_lesson = 캐릭터 튜토리얼이 있다.
func open_for_shop(data: CharacterData, action: CharacterCollection.PurchaseAction, best: int, has_lesson: bool = false) -> void:
	info().show_for_shop(data, action, best, has_lesson)
	visible = true


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func info() -> CharacterInfo:
	return %Info as CharacterInfo


## 보이는 버튼 문구 (테스트/디버그용).
func shown_actions() -> PackedStringArray:
	return info().shown_actions()


func _on_info_purchase_requested(data: CharacterData) -> void:
	purchase_requested.emit(data)


func _on_info_lesson_requested(data: CharacterData) -> void:
	lesson_requested.emit(data)


func _on_close_pressed() -> void:
	close()
