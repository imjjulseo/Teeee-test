class_name CharacterRow
extends PanelContainer
## HUD 캐릭터 줄 (족보 카드 아래 한 줄): 왼쪽 아이콘(캐릭터 이미지, 없으면 캐릭터 색 칸에 이름 첫 글자), 이름, 등급 문자 + 상태
## (남은 초·스택) + 지속 효과 남은 시간 막대, 오른쪽에 능력 발동 족보 점(발동형) 또는 능력 이름(상시형).
## 캐릭터 색 테두리·은은한 바탕, 빛 띠가 계속 지나가고(HTML sheen), 발동하면 커졌다 돌아오며 빛이 퍼진다(HTML chrBurst).
## 판넬 모양은 테마 변형 CharacterRowPanel (이미지 판넬로 바꿀 수 있음, 그때는 테두리 색을 바꾸지 않는다).
## 효과 줄이기면 빛 띠·발동 연출을 끈다. 로직을 읽기만 한다.

@export var theme_data: BoardTheme

var _accent: Color = Color.WHITE
var _style: StyleBoxFlat
var _reduce_motion: bool = false
## 지속 효과: 이번 효과의 처음 길이 (남은 시간이 늘면 새로 잰다).
var _effect_total: float = 0.0
var _sheen_t: float = 0.0
var _burst_tween: Tween
## 튜토리얼이 이 줄을 가리키는 중: 테두리 밖으로 캐릭터 색 빛이 맥박처럼 (HTML ctPulse 1.2초).
var highlight: bool = false

@onready var _icon: Panel = %CharIcon
@onready var _portrait: PortraitRect = %CharPortrait
@onready var _initial: Label = %CharInitial
@onready var _name: Label = %CharName
@onready var _grade: Label = %CharGrade
@onready var _status: Label = %CharStatus
@onready var _bar: Control = %CharBar
@onready var _bar_fill: ColorRect = %CharBarFill
@onready var _sheen: ColorRect = %Sheen
## 능력 발동 족보 점 (RecipeView, 점만).
@onready var recipe_view: RecipeView = %AbilityView


func _ready() -> void:
	var box: StyleBox = get_theme_stylebox("panel")
	if box is StyleBoxFlat:
		_style = box.duplicate() as StyleBoxFlat
		add_theme_stylebox_override("panel", _style)
	_bar.visible = false


## 캐릭터를 보인다. 능력이 없으면 줄을 숨긴다 (HUD 높이는 그대로라 판 크기는 변하지 않는다).
func show_character(character: CharacterData) -> void:
	visible = character != null and character.has_ability()
	if not visible:
		return
	_accent = character.accent_color
	_name.text = character.display_name
	_grade.text = character.grade_letter()
	_grade.visible = not _grade.text.is_empty()
	var has_art: bool = _portrait.show_character(character)
	_initial.visible = not has_art
	_initial.text = character.display_name.left(1)
	var icon_box: StyleBox = _icon.get_theme_stylebox("panel")
	if icon_box is StyleBoxFlat:
		var icon_style: StyleBoxFlat = icon_box.duplicate() as StyleBoxFlat
		icon_style.bg_color = Color.TRANSPARENT if has_art else _accent
		_icon.add_theme_stylebox_override("panel", icon_style)
	if _style != null:
		_style.border_color = _accent
		_style.bg_color = theme_data.recipe_card_bg.lerp(_accent, theme_data.character_row_tint)
	_bar_fill.color = _accent
	var band: Color = _accent
	band.a = theme_data.character_row_sheen_alpha
	(_sheen.material as ShaderMaterial).set_shader_parameter("band_color", band)


## 둘째 줄 상태 문구 (남은 초·스택). 비어 있으면 능력 이름.
func show_status(text: String, fallback: String) -> void:
	_status.text = text if not text.is_empty() else fallback


## 지속 효과 남은 시간 (음수 = 꺼짐, INF = 끝없음). 켜져 있으면 막대로 보인다.
func show_effect(remaining: float) -> void:
	if remaining < 0.0 or is_inf(remaining):
		_bar.visible = false
		_effect_total = 0.0
		return
	if remaining > _effect_total:
		_effect_total = remaining
	_bar.visible = true
	_bar_fill.anchor_right = clampf(remaining / maxf(_effect_total, 0.001), 0.0, 1.0)


func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled
	_sheen.visible = not enabled
	recipe_view.set_reduce_motion(enabled)


## 능력 발동 (HTML chrBurst 0.6초 ease-out: 1.08배·빛 → 원래).
func play_burst() -> void:
	if _reduce_motion or not is_inside_tree():
		return
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	pivot_offset = size / 2.0
	var b: float = theme_data.character_burst_brightness
	_burst_tween = KeyframeAnim.play(self, self, theme_data.character_burst_duration, [
		[0.0, {"scale": Vector2.ONE * theme_data.character_burst_scale, "modulate": Color(b, b, b, 1.0)}],
		[1.0, {"scale": Vector2.ONE, "modulate": Color.WHITE}],
	], KeyframeAnim.EASE_OUT)


func _process(delta: float) -> void:
	if not visible:
		return
	if not _reduce_motion:
		# HTML sheen 3.8초: 0~55% 왼쪽 → 오른쪽 (ease-in-out), 그 뒤 쉼.
		_sheen_t = fmod(_sheen_t + delta / theme_data.character_row_sheen_period, 1.0)
		var e: float = KeyframeAnim.bezier(KeyframeAnim.EASE_IN_OUT, minf(_sheen_t / 0.55, 1.0))
		(_sheen.material as ShaderMaterial).set_shader_parameter("offset", lerpf(-0.45, 0.45, e))
		(_sheen.material as ShaderMaterial).set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	if _style != null:
		var glow: float = 0.0
		if highlight and not _reduce_motion:
			glow = 0.5 - 0.5 * cos(Time.get_ticks_msec() / 1000.0 / theme_data.character_row_pulse_period * TAU)
		_style.shadow_color = Color(_accent.r, _accent.g, _accent.b, glow * 0.8)
		_style.shadow_size = int(glow * theme_data.character_row_pulse_size)
