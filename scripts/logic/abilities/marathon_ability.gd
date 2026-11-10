class_name MarathonAbility
extends Ability
## 마라토너 (상시): 깃발이 왼쪽 위 → 왼쪽 아래 → 오른쪽 아래 → 오른쪽 위 모서리를 차례로 돈다.
## 직전 깃발 이후 매치를 한 번 이상 하고 깃발 칸에 들어가면 시간 + bonus_time, 깃발은 다음 모서리로.
## 깃발 칸 도착은 그 이동의 매치 판정보다 먼저 본다 (그 칸에서 한 매치는 다음 깃발 준비가 된다).

@export var bonus_time: float = 2.0

## 업적 지표: 깃발 통과 횟수.
const METRIC_FLAGS: StringName = &"marathon_flags"

## 모서리 순서를 화살표로 (카드 표시).
const ARROWS: PackedStringArray = ["↖", "↙", "↘", "↗"]

## 지금 가야 할 모서리 (0~3).
var target: int = 0
## 직전 깃발 이후 매치를 했다.
var flag_ready: bool = false
## 깃발 통과 횟수.
var laps: int = 0

var _board_size: int = 0


func setup(session: GameSession) -> void:
	_board_size = session.board.size


func on_move(session: GameSession, result: Board.MoveResult) -> void:
	if not flag_ready or result.to != corner(target):
		return
	laps += 1
	session.metrics.add(METRIC_FLAGS)
	flag_ready = false
	target = (target + 1) % ARROWS.size()
	session.add_time(bonus_time)
	session.notify_marks_changed()


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if not flag_ready:
		flag_ready = true
		session.notify_marks_changed()


## i번째 깃발 모서리: 왼쪽 위, 왼쪽 아래, 오른쪽 아래, 오른쪽 위.
func corner(i: int) -> Vector2i:
	var last: int = _board_size - 1
	return [Vector2i(0, 0), Vector2i(0, last), Vector2i(last, last), Vector2i(last, 0)][i]


func status_text() -> String:
	return "깃발 %s%s · +%s초" % [ARROWS[target], " 준비" if flag_ready else "", Ability.format_seconds(bonus_time)]


func board_marks() -> Array[BoardMark]:
	return [
		BoardMark.at_cell(BoardMark.Kind.FLAG_READY if flag_ready else BoardMark.Kind.FLAG, corner(target)),
		BoardMark.at_cell(BoardMark.Kind.FLAG_NEXT, corner((target + 1) % ARROWS.size())),
	]
