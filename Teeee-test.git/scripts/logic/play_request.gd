class_name PlayRequest
extends RefCounted
## 다음 게임 씬을 평소와 다르게 여는 요청: 규칙 튜토리얼 다시 보기(설정), 짧은 판(디버그).
## 씬끼리 서로 참조하지 않으려고 정적 값으로 넘기고, GameController가 읽고 지운다 (TrialRequest와 같은 방식).
## 테스트 러너가 되돌리지 않은 값을 실패로 센다.

## 규칙 튜토리얼을 다시 본다 (기록·보상 없음, 끝나면 메뉴로).
static var replay_tutorial: bool = false
## 이 판의 제한시간(초). 0 이하면 평소대로 (디버그: 결과·부활 화면을 빨리 본다).
static var game_seconds: float = 0.0


static func is_pending() -> bool:
	return replay_tutorial or game_seconds > 0.0


static func take_replay_tutorial() -> bool:
	var replay: bool = replay_tutorial
	replay_tutorial = false
	return replay


static func take_game_seconds() -> float:
	var seconds: float = game_seconds
	game_seconds = 0.0
	return seconds
