class_name PuzzleLevel
extends Resource
<<<<<<< HEAD
## 블록 모으기 단계 하나 (Lv.0 들어가기 … Lv.4 마지막 라운드). 판 여러 개를 차례로 푼다.
=======
## 블럭 모으기 단계 하나 (Lv.0 들어가기 … Lv.4 마지막 라운드). 판 여러 개를 차례로 푼다.
>>>>>>> Choi
## Lv.0·1은 규칙 튜토리얼에서 풀고(화면에 단계 번호는 보이지 않는다), Lv.2~4(in_menu)는 메뉴 > 퍼즐의 판이다 (팀 결정 11/06, E28).

@export var level: int = 0
@export var name: String = ""
## 목표 모양(점선)을 힌트 전까지 숨긴다.
@export var hide_goal: bool = false
@export var boards: Array[PuzzleDef] = []
## 메뉴 > 퍼즐 목록에 넣는다 (단계 구분 없이 PuzzleBook 순서대로 번호를 붙인다).
@export var in_menu: bool = false
