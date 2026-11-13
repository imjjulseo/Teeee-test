class_name AchievementBook
extends Resource
## 업적 목록과 보상 (기획서 8.6 · 8.7장, 별첨 B). 목표·보상은 (임시) 수치라 코드에 두지 않는다 (E15).

## 단계 이름: 캐릭터 업적(입문·숙련·극한), 공통 업적(I · II · III).
@export var chain_tier_names: PackedStringArray = PackedStringArray(["입문", "숙련", "극한"])
@export var common_tier_names: PackedStringArray = PackedStringArray(["I", "II", "III"])
## 단계별 보상 (공통·캐릭터 업적 같음): I 코인 100 · II 다이아 10 · III 다이아 30.
@export var tier_coins: PackedInt32Array = PackedInt32Array([100, 0, 0])
@export var tier_diamonds: PackedInt32Array = PackedInt32Array([0, 10, 30])

@export var common: Array[CommonAchievement] = []
@export var chains: Array[CharacterAchievementChain] = []
@export var hidden: Array[HiddenAchievement] = []

## 튜토리얼 완료 업적 (숨김, 8.6장): 이름과 보상 코인.
@export var tutorial_name: String = "규칙 익히기"
@export var tutorial_coins: int = 50

## 히든 업적 보상 칸 문구 (달성하면 그 캐릭터를 바로 해금한다, E39).
@export var hidden_reward: String = "히든 캐릭터"

## 히든 업적 "직선 이동 뒤 매치"로 치는 같은 방향 연속 칸 수 (8.7장 파키케팔로사우르스 조건 초안).
@export var straight_run: int = 5


## 캐릭터의 업적 3단계 (없으면 null → 업적 화면에 나오지 않는다).
func chain_for(character_id: StringName) -> CharacterAchievementChain:
	for chain: CharacterAchievementChain in chains:
		if chain.character_id == character_id:
			return chain
	return null


func tier_coin(tier: int) -> int:
	return tier_coins[tier] if tier >= 0 and tier < tier_coins.size() else 0


func tier_diamond(tier: int) -> int:
	return tier_diamonds[tier] if tier >= 0 and tier < tier_diamonds.size() else 0


## 단계 보상 문구 ("● 100" / "◆ 10").
func reward_text(tier: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if tier_coin(tier) > 0:
		parts.append("● %d" % tier_coin(tier))
	if tier_diamond(tier) > 0:
		parts.append("◆ %d" % tier_diamond(tier))
	return "  ".join(parts)


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for item: CommonAchievement in common:
		if item == null or item.goals.is_empty():
			errors.append("common achievements need goals")
			break
	for chain: CharacterAchievementChain in chains:
		if chain == null or chain.tier_count() != chain_tier_names.size():
			errors.append("chain %s needs %d texts, metrics and goals" % [chain.character_id if chain != null else &"?", chain_tier_names.size()])
	if straight_run <= 0:
		errors.append("straight_run must be > 0")
	return errors


static func ensure_valid(book: AchievementBook) -> AchievementBook:
	if book == null:
		push_error("AchievementBook: book is null, using an empty book")
		return AchievementBook.new()
	var errors: PackedStringArray = book.validate()
	if errors.is_empty():
		return book
	push_error("AchievementBook: invalid settings, using an empty book instead: %s" % ", ".join(errors))
	return AchievementBook.new()
