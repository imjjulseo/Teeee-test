class_name SpotlightOverlay
extends CanvasLayer
## 스포트라이트 (기획서 8.8장, HTML #tsp · #tspCap): 화면을 살짝 어둡게 덮고 볼 곳(holes)만 가장자리가 부드럽게 밝힌다
## (HTML: 여백 16 · 모서리 28 · 흐림 16px 마스크, 구멍이 없으면 막도 없음, 처음 뜰 때 0.45초 서서히). 아래(또는 위)에 설명 칸:
## 왼쪽 아이콘(CaptionIcon) · 진행 막대(SegmentBar) · 제목 · 설명 · 퍼즐 줄(Foot = TutorialPuzzleBar) · 오른쪽 노란 버튼 또는 탭 고리.
## 건너뛰기는 설명 칸 위 오른쪽 알약 버튼.
## - TAP: 아무 곳이나 누르면 tapped (판은 주인이 멈춘다). 버튼 문구가 있으면 그 버튼으로.
## - ACT: 판을 직접 조작한다 — 어두운 막이 손을 막지 않는다 (설명만 떠 있다).
## 버튼이 둘이면(alt_text) 두 번째 버튼은 alt_pressed (첫 사용 질문의 "바로 시작"). 건너뛰기를 누르면 skip_requested. 구멍 자리는 주인이 매 프레임 update_holes로 넘긴다 (캔버스 좌표).

signal tapped
signal skip_requested
signal alt_pressed

enum Mode { TAP, ACT }

## 구멍 최대 수 (셰이더 배열 크기).
const MAX_HOLES: int = 8

## 구멍 여백·모서리·가장자리 흐림·최소 크기 (HTML 16 · 28 · 흐림 16 · 최소 40 css px를 1080 기준으로).
@export var hole_pad: float = 42.0
@export var hole_radius: float = 75.0
@export var hole_feather: float = 67.5
@export var hole_min: float = 106.0
## 막이 처음 뜰 때 서서히 나타나는 시간(초).
@export var fade_time: float = 0.45
## 설명 칸이 화면 끝에서 떨어진 거리, 건너뛰기 알약이 칸 위로 뜬 거리.
@export var caption_margin: float = 60.0
@export var skip_gap: float = 18.0

var mode: Mode = Mode.TAP
var _holes: Array[Rect2] = []

@onready var _blocker: Control = %Blocker
@onready var _dim: ColorRect = %Dim
@onready var _caption: PanelContainer = %Caption
@onready var _icon: CaptionIcon = %Icon
@onready var _segments: SegmentBar = %Segments
@onready var _foot: TutorialPuzzleBar = %Foot
@onready var _head: Label = %CaptionHead
@onready var _text: Label = %CaptionText
@onready var _button: Button = %CaptionButton
@onready var _alt_button: Button = %AltButton
@onready var _skip: Button = %SkipButton
@onready var _tap_hint: TapRing = %TapHint

var _fade: Tween


func _ready() -> void:
	var material: ShaderMaterial = _dim.material as ShaderMaterial
	material.set_shader_parameter("dim_color", _dim.get_theme_color(&"spotlight_dim", DesignTokens.THEME_TYPE))
	material.set_shader_parameter("radius", hole_radius)
	material.set_shader_parameter("feather", hole_feather)
	material.set_shader_parameter("min_size", hole_min)
	close()


## 설명을 띄운다. top이면 화면 위쪽에.
func open(p_mode: Mode, head: String, text: String, holes: Array[Rect2], button_text: String = "", skippable: bool = true, top: bool = false,
		alt_text: String = "") -> void:
	mode = p_mode
	var was_open: bool = visible
	visible = true
	_icon.show_icon(CaptionIcon.Kind.NONE)
	_segments.show_progress(0, 0)
	if not was_open:
		_fade_in()
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


## 설명 칸 왼쪽 아이콘 (HTML icon: ㅗ 모양 · 족보 점 · 금화 · 시계 · 씨앗). open이 지우므로 open 뒤에 부른다.
func set_icon(kind: CaptionIcon.Kind, colors: PackedInt32Array = PackedInt32Array()) -> void:
	_icon.show_icon(kind, colors)


## 진행 막대 (count 0이면 숨김).
func set_progress(index: int, count: int) -> void:
	_segments.show_progress(index, count)


## 설명 칸 안의 퍼즐 줄 (수 · 되돌리기 · 처음부터 · 힌트).
func foot() -> TutorialPuzzleBar:
	return get_node("%Foot") as TutorialPuzzleBar  # 형제 노드의 _ready 전에도 부를 수 있게


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
	_dim.visible = visible and not _holes.is_empty()  # HTML: 구멍이 없으면 막도 없음
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


func _fade_in() -> void:
	if _fade != null:
		_fade.kill()
	_dim.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_dim, "modulate:a", 1.0, fade_time)


## 칸은 내용 높이만큼, 아래(위)에서 caption_margin 떨어져 자란다.
func _place_caption(top: bool) -> void:
	_caption.anchor_top = 0.0 if top else 1.0
	_caption.anchor_bottom = 0.0 if top else 1.0
	_caption.offset_top = caption_margin if top else -caption_margin
	_caption.offset_bottom = caption_margin if top else -caption_margin
	_caption.grow_vertical = Control.GROW_DIRECTION_END if top else Control.GROW_DIRECTION_BEGIN
	_place_skip.call_deferred()


## 건너뛰기 알약: 칸 위 오른쪽 (위쪽 칸이면 칸 아래).
func _place_skip() -> void:
	var at_top: bool = _caption.anchor_top == 0.0
	var x: float = _caption.position.x + _caption.size.x - _skip.size.x - 27.0
	var y: float = _caption.position.y + _caption.size.y + skip_gap if at_top else _caption.position.y - _skip.size.y - skip_gap
	_skip.position = Vector2(x, y)


func _on_caption_resized() -> void:
	if is_node_ready():
		_place_skip()


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
