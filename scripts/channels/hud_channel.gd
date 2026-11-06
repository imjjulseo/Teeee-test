class_name HudChannel
extends Node
## HUD용 이벤트 채널: 시간, 점수, 코인, 족보, 캐릭터 능력(카드 상태·발동·배경 효과). GameController가 판마다
## bind()로 세션 이벤트를 연결하고 매 프레임 publish_frame()으로 시간·능력 상태를 보낸다 (연결은 main.tscn에 명시).

## fraction: 시간 막대 길이 0~1 (남은 시간 ÷ 제한시간). clock_stopped: 능력(시계공 "정지")으로 남은 시간이 멈춘 상태.
signal time_updated(remaining: float, fraction: float, clock_stopped: bool)
## 매치로 얻은 시간.
signal time_gained(seconds: float)
signal score_changed(score: int)
## 판에서 주운 코인 합. amount > 0이면 방금 주운 양, chain은 연속 횟수 (amount 0 = 표시만 맞춤).
signal coins_updated(total: int, amount: int, chain: int)
signal recipes_updated(recipes: RecipeSet, outcome: RecipeSet.ClearOutcome)
## 캐릭터 족보 진행 (발동형이 아니면 recipe == null).
signal ability_updated(recipe: RecipeSet.Recipe, character: CharacterData)
## 능력 발동. message는 메시지 줄 결과 문구.
signal ability_triggered(character: CharacterData, message: String)
## 캐릭터 카드 둘째 줄 상태 (남은 초·스택·남은 횟수). 비어 있으면 능력 이름.
signal ability_status(text: String)
## 능력 배경 효과. remaining < 0이면 꺼짐, INF면 끝없이 켜짐. 색은 block_color(블록 색 ID)가 있으면 그 색, 없으면 accent.
## blink_window: 깜빡이기 시작하는 남은 초 (음수면 테마 기본).
signal effect_updated(accent: Color, block_color: int, remaining: float, blink_window: float)
## 능력이 메시지 줄에 알리는 문구 (현상금 색 변경 등).
signal ability_announced(text: String)
## 족보 카드의 표시 방식 (색약·레트로, null = 보통).
signal display_style_changed(style: DisplayStyle)
## 족보 밖 점수 (피버 정산 등). label은 연출 문구.
signal bonus_scored(points: int, label: String)

var _character: CharacterData
## 지금 판 (코인 합계를 읽는다). 약한 참조 — 채널이 세션을 붙잡아 두지 않게.
var _session_ref: WeakRef
## 마지막으로 보낸 값(화면 표시 단위). 같으면 다시 보내지 않는다.
var _last_time_key: String = ""
var _last_status_key: String = ""
var _last_effect_key: String = ""
var _has_published: bool = false


## 새 판의 세션 이벤트를 이 채널로 연결하고, 초기 HUD 상태를 한 번 보낸다.
func bind(session: GameSession, character: CharacterData) -> void:
	_character = character
	_session_ref = weakref(session)
	session.recipes_updated.connect(recipes_updated.emit)
	session.score_changed.connect(score_changed.emit)
	session.time_gained.connect(time_gained.emit)
	session.coins_collected.connect(_on_coins_collected)
	session.ability_updated.connect(_on_ability_updated)
	session.ability_triggered.connect(_on_ability_triggered)
	session.bonus_scored.connect(bonus_scored.emit)
	session.ability_announced.connect(ability_announced.emit)
	session.display_style_changed.connect(display_style_changed.emit)
	display_style_changed.emit(session.display_style())
	recipes_updated.emit(session.recipes, RecipeSet.ClearOutcome.new())
	ability_updated.emit(session.ability_recipe, character)
	score_changed.emit(session.score)
	coins_updated.emit(session.collected_coins(), 0, 0)
	publish_frame(session, true)


## 매 프레임 불리지만, 화면에 보이는 값(남은 시간 0.1초, 정지 여부, 능력 상태 문구, 배경 효과)이
## 바뀔 때만 signal을 보낸다. force면 무조건 보낸다 (새 판 시작 등).
func publish_frame(session: GameSession, force: bool = false) -> void:
	var always: bool = force or not _has_published
	var remaining: float = session.remaining_time()
	var stopped: bool = session.is_clock_stopped()
	# HUD 표시와 같은 형식으로 비교한다 (반올림 경계에서 표시와 어긋나지 않게).
	var time_key: String = "%.1f|%s" % [remaining, stopped]
	if always or time_key != _last_time_key:
		_last_time_key = time_key
		time_updated.emit(remaining, remaining / session.get_config().game_duration, stopped)
	var ability: Ability = session.ability
	var status: String = ability.status_text() if ability != null else ""
	if always or status != _last_status_key:
		_last_status_key = status
		ability_status.emit(status)
	# 배경 효과는 판이 흐르는 동안만 (첫 이동 전·0초 이후 꺼짐). 깜빡임이 남은 시간을 따라가므로 1/100초 단위로 보낸다.
	var effect: float = ability.effect_remaining() if ability != null and session.is_running() else -1.0
	var block_color: int = ability.effect_block_color() if effect >= 0.0 else Board.NO_COLOR
	var window: float = ability.effect_blink_window() if effect >= 0.0 else -1.0
	var effect_key: String = "%d|%.2f|%.2f" % [block_color, effect, window]
	if always or effect_key != _last_effect_key:
		_last_effect_key = effect_key
		var accent: Color = session.character.accent_color if effect >= 0.0 else Color.TRANSPARENT
		effect_updated.emit(accent, block_color, effect, window)
	_has_published = true


func _on_coins_collected(amount: int, chain: int) -> void:
	var session: GameSession = _session_ref.get_ref() as GameSession if _session_ref != null else null
	coins_updated.emit(session.collected_coins() if session != null else amount, amount, chain)


func _on_ability_updated(recipe: RecipeSet.Recipe) -> void:
	ability_updated.emit(recipe, _character)


func _on_ability_triggered(message: String) -> void:
	ability_triggered.emit(_character, message)
