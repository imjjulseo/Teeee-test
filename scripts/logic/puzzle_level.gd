class_name PuzzleLevel
extends Resource
## 블럭 모으기 단계 하나 (Lv.0 들어가기 … Lv.4 흩어진 블럭). 판 여러 개를 차례로 푼다.
## Lv.0·1은 규칙 튜토리얼에서도 풀고, Lv.2~4는 설정 → 연습의 보상 퍼즐이다 (팀 결정 11/04, E27).

@export var level: int = 0
@export var name: String = ""
## 목표 모양(점선)을 힌트 전까지 숨긴다.
@export var hide_goal: bool = false
@export var boards: Array[PuzzleDef] = []
## 이 단계의 판을 처음 풀면 판마다 한 번 받는 코인 (0 = 보상 없음, 임시).
@export var clear_coins: int = 0
