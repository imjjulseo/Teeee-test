class_name WandererAbility
extends Ability
## 떠돌이 (상시): 완성한 족보 점수 × multiplier (족보마다 반올림). moves_per_jump번 움직이는 동안 매치하지 못하면
## 판의 무작위 칸(플레이어와 거리 2 이상, 능력 RNG)으로 순간이동한다 — 그 칸과 자리를 바꾸고, 도착 자리가 매치면 매치.
## 매치하면 다시 moves_per_jump번부터 센다.

@export var multiplier: float = 1.5
@export var moves_per_jump: int = 10

## 업적 지표: 순간이동 횟수, 순간이동하자마자 한 매치 수.
const METRIC_TELEPORTS: StringName = &"wanderer_teleports"
const METRIC_TELEPORT_MATCHES: StringName = &"wanderer_teleport_matches"

var moves_left: int = 10
var teleports: int = 0


func setup(_session: GameSession) -> void:
	moves_left = moves_per_jump


func modify_outcome(_session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	outcome.scale_completed(multiplier)


func after_move(session: GameSession, matched: bool) -> void:
	if matched:
		moves_left = moves_per_jump
		return
	moves_left -= 1
	if moves_left <= 0:
		_teleport(session)


func status_text() -> String:
	return "%d수 뒤 이동" % moves_left


func _teleport(session: GameSession) -> void:
	var board: Board = session.board
	var options: Array[Vector2i] = []
	for pos: Vector2i in board.all_positions():
		if Board.distance(pos, board.player_pos) > 1 and board.get_cell_type(pos) != Board.CellType.EMPTY:
			options.append(pos)
	moves_left = moves_per_jump
	if options.is_empty():
		return
	teleports += 1
	session.metrics.add(METRIC_TELEPORTS)
	session.announce("순간이동!")
	if session.teleport_player(options[session.get_rng().randi_range(0, options.size() - 1)]):
		session.metrics.add(METRIC_TELEPORT_MATCHES)
