class_name SpotlightOverlay
extends CanvasLayer
## 스포트라이트 (기획서 8.8장, HTML 10/18 튜토리얼): 볼 곳(holes)만 밝게 남기고 나머지를 어둡게, 아래(또는 위)에 한 줄 설명.
## - TAP: 아무 곳이나 누르면 tapped (판은 주인이 멈춘다). 버튼 문구가 있으면 그 버튼으로.
## - ACT: 판을 직접 조작한다 — 어두운 막이 손을 막지 않는다 (설명만 떠 있다).
## 버튼이 둘이면(alt_text) 두 번째 버튼은 alt_pressed (첫 사용 질문의 "바로 시작"). 건너뛰기를 누르면 skip_requested. 구멍 자리는 주인이 매 프레임 update_holes로 넘긴다 (캔버스 좌표).

signal tapped
signal skip_requested
signal alt_pressed

enum Mode { TAP, ACT }

## 구멍 최대 수 (셰이더 배열 크기).
const MAX_HOLES: int = 8

@export var hole_pad: float = 6.0

var mode: Mode = Mode.TAP
var _holes: Array[Rect2] = []

@onready var _blocker: Control = %Blocker
@onready var _dim: ColorRect = %Dim
@onready var _rings: SpotlightRings = %Rings
@onready var _caption: PanelContainer = %Caption
@onready var _head: Label = %CaptionHead
@onready var _text: Label = %CaptionText
@onready var _button: Button = %CaptionButton
@onready var _alt_button: Button = %AltButton
@onready var _skip: Button = %SkipButton
@onready var _tap_hint: Label = %TapHint


func _ready() -> void:
	close()


## 설명을 띄운다. top이면 화면 위쪽에.
func open(p_mode: Mode, head: String, text: String, holes: Array[Rect2], button_text: String = "", skippable: bool = true, top: bool = false,
		alt_text: String = "") -> void:
	mode = p_mode
	visible = true
	_head.text = head
	_head.visible = not head.is_empty()
	_text.text = text
	_text.visible = not text.is_empty()
	_button.visible = not button_text.is_empty()
	_button.text = button_text
	_alt_button.visible = not alt_text.is_empty()
	_alt_button.text = alt_text
	_skip.visible = skippable
	_tap_hint.visible = mode == Mode.TAP and button_text.is_empty()
	_blocker.visible = mode == Mode.TAP
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE if mode == Mode.ACT else Control.MOUSE_FILTER_STOP
	_place_caption(top)
	update_holes(holes)


## 조작 설명의 한 줄만 바꾼다 (진행 수 "2 / 5").
func set_text(text: String, head: String = "") -> void:
	_text.text = text
	_text.visible = not text.is_empty()
	if not head.is_empty():
		_head.text = head


func close() -> void:
	visible = false
	_holes.clear()
	if _dim != null:
		_apply_holes()


func is_open() -> bool:
	return visible


func is_blocking() -> bool:
	return visible and mode == Mode.TAP


func update_holes(holes: Array[Rect2]) -> void:
	_holes = holes.slice(0, MAX_HOLES)
	_apply_holes()


func caption_head() -> String:
	return _head.text if visible else ""


func caption_text() -> String:
	return _text.text if visible else ""


func _apply_holes() -> void:
	var material: ShaderMaterial = _dim.material as ShaderMaterial
	_dim.visible = visible and not _holes.is_empty()
	if material != null:
		var packed: Array[Vector4] = []
		for rect: Rect2 in _holes:
			packed.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		while packed.size() < MAX_HOLES:
			packed.append(Vector4.ZERO)
		material.set_shader_parameter("holes", packed)
		material.set_shader_parameter("hole_count", _holes.size())
		material.set_shader_parameter("rect_size", _dim.size)
		material.set_shader_parameter("pad", hole_pad)
	var rings: Array[Rect2] = []
	for rect: Rect2 in _holes:
		rings.append(rect.grow(hole_pad))
	_rings.show_rects(rings if visible else ([] as Array[Rect2]))


func _place_caption(top: bool) -> void:
	_caption.anchor_top = 0.0 if top else 1.0
	_caption.anchor_bottom = 0.0 if top else 1.0
	_caption.offset_top = 40.0 if top else -270.0
	_caption.offset_bottom = 270.0 if top else -40.0


## 막이나 설명 칸을 누름 (TAP 모드, 버튼이 없을 때만 — 버튼이 있으면 그 버튼으로).
func _on_blocker_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT):
		return
	get_viewport().set_input_as_handled()
	if mode == Mode.TAP and not _button.visible:
		tapped.emit()


func _on_caption_button_pressed() -> void:
	tapped.emit()


func _on_alt_button_pressed() -> void:
	alt_pressed.emit()


## 보이는 버튼 문구 (테스트/디버그용).
func button_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for button: Button in [_alt_button, _button]:
		if visible and button.visible:
			texts.append(button.text)
	return texts


func _on_skip_button_pressed() -> void:
	skip_requested.emit()


func _on_dim_resized() -> void:
	if is_node_ready():  # 트리에 들어가며 _ready 전에도 온다
		_apply_holes()
