class_name GachaTier
extends Resource
## 뽑기 머신 단계 하나 (기획서 8.5장): 이 계정 레벨부터의 등급 확률(%). 레벨이 오르면 머신이 업그레이드된다 (E25).
## 가격은 단계와 무관하게 GachaConfig.price 하나. 확률 수치는 (임시, E15).

## 이 레벨부터 이 단계.
@export var min_level: int = 1
## 등급(CharacterData.Grade) → 확률(%). 합이 100.
@export var rates: Dictionary[int, float] = {}

## 높은 등급부터 굴린다 (HTML과 같은 순서 → 같은 난수면 같은 등급).
const ROLL_ORDER: Array[int] = [CharacterData.Grade.MYTH, CharacterData.Grade.LEGEND, CharacterData.Grade.HERO, CharacterData.Grade.RARE]


## 등급 하나를 뽑는다. 확률이 모자라면(반올림 오차) 희귀.
func roll_grade(rng: RandomNumberGenerator) -> int:
	var x: float = rng.randf() * 100.0
	for grade: int in ROLL_ORDER:
		var rate: float = rates.get(grade, 0.0)
		if x < rate:
			return grade
		x -= rate
	return CharacterData.Grade.RARE


func rate_of(grade: int) -> float:
	return rates.get(grade, 0.0)


func total_rate() -> float:
	var total: float = 0.0
	for grade: int in rates:
		total += rates[grade]
	return total
