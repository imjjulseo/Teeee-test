class_name DiamondRevivePolicy
extends RevivePolicy
## 다이아 부활 (기획서 8.4장, E10): 0초에 다이아가 cost개 이상이면 부활을 제안한다. 판당 1번.
## 받아들이면 다이아를 쓴다 (시간은 GameFlow가 GameConfig.revive_time으로 채운다). 체험·튜토리얼 판은 5b·6단계에서 끈다.

var store: ProgressStore
var cost: int

var _used: bool = false


func _init(p_store: ProgressStore, p_cost: int) -> void:
	store = p_store
	cost = p_cost


func can_offer(_session: GameSession) -> bool:
	return not _used and store.diamonds >= cost


func consume(_session: GameSession) -> void:
	if store.spend_diamonds(cost):
		_used = true


func reset() -> void:
	_used = false
