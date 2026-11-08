class_name CharacterCard
extends Button
## 캐릭터 화면의 카드 (기획서 8.1장): 플레이어 외형, 이름, 등급(등급 색), 상태(장착 중·보유·선택권·히든 업적·◆ 가격·상점 Lv N),
## 캐릭터 족보(발동형) 또는 "항상 켜짐"(상시형). 얻기 전 히든 캐릭터는 "???"로 가린다.
## 눌리면 chosen을 보낸다 (상세 시트는 CharacterSelect가 연다). 장착 중 강조는 show_status로만 바꾼다.

signal chosen(character: CharacterData)

@export var theme_data: BoardTheme
## 카드 안 족보 칸 크기 (카드 폭에 5칸 족보가 들어가게).
@export var step_size: float = 39.0
## 잠긴 카드 밝기.
@export var locked_alpha: float = 0.55
## 가린 히든 카드의 외형 색.
@export var veiled_fill: Color = Color(0.2, 0.22, 0.25, 1)

var character: CharacterData
var status: CharacterCollection.Status = CharacterCollection.Status.LOCKED
var veiled: bool = false

@onready var _preview: Panel = %Preview
@onready var _portrait: PortraitRect = %Portrait
@onready var _name_label: Label = %NameLabel
@onready var _grade_label: Label = %GradeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _condition: RecipeView = %Condition
@onready var _passive_label: Label = %PassiveLabel


func setup(data: CharacterData, p_veiled: bool) -> void:
	character = data
	veiled = p_veiled
	_name_label.text = "???" if veiled else data.display_name
	_grade_label.text = CharacterData.GRADE_NAMES[data.grade]
	_grade_label.add_theme_color_override("font_color", theme_data.grade_color(data.grade))
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = veiled_fill if veiled else data.player_fill
	style.border_color = veiled_fill if veiled else data.player_border
	style.set_border_width_all(int(theme_data.player_border_width))
	if _portrait.show_character(data, veiled):  # 캐릭터 이미지가 있으면 채움색 대신 이미지
		style.bg_color = Color.TRANSPARENT
	_preview.add_theme_stylebox_override("panel", style)
	var show_recipe: bool = data.has_recipe() and not veiled
	_condition.visible = show_recipe
	_passive_label.visible = not show_recipe
	_passive_label.text = "?" if veiled else ("항상 켜짐" if data.has_ability() else "능력 없음")
	if show_recipe:
		_condition.set_step_size(step_size)
		_condition.show_recipe(RecipeSet.Recipe.new(data.condition_colors, 0), data.ability_name)
		_condition.set_border_color(data.accent_color)


## text = CharacterCollection.status_text (예: "◆ 200", "상점 Lv 8").
func show_status(p_status: CharacterCollection.Status, text: String) -> void:
	status = p_status
	_status_label.text = text
	set_pressed_no_signal(status == CharacterCollection.Status.EQUIPPED)
	var owned: bool = status == CharacterCollection.Status.EQUIPPED or status == CharacterCollection.Status.OWNED
	modulate.a = 1.0 if owned or status == CharacterCollection.Status.TICKET else locked_alpha


## 카드에 보이는 이름·상태 (테스트/디버그용).
func shown_name() -> String:
	return _name_label.text


func shown_status() -> String:
	return _status_label.text


## pressed signal (character_card.tscn에서 연결).
func _on_pressed() -> void:
	set_pressed_no_signal(status == CharacterCollection.Status.EQUIPPED)  # 토글 표시는 장착 상태만 따른다
	chosen.emit(character)
