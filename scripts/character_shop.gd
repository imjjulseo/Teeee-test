class_name CharacterShop
extends RefCounted
## 뽑기 · 선택권 합성 · 광고 보상 (기획서 8.4 · 8.5장). 수치는 GachaConfig, 저장은 ProgressStore.
## 뽑기 1회 = 지금 레벨의 뽑기 단계 가격(코인)으로 등급을 굴린 뒤 그 등급 캐릭터 하나를 무작위로.
## 새 캐릭터면 해금, 이미 있으면 그 등급 선택권 1장. 다이아 구매·선택권 사용은 CharacterCollection.
## 튜토리얼 흐름의 첫 뽑기는 pull(forced)로 고정한다 (ShopScreen이 TutorialFlow를 보고 정한다).

## 뽑기 1회의 결과.
class PullResult:
	var character: CharacterData
	var grade: int = 0
	## 새로 얻었으면 true, 중복이라 선택권을 받았으면 false.
	var is_new: bool = false

var collection: CharacterCollection
var gacha: GachaConfig
## 뽑기 난수 (테스트는 seed를 정한다). 판의 seed RNG와 따로 쓴다 — 메뉴의 뽑기는 판과 무관하다.
var rng: RandomNumberGenerator


func _init(p_collection: CharacterCollection, p_rng: RandomNumberGenerator = null) -> void:
	collection = p_collection
	gacha = p_collection.gacha
	rng = p_rng
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()


func progress() -> ProgressStore:
	return collection.progress


## 뽑기 1회 가격 (고정, E25).
func pull_price() -> int:
	return gacha.pull_price()


func can_pull() -> bool:
	return gacha.tier_for(progress().level) != null and progress().coins >= pull_price()


## 코인으로 1회 뽑는다. 코인이 모자라거나 뽑기 단계가 없으면 null.
## forced가 있으면 그중 아직 없는 캐릭터 하나로 고정한다 (튜토리얼 흐름의 첫 뽑기: 정원사·시계공).
func pull(forced: Array[StringName] = []) -> PullResult:
	if not can_pull():
		return null
	var tier: GachaTier = gacha.tier_for(progress().level)
	var character: CharacterData = _forced_pick(forced)
	var grade: int = character.grade if character != null else tier.roll_grade(rng)
	if character == null:
		var pool: Array[CharacterData] = collection.gacha_pool(grade)
		if pool.is_empty():
			push_error("CharacterShop: no gacha character of grade %d" % grade)
			return null
		character = pool[rng.randi_range(0, pool.size() - 1)]
	progress().spend_coins(gacha.pull_price())
	var result: PullResult = PullResult.new()
	result.character = character
	result.grade = grade
	result.is_new = not progress().is_unlocked(result.character.id)
	if result.is_new:
		progress().unlock(result.character.id)
	else:
		progress().add_ticket(grade)
	return result


func _forced_pick(forced: Array[StringName]) -> CharacterData:
	var options: Array[CharacterData] = []
	for id: StringName in forced:
		var character: CharacterData = collection.roster.find(id)
		if character.id == id and not progress().is_unlocked(id):
			options.append(character)
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else null


## grade 선택권 fuse_count장으로 다음 등급 선택권 1장을 만들 수 있는지.
func can_fuse(grade: int) -> bool:
	return gacha.next_grade(grade) >= 0 and progress().ticket_count(grade) >= gacha.fuse_count


func fuse(grade: int) -> bool:
	if not can_fuse(grade):
		return false
	for _i: int in gacha.fuse_count:
		progress().spend_ticket(grade)
	progress().add_ticket(gacha.next_grade(grade))
	return true


## today("YYYY-MM-DD")에 남은 광고 보상 횟수.
func ads_left(today: String) -> int:
	return maxi(gacha.ad_daily_max - progress().ads_claimed_on(today), 0)


## 광고 보상 (자리만, E18 — 실제 광고 없이 다이아를 준다). 오늘 횟수를 다 썼으면 false.
func claim_ad(today: String) -> bool:
	if ads_left(today) <= 0:
		return false
	progress().record_ad(today)
	progress().add_currency(0, gacha.ad_diamonds)
	return true


## 오늘 날짜 (기기 시계, 광고 횟수의 기준).
static func today() -> String:
	return Time.get_date_string_from_system()
