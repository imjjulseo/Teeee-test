class_name FeverAbility
extends Ability
## 축제꾼 "피버": duration초(실제 플레이 시간) 동안 색과 무관하게 매치마다 스택 +1, 리필 시계 × refill_rate.
## 끝나면 stack_points × n(n+1)/2점을 한 번에 얻는다 (5스택 750 · 10스택 2,750). 족보는 평소대로 진행한다.
## 피버 중 재발동하면 남은 시간에 duration초를 더한다 (스택 유지). 판이 끝날 때 피버 중이면 그 자리에서 정산한다.
## 피버를 발동시킨 매치는 스택에 들어가지 않는다 (세션이 on_match 뒤에 캐릭터 족보를 진행하므로).

@export var duration: float = 10.0
@export var stack_points: int = 50
@export var refill_rate: float = 2.0

## 업적 지표: 피버 한 번의 스택(가장 큰 값), 피버 정산 점수 누적.
const METRIC_STACKS: StringName = &"fever_stacks"
const METRIC_POINTS: StringName = &"fever_points"
## 피버가 끝났다 (정산 순간).
const MOMENT_END: StringName = &"fever_end"

var time_left: float = 0.0
var stacks: int = 0


func trigger(_session: GameSession) -> String:
	if not is_active():
		stacks = 0
	time_left += duration
	return "피버 %s초" % Ability.format_seconds(duration)


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if is_active():
		stacks += 1
		session.metrics.record_max(METRIC_STACKS, stacks)


func clock_rate(clock: TimedSystem.Clock) -> float:
	return refill_rate if clock == TimedSystem.Clock.REFILL and is_active() else 1.0


func advance(session: GameSession, delta: float) -> void:
	if not is_active():
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		_settle(session)


## 피버가 끝나는 순간 리필 배속이 바뀌고 점수가 들어오므로 사건으로 알린다.
func time_to_next_event() -> float:
	return time_left if is_active() else INF


func on_game_end(session: GameSession) -> void:
	if is_active():
		_settle(session)


func is_active() -> bool:
	return time_left > 0.0


## 스택 n개의 피버 점수.
func payout(n: int) -> int:
	return roundi(stack_points * n * (n + 1) / 2.0)


func status_text() -> String:
<<<<<<< HEAD
	return "%s초 / %d스택" % [Ability.format_seconds(time_left), stacks] if is_active() else ""
=======
	return "%s초 · %d스택" % [Ability.format_seconds(time_left), stacks] if is_active() else ""
>>>>>>> Choi


func effect_remaining() -> float:
	return time_left if is_active() else -1.0


func _settle(session: GameSession) -> void:
	time_left = 0.0
	var n: int = stacks
	stacks = 0
	if n > 0:
		session.metrics.add(METRIC_POINTS, payout(n))
		session.add_bonus_score(payout(n), "피버 %d스택!" % n)
	session.notify_moment(MOMENT_END)
