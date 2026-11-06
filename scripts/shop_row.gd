class_name ShopRow
extends PanelContainer
## 다이아 상점 한 줄 (기획서 8.5장): 캐릭터 색·이름·등급·능력, 오른쪽에 "보유" 또는 [선택권] [◆ 가격] 버튼.
## 등급이 상점에 열리지 않았으면 다이아 버튼이 없다 (선택권은 열리기 전에도 쓸 수 있음). 버튼은 signal로만 알린다.

signal ticket_requested(character: CharacterData)
signal buy_requested(character: CharacterData)

@export var locked_alpha: float = 0.5

var character: CharacterData

@onready var _swatch: Panel = %Swatch
@onready var _portrait: PortraitRect = %Portrait
@onready var _name_label: Label = %RowName
@onready var _ability_label: Label = %RowAbility
@onready var _owned_label: Label = %OwnedLabel
@onready var _ticket_button: Button = %TicketButton
@onready var _buy_button: Button = %RowBuyButton


func setup(data: CharacterData, grade_color: Color) -> void:
	character = data
	_name_label.text = "%s · %s" % [data.display_name, CharacterData.GRADE_NAMES[data.grade]]
	_ability_label.text = data.ability_description
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = data.accent_color
	style.border_color = grade_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	if _portrait.show_character(data):
		style.bg_color = Color.TRANSPARENT
	_swatch.add_theme_stylebox_override("panel", style)


func show_offer(owned: bool, offer: CharacterCollection.Offer) -> void:
	_owned_label.visible = owned
	_ticket_button.visible = not owned and offer.tickets > 0
	_buy_button.visible = not owned and offer.shop_open
	_buy_button.text = "◆ %d" % offer.diamond_price
	_buy_button.disabled = not offer.affordable
	modulate.a = 1.0 if owned or offer.shop_open or offer.tickets > 0 else locked_alpha


## 보이는 오른쪽 문구 (테스트/디버그용).
func shown_actions() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	if _owned_label.visible:
		texts.append(_owned_label.text)
	for button: Button in [_ticket_button, _buy_button]:
		if button.visible:
			texts.append(button.text)
	return texts


func _on_ticket_button_pressed() -> void:
	ticket_requested.emit(character)


func _on_buy_button_pressed() -> void:
	buy_requested.emit(character)
