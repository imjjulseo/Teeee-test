class_name PuzzleDifficulty
extends Resource
## 블록 모으기 연습 난이도 (쉬움 · 보통 · 어려움 · 속 빈 모양): 최소 수 구간 안의 문제를 무작위로 만든다.

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var tip: String = ""
## 최소 수 구간 [min_moves, max_moves].
@export var min_moves: int = 3
@export var max_moves: int = 5
## 가운데가 다른 색인 함정 모양으로 만든다.
@export var hollow: bool = false
## 목표 모양(점선)을 힌트 전까지 숨긴다.
@export var hide_goal: bool = false
