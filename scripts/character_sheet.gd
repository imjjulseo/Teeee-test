class_name CharacterSheet
extends Control
## 캐릭터 상세 시트 (기획서 8.1장): 이름·등급·캐릭터 족보, 효과·잘 맞는 때·팁, 캐릭터 업적(5d 전까지 "준비 중"),
## 버튼(장착하기 / 장착 중, 선택권으로 해금, 다이아로 해금, 한 판 체험하기, 가진 캐릭터의 튜토리얼 다시 하기). 얻기 전 히든 캐릭터는 정체와 조건을 숨긴다.
## 무엇을 할지는 정하지 않고 signal로만 알린다 (CharacterSelect가 CharacterCollection으로 처리).

signal equip_requested(character: CharacterData)
signal unlock_requested(character: CharacterData)
signal buy_requested(character: CharacterData)
signal trial_requested(character: CharacterData)
signal lesson_requested(character: CharacterData)
signal closed

@export var theme_data: BoardTheme
## 캐릭터 업적 한 단계 줄 (데이터로 개수가 정해지는 반복 노드).
@export var achievement_row_scene: PackedScene

var character: CharacterData

@onready var _preview: Panel = %SheetPreview
@onready var _portrait: PortraitRect = %Portrait
@onready var _name_label: Label = %SheetNameLabel
@onready var _grade_label: Label = %SheetGradeLabel
@onready var _condition: RecipeView = %SheetCondition
@onready var _passive_label: Label = %SheetPassiveLabel
@onready var _sections: Dictionary[String, Label] = {"effect": %EffectLabel, "when": %WhenLabel, "tip": %TipLabel}
@onready var _hidden_note: Label = %HiddenNote
@onready var _achievements: Control = %AchievementsBox
@onready var _achievement_list: VBoxContainer = %AchievementsList
@onready var _achievements_pending: Label = %AchievementsLabel
@onready var _equip_button: Button = %EquipButton
@onready var _unlock_button: Button = %UnlockButton
@onready var _buy_button: Button = %BuyButton
@onready var _trial_button: Button = %TrialButton
@onready var _trial_note: Label = %TrialNote
@onready var _lesson_button: Button = %LessonButton


func _ready() -> void:
	visible = false


## status·veiled·offer는 CharacterCollection이, tiers는 AchievementTracker.chain_status가 정한 값 (비어 있으면 "준비 중").
## has_lesson = 캐릭터 튜토리얼이 있는지 (가진 캐릭터면 "튜토리얼 다시 하기").
func open(data: CharacterData, status: CharacterCollection.Status, veiled: bool, offer: CharacterCollection.Offer,
		tiers: Array[AchievementTracker.TierStatus], has_lesson: bool = false) -> void:
	character = data
	_show_header(data, veiled)
	_show_details(data, veiled)
	_show_achievements(tiers)
	_show_actions(data, status, veiled, offer)
	var owned: bool = status == CharacterCollection.Status.EQUIPPED or status == CharacterCollection.Status.OWNED
	_lesson_button.visible = owned and has_lesson
	visible = true


## 보이는 업적 줄 (테스트/디버그용).
func achievement_rows() -> Array[AchievementRow]:
	var rows: Array[AchievementRow] = []
	for row: Node in _achievement_list.get_children():
		if not row.is_queued_for_deletion():
			rows.append(row as AchievementRow)
	return rows


func _show_achievements(tiers: Array[AchievementTracker.TierStatus]) -> void:
	for row: Node in _achievement_list.get_children():
		_achievement_list.remove_child(row)
		row.queue_free()
	_achievements_pending.visible = tiers.is_empty()
	if achievement_row_scene == null:
		return
	for status: AchievementTracker.TierStatus in tiers:
		var row: AchievementRow = achievement_row_scene.instantiate() as AchievementRow
		_achievement_list.add_child(row)
		row.show_status(status)


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _show_header(data: CharacterData, veiled: bool) -> void:
	_name_label.text = "???" if veiled else data.display_name
	_grade_label.text = CharacterData.GRADE_NAMES[data.grade]
	_grade_label.add_theme_color_override("font_color", theme_data.grade_color(data.grade))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.22, 0.25, 1) if veiled else data.player_fill
	style.border_color = style.bg_color if veiled else data.player_border
	style.set_border_width_all(int(theme_data.player_border_width))
	if _portrait.show_character(data, veiled):
		style.bg_color = Color.TRANSPARENT
	_preview.add_theme_stylebox_override("panel", style)


func _show_details(data: CharacterData, veiled: bool) -> void:
	var show_recipe: bool = data.has_recipe() and not veiled
	_condition.visible = show_recipe
	if show_recipe:
		_condition.show_recipe(RecipeSet.Recipe.new(data.condition_colors, 0), data.ability_name)
		_condition.set_border_color(data.accent_color)
	_passive_label.visible = not show_recipe and not veiled
	_passive_label.text = "상시형 · 항상 켜짐" if data.has_ability() else "능력 없음"
	var texts: Dictionary[String, String] = {
		"effect": data.detail_effect if not data.detail_effect.is_empty() else data.ability_description,
		"when": data.detail_when, "tip": data.detail_tip,
	}
	for key: String in _sections:
		var label: Label = _sections[key]
		label.text = texts[key]
		label.get_parent().visible = not veiled and not texts[key].is_empty()  # 제목 + 본문 묶음
	_hidden_note.visible = veiled
	_achievements.visible = not veiled and data.grade != CharacterData.Grade.BASIC


## HTML 순서: 선택권(있을 때만) → 다이아(상점에 열렸으면 "◆ p로 해금", 아니면 열리는 레벨 안내) → 체험.
func _show_actions(data: CharacterData, status: CharacterCollection.Status, veiled: bool, offer: CharacterCollection.Offer) -> void:
	var owned: bool = status == CharacterCollection.Status.EQUIPPED or status == CharacterCollection.Status.OWNED
	var purchasable: bool = not owned and CharacterCollection.is_gacha(data)
	_equip_button.visible = owned
	_equip_button.disabled = status == CharacterCollection.Status.EQUIPPED
	_equip_button.text = "장착 중" if status == CharacterCollection.Status.EQUIPPED else "장착하기"
	_unlock_button.visible = purchasable and offer.tickets > 0
	_unlock_button.text = "%s 선택권으로 해금 · %d장" % [CharacterData.GRADE_NAMES[data.grade], offer.tickets]
	_buy_button.visible = purchasable
	_buy_button.disabled = not offer.shop_open or not offer.affordable
	_buy_button.text = "◆ %d로 해금" % offer.diamond_price if offer.shop_open \
		else "상점에서 Lv %d부터 ◆ %d" % [offer.shop_level, offer.diamond_price]
	_trial_button.visible = not owned and not veiled
	_trial_note.visible = _trial_button.visible


## 보이는 버튼 문구 (테스트/디버그용). 숨은 버튼은 빠진다.
func shown_actions() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for button: Button in [_equip_button, _unlock_button, _buy_button, _trial_button, _lesson_button]:
		if button.visible:
			texts.append(button.text)
	return texts


func _on_equip_button_pressed() -> void:
	equip_requested.emit(character)


func _on_unlock_button_pressed() -> void:
	unlock_requested.emit(character)


func _on_buy_button_pressed() -> void:
	buy_requested.emit(character)


func _on_trial_button_pressed() -> void:
	trial_requested.emit(character)


func _on_lesson_button_pressed() -> void:
	lesson_requested.emit(character)


func _on_close_pressed() -> void:
	close()
