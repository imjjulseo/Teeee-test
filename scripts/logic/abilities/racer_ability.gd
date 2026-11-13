class_name RacerAbility
extends Ability
## 레이서 (상시, 히든): 바라보는 방향으로 interval초(판 경과)마다 한 칸씩 저절로 달린다. 입력은 방향만 바꾼다 (다른 방향이면
## 이어 달린 칸 수가 0부터). 벽에 막히면 그 자리에 선다. 매치하면 같은 방향으로 이어 달린 칸 수 × streak_bonus초를 더 얻는다
## (매치를 만든 칸까지 포함).

@export var interval: float = 0.13
@export var streak_bonus: float = 0.5

## 지표: 질주 보너스를 받은 매치 수 (캐릭터 튜토리얼 목표).
const METRIC_STREAK_MATCHES: StringName = &"racer_streak_matches"

## 바라보는 방향 (처음에는 오른쪽).
var direction: Vector2i = Vector2i.RIGHT
## 같은 방향으로 이어 달린 칸 수.
var streak: int = 0
var turns: int = 0
## 질주로 얻은 시간 합.
var bonus_total: float = 0.0

var _next_in: float = 0.0


func setup(_session: GameSession) -> void:
	_next_in = interval


func intercept_move(_session: GameSession, dir: Vector2i) -> bool:
	if dir != direction:
		turns += 1
		streak = 0
	direction = dir
	return true


func advance(session: GameSession, delta: float) -> void:
	_next_in -= delta
	while _next_in <= TimedSystem.EPSILON and session.is_running():
		_next_in += interval
		_run_step(session)


func time_to_next_event() -> float:
	return maxf(_next_in, 0.0)


func modify_match_time(session: GameSession, seconds: float, _found: MatchRule.Found) -> float:
	if streak <= 0:
		return seconds
	var bonus: float = streak * streak_bonus
	bonus_total += bonus
	session.metrics.add(METRIC_STREAK_MATCHES)
	streak = 0
	return seconds + bonus


func status_text() -> String:
	if streak <= 0:
		return "0칸 질주"
<<<<<<< HEAD
	return "%d칸 질주 / +%s초" % [streak, Ability.format_number(streak * streak_bonus)]
=======
	return "%d칸 질주 · +%s초" % [streak, Ability.format_number(streak * streak_bonus)]
>>>>>>> Choi


## 한 칸 달린다. 벽이면 그 자리.
func _run_step(session: GameSession) -> void:
	var board: Board = session.board
	if not board.is_inside(board.step_from(board.player_pos, direction)):
		return
	streak += 1  # 이번 칸도 질주에 넣고 매치를 판정한다 (매치를 만든 칸까지 보너스)
	var before: Vector2i = board.player_pos
	session.perform_move(direction)
	if board.player_pos == before and streak > 0:
		streak -= 1
