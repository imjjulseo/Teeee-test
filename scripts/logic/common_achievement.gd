class_name CommonAchievement
extends Resource
## 공통 업적 한 장 (기획서 8.6장): 누적·기록 값 하나가 단계 목표(I · II · III)를 넘을 때마다 단계 보상.

## 값 이름: blocks(블록 누적 제거) / recipes(족보 누적 완성) / best(한 판 최고 점수) / games(플레이한 판) /
## coins(판에서 주운 금화 누적) / owned(모은 캐릭터 수, 기본 제외).
@export var stat: StringName = &""
@export var name: String = ""
## 조건 문구 (목표 앞에 붙는다: "블록 누적 제거 300").
@export var text: String = ""
@export var goals: PackedInt32Array = PackedInt32Array()


func id_for(tier: int) -> String:
	return "g_%s_%d" % [stat, tier + 1]
