class_name Hud
extends CanvasLayer
## 플레이 HUD (기획서 7.1): 위 줄(일시정지 · 점수 · 주운 코인 · 남은 시간), 시간 막대, 족보 카드 + 캐릭터 카드,
## 아래 메시지 줄. 점수는 부드럽게 차오르고, 매치 시간·금화는 떠오르는 숫자로 보여준다 (7.2).
## 캐릭터 카드: 캐릭터 족보와 둘째 줄 상태(남은 초·스택). 카드가 있으면 4개가 한 줄에 들어가도록 족보 칸을 줄인다.
## 능력 발동: 캐릭터 색 섬광 + 배너("촉진!" + 설명) + 메시지 줄에 결과 문구. 족보 밖 점수(피버 정산)도 배너로.
## 게임 상태를 바꾸지 않고, 버튼 입력은 pause_requested signal로만 알린다.

signal pause_requested
## 경고 구간에서 매 초 1회 (틱 사운드용).
signal warning_tick

const WAITING_CUE: String = "움직이면 시작. 깨면 시간, 족보를 완성하면 점수"

@export var config: GameConfig
@export var theme_data: BoardTheme
## 화면 공통 이미지 (코인 아이콘).
@export var ui_assets: UiAssets
@export var floating_text_scene: PackedScene

## 경고 구간에서 마지막으로 펄스를 준 정수 초. 매 초 한 번만 펄스한다 (-1 = 경고 구간 밖).
var _last_warning_second: int = -1
## 현재 시간 색 (투명 = 아직 설정 안 함).
var _time_color: Color = Color(0, 0, 0, 0)
var _popup_tween: Tween
var _popup_home_y: float = 0.0
## 점수 표시: 실제 점수(목표)를 향해 부드럽게 차오른다.
var _score_target: int = 0
var _score_shown: float = 0.0
## 효과 줄이기 옵션 (펄스·떠오르는 숫자·배너 확대 끔).
var _reduce_motion: bool = false
## 캐릭터 색 (섬광·배너·캐릭터 카드 테두리).
var _accent: Color = Color.WHITE
## 배너 테두리를 캐릭터 색으로 칠할 스타일 (테마의 배너가 이미지 판넬이면 null — 색을 바꾸지 않는다).
var _banner_style: StyleBoxFlat
var _banner_tween: Tween
var _flash_tween: Tween

@onready var _time_label: Label = %TimeLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _coin_label: Label = %CoinLabel
## 코인 아이콘 (UiAssets.coin_icon, 없으면 숨기고 글자 "●").
@onready var _coin_icon: TextureRect = %CoinIcon
@onready var _time_bar: Control = %TimeBar
@onready var _time_fill: ColorRect = %Fill
@onready var _message_label: Label = %MessageLabel
@onready var _pause_button: Button = %PauseButton
@onready var _recipe_views: Array[RecipeView] = [%Recipe0, %Recipe1, %Recipe2]
@onready var _score_popup: Label = %ScorePopup
## 캐릭터 카드 (캐릭터 족보 + 둘째 줄 상태).
@onready var _ability_view: RecipeView = %AbilityView
@onready var _floats: Control = %Floats
@onready var _flash: ColorRect = %Flash
## 발동 섬광 이미지 (BoardTheme.ability_flash_texture, 없으면 숨김 → 단색 섬광).
@onready var _flash_art: TextureRect = %FlashArt
@onready var _banner: PanelContainer = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_sub: Label = %BannerSub


func _ready() -> void:
	_popup_home_y = _score_popup.position.y
	_score_popup.modulate.a = 0.0
	# 배너 테두리를 캐릭터 색으로 바꾸므로 씬의 스타일을 복제해 쓴다 (이미지 판넬이면 그대로).
	var banner_box: StyleBox = _banner.get_theme_stylebox("panel")
	if banner_box is StyleBoxFlat:
		_banner_style = banner_box.duplicate() as StyleBoxFlat
		_banner.add_theme_stylebox_override("panel", _banner_style)
	_flash_art.texture = theme_data.ability_flash_texture
	_coin_icon.texture = ui_assets.coin_icon if ui_assets != null else null
	_coin_icon.visible = _coin_icon.texture != null
	_flash_art.visible = _flash_art.texture != null


## 튜토리얼 스포트라이트가 밝힐 HUD 자리 (캔버스 좌표): cards(보이는 족보 카드) · chr(캐릭터 카드) · score · coin · time.
func target_rects(target: String) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	match target:
		"cards":
			for view: RecipeView in _recipe_views:
				if view.is_visible_in_tree():
					rects.append(view.get_global_rect())
		"chr":
			if _ability_view.is_visible_in_tree():
				rects.append(_ability_view.get_global_rect())
		"score":
			rects.append(_score_label.get_global_rect())
		"coin":
			rects.append(_coin_label.get_global_rect())
		"time":
			rects.append(_time_label.get_global_rect().merge(_time_bar.get_global_rect()))
		"card:0", "card:1", "card:2":  # 족보 카드 한 장
			var slot: int = int(target.get_slice(":", 1))
			if slot < _recipe_views.size() and _recipe_views[slot].is_visible_in_tree():
				rects.append(_recipe_views[slot].get_global_rect())
	return rects


## 점수를 실제 점수 쪽으로 부드럽게 올린다 (초당 score_count_speed 비율).
func _process(delta: float) -> void:
	if is_equal_approx(_score_shown, _score_target):
		return
	_score_shown += (_score_target - _score_shown) * minf(1.0, delta * theme_data.score_count_speed)
	if absf(_score_target - _score_shown) < 0.5:
		_score_shown = _score_target
	_score_label.text = str(roundi(_score_shown))


## 남은 시간·시간 막대. fraction은 막대 길이 0~1, clock_stopped는 능력(시계공 "정지")으로 시간이 멈춘 상태.
func _on_time_updated(remaining: float, fraction: float, clock_stopped: bool) -> void:
	_time_label.text = "%.1f" % remaining
	_time_fill.anchor_right = clampf(fraction, 0.0, 1.0)
	if clock_stopped:
		_set_time_color(theme_data.hud_time_stop_color)
		return
	if remaining >= config.warning_time_threshold:
		_last_warning_second = -1
		_set_time_color(theme_data.hud_time_color)
		return
	_set_time_color(theme_data.hud_warning_color)
	var second: int = ceili(remaining)
	if second != _last_warning_second and remaining > 0.0:
		_last_warning_second = second
		_pulse_time_label()
		warning_tick.emit()


## 매치로 얻은 시간: 시간 옆에 "+2.5"가 떠오른다.
func _on_time_gained(seconds: float) -> void:
	_float_near(_time_label, "+%s" % _format_seconds(seconds), theme_data.hud_time_color)


## 판에서 주운 코인. amount > 0이면 방금 주운 것: "+10" (연속이면 "금화 N연속!")이 떠오른다.
func _on_coins_updated(total: int, amount: int, chain: int) -> void:
	_coin_label.text = ("%d" if _coin_icon.visible else "● %d") % total
	if amount <= 0:
		return
	_float_near(_coin_label, "+%d" % amount, theme_data.coin_color)
	if chain > 1:
		_float_near(_coin_label, "금화 %d연속!" % chain, theme_data.coin_color, theme_data.float_rise)


## 캐릭터 카드 둘째 줄 (예: "3.7초", "×2 (2)", "와일드 2"). 비어 있으면 능력 이름. 문구는 능력이 정한다.
func _on_ability_status(text: String) -> void:
	_ability_view.show_status(text)


## 족보 밖 점수 (피버 정산 등): 배너 + 점수 옆에 떠오르는 숫자.
func _on_bonus_scored(points: int, label: String) -> void:
	var amount: String = ("+%d" if points >= 0 else "%d") % points  # 음수(마탄 저주)는 부호 그대로
	_show_banner(label, amount)
	_float_near(_score_label, amount, _accent)


func _on_reduce_motion_ready(enabled: bool) -> void:
	_reduce_motion = enabled


## 남은 시간이 경고 구간인지 (테스트/디버그용).
func is_time_warning() -> bool:
	return _time_color == theme_data.hud_warning_color


## 지금 화면에 보이는 점수 (테스트/디버그용).
func shown_score() -> int:
	return roundi(_score_shown)


func _on_score_changed(score: int) -> void:
	_score_target = score
	if score < _score_shown:  # 새 판: 바로 맞춘다
		_score_shown = score
		_score_label.text = str(score)


func _on_recipes_updated(recipes: RecipeSet, outcome: RecipeSet.ClearOutcome) -> void:
	for view: RecipeView in _recipe_views:
		view.visible = view.slot < recipes.slot_count()
		if not view.visible:
			continue
		view.show_recipe(recipes.recipes[view.slot])
		if outcome.completed_slots.has(view.slot):
			view.play_complete()
	if outcome.points > 0:
		_show_popup("+%d" % outcome.points)


## 캐릭터 카드 (족보 카드 오른쪽). 발동형은 캐릭터 족보, 상시형은 이름·상태만. 능력이 없으면 숨기고
## 족보 칸을 기본 크기로 둔다.
func _on_ability_updated(recipe: RecipeSet.Recipe, character: CharacterData) -> void:
	if character != null:
		_accent = character.accent_color
		_ability_view.set_border_color(_accent)
	var has_card: bool = character != null and character.has_ability()
	_ability_view.visible = has_card
	var step: float = theme_data.recipe_step_size_compact if has_card else theme_data.recipe_step_size
	for view: RecipeView in _recipe_views:
		view.set_step_size(step)
	_ability_view.set_step_size(step)
	if recipe != null:
		_ability_view.show_recipe(recipe, character.ability_name)
	elif has_card:
		_ability_view.show_passive(character.ability_name)


## 능력의 표시 방식 (색약 색 합치기, 레트로 흑백)을 족보 카드·캐릭터 카드에.
func _on_display_style_changed(style: DisplayStyle) -> void:
	for view: RecipeView in _recipe_views:
		view.set_display_style(style)
	_ability_view.set_display_style(style)


## 능력이 알리는 문구 (현상금 색 변경 등)를 메시지 줄에.
func _on_ability_announced(text: String) -> void:
	_message_label.text = text


## 능력 발동: 캐릭터 카드 강조, 캐릭터 색 섬광, 배너, 메시지 줄에 결과 문구 (7.2).
func _on_ability_triggered(character: CharacterData, message: String) -> void:
	_ability_view.play_complete()
	_flash_screen()
	if character != null:
		_show_banner("%s!" % character.ability_name, character.ability_description)
	_message_label.text = message


## 지금 배너 제목 (보이지 않으면 빈 문자열, 테스트/디버그용).
func banner_title() -> String:
	return _banner_title.text if _banner.visible else ""


## 지금 메시지 줄 (테스트/디버그용).
func message_text() -> String:
	return _message_label.text


func _on_state_changed(state: GameFlow.GameState) -> void:
	_pause_button.visible = state == GameFlow.GameState.WAITING or state == GameFlow.GameState.PLAYING
	_message_label.text = WAITING_CUE if state == GameFlow.GameState.WAITING else ""


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


## 시간 색은 실제로 바뀔 때만 다시 설정한다 (테마 재계산 비용). 글자와 막대를 같은 색으로.
func _set_time_color(color: Color) -> void:
	if _time_color == color:
		return
	_time_color = color
	_time_label.add_theme_color_override("font_color", color)
	_time_fill.color = color


func _pulse_time_label() -> void:
	if _reduce_motion:
		return
	_time_label.pivot_offset = _time_label.size / 2.0
	_time_label.scale = Vector2.ONE * theme_data.hud_warning_pulse_scale
	_time_label.create_tween().tween_property(_time_label, "scale", Vector2.ONE, theme_data.hud_warning_pulse_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 화면 전체를 캐릭터 색으로 덮었다가 사라진다.
func _flash_screen() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	if _flash_art.visible:  # 섬광 이미지를 캐릭터 색으로 물들여 띄운다
		_flash.color = Color.TRANSPARENT
		_flash_art.modulate = Color(_accent.r, _accent.g, _accent.b, theme_data.ability_flash_alpha)
		_flash_tween.tween_property(_flash_art, "modulate:a", 0.0, theme_data.ability_flash_duration).set_ease(Tween.EASE_OUT)
		return
	_flash.color = Color(_accent.r, _accent.g, _accent.b, theme_data.ability_flash_alpha)
	_flash_tween.tween_property(_flash, "color:a", 0.0, theme_data.ability_flash_duration).set_ease(Tween.EASE_OUT)


## 판 가운데 배너: 크게 나타나 줄어들며 자리 잡고(효과 줄이기면 크기 그대로), 잠시 뒤 사라진다.
func _show_banner(title: String, sub: String) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", _accent)
	_banner_sub.text = sub
	if _banner_style != null:
		_banner_style.border_color = _accent
	_banner.visible = true
	# 가운데 앵커 + 양쪽으로 자람: 크기는 내용 최소 크기 그대로라 가운데를 기준으로 커지고 줄어든다.
	_banner.pivot_offset = _banner.get_combined_minimum_size() / 2.0
	var duration: float = theme_data.ability_banner_duration
	_banner.scale = Vector2.ONE * (1.0 if _reduce_motion else theme_data.ability_banner_start_scale)
	_banner.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, duration * 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.parallel().tween_property(_banner, "modulate:a", 1.0, duration * 0.16)
	_banner_tween.tween_interval(duration * 0.5)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, duration * 0.22)
	_banner_tween.tween_callback(_banner.hide)


## 족보 완성 "+N" 문구가 점수 아래에서 떠올랐다 사라진다 (기획서 7.2 보상감).
func _show_popup(text: String) -> void:
	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()
	_score_popup.text = text
	_score_popup.position.y = _popup_home_y
	_score_popup.modulate.a = 1.0
	_popup_tween = create_tween().set_parallel(true)
	_popup_tween.tween_property(_score_popup, "position:y", _popup_home_y - theme_data.score_popup_rise,
		theme_data.score_popup_duration).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_score_popup, "modulate:a", 0.0, theme_data.score_popup_duration) \
		.set_ease(Tween.EASE_IN)


## anchor 컨트롤 아래쪽에 떠오르는 문구를 띄운다 (offset만큼 더 아래에서 시작).
func _float_near(anchor: Control, text: String, color: Color, offset: float = 0.0) -> void:
	if _reduce_motion or floating_text_scene == null:
		return
	var label: FloatingText = floating_text_scene.instantiate() as FloatingText
	_floats.add_child(label)
	var rect: Rect2 = anchor.get_global_rect()
	var at: Vector2 = _floats.get_global_transform().affine_inverse() * Vector2(rect.get_center().x, rect.end.y + offset)
	label.rise(text, color, at, theme_data.float_rise, theme_data.float_duration)


static func _format_seconds(seconds: float) -> String:
	return str(snappedf(seconds, 0.01))
