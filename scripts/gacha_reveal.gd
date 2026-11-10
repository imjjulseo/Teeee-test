class_name GachaReveal
extends Control
## 뽑기 결과 카드 (기획서 8.5장 연출): 등급 색 테두리 카드가 뒤집히며 캐릭터가 나온다. 새 캐릭터는 "NEW",
## 중복이면 "<등급> 선택권". 확인 버튼 → closed. 화면을 누르면 뒤집기를 바로 끝낸다.

signal closed

@export var theme_data: BoardTheme

var result: CharacterShop.PullResult
var _tween: Tween

@onready var _card: PanelContainer = %Card
@onready var _swatch: Panel = %RevealSwatch
@onready var _portrait: PortraitRect = %Portrait
@onready var _name_label: Label = %RevealName
@onready var _grade_label: Label = %RevealGrade
@onready var _tag_label: Label = %RevealTag
@onready var _ok_button: Button = %OkButton


func _ready() -> void:
	visible = false


## flip_time = 0이면 (효과 줄이기) 바로 보인다.
func show_result(p_result: CharacterShop.PullResult, flip_time: float) -> void:
	result = p_result
	var color: Color = theme_data.grade_color(result.grade)
	var card_box: StyleBox = _card.get_theme_stylebox("panel")
	if card_box is StyleBoxFlat:  # 등급 색 테두리 (이미지 판넬이면 그대로)
		var card_style: StyleBoxFlat = card_box.duplicate() as StyleBoxFlat
		card_style.border_color = color
		_card.add_theme_stylebox_override("panel", card_style)
	var swatch_style: StyleBoxFlat = StyleBoxFlat.new()
	swatch_style.bg_color = result.character.accent_color
	swatch_style.set_corner_radius_all(24)
	if _portrait.show_character(result.character):
		swatch_style.bg_color = Color.TRANSPARENT
	_swatch.add_theme_stylebox_override("panel", swatch_style)
	_name_label.text = result.character.display_name
	_grade_label.text = CharacterData.GRADE_NAMES[result.grade]
	_grade_label.add_theme_color_override("font_color", color)
	_tag_label.text = GachaReveal.tag_text(result)
	visible = true
	_flip(flip_time)


## 결과 카드의 표시 문구: 새 캐릭터 "NEW", 중복 "<등급> 선택권".
static func tag_text(p_result: CharacterShop.PullResult) -> String:
	return "NEW" if p_result.is_new else "%s 선택권" % CharacterData.GRADE_NAMES[p_result.grade]


func tag() -> String:
	return _tag_label.text


func _flip(flip_time: float) -> void:
	if _tween != null:
		_tween.kill()
	_card.pivot_offset = _card.size / 2.0
	_ok_button.disabled = flip_time > 0.0
	if flip_time <= 0.0:
		_card.scale = Vector2.ONE
		return
	_card.scale = Vector2(0.0, 1.0)
	_tween = create_tween()
	_tween.tween_property(_card, "scale", Vector2.ONE, flip_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(_finish_flip)


func _finish_flip() -> void:
	_card.scale = Vector2.ONE
	_ok_button.disabled = false


## 화면 아무 곳 (gacha_reveal.tscn에서 연결): 뒤집는 중이면 바로 끝낸다.
func _on_dim_pressed() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
		_finish_flip()


func _on_ok_button_pressed() -> void:
	visible = false
	closed.emit()
