class_name ShopGradeSection
extends VBoxContainer
## 상점 선택 탭의 등급 구역 (기획서 8.5장, E37·E38): 등급 머리줄, 그 등급 선택권 줄(보유 수 · 사용 · 합성), 그 등급 캐릭터 카드(4열).
## 구역은 shop.tscn에 등급마다 놓여 있고, 카드 수만 로스터로 정해져 코드에서 인스턴스화한다. 할 일은 signal로만 알린다.

signal character_chosen(character: CharacterData)
signal use_toggled(grade: int)
signal fuse_requested(grade: int)

## CharacterData.Grade (shop.tscn에서 구역마다 정한다).
@export var grade: int = CharacterData.Grade.RARE
## 캐릭터 카드 하나.
@export var card_scene: PackedScene

var _cards: Array[ShopCard] = []

@onready var _header: GradeHeader = %Header
@onready var _ticket_row: TicketRow = %TicketRow
@onready var _characters: GridContainer = %Characters


func setup(grade_color: Color, next_grade: int, characters: Array[CharacterData]) -> void:
	_header.setup(grade, grade_color)
	_ticket_row.setup(grade, grade_color, next_grade)
	for character: CharacterData in characters:
		var card: ShopCard = card_scene.instantiate() as ShopCard
		_characters.add_child(card)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.setup(character)
		card.chosen.connect(_on_card_chosen)
		_cards.append(card)


func show_shop(open: bool, open_level: int) -> void:
	_header.show_shop(open, open_level)


func ticket_row() -> TicketRow:
	return _ticket_row


func cards() -> Array[ShopCard]:
	return _cards


func _on_card_chosen(character: CharacterData) -> void:
	character_chosen.emit(character)


func _on_ticket_row_use_toggled(p_grade: int) -> void:
	use_toggled.emit(p_grade)


func _on_ticket_row_fuse_requested(p_grade: int) -> void:
	fuse_requested.emit(p_grade)
