class_name ProgressStore
extends RefCounted
## 계정 진행·재화 (기획서 8.2 · 8.4 · 8.9장): 레벨·경험치, 코인·다이아, 등급별 선택권, 해금한 캐릭터.
## 저장 파일 입출력은 SaveData가 한다 ([progress]). 바꿀 때마다 전체 항목을 한 번에 저장한다.
## 처음에는 기본 캐릭터만 해금되어 있다 (기본 캐릭터는 늘 해금).

const SECTION: String = "progress"
const KEY_LEVEL: String = "level"
const KEY_EXP: String = "exp"
const KEY_COINS: String = "coins"
const KEY_DIAMONDS: String = "diamonds"
const KEY_TICKETS: String = "tickets"
const KEY_UNLOCKED: String = "unlocked"
const KEY_AD_DAY: String = "ad_day"
const KEY_AD_COUNT: String = "ad_count"
const KEY_REWARD_CLAIMS: String = "reward_claims"
## 레벨 보상이 있는 첫 레벨 (Lv1은 보상이 없다).
const FIRST_REWARD_LEVEL: int = 2
const BASIC_ID: StringName = &"basic"

var path: String
var level: int = 1
## 지금 레벨에서 모은 경험치.
var experience: int = 0
var coins: int = 0
var diamonds: int = 0
## 등급(CharacterData.Grade) → 선택권 수.
var tickets: Dictionary[int, int] = {}
var unlocked: Array[StringName] = [BASIC_ID]
## 광고 보상을 마지막으로 받은 날("YYYY-MM-DD")과 그날 받은 횟수.
var ad_day: String = ""
var ad_count: int = 0
## 레벨 보상을 받은 레벨들 (E36: 레벨 보상 화면에서 눌러서 받는다).
var reward_claims: Array[int] = []


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	level = maxi(_int(data, KEY_LEVEL, 1), 1)
	experience = maxi(_int(data, KEY_EXP, 0), 0)
	coins = maxi(_int(data, KEY_COINS, 0), 0)
	diamonds = maxi(_int(data, KEY_DIAMONDS, 0), 0)
	var saved_tickets: Variant = data.get_value(SECTION, KEY_TICKETS, {})
	if saved_tickets is Dictionary:
		for grade: Variant in saved_tickets:
			if typeof(grade) == TYPE_INT and typeof(saved_tickets[grade]) == TYPE_INT and saved_tickets[grade] > 0:
				tickets[grade] = saved_tickets[grade]
	var saved_unlocked: Variant = data.get_value(SECTION, KEY_UNLOCKED, PackedStringArray())
	if saved_unlocked is PackedStringArray or saved_unlocked is Array:
		for id: Variant in saved_unlocked:
			if (typeof(id) == TYPE_STRING or typeof(id) == TYPE_STRING_NAME) and not unlocked.has(StringName(id)):
				unlocked.append(StringName(id))
	var saved_day: Variant = data.get_value(SECTION, KEY_AD_DAY, "")
	ad_day = saved_day if typeof(saved_day) == TYPE_STRING else ""
	ad_count = maxi(_int(data, KEY_AD_COUNT, 0), 0)
	var saved_claims: Variant = data.get_value(SECTION, KEY_REWARD_CLAIMS, PackedInt32Array())
	if saved_claims is PackedInt32Array or saved_claims is Array:
		for value: Variant in saved_claims:
			if typeof(value) == TYPE_INT:
				reward_claims.append(value)


## 판 끝 정산을 반영한다 (코인·레벨·경험치). 레벨업 보상은 claim_level_reward로 따로 받는다.
func apply_rewards(rewards: RunRewards.Result) -> void:
	level = rewards.level_after
	experience = rewards.exp_after
	coins += rewards.coins
	save()


## 아직 받지 않은 레벨 보상이 있는 레벨들 (낮은 레벨부터).
func claimable_levels() -> Array[int]:
	var levels: Array[int] = []
	for lv: int in range(FIRST_REWARD_LEVEL, level + 1):
		if not reward_claims.has(lv):
			levels.append(lv)
	return levels


func is_reward_claimable(p_level: int) -> bool:
	return p_level >= FIRST_REWARD_LEVEL and p_level <= level and not reward_claims.has(p_level)


## 그 레벨의 보상을 받는다. 아직 오르지 않았거나 이미 받았으면 false.
func claim_level_reward(reward: RunRewards.LevelUp) -> bool:
	if not is_reward_claimable(reward.level):
		return false
	reward_claims.append(reward.level)
	coins += reward.coins
	diamonds += reward.diamonds
	if reward.ticket_grade >= 0:
		tickets[reward.ticket_grade] = ticket_count(reward.ticket_grade) + 1
	save()
	return true


## 다이아를 쓴다. 모자라면 쓰지 않고 false.
func spend_diamonds(amount: int) -> bool:
	if amount > diamonds:
		return false
	diamonds -= amount
	save()
	return true


## 코인을 쓴다. 모자라면 쓰지 않고 false.
func spend_coins(amount: int) -> bool:
	if amount > coins:
		return false
	coins -= amount
	save()
	return true


## today에 받은 광고 보상 횟수 (날이 바뀌면 0).
func ads_claimed_on(today: String) -> int:
	return ad_count if ad_day == today else 0


## today의 광고 보상 1회를 기록한다.
func record_ad(today: String) -> void:
	ad_count = ads_claimed_on(today) + 1
	ad_day = today
	save()


func add_currency(add_coins: int, add_diamonds: int) -> void:
	coins = maxi(coins + add_coins, 0)
	diamonds = maxi(diamonds + add_diamonds, 0)
	save()


func ticket_count(grade: int) -> int:
	return tickets.get(grade, 0)


## 그 등급 선택권 1장을 쓴다. 없으면 false.
func spend_ticket(grade: int) -> bool:
	if ticket_count(grade) <= 0:
		return false
	tickets[grade] = ticket_count(grade) - 1
	if tickets[grade] == 0:
		tickets.erase(grade)
	save()
	return true


## 선택권을 1장 더한다 (뽑기 중복·합성, 개발용 디버그).
func add_ticket(grade: int) -> void:
	tickets[grade] = ticket_count(grade) + 1
	save()


func is_unlocked(id: StringName) -> bool:
	return id == BASIC_ID or unlocked.has(id)


func unlock(id: StringName) -> void:
	if not unlocked.has(id):
		unlocked.append(id)
		save()


## 개발용: 레벨을 바꾼다 (경험치 0부터).
func set_level(value: int) -> void:
	level = maxi(value, 1)
	experience = 0
	save()


func save() -> void:
	var data: SaveData = SaveData.new(path)
	data.set_value(SECTION, KEY_LEVEL, level)
	data.set_value(SECTION, KEY_EXP, experience)
	data.set_value(SECTION, KEY_COINS, coins)
	data.set_value(SECTION, KEY_DIAMONDS, diamonds)
	data.set_value(SECTION, KEY_TICKETS, tickets.duplicate())
	var ids: PackedStringArray = PackedStringArray()
	for id: StringName in unlocked:
		ids.append(String(id))
	data.set_value(SECTION, KEY_UNLOCKED, ids)
	data.set_value(SECTION, KEY_AD_DAY, ad_day)
	data.set_value(SECTION, KEY_AD_COUNT, ad_count)
	data.set_value(SECTION, KEY_REWARD_CLAIMS, PackedInt32Array(reward_claims))
	data.save()


static func _int(data: SaveData, key: String, default: int) -> int:
	var value: Variant = data.get_value(SECTION, key, default)
	return value if typeof(value) == TYPE_INT else default
