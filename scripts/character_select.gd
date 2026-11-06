class_name CharacterSelect
extends Control
## 캐릭터 화면 (기획서 8.1장): 위에 지갑과 장착 중인 캐릭터, 등급 필터(해금 수/전체), 등급순 카드 가로 스크롤.
## 카드를 누르면 상세 시트가 열리고, 시트의 장착·선택권 해금·다이아 해금·체험을 CharacterCollection으로 처리한다.
## 체험·튜토리얼 다시 하기는 TrialRequest에 캐릭터를 적고 trial_started (character_select.tscn에서 게임 씬 전환에 연결).
## 카드·필터 칩 수는 데이터로 정해지므로 코드에서 인스턴스화한다.

signal trial_started

@export var roster: CharacterRoster
## 다이아 상점 가격·개방 레벨 (ProgressionConfig.gacha).
@export var progression: ProgressionConfig
## 상세 시트의 캐릭터 업적.
@export var achievements: AchievementBook
## 상세 시트의 "튜토리얼 다시 하기" (튜토리얼이 있는 캐릭터만).
@export var lessons: CharacterTutorialBook
## 처음 볼 때 안내 (처음 열면 카드 줄을 설명한다, 8.8장).
@export var tips: FirstViewTips
@export var spotlight: SpotlightOverlay
@export var card_scene: PackedScene
@export var chip_scene: PackedScene
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

## 필터 칩 등급 (기본 캐릭터는 "전체"에서만 보인다).
const FILTER_GRADES: Array[CharacterData.Grade] = [
	CharacterData.Grade.RARE, CharacterData.Grade.HERO, CharacterData.Grade.LEGEND,
	CharacterData.Grade.MYTH, CharacterData.Grade.HIDDEN,
]

var collection: CharacterCollection
var filter_grade: int = FilterChip.ALL
var _progress: ProgressStore
var _tracker: AchievementTracker
var _cards: Array[CharacterCard] = []
var _chips: Array[FilterChip] = []
var _guides: GuideQueue

@onready var _cards_box: HBoxContainer = %Cards
@onready var _chips_box: HBoxContainer = %Filters
@onready var _wallet_label: WalletView = %WalletLabel
@onready var _equipped_label: Label = %EquippedLabel
@onready var _sheet: CharacterSheet = %CharacterSheet


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	_progress = ProgressStore.new(save_path)
	collection = CharacterCollection.new(roster, _progress, CharacterStore.new(save_path), progression.gacha)
	_tracker = AchievementTracker.new(AchievementBook.ensure_valid(achievements), AchievementStore.new(save_path), _progress)
	_add_chip(FilterChip.ALL)
	for grade: CharacterData.Grade in FILTER_GRADES:
		_add_chip(grade)
	for data: CharacterData in collection.sorted():
		var card: CharacterCard = card_scene.instantiate() as CharacterCard
		_cards_box.add_child(card)
		card.setup(data, collection.is_veiled(data))
		card.chosen.connect(_on_card_chosen)
		_cards.append(card)
	_refresh()
	_queue_guide(TutorialStore.new(save_path))


## 처음 열면 카드 줄 안내 (HTML spotOnce _chr). 본 기록은 튜토리얼 흐름(게임 시작이 빛남)에도 쓴다.
func _queue_guide(tutorial: TutorialStore) -> void:
	if tips == null or spotlight == null:
		tutorial.mark_seen(TutorialStore.SEEN_CHARACTERS)
		return
	_guides = GuideQueue.new(spotlight, tutorial)
	var scroll: Control = %Scroll
	if _guides.add(TutorialStore.SEEN_CHARACTERS, tips.characters_head, tips.characters_text,
			func() -> Array[Rect2]: return [scroll.get_global_rect()] as Array[Rect2], true):
		_guides.start(self)


## 처음 볼 때 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guides != null and _guides.is_open()


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()

## 지금 장착한 캐릭터 id.
func selected_id() -> StringName:
	return collection.equipped_character().id


## 등급 필터 (FilterChip.ALL = 전체).
func set_filter(grade: int) -> void:
	filter_grade = grade
	_refresh()


## 카드 (등급순, 필터로 숨은 카드 포함).
func cards() -> Array[CharacterCard]:
	return _cards


func card_for(id: StringName) -> CharacterCard:
	for card: CharacterCard in _cards:
		if card.character.id == id:
			return card
	return null


func _add_chip(grade: int) -> void:
	var chip: FilterChip = chip_scene.instantiate() as FilterChip
	_chips_box.add_child(chip)
	chip.chosen.connect(set_filter)
	chip.grade = grade
	_chips.append(chip)


func _refresh() -> void:
	_wallet_label.show_amounts(_progress.coins, _progress.diamonds)
	_equipped_label.text = "장착 중 · %s" % collection.equipped_character().display_name
	for chip: FilterChip in _chips:
		chip.setup(chip.grade, _chip_text(chip.grade))
		chip.set_selected(chip.grade == filter_grade)
	for card: CharacterCard in _cards:
		card.show_status(collection.status_of(card.character), collection.status_text(card.character))
		card.visible = filter_grade == FilterChip.ALL or card.character.grade == filter_grade


func _chip_text(grade: int) -> String:
	if grade == FilterChip.ALL:
		var owned: int = 0
		for data: CharacterData in roster.characters:
			owned += 1 if _progress.is_unlocked(data.id) else 0
		return "전체 %d/%d" % [owned, roster.characters.size()]
	var counts: Vector2i = collection.grade_counts(grade)
	return "%s %d/%d" % [CharacterData.GRADE_NAMES[grade], counts.x, counts.y]


func _open_sheet(character: CharacterData) -> void:
	_sheet.open(character, collection.status_of(character), collection.is_veiled(character), collection.offer_for(character),
		_tracker.chain_status(character.id), lessons != null and lessons.find(character.id) != null)


func _on_card_chosen(character: CharacterData) -> void:
	_open_sheet(character)


## 시트의 장착하기 (character_select.tscn에서 연결).
func _on_equip_requested(character: CharacterData) -> void:
	if collection.equip(character):
		_refresh()
		_open_sheet(character)


func _on_unlock_requested(character: CharacterData) -> void:
	if collection.unlock_with_ticket(character):
		_refresh()
		_open_sheet(character)


func _on_buy_requested(character: CharacterData) -> void:
	if collection.buy_with_diamonds(character):
		_refresh()
		_open_sheet(character)


func _on_trial_requested(character: CharacterData) -> void:
	TrialRequest.character_id = character.id
	trial_started.emit()


## 시트의 튜토리얼 다시 하기: 체험 판(보상·기록 없음)을 캐릭터 튜토리얼부터.
func _on_lesson_requested(character: CharacterData) -> void:
	TrialRequest.character_id = character.id
	TrialRequest.with_lesson = true
	trial_started.emit()
