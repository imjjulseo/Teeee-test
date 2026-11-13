class_name VampireAbility
extends Ability
## 뱀파이어 "피의 시간": duration초(실제 플레이 시간) 동안 모든 블록이 blood_color(빨강)이 된다 — 색 비교에서 모든 색을
## 빨강으로 보므로 주위 4칸이 다 자란 블록이면 색과 무관하게 매치. 매치는 시간을 주지 않고, 족보는 2칸 → 3칸 → 4칸
## 순서로 하나씩 채운다 (지금 채우는 족보가 완성되면 다음 족보). 리필 시계 × refill_rate. 그동안 캐릭터 족보는 멈춘다.
## 블록의 실제 색은 바뀌지 않고 화면에서만 빨강으로 칠한다. 효과 중 재발동하면 남은 시간에 더한다.

@export var duration: float = 6.0
@export var refill_rate: float = 2.5
@export var blood_color: int = 1

## 업적 지표: 피의 시간 한 번의 매치·완성 수 (가장 큰 값).
const METRIC_BLOOD_MATCHES: StringName = &"vampire_matches"
const METRIC_BLOOD_RECIPES: StringName = &"vampire_recipes"

var time_left: float = 0.0
var _window: EffectWindowMetrics = EffectWindowMetrics.new(METRIC_BLOOD_MATCHES, METRIC_BLOOD_RECIPES)
## 지금 채우는 족보 슬롯.
var target_slot: int = 0

var _color_count: int = 4


func setup(session: GameSession) -> void:
	_color_count = session.get_config().color_count


func trigger(session: GameSession) -> String:
	if is_active():
		time_left += duration
	else:
		time_left = duration
		target_slot = 0
		_window.begin()
		session.notify_display_changed()
<<<<<<< HEAD
	return "피의 시간: %s초 동안 모든 블록이 빨강" % Ability.format_seconds(duration)
=======
	return "피의 시간: %s초 동안 모든 블럭이 빨강" % Ability.format_seconds(duration)
>>>>>>> Choi


func canonical_color(color: int) -> int:
	return blood_color if is_active() else color


func condition_frozen() -> bool:
	return is_active()


func modify_match_time(_session: GameSession, seconds: float, _found: MatchRule.Found) -> float:
	return 0.0 if is_active() else seconds


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if is_active():
		_window.on_match(session.metrics)


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if is_active():
		_window.on_outcome(session.metrics, outcome)


func override_clear(session: GameSession, _color: int) -> RecipeSet.ClearOutcome:
	if not is_active():
		return null
	var recipes: RecipeSet = session.recipes
	var outcome: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	if recipes.advance_slot(target_slot, outcome):
		target_slot = (target_slot + 1) % recipes.slot_count()
	return outcome


func clock_rate(clock: TimedSystem.Clock) -> float:
	return refill_rate if clock == TimedSystem.Clock.REFILL and is_active() else 1.0


func advance(session: GameSession, delta: float) -> void:
	if not is_active():
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		time_left = 0.0
		session.notify_display_changed()
		session.announce("피의 시간 종료")


func time_to_next_event() -> float:
	return time_left if is_active() else INF


func is_active() -> bool:
	return time_left > 0.0


func display_style() -> DisplayStyle:
	if not is_active():
		return null
	var style: DisplayStyle = DisplayStyle.new()
	for color: int in _color_count:
		style.color_alias[color] = blood_color
	return style


func status_text() -> String:
	return "%s초" % Ability.format_seconds(time_left) if is_active() else ""


## 피의 시간 동안 화면 가장자리가 붉게 맥박친다 (HTML bloodPulse 1초).
func effect_pulse_period() -> float:
	return 1.0 if effect_remaining() >= 0.0 else 0.0


func effect_remaining() -> float:
	return time_left if is_active() else -1.0
