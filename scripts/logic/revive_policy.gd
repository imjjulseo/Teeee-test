class_name RevivePolicy
extends RefCounted
## 0초가 됐을 때 부활을 제안할지 정한다 (기획서 5장, E10). GameFlow가 쓰는 확장 지점.
## 기본은 부활 없음. 진행·재화(5단계)에서 다이아·판당 1번·튜토리얼 제외 규칙을 가진 하위 클래스로 바꾼다.


## session이 0초가 됐을 때 부활을 제안할 수 있는지.
func can_offer(_session: GameSession) -> bool:
	return false


## 부활을 받아들였다 (비용 지불 등).
func consume(_session: GameSession) -> void:
	pass


## 새 판이 시작된다 (판당 횟수 제한을 다시 센다).
func reset() -> void:
	pass
