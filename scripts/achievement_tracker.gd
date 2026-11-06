class_name AchievementTracker
extends RefCounted
## 업적 판정과 보상 (기획서 8.6 · 8.7장). 목록·목표·보상은 AchievementBook, 진행·달성·누적 통계는 AchievementStore,
## 보상 재화는 ProgressStore. 판이 결과로 끝나면 record_game이 한 번에 평가한다
## (메뉴로 나간 판·체험 판은 부르지 않는다 → 업적 진행 없음).
## - 공통 업적: 누적 통계·최고 점수·모은 캐릭터 수가 단계 목표를 넘을 때마다 달성.
## - 캐릭터 업적: 그 캐릭터로 한 판의 지표(RunMetrics)가 목표 이상이면 달성. 앞 단계를 깨야 다음 단계가 열린다.
## - 히든 업적: 진행 값만 기록한다 (달성 판정·캐릭터 지급은 조건 확정 뒤, 5a 결정).

## 화면에 보일 업적 한 단계.
class TierStatus:
	var id: String = ""
	var name: String = ""
	var text: String = ""
	var value: int = 0
	var goal: int = 0
	var done: bool = false
	## 진행할 수 있는 단계 (앞 단계를 깼다).
	var open: bool = true
	var reward: String = ""


## 이번에 달성한 업적 (결과 화면 보상 목록).
class Completion:
	var name: String = ""
	var reward: String = ""

	func _init(p_name: String, p_reward: String) -> void:
		name = p_name
		reward = p_reward


var book: AchievementBook
var store: AchievementStore
var progress: ProgressStore


func _init(p_book: AchievementBook, p_store: AchievementStore, p_progress: ProgressStore) -> void:
	book = p_book
	store = p_store
	progress = p_progress


## 결과로 끝난 판 하나를 반영한다: 누적 통계, 캐릭터 업적, 히든 업적 진행, 공통 업적. best = 갱신 뒤 최고 점수.
func record_game(session: GameSession, best: int) -> Array[Completion]:
	var metrics: RunMetrics = session.metrics
	metrics.fill_from_session(session)
	store.add_stat("games", 1)
	store.add_stat("blocks", session.stats.blocks_cleared)
	store.add_stat("recipes", session.stats.recipes_completed)
	store.add_stat("coins", session.collected_coins())
	var completions: Array[Completion] = []
	if session.character != null:
		var chain: CharacterAchievementChain = book.chain_for(session.character.id)
		if chain != null:
			_advance_chain(chain, session.character.display_name, metrics, completions)
	for item: HiddenAchievement in book.hidden:
		store.record_progress(item.id(), metrics.value(item.metric))
	completions.append_array(_check_common(best))
	store.save()
	return completions


## 튜토리얼 완료 업적 (숨김): 처음 한 번만 코인을 준다. 달성했으면 그 업적, 이미 있었으면 null.
const TUTORIAL_ID: String = "tut"


func complete_tutorial() -> Completion:
	if store.is_done(TUTORIAL_ID):
		return null
	store.mark_done(TUTORIAL_ID)
	progress.add_currency(book.tutorial_coins, 0)
	store.save()
	return Completion.new(book.tutorial_name, "● %d" % book.tutorial_coins)


## 판 밖에서 공통 업적만 다시 본다 (업적 화면을 열 때: 뽑기·상점으로 모은 캐릭터 등).
func check_common(best: int) -> Array[Completion]:
	var completions: Array[Completion] = _check_common(best)
	store.save()
	return completions


## 공통 업적 한 장의 지금 단계 (모두 깼으면 마지막 단계, done = true).
func common_status(item: CommonAchievement, best: int) -> TierStatus:
	var status: TierStatus = TierStatus.new()
	var tier: int = 0
	while tier < item.goals.size() - 1 and store.is_done(item.id_for(tier)):
		tier += 1
	status.id = item.id_for(tier)
	status.name = "%s %s" % [item.name, book.common_tier_names[tier]]
	status.text = "%s %s" % [item.text, AchievementTracker.format_count(item.goals[tier])]
	status.goal = item.goals[tier]
	status.done = store.is_done(status.id)
	status.value = mini(common_value(item.stat, best), status.goal)
	status.reward = book.reward_text(tier)
	return status


## 캐릭터 업적 3단계 (업적이 없는 캐릭터는 빈 목록 → "준비 중").
func chain_status(character_id: StringName) -> Array[TierStatus]:
	var list: Array[TierStatus] = []
	var chain: CharacterAchievementChain = book.chain_for(character_id)
	if chain == null:
		return list
	for tier: int in chain.tier_count():
		var status: TierStatus = TierStatus.new()
		status.id = chain.id_for(tier)
		status.name = book.chain_tier_names[tier]
		status.text = chain.texts[tier]
		status.goal = chain.goals[tier]
		status.done = store.is_done(status.id)
		status.open = tier == 0 or store.is_done(chain.id_for(tier - 1))
		status.value = status.goal if status.done else mini(store.progress_of(status.id), status.goal)
		status.reward = book.reward_text(tier)
		list.append(status)
	return list


## 공통 업적의 지금 값.
func common_value(stat: StringName, best: int) -> int:
	match stat:
		&"best":
			return best
		&"owned":
			return maxi(progress.unlocked.size() - 1, 0)  # 기본 캐릭터 제외
	return store.stat(String(stat))


## 큰 수를 세 자리마다 쉼표로 (30000 → "30,000").
static func format_count(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


func _advance_chain(chain: CharacterAchievementChain, character_name: String, metrics: RunMetrics, out: Array[Completion]) -> void:
	for tier: int in chain.tier_count():
		var id: String = chain.id_for(tier)
		if store.is_done(id):
			continue
		if tier > 0 and not store.is_done(chain.id_for(tier - 1)):
			return
		var value: int = metrics.value(StringName(chain.metrics[tier]))
		store.record_progress(id, value)
		if value < chain.goals[tier]:
			return
		_complete(id, "%s %s" % [character_name, book.chain_tier_names[tier]], tier, out)


func _check_common(best: int) -> Array[Completion]:
	var out: Array[Completion] = []
	for item: CommonAchievement in book.common:
		var value: int = common_value(item.stat, best)
		for tier: int in item.goals.size():
			var id: String = item.id_for(tier)
			if store.is_done(id):
				continue
			store.record_progress(id, value)
			if value >= item.goals[tier]:
				_complete(id, "%s %s" % [item.name, book.common_tier_names[tier]], tier, out)
	return out


func _complete(id: String, name: String, tier: int, out: Array[Completion]) -> void:
	store.mark_done(id)
	progress.add_currency(book.tier_coin(tier), book.tier_diamond(tier))
	out.append(Completion.new(name, book.reward_text(tier)))
