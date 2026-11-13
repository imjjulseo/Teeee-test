class_name TimedSystem
extends RefCounted
## 시간이 지나면 사건을 일으키는 세션 구성 요소의 기반 (공통 시간표).
## GameSession은 등록된 시스템들의 "다음 사건까지 남은 시간" 중 가장 짧은 시각에서 한 프레임을 끊고
## 모든 시스템을 그만큼 advance()한다 → 프레임을 어떻게 나누든 사건 순서와 결과가 같다.
## 시간에 따라 일어나는 일을 새로 만들면 이 클래스를 상속해 세션에 등록한다 (사건 시각을 손으로 이어 붙이지 않는다).

## 시스템이 따르는 시계. 세션이 실제 시간을 시계별 배속으로 바꿔 전달한다.
enum Clock {
	PLAY,  ## 판 경과 시간 (일시정지 제외). 배속 1.
	REFILL,  ## 리필 시계: 씨앗 성장·금화 수명. 능력이 빠르게 하거나 멈출 수 있다 (4.3장).
	TIMER,  ## 남은 시간이 줄어드는 시계. 시간 정지 능력이 멈춘다 (5장).
}

## 부동소수점 오차로 아주 작은 양수가 남아도 사건이 일어나도록 하는 여유.
const EPSILON: float = 1e-9


## 이 시스템의 시계.
func clock() -> Clock:
	return Clock.PLAY


## 다음 사건까지 남은 시간 (자기 시계 기준 초). 사건이 없으면 INF.
func time_to_next_event() -> float:
	return INF


## 자기 시계로 dt초 진행하고, 그 사이에 도달한 사건을 처리한다.
func advance(_dt: float) -> void:
	pass
