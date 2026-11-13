class_name TimeKeeper
extends RefCounted
## 남은 시간 (기획서 5장, E5). 시간 가속 없이 게임 시계만큼 줄고, 매치·능력으로 늘어난다. 순수 로직.

## 부동소수점 오차로 남은 시간이 아주 작은 양수여도 0초로 본다.
const EPSILON: float = 1e-9

var remaining: float


func _init(duration: float) -> void:
	remaining = duration


## 게임 시계로 dt초가 흘렀다. 0 아래로 내려가지 않는다.
func consume(dt: float) -> void:
	remaining = maxf(remaining - dt, 0.0)


func add(seconds: float) -> void:
	remaining += seconds


## 부활 등으로 남은 시간을 정한다.
func set_remaining(seconds: float) -> void:
	remaining = maxf(seconds, 0.0)


func is_out() -> bool:
	return remaining <= EPSILON


## 게임 시계로 0초가 될 때까지 남은 시간.
func time_to_zero() -> float:
	return remaining
