class_name PhotoAbility
extends Ability
## 사진사 "찰칵": duration초(판 경과) 동안 판이 사진으로 멈춘다 (시간·리필 정지). 그동안 이동 입력은 경로만 계획한다
## (최대 max_plan수, 판 밖으로는 계획하지 않음). 사진이 깨지면 계획대로 실행한다: lead초 뒤 첫 칸, 칸마다
## first_gap초 × gap_scale^(이어 달린 칸 수), 최소 min_gap초. 매치가 나면 hit_pause초 멈칫하고 다시 처음 속도부터.
## 실행 중에는 시간이 멈추고 입력을 무시한다 (리필은 흐름). 실행이 끝나면 매치 n번마다 보너스 bonus_base × 2^(n−1)
## (bonus_cap번까지). 사진 중 재발동 = 사진 시간 + duration, 실행 중 재발동 = 실행이 끝난 뒤 사진 한 장 더.

@export var duration: float = 7.0
@export var max_plan: int = 60
@export var lead: float = 0.12
@export var first_gap: float = 0.06
@export var gap_scale: float = 0.8
@export var min_gap: float = 0.022
@export var hit_pause: float = 0.13
@export var bonus_base: int = 250
@export var bonus_cap: int = 6

## 업적 지표: 사진 한 장(실행 한 번) 안의 매치·완성 수 (가장 큰 값).
const METRIC_PHOTO_MATCHES: StringName = &"photo_matches"
const METRIC_PHOTO_RECIPES: StringName = &"photo_recipes"
## 계획 실행이 끝났다.
const MOMENT_END: StringName = &"photo_end"

var _window: EffectWindowMetrics = EffectWindowMetrics.new(METRIC_PHOTO_MATCHES, METRIC_PHOTO_RECIPES)

## 사진(계획) 중.
var planning: bool = false
## 계획 실행 중.
var replaying: bool = false
var photo_left: float = 0.0
## 계획한 방향들.
var plan: Array[Vector2i] = []
## 계획한 길 (지금 위치부터).
var plan_path: Array[Vector2i] = []
## 이번 실행에서 매치한 횟수.
var hits: int = 0

var _replay_index: int = 0
var _run: int = 0
var _next_in: float = 0.0
var _again: bool = false


func trigger(session: GameSession) -> String:
	if planning:
		photo_left += duration
	elif replaying:
		_again = true
	else:
		_start_photo(session)
	return "찰칵: %s초" % Ability.format_seconds(duration)


func intercept_move(session: GameSession, dir: Vector2i) -> bool:
	if not planning:
		return false
	var ghost: Vector2i = plan_path.back()
	var target: Vector2i = session.board.step_from(ghost, dir)
	if session.board.is_inside(target) and plan.size() < max_plan:
		plan.append(dir)
		plan_path.append(target)
		session.notify_marks_changed()
	return true


func locks_input() -> bool:
	return replaying


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if replaying:
		_window.on_match(session.metrics)


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if replaying:
		_window.on_outcome(session.metrics, outcome)


func clock_rate(clock: TimedSystem.Clock) -> float:
	if clock == TimedSystem.Clock.TIMER and (planning or replaying):
		return 0.0
	if clock == TimedSystem.Clock.REFILL and planning:
		return 0.0
	return 1.0


func advance(session: GameSession, delta: float) -> void:
	if planning:
		photo_left -= delta
		if photo_left <= TimedSystem.EPSILON:
			_begin_replay(session)
	elif replaying:
		_next_in -= delta
		while replaying and _next_in <= TimedSystem.EPSILON:
			_replay_step(session)


func time_to_next_event() -> float:
	if planning:
		return maxf(photo_left, 0.0)
	if replaying:
		return maxf(_next_in, 0.0)
	return INF


## 매치 n번의 사진 보너스.
func bonus_for(n: int) -> int:
	return bonus_base * int(pow(2, mini(bonus_cap, n) - 1)) if n > 0 else 0


func status_text() -> String:
	if planning:
		return "계획 %d수 / %s초" % [plan.size(), Ability.format_seconds(photo_left)]
	if replaying:
		return "%d연속" % hits
	return ""


func effect_remaining() -> float:
	return photo_left if planning else (INF if replaying else -1.0)


func board_marks() -> Array[BoardMark]:
	var marks: Array[BoardMark] = []
	if planning:
		marks.append(BoardMark.path(plan_path))
	elif replaying and _replay_index < plan_path.size():
		marks.append(BoardMark.path(plan_path.slice(_replay_index)))
	return marks


func _start_photo(session: GameSession) -> void:
	planning = true
	photo_left = duration
	plan = []
	plan_path = [session.board.player_pos]
	session.notify_marks_changed()


func _begin_replay(session: GameSession) -> void:
	planning = false
	photo_left = 0.0
	replaying = true
	hits = 0
	_window.begin()
	_replay_index = 0
	_run = 0
	_next_in = lead
	if plan.is_empty():
		_finish(session)
	session.notify_marks_changed()


func _replay_step(session: GameSession) -> void:
	if _replay_index >= plan.size():
		_finish(session)
		return
	var matches: int = session.match_count
	session.perform_move(plan[_replay_index])
	_replay_index += 1
	if session.match_count > matches:
		hits += 1
		_run = 0
		_next_in += hit_pause
	else:
		_run += 1
		_next_in += maxf(min_gap, first_gap * pow(gap_scale, _run))
	session.notify_marks_changed()


func _finish(session: GameSession) -> void:
	replaying = false
	if hits > 0:
		session.add_bonus_score(bonus_for(hits), "%d연속!" % hits)
	session.announce("사진 실행: %d수, 매치 %d회" % [plan.size(), hits])
	session.notify_moment(MOMENT_END)
	plan = []
	plan_path = []
	session.notify_marks_changed()
	if _again:
		_again = false
		_start_photo(session)
