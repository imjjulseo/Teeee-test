class_name GrowAllAbility
extends Ability
## 정원사 "촉진": 판 위의 모든 씨앗이 즉시 다 자란다. 다 자란 뒤 매치 판정은 하지 않는다.

## 업적 지표: 한 번에 키운 씨앗 수(가장 큰 값), 촉진 횟수, 키운 씨앗 누적.
const METRIC_GROWN_ONCE: StringName = &"gardener_grown_once"
const METRIC_USES: StringName = &"gardener_uses"
const METRIC_GROWN: StringName = &"gardener_grown"


func trigger(session: GameSession) -> String:
	var grown: int = session.refill.mature_all().size()
	session.metrics.record_max(METRIC_GROWN_ONCE, grown)
	session.metrics.add(METRIC_USES)
	session.metrics.add(METRIC_GROWN, grown)
	return "촉진: 씨앗 전부 성장"


## 튜토리얼 힌트: 씨앗이 goal개 모일 때까지는 다른 색으로, 그다음 캐릭터 족보 색으로 발동.
func prefers_hint(session: GameSession, color: int, _center: Vector2i, goal: int) -> bool:
	var seeds: int = session.board.positions_of_type(Board.CellType.SEED).size()
	return Ability.needs_for_condition(session, color) == (seeds >= goal)
