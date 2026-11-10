class_name NavigatorAbility
extends Ability
## 항해사 (상시): 판 끝과 끝이 이어진다. 벽 밖으로 나가면 반대편 칸으로 나오고, 매치 판정도 반대편 칸을 이웃으로 본다.

## 업적 지표: 벽 넘기 횟수, 가장자리 칸에서 한 매치 수.
const METRIC_WRAPS: StringName = &"navigator_wraps"
const METRIC_EDGE_MATCHES: StringName = &"navigator_edge_matches"


func setup(session: GameSession) -> void:
	session.board.wraps_edges = true


func on_move(session: GameSession, result: Board.MoveResult) -> void:
	if result.wrapped:
		session.metrics.add(METRIC_WRAPS)


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	var pos: Vector2i = session.board.player_pos
	var last: int = session.board.size - 1
	if pos.x == 0 or pos.y == 0 or pos.x == last or pos.y == last:
		session.metrics.add(METRIC_EDGE_MATCHES)


func status_text() -> String:
	return "양 끝 연결"
