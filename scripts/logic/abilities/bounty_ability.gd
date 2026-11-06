class_name BountyAbility
extends Ability
## 현상금 사냥꾼 (상시): 현상금 색이 interval초(판 경과)마다 직전과 다른 색으로 바뀐다. 현상금 색으로 매치하면 시간 + bonus_time.
## 배경은 현상금 색으로 칠하고, 바뀌기 blink_window초 전부터 깜빡인다. 색은 능력 RNG로 뽑는다.

@export var interval: float = 10.0
@export var bonus_time: float = 2.0
@export var blink_window: float = 2.0

## 업적 지표: 현상금 색 매치 수.
const METRIC_HUNTS: StringName = &"bounty_hunts"

## 지금 현상금 색.
var bounty_color: int = Board.NO_COLOR
## 다음 색 변경까지 남은 시간(초).
var time_left: float = 0.0
## 현상금 색으로 매치한 횟수.
var hunts: int = 0

var _color_count: int = 4


func setup(session: GameSession) -> void:
	_color_count = session.get_config().color_count
	time_left = interval
	_pick(session.get_rng())


func advance(session: GameSession, delta: float) -> void:
	time_left -= delta
	if time_left > TimedSystem.EPSILON:
		return
	time_left += interval
	_pick(session.get_rng())
	session.announce("현상금: %s" % _color_name())


func time_to_next_event() -> float:
	return maxf(time_left, 0.0)


func modify_match_time(session: GameSession, seconds: float, found: MatchRule.Found) -> float:
	if found.color != bounty_color:
		return seconds
	hunts += 1
	session.metrics.add(METRIC_HUNTS)
	return seconds + bonus_time


func status_text() -> String:
	# 남은 초를 올림해 보인다 (7.0000001초가 8초로 보이지 않게 아주 작은 오차는 뺀다).
	return "현상금 %s · %d초" % [_color_name(), ceili(maxf(time_left - 1e-6, 0.0))]


func effect_remaining() -> float:
	return maxf(time_left, 0.0)


func effect_block_color() -> int:
	return bounty_color


func effect_blink_window() -> float:
	return blink_window


## 직전과 다른 색을 뽑는다 (색이 하나뿐이면 그 색).
func _pick(rng: RandomNumberGenerator) -> void:
	var previous: int = bounty_color
	var next: int = rng.randi_range(0, _color_count - 1)
	while next == previous and _color_count > 1:
		next = rng.randi_range(0, _color_count - 1)
	bounty_color = next


func _color_name() -> String:
	return Board.COLOR_NAMES[bounty_color] if bounty_color >= 0 and bounty_color < Board.COLOR_NAMES.size() else ""


## 튜토리얼 힌트: 현상금 색 매치.
func prefers_hint(_session: GameSession, color: int, _center: Vector2i, _goal: int) -> bool:
	return color == bounty_color
