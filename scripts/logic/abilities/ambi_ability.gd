class_name AmbiAbility
extends Ability
## 양손잡이 (상시, 히든): 플레이어가 둘이다 — 가운데 줄의 좌우 벽 한 칸 안쪽에서 시작한다.
## 화면 왼쪽 절반·WASD·패드 = 왼손(0번), 화면 오른쪽 절반·방향키 = 오른손(1번). 서로의 칸으로는 들어갈 수 없다.

const LEFT_HAND: int = 0
const RIGHT_HAND: int = 1
## 업적 지표: 두 손의 매치 수 중 작은 쪽 (양손 모두 매치 · 양손 각각 N회).
const METRIC_BOTH_HANDS: StringName = &"ambi_both_hands"

## 손별 매치 수 [왼손, 오른손].
var matches: Array[int] = [0, 0]


func setup(session: GameSession) -> void:
	var board: Board = session.board
	var mid: int = board.center().y
	board.teleport_player(Vector2i(1, mid))  # 가운데의 플레이어를 왼쪽으로 (그 칸의 블록은 가운데로)
	board.add_player(Vector2i(board.size - 2, mid))
	board.select_player(LEFT_HAND)


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	matches[session.board.active_player] += 1
	session.metrics.record_max(METRIC_BOTH_HANDS, mini(matches[LEFT_HAND], matches[RIGHT_HAND]))


func status_text() -> String:
<<<<<<< HEAD
	return "왼 %d / 오 %d" % [matches[LEFT_HAND], matches[RIGHT_HAND]]
=======
	return "왼 %d · 오 %d" % [matches[LEFT_HAND], matches[RIGHT_HAND]]
>>>>>>> Choi
