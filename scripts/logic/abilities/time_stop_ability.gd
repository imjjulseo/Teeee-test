class_name TimeStopAbility
extends Ability
## 시계공 "정지": duration초(실제 플레이 시간) 동안 남은 시간이 줄지 않는다.
## 리필·금화·이동은 계속 진행된다. 정지 중 재발동하면 남은 정지 시간에 이어 붙인다.

@export var duration: float = 4.0

## 업적 지표: 정지 한 번 동안 매치·완성 수(가장 큰 값), 정지 중 얻은 점수.
const METRIC_STOP_MATCHES: StringName = &"clock_stop_matches"
const METRIC_STOP_RECIPES: StringName = &"clock_stop_recipes"
const METRIC_STOP_POINTS: StringName = &"clock_stop_points"

var time_left: float = 0.0
var _window: EffectWindowMetrics = EffectWindowMetrics.new(METRIC_STOP_MATCHES, METRIC_STOP_RECIPES, METRIC_STOP_POINTS)


func trigger(_session: GameSession) -> String:
	if not is_active():
		_window.begin()
	time_left += duration
	return "정지: %s초" % Ability.format_seconds(duration)


func clock_rate(clock: TimedSystem.Clock) -> float:
	return 0.0 if clock == TimedSystem.Clock.TIMER and is_active() else 1.0


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if is_active():
		_window.on_match(session.metrics)


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if is_active():
		_window.on_outcome(session.metrics, outcome)


func advance(_session: GameSession, delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	if time_left <= TimedSystem.EPSILON:
		time_left = 0.0


## 정지가 끝나는 순간 남은 시간이 다시 흐르므로 사건으로 알린다 (0초 도달 시각을 다시 계산하기 위해).
func time_to_next_event() -> float:
	return time_left if is_active() else INF


func is_active() -> bool:
	return time_left > 0.0


func status_text() -> String:
	return "%s초" % Ability.format_seconds(time_left) if is_active() else ""


func effect_remaining() -> float:
	return time_left if is_active() else -1.0


## 튜토리얼 힌트: 정지 중에는 아무 매치, 아니면 캐릭터 족보 색.
func prefers_hint(session: GameSession, color: int, _center: Vector2i, _goal: int) -> bool:
	return is_active() or Ability.needs_for_condition(session, color)
