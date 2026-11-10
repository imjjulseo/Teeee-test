class_name RunRewards
extends RefCounted
## 판 끝 정산 (기획서 8.2 · 8.4장). 순수 계산 — 저장은 ProgressStore가 한다.
## - 코인 = ⌊점수 ÷ 100⌋ + 판에서 주운 금화.
## - 경험치 = 판마다 500 + 0.25 × 점수 (ProgressionConfig, 임시 E26), 판을 넘어 누적. 한 판에 여러 레벨이 오를 수 있다.
## - 레벨업 보상(코인 100 + 다이아 10, 정해진 레벨에서 선택권)은 정산에 들어가지 않는다: 레벨 보상 화면에서 눌러서 받는다 (E36).
## - 레벨이 보드 단계 표 안에서 오르면 보드 업그레이드.


## 레벨 하나의 보상 (받는 곳은 레벨 보상 화면, ProgressStore.claim_level_reward).
class LevelUp:
	extends RefCounted

	var level: int
	var coins: int
	var diamonds: int
	## 선택권 등급 (CharacterData.Grade), 없으면 -1.
	var ticket_grade: int = -1

	func _init(p_level: int, p_coins: int, p_diamonds: int, p_ticket_grade: int) -> void:
		level = p_level
		coins = p_coins
		diamonds = p_diamonds
		ticket_grade = p_ticket_grade


## 결과 화면 경험치 바의 한 구간: level 바가 from에서 to까지 찬다 (to = 1이면 이어서 레벨이 오른다).
class BarStep:
	extends RefCounted

	var level: int
	var from: float
	var to: float

	func _init(p_level: int, p_from: float, p_to: float) -> void:
		level = p_level
		from = p_from
		to = p_to


## 한 판의 정산 결과.
class Result:
	extends RefCounted

	## 이번 판 코인 (점수 몫 + 주운 금화).
	var coins: int = 0
	var picked_coins: int = 0
	var exp_gained: int = 0
	var level_before: int = 1
	var exp_before: int = 0
	var level_after: int = 1
	var exp_after: int = 0
	## level_after에서 다음 레벨까지 필요한 경험치.
	var exp_needed: int = 1
	## 이번 판에 오른 레벨들 (보상은 아직 받지 않은 상태).
	var level_ups: Array[LevelUp] = []
	## 경험치 바 연출 구간 (차례대로, 마지막은 level_after).
	var bar_steps: Array[BarStep] = []
	var stage_before: int = 1
	var stage_after: int = 1
	## 다음 보드 단계 안내 (이미 본 게임 보드면 빈 문자열).
	var next_stage_description: String = ""
	## 새로 된 보드 단계의 안내 (보드 업그레이드가 없으면 빈 문자열).
	var upgraded_description: String = ""

	func board_upgraded() -> bool:
		return stage_after > stage_before


## score점, 판에서 주운 금화 picked_coins개로 끝난 판을 (level, experience)에서 정산한다.
static func compute(score: int, picked_coins: int, level: int, experience: int, config: ProgressionConfig) -> Result:
	var result: Result = Result.new()
	result.picked_coins = picked_coins
	result.coins = config.coins_for_run(score, picked_coins)
	result.exp_gained = config.exp_for_score(score)
	result.level_before = level
	result.exp_before = experience
	result.stage_before = config.stage_number(level)
	var lv: int = level
	var xp: int = experience + result.exp_gained
	var bar_from: float = _ratio(experience, config.exp_to_next(lv))
	while xp >= config.exp_to_next(lv):
		result.bar_steps.append(BarStep.new(lv, bar_from, 1.0))
		bar_from = 0.0
		xp -= config.exp_to_next(lv)
		lv += 1
		result.level_ups.append(config.level_up_for(lv))
	result.bar_steps.append(BarStep.new(lv, bar_from, _ratio(xp, config.exp_to_next(lv))))
	result.level_after = lv
	result.exp_after = xp
	result.exp_needed = config.exp_to_next(lv)
	result.stage_after = config.stage_number(lv)
	result.next_stage_description = config.next_stage_description(lv)
	if result.board_upgraded():
		result.upgraded_description = config.stage_for_level(lv).description
	return result


static func _ratio(value: int, needed: int) -> float:
	return clampf(float(value) / maxi(needed, 1), 0.0, 1.0)
