class_name HiddenAchievement
extends Resource
## 히든 업적 (기획서 8.7장, E12): 조건은 달성 전까지 숨기고, 달성하면 히든 캐릭터를 얻는다.
## 지금은 진행만 기록한다 (5a 결정: 달성 판정·캐릭터 지급은 조건이 확정된 뒤).

@export var character_id: StringName = &""
@export var name: String = ""
@export var text: String = ""
## RunMetrics 지표 이름과 목표 (한 판에서 가장 큰 값).
@export var metric: StringName = &""
@export var goal: int = 1


func id() -> String:
	return "h_%s" % character_id
