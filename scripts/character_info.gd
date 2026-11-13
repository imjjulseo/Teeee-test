class_name CharacterInfo
extends PanelContainer
## 캐릭터 정보 한 장 (기획서 8.1 · 8.5장, E37·E38·E42): 왼쪽 위에 블록·이름·등급, 오른쪽 위에 캐릭터 최고점·능력명 + 족보형/상시형·족보 카드,
## 가운데 아래에 효과 설명,
## 장착 자리(장착 / 구매), 튜토리얼 · 체험. 캐릭터 화면의 넘기는 판과 상점 설명창이 함께 쓴다.
## 무엇을 할지는 정하지 않고 signal로만 알린다.

signal equip_requested(character: CharacterData)
signal purchase_requested(character: CharacterData)
signal lesson_requested(character: CharacterData)

@export var theme_data: BoardTheme

var character: CharacterData

@onready var _block: CharacterBlockView = %InfoBlock
@onready var _name_label: Label = %SheetNameLabel
@onready var _grade_label: Label = %SheetGradeLabel
@onready var _best_label: Label = %CharacterBestLabel
@onready var _condition: RecipeView = %SheetCondition
@onready var _ability_name: Label = %AbilityName
@onready var _ability_kind: Label = %AbilityKind
@onready var _effect_label: Label = %EffectLabel
@onready var _ability_box: Control = %AbilityBox
@onready var _hidden_note: Label = %HiddenNote
@onready var _equip_button: Button = %EquipButton
@onready var _purchase_button: Button = %PurchaseButton
@onready var _lesson_button: Button = %LessonButton


## 캐릭터 화면용: 장착 자리에 장착하기 / 장착 중 / 미보유. has_lesson = 캐릭터 튜토리얼이 있다.
func show_for_equip(data: CharacterData, status: CharacterCollection.Status, veiled: bool, best: int, has_lesson: bool) -> void:
	_show_common(data, veiled, best, has_lesson)
	_purchase_button.visible = false
	_equip_button.visible = true
	var owned: bool = status == CharacterCollection.Status.EQUIPPED or status == CharacterCollection.Status.OWNED
	_equip_button.disabled = not owned or status == CharacterCollection.Status.EQUIPPED
	if status == CharacterCollection.Status.EQUIPPED:
		_equip_button.text = "장착 중"
	else:
		_equip_button.text = "장착하기" if owned else "미보유"


## 상점용: 장착 자리에 구매 자리 (action은 CharacterCollection.purchase_action).
func show_for_shop(data: CharacterData, action: CharacterCollection.PurchaseAction, best: int, has_lesson: bool) -> void:
	_show_common(data, false, best, has_lesson)
	_equip_button.visible = false
	_purchase_button.visible = true
	_purchase_button.text = action.text
	_purchase_button.disabled = not action.enabled


## 보이는 버튼 문구 (테스트/디버그용). 숨은 버튼은 빠진다.
func shown_actions() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for button: Button in [_equip_button, _purchase_button, _lesson_button]:
		if button.visible:
			texts.append(button.text)
	return texts


## 블록 그림 (올라오는 연출이 위치를 본다).
func block() -> CharacterBlockView:
	return _block


func _show_common(data: CharacterData, veiled: bool, best: int, has_lesson: bool) -> void:
	character = data
	_block.show_character(data, veiled)
	_name_label.text = "???" if veiled else data.display_name
	_grade_label.text = CharacterData.GRADE_NAMES[data.grade]
	_grade_label.add_theme_color_override("font_color", theme_data.grade_color(data.grade))
	_best_label.text = "최고점 %d" % best
	_best_label.visible = not veiled
	_ability_name.text = data.ability_name if data.has_ability() else "능력 없음"
	_ability_kind.visible = data.has_ability()
	_ability_kind.text = "족보형" if data.has_recipe() else "상시형"
	_condition.visible = data.has_recipe()
	if data.has_recipe() and not veiled:
		_condition.show_recipe(RecipeSet.Recipe.new(data.condition_colors, 0))
	_effect_label.text = data.detail_effect if not data.detail_effect.is_empty() else data.ability_description
	_effect_label.visible = not veiled and not _effect_label.text.is_empty()
	_ability_box.visible = not veiled
	_hidden_note.visible = veiled
	_lesson_button.visible = has_lesson and not veiled


func _on_equip_button_pressed() -> void:
	equip_requested.emit(character)


func _on_purchase_button_pressed() -> void:
	purchase_requested.emit(character)


func _on_lesson_button_pressed() -> void:
	lesson_requested.emit(character)
