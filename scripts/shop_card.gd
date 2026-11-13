class_name ShopCard
extends PanelContainer
<<<<<<< HEAD
## 상점 선택 탭의 캐릭터 카드 (기획서 8.5장, E38): 캐릭터 블록, 이름, 아래에 가격(◆ 80) · 선택 · 보유 · Lv 8.
=======
## 상점 선택 탭의 캐릭터 카드 (기획서 8.5장, E38): 캐릭터 블럭, 이름, 아래에 가격(◆ 80) · 선택 · 보유 · Lv 8.
>>>>>>> Choi
## 누르면 chosen으로 알린다 (설명창에서 구매한다). 아직 살 수 없으면 흐리게.

signal chosen(character: CharacterData)

@export var locked_alpha: float = 0.5

var character: CharacterData
var _action_kind: CharacterCollection.Purchase = CharacterCollection.Purchase.CLOSED


func setup(data: CharacterData) -> void:
	character = data
	(%CardBlock as CharacterBlockView).show_character(data)
	(%CardName as Label).text = data.display_name


func show_action(action: CharacterCollection.PurchaseAction) -> void:
	_action_kind = action.kind
	(%CardPrice as Label).text = action.card_text
	modulate.a = locked_alpha if action.kind == CharacterCollection.Purchase.CLOSED else 1.0


func shows_owned() -> bool:
	return _action_kind == CharacterCollection.Purchase.OWNED


func price_text() -> String:
	return (%CardPrice as Label).text


func _on_press_pressed() -> void:
	chosen.emit(character)
