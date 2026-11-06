class_name CharacterAchievementChain
extends Resource
## 캐릭터 업적 3단계 (기획서 8.6장, 별첨 B): 입문 · 숙련 · 극한. 앞 단계를 깨야 다음이 열리고, 그 캐릭터로 플레이할 때만 진행.
## 단계마다 RunMetrics 지표 하나와 목표. 판이 끝날 때 그 판의 지표 값이 목표 이상이면 달성 (진행은 가장 큰 값을 남긴다).

@export var character_id: StringName = &""
@export var texts: PackedStringArray = PackedStringArray()
## 단계별 지표 이름 (능력의 METRIC_* 상수 또는 RunMetrics.SCORE·MATCHES·RECIPES).
@export var metrics: PackedStringArray = PackedStringArray()
@export var goals: PackedInt32Array = PackedInt32Array()


func id_for(tier: int) -> String:
	return "%s_%d" % [character_id, tier + 1]


func tier_count() -> int:
	return mini(texts.size(), mini(metrics.size(), goals.size()))
