class_name Hud
extends CanvasLayer
## 플레이 HUD (기획서 7.1): 위 줄(일시정지 · 점수 · 주운 코인 · 남은 시간), 시간 막대, 족보 카드 + 캐릭터 카드,
## 아래 메시지 줄. 점수는 부드럽게 차오르고, 매치 시간·금화는 떠오르는 숫자로 보여준다 (7.2).
## HTML 연출 (E32, 수치는 BoardTheme HUD 그룹): 매치 시간 "+2.5"는 시간 옆에서 떠오르고(rise) 시간이 통통 튄다(bump).
## 족보 완성 "+점수"와 금화 "+10"은 카드·매치 자리에서 점수·코인으로 날아가고(fly), 닿는 순간 숫자가 오르며 통통 튄다.
## 족보 카드는 깨지며 파편을 뿌리고 새 카드가 내려온다 (RecipeView). 효과 줄이기면 날지 않고 바로 오른다.
## 캐릭터 줄 (족보 카드 아래, CharacterRow): 아이콘·이름·등급 문자·상태(남은 초·스택)·지속 효과 막대, 오른쪽에 캐릭터 족보 점.
## 능력이 없으면 줄을 숨긴다 (HUD 높이는 그대로 → 판 크기는 변하지 않는다).
## 능력 발동: 캐릭터 색 섬광 + 배너("촉진!" + 설명) + 메시지 줄에 결과 문구. 족보 밖 점수(피버 정산)도 배너로.
## 게임 상태를 바꾸지 않고, 버튼 입력은 pause_requested signal로만 알린다.

signal pause_requested
## 경고 구간에서 매 초 1회 (틱 사운드용).
signal warning_tick

@export var config: GameConfig
@export var theme_data: BoardTheme
## 화면 공통 이미지 (코인 아이콘).
@export var ui_assets: UiAssets
@export var floating_text_scene: PackedScene
## 족보 완성·칭찬 파편.
@export var burst_scene: PackedScene

## 경고 구간에서 마지막으로 펄스를 준 정수 초. 매 초 한 번만 펄스한다 (-1 = 경고 구간 밖).
var _last_warning_second: int = -1
## 현재 시간 색 (투명 = 아직 설정 안 함).
var _time_color: Color = Color(0, 0, 0, 0)
## 점수 표시: 실제 점수(목표)를 향해 부드럽게 차오른다. 날아가는 중인 점수(_score_flying)는 닿을 때까지 빼 둔다.
var _score_real: int = 0
var _score_flying: int = 0
var _score_target: int = 0
var _score_shown: float = 0.0
## 판에서 주운 코인 합과, 코인 쪽으로 날아가는 중이라 아직 안 보인 양.
var _coins_real: int = 0
var _coins_flying: int = 0
## 마지막 매치 자리 (캔버스 좌표, BoardView.match_point). 금화가 여기서 날아간다.
var _match_point: Vector2 = Vector2.ZERO
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
## 캐릭터 족보 점 (CharacterRow 안, 둘째 줄 문구는 숨겨 두고 상태만 기록).
@onready var _ability_view: RecipeView = %AbilityView
@onready var _character_row: CharacterRow = %CharacterRow
## 캐릭터 능력 이름 (상태 문구가 비어 있을 때)과 지금 상태 문구.
var _ability_name: String = ""
var _ability_status: String = ""
@onready var _floats: Control = %Floats
@onready var _flash: ColorRect = %Flash
## 발동 섬광 이미지 (BoardTheme.ability_flash_texture, 없으면 숨김 → 단색 섬광).
@onready var _flash_art: TextureRect = %FlashArt
@onready var _banner: PanelContainer = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_sub: Label = %BannerSub


func _ready() -> void:
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
			if _character_row.is_visible_in_tree():
				rects.append(_character_row.get_global_rect())
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


## 매치로 얻은 시간: 시간 오른쪽에 "+2.5"가 떠오르고 시간이 통통 튄다 (HTML matchFx).
func _on_time_gained(seconds: float) -> void:
	var rect: Rect2 = _time_label.get_global_rect()
	var at: Vector2 = rect.get_center() + Vector2(rect.size.x * 0.6, 0.0)
	_rise_at(at, "+%s" % _format_seconds(seconds), theme_data.float_time_color, theme_data.float_time_size)
	_bump(_time_label)


## 매치 자리 (BoardView.match_point, 캔버스 좌표).
func _on_match_point(canvas_position: Vector2) -> void:
	_match_point = canvas_position


## 판에서 주운 코인. amount > 0이면 방금 주운 것: 매치 자리에서 "+10"이 코인으로 날아가고(닿으면 숫자가 오름),
## 연속이면 "코인 N연속!"이 떠오른다. 매치 자리는 같은 프레임 뒤에 오므로 날리기는 프레임 끝에 한다.
func _on_coins_updated(total: int, amount: int, chain: int) -> void:
	if total < _coins_real or amount <= 0 or not _animates():
		_coins_flying = 0
	_coins_real = total
	if amount > 0 and _animates():
		_coins_flying += amount
		_fly_coins.call_deferred(amount, chain)
	_show_coins()


func _fly_coins(amount: int, chain: int) -> void:
	var size: float = theme_data.float_coin_size + theme_data.float_coin_size_step * mini(chain, 4)
	var label: FloatingText = _fly(_match_point, _coin_label, "+%d" % amount, theme_data.coin_color, size)
	if label == null:
		_coins_flying = maxi(_coins_flying - amount, 0)
		_show_coins()
		return
	label.arrived.connect(_on_coins_arrived.bind(amount))
	if chain > 1:
		var chain_size: float = theme_data.float_chain_size + theme_data.float_chain_size_step * mini(chain, 4)
		_rise_at(_match_point - Vector2(0.0, theme_data.float_chain_offset), "코인 %d연속!" % chain, theme_data.coin_color, chain_size)


func _on_coins_arrived(amount: int) -> void:
	_coins_flying = maxi(_coins_flying - amount, 0)
	_show_coins()
	_bump(_coin_label)


func _show_coins() -> void:
	_coin_label.text = ("%d" if _coin_icon.visible else "● %d") % (_coins_real - _coins_flying)


## 캐릭터 카드 둘째 줄 (예: "3.7초", "×2 (2)", "와일드 2"). 비어 있으면 능력 이름. 문구는 능력이 정한다.
func _on_ability_status(text: String) -> void:
	_ability_status = text
	_ability_view.show_status(text)
	_character_row.show_status(text, _ability_name)


## 능력 지속 효과 남은 시간 → 캐릭터 줄 막대.
func _on_effect_updated(_accent_color: Color, _block_color: int, remaining: float, _blink_window: float) -> void:
	_character_row.show_effect(remaining)


## 튜토리얼이 캐릭터 줄을 가리키는 동안 테두리가 맥박처럼 빛난다.
func highlight_character(on: bool) -> void:
	_character_row.highlight = on


## 족보 밖 점수 (피버 정산 등): 배너 + 판 가운데에서 점수로 날아가는 숫자 (HTML fever 정산 floatText → rScore).
func _on_bonus_scored(points: int, label: String) -> void:
	var amount: String = ("+%d" if points >= 0 else "%d") % points  # 음수(마탄 저주)는 부호 그대로
	_show_banner(label, amount)
	_fly_score(_floats.get_global_rect().get_center(), amount, _accent, theme_data.float_bonus_size, points)


func _on_reduce_motion_ready(enabled: bool) -> void:
	_reduce_motion = enabled
	for view: RecipeView in _recipe_views:
		view.set_reduce_motion(enabled)
	_character_row.set_reduce_motion(enabled)


## 남은 시간이 경고 구간인지 (테스트/디버그용).
func is_time_warning() -> bool:
	return _time_color == theme_data.hud_warning_color


## 지금 화면에 보이는 점수 (테스트/디버그용).
func shown_score() -> int:
	return roundi(_score_shown)


func _on_score_changed(score: int) -> void:
	if score < _score_real:  # 새 판(또는 감점): 날아가는 점수는 버리고 바로 맞춘다
		_score_flying = 0
	_score_real = score
	_score_target = _score_real - _score_flying
	if _score_target < _score_shown:
		_score_shown = _score_target
		_score_label.text = str(_score_target)


func _on_recipes_updated(recipes: RecipeSet, outcome: RecipeSet.ClearOutcome) -> void:
	for view: RecipeView in _recipe_views:
		view.visible = view.slot < recipes.slot_count()
		if not view.visible:
			continue
		var done: int = outcome.completed_slots.find(view.slot)
		if done < 0:
			view.show_recipe(recipes.recipes[view.slot])
			continue
		_celebrate_card(view, outcome.completed_recipes[done], outcome.completed_points[done])
		view.break_and_replace(recipes.recipes[view.slot])


## 족보 완성 (HTML breakCard): 카드 가운데에서 색마다 파편, "+점수"가 점수로 날아간다 (크기는 족보 난이도 = 길이 + 반복).
func _celebrate_card(view: RecipeView, recipe: RecipeSet.Recipe, points: int) -> void:
	var center: Vector2 = view.get_global_rect().get_center()
	if _animates():
		for color: int in recipe.colors:
			_burst_at(center, theme_data.display_color(color, null), theme_data.card_burst_count, theme_data.card_burst_speed,
				theme_data.card_burst_size)
	var difficulty: int = recipe.length()
	for i: int in range(1, recipe.length()):
		if recipe.colors[i] == recipe.colors[i - 1]:
			difficulty += 1
	var size: float = theme_data.float_recipe_size + theme_data.float_recipe_size_step * mini(difficulty, 4)
	_fly_score(center, "+%d" % points, theme_data.float_time_color, size, points)


## 캐릭터 줄 (족보 카드 아래). 발동형은 오른쪽에 캐릭터 족보 점, 상시형은 상태 문구만. 능력이 없으면 숨긴다.
func _on_ability_updated(recipe: RecipeSet.Recipe, character: CharacterData) -> void:
	if character != null:
		_accent = character.accent_color
		_ability_name = character.ability_name
	var has_card: bool = character != null and character.has_ability()
	_character_row.show_character(character)
	_ability_view.visible = has_card  # 상시형은 점 없이 비어 있다 (상태는 줄 가운데)
	_character_row.show_status(_ability_status, _ability_name)
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
	_character_row.play_burst()
	_flash_screen()
	if character != null:
		_show_banner("%s!" % character.ability_name, character.player_summary())
	_message_label.text = message


## 지금 배너 제목 (보이지 않으면 빈 문자열, 테스트/디버그용).
func banner_title() -> String:
	return _banner_title.text if _banner.visible else ""


## 지금 메시지 줄 (테스트/디버그용).
func message_text() -> String:
	return _message_label.text


func _on_state_changed(state: GameFlow.GameState) -> void:
	_pause_button.visible = state == GameFlow.GameState.WAITING or state == GameFlow.GameState.PLAYING
	_message_label.text = ""
	if state == GameFlow.GameState.WAITING:  # 새 판: 족보 카드가 위에서 내려온다 (HTML newGame의 cardIn)
		for view: RecipeView in _recipe_views:
			if view.visible:
				view.play_enter()


## 튜토리얼 칭찬 (HTML tutCheer): 플레이어 칸(캔버스 좌표 at) 위로 떠오른다. grade 0~2 = Good · Great! · Awesome!
## (등급마다 크기·색, Great! 이상은 파편), -1 = 등급 없는 칭찬 글. 효과 줄이기면 메시지 줄에.
func cheer(text: String, grade: int, at: Vector2) -> void:
	if not _animates():
		_message_label.text = text
		return
	var point: Vector2 = at - Vector2(0.0, theme_data.cheer_offset)
	if grade < 0:
		_rise_at(point, text, theme_data.cheer_text_color, theme_data.cheer_text_size)
		return
	var g: int = clampi(grade, 0, theme_data.cheer_sizes.size() - 1)
	var color: Color = theme_data.cheer_colors[mini(g, theme_data.cheer_colors.size() - 1)]
	_rise_at(point, text, color, theme_data.cheer_sizes[g])
	if g < theme_data.cheer_burst_counts.size() and theme_data.cheer_burst_counts[g] > 0:
		_burst_at(point, color, theme_data.cheer_burst_counts[g], theme_data.cheer_burst_speeds[g], theme_data.cheer_burst_size)


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


## 터치가 스와이프가 됐다: 일시정지 버튼 위에서 시작했어도 이동이지 일시정지가 아니다 (E36, 버튼의 누름을 스크롤 때처럼 취소).
func _on_swiped() -> void:
	_pause_button.notification(Control.NOTIFICATION_SCROLL_BEGIN)


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
	var start: float = 1.0 if _reduce_motion else theme_data.ability_banner_start_scale
	# HTML slam (1초, 구간마다 cubic-bezier(.2,.9,.3,1)): 2.3배·투명 → 16% 0.94배 → 28% 1배 → 78%까지 보임 → 1.04배로 사라짐.
	var settle: float = 1.0 if _reduce_motion else 0.94
	var leave: float = 1.0 if _reduce_motion else 1.04
	_banner_tween = KeyframeAnim.play(_banner, _banner, duration, [
		[0.0, {"scale": Vector2.ONE * start, "modulate:a": 0.0}],
		[0.16, {"scale": Vector2.ONE * settle, "modulate:a": 1.0}],
		[0.28, {"scale": Vector2.ONE}],
		[0.78, {"modulate:a": 1.0}],
		[1.0, {"scale": Vector2.ONE * leave, "modulate:a": 0.0}],
	], Vector4(0.2, 0.9, 0.3, 1.0))
	_banner_tween.tween_callback(_banner.hide)


## 연출을 보여 주는지 (효과 줄이기면 떠오르는·날아가는 글자와 파편이 없다).
func _animates() -> bool:
	return not _reduce_motion and floating_text_scene != null


## 캔버스 위치 at을 기준으로 떠오르는 글자 (HTML rise).
func _rise_at(at: Vector2, text: String, color: Color, font_size: float) -> void:
	if not _animates():
		return
	var label: FloatingText = floating_text_scene.instantiate() as FloatingText
	_floats.add_child(label)
	label.rise(text, color, _to_floats(at), font_size, theme_data.float_duration)


## 캔버스 위치 from에서 target 가운데로 날아가는 글자 (HTML fly). 효과 줄이기면 null.
func _fly(from: Vector2, target: Control, text: String, color: Color, font_size: float) -> FloatingText:
	if not _animates():
		return null
	var label: FloatingText = floating_text_scene.instantiate() as FloatingText
	_floats.add_child(label)
	label.fly(text, color, _to_floats(from), _to_floats(target.get_global_rect().get_center()), font_size, theme_data.fly_duration)
	return label


## 점수로 날아가는 숫자. 닿을 때까지 그 점수는 화면 점수에 넣지 않고, 닿으면 차오르며 통통 튄다.
func _fly_score(from: Vector2, text: String, color: Color, font_size: float, points: int) -> void:
	var label: FloatingText = _fly(from, _score_label, text, color, font_size)
	if label == null or points <= 0:
		return
	_score_flying += points
	_score_target = _score_real - _score_flying
	label.arrived.connect(_on_score_arrived.bind(points))


func _on_score_arrived(points: int) -> void:
	_score_flying = maxi(_score_flying - points, 0)
	_score_target = _score_real - _score_flying
	_bump(_score_label)


## 숫자가 바뀌어 통통 튄다 (HTML bump: 1.22배 → 원래, 글자 아래쪽 기준).
func _bump(label: Label) -> void:
	if _reduce_motion:
		return
	var x: float = 0.0
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = label.size.x / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = label.size.x
	label.pivot_offset = Vector2(x, label.size.y)
	KeyframeAnim.play(label, label, theme_data.bump_duration,
		[[0.0, {"scale": Vector2.ONE * theme_data.bump_scale}], [1.0, {"scale": Vector2.ONE}]], KeyframeAnim.EASE_OUT)


## 캔버스 위치 at에서 색 파편.
func _burst_at(at: Vector2, color: Color, count: int, speed: float, size: float) -> void:
	if burst_scene == null or _reduce_motion:
		return
	var burst: BurstEffect = burst_scene.instantiate() as BurstEffect
	_floats.add_child(burst)
	burst.position = _to_floats(at)
	burst.play(color, theme_data, count, speed, size)


func _to_floats(canvas_position: Vector2) -> Vector2:
	return _floats.get_global_transform().affine_inverse() * canvas_position


static func _format_seconds(seconds: float) -> String:
	return str(snappedf(seconds, 0.01))
