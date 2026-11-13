class_name PachyAbility
extends Ability
## 파키케팔로사우르스 (상시, 히든): 손가락·패드 버튼·방향키를 hold_time초 누르고 있으면 그 방향으로 돌진한다.
## 첫 칸은 first_gap초 뒤, 그다음 칸마다 × gap_scale, 최소 min_gap초. 손을 떼거나 벽에 부딪히면 멈춘다.
## 돌진 중 매치하면 박치기: points × min(칸 수, cap)²점을 얻고 멈춘다.
## 누르고 있는 동안 같은 방향의 반복 입력(키 반복, 패드 반복)은 한 칸씩 움직이지 않는다 (처음 누른 한 칸만).

@export var hold_time: float = 0.18
@export var first_gap: float = 0.25
@export var gap_scale: float = 0.8
@export var min_gap: float = 0.04
@export var points: int = 20
@export var cap: int = 5

## 지표: 박치기 수 (캐릭터 튜토리얼 목표).
const METRIC_HEADBUTTS: StringName = &"pachy_headbutts"

var holding: bool = false
var dashing: bool = false
var hold_dir: Vector2i = Vector2i.ZERO
## 이번 돌진으로 달린 칸 수.
var steps: int = 0
var headbutts: int = 0

var _hold_left: float = 0.0
## 누르기 시작한 그 입력의 한 칸은 보통 이동이다.
var _allow_first: bool = false
var _next_in: float = 0.0


func on_hold(_session: GameSession, dir: Vector2i) -> void:
	holding = true
	dashing = false
	hold_dir = dir
	_hold_left = hold_time
	_allow_first = true


func on_release(_session: GameSession) -> void:
	holding = false
	dashing = false


func intercept_move(_session: GameSession, dir: Vector2i) -> bool:
	if dashing:
		return true
	if holding and dir == hold_dir:
		if _allow_first:
			_allow_first = false
			return false
		return true  # 누르고 있는 동안의 반복 입력
	return false


func advance(session: GameSession, delta: float) -> void:
	if dashing:
		_next_in -= delta
		while dashing and _next_in <= TimedSystem.EPSILON:
			_dash_step(session)
	elif holding:
		_hold_left -= delta
		if _hold_left <= TimedSystem.EPSILON:
			dashing = true
			steps = 0
			_next_in = first_gap


func time_to_next_event() -> float:
	if dashing:
		return maxf(_next_in, 0.0)
	if holding:
		return maxf(_hold_left, 0.0)
	return INF


## 돌진 n칸째 매치의 박치기 점수.
func headbutt_points(n: int) -> int:
	var k: int = mini(cap, n)
	return points * k * k


func status_text() -> String:
	if dashing:
		return "%d칸 돌진 / +%d" % [steps, headbutt_points(steps + 1)]
	return "밀고 그대로 누르면 돌진"


func _dash_step(session: GameSession) -> void:
	var board: Board = session.board
	if not board.is_inside(board.step_from(board.player_pos, hold_dir)):
		_stop()
		if steps >= 2:
			session.announce("쿵")
		return
	steps += 1
	var matches: int = session.match_count
	session.perform_move(hold_dir)
	if session.match_count > matches:
		headbutts += 1
		session.metrics.add(METRIC_HEADBUTTS)
		session.add_bonus_score(headbutt_points(steps), "박치기 %d칸!" % steps)
		_stop()
		return
	_next_in += maxf(min_gap, first_gap * pow(gap_scale, steps))


## 돌진을 멈춘다. 다시 돌진하려면 새로 누르고 있어야 한다.
func _stop() -> void:
	dashing = false
	holding = false
