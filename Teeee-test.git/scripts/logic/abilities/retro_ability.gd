class_name RetroAbility
extends Ability
## 레트로 "흑백": duration초(실제 플레이 시간) 동안 판·족보가 흑백(문양으로만 구분)이 되고, 완성한 족보 점수 × multiplier
## (족보마다 반올림). 족보 완성으로 늘어나지는 않는다. 효과 중 재발동하면 남은 시간에 더한다.

@export var duration: float = 10.0
@export var multiplier: float = 2.0

## 업적 지표: 흑백 한 번에 완성한 족보 수(가장 큰 값), 흑백 중 얻은 족보 점수.
const METRIC_MONO_RECIPES: StringName = &"retro_recipes"
const METRIC_MONO_POINTS: StringName = &"retro_points"

var time_left: float = 0.0
var _window: EffectWindowMetrics = EffectWindowMetrics.new(&"", METRIC_MONO_RECIPES, METRIC_MONO_POINTS)


func trigger(session: GameSession) -> String:
	var was_active: bool = is_active()
	time_left += duration
	if not was_active:
		_window.begin()
		session.notify_display_changed()
	return "레트로: %s초 동안 점수 ×%s" % [Ability.format_seconds(duration), Ability.format_number(multiplier)]


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if is_active():
		outcome.scale_completed(multiplier)
		_window.on_outcome(session.metrics, outcome)


func advance(session: GameSession, delta: float) -> void:
	if not is_active():
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		time_left = 0.0
		session.notify_display_changed()


func time_to_next_event() -> float:
	return time_left if is_active() else INF


func is_active() -> bool:
	return time_left > 0.0


func display_style() -> DisplayStyle:
	if not is_active():
		return null
	var style: DisplayStyle = DisplayStyle.new()
	style.monochrome = true
	return style


func status_text() -> String:
	return "%s초" % Ability.format_seconds(time_left) if is_active() else ""


func effect_remaining() -> float:
	return time_left if is_active() else -1.0
