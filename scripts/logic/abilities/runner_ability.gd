class_name RunnerAbility
extends Ability
## 묘수꾼 "수읽기": 남은 시간이 멈추고 씨앗이 전부 즉시 자란다. moves번 움직이거나 duration초가 지나면 풀린다.
## 수읽기 중 매치는 시간을 주지 않는 대신 깨진 자리 씨앗이 바로 자라고 moves번·duration초가 다시 시작된다.
## 한 번의 수읽기는 처음 발동부터 max_duration초를 넘지 않는다 (재발동해도 이 한도는 처음 발동 기준).

@export var moves: int = 8
@export var duration: float = 6.0
@export var max_duration: float = 10.0

## 업적 지표: 수읽기 한 번의 매치 수(가장 큰 값), 수읽기 중 매치 누적.
const METRIC_READING_MATCHES_ONCE: StringName = &"runner_matches_once"
const METRIC_READING_MATCHES: StringName = &"runner_matches"
## 수읽기가 끝났다.
const MOMENT_END: StringName = &"runner_end"

var active: bool = false
var _window: EffectWindowMetrics = EffectWindowMetrics.new(METRIC_READING_MATCHES_ONCE, &"", &"", METRIC_READING_MATCHES)
var moves_left: int = 0
## duration 쪽 남은 시간.
var time_left: float = 0.0
## max_duration 쪽 남은 시간.
var cap_left: float = 0.0


func trigger(session: GameSession) -> String:
	if not active:
		cap_left = max_duration
		_window.begin()
	active = true
	moves_left = moves
	time_left = duration
	session.refill.mature_all()
	return "수읽기: %d번 움직이거나 %s초가 지날 때까지 시간 정지" % [moves, Ability.format_seconds(duration)]


func modify_match_time(_session: GameSession, seconds: float, _found: MatchRule.Found) -> float:
	return 0.0 if active else seconds


func on_match(session: GameSession, _color: int, cells: Array[Vector2i]) -> void:
	if not active:
		return
	_window.on_match(session.metrics)
	time_left = duration
	moves_left = moves
	session.refill.mature_cells(cells)


func after_move(session: GameSession, _matched: bool) -> void:
	if not active:
		return
	moves_left -= 1
	if moves_left <= 0:
		_end(session)


func clock_rate(clock: TimedSystem.Clock) -> float:
	return 0.0 if clock == TimedSystem.Clock.TIMER and active else 1.0


func advance(session: GameSession, delta: float) -> void:
	if not active:
		return
	time_left -= delta
	cap_left -= delta
	if remaining() <= TimedSystem.EPSILON:
		_end(session)


func time_to_next_event() -> float:
	return maxf(remaining(), 0.0) if active else INF


## 풀릴 때까지 남은 시간 (duration과 max_duration 중 먼저 오는 쪽).
func remaining() -> float:
	return minf(time_left, cap_left)


func status_text() -> String:
	return "%d수 / %s초" % [moves_left, Ability.format_seconds(remaining())] if active else ""


func effect_remaining() -> float:
	return maxf(remaining(), 0.0) if active else -1.0


func _end(session: GameSession) -> void:
	active = false
	moves_left = 0
	session.announce("수읽기 끝")
	session.notify_moment(MOMENT_END)
