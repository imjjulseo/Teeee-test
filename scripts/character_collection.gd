class_name CharacterCollection
extends RefCounted
## 캐릭터 모음 규칙 (기획서 8.3 · 8.5장): 카드 상태(장착 중·보유·미보유·히든 업적), 등급순 목록, 선택권·다이아로 해금, 장착. 진행 저장은 ProgressStore, 장착 저장은 CharacterStore가 한다.
## 화면은 이 클래스의 결과를 보여 주기만 한다. 뽑기·선택권 합성은 CharacterShop.

enum Status {
	EQUIPPED,  ## 장착 중
	OWNED,  ## 보유
	HIDDEN,  ## 히든 캐릭터: 히든 업적으로만 (얻기 전까지 정체를 숨김)
	UNOWNED,  ## 미보유 (뽑기·상점에서 얻는다)
}

## 상점 한 줄의 해금 방법: 선택권 수, 다이아 가격, 상점에 등급이 열리는 레벨과 열렸는지, 다이아가 충분한지.
class Offer:
	var tickets: int = 0
	var diamond_price: int = 0
	var shop_level: int = 1
	var shop_open: bool = false
	var affordable: bool = false

## 상점 설명창의 구매 자리 (E37).
class PurchaseAction:
	var kind: Purchase = Purchase.OWNED
	var text: String = ""
	## 상점 카드 아래의 짧은 문구 (◆ 80 · 선택 · 보유 · Lv 8, E38).
	var card_text: String = ""
	var enabled: bool = false

enum Purchase {
	OWNED,  ## 이미 가짐
	DIAMOND,  ## 다이아로 구매
	TICKET,  ## 선택권 사용
	CLOSED,  ## 그 등급 상점이 아직 안 열림
}

var roster: CharacterRoster
var progress: ProgressStore
var equipped: CharacterStore
var gacha: GachaConfig


## p_gacha가 없으면 기본값 (다이아 상점 가격·개방 레벨).
func _init(p_roster: CharacterRoster, p_progress: ProgressStore, p_equipped: CharacterStore, p_gacha: GachaConfig = null) -> void:
	roster = p_roster
	progress = p_progress
	equipped = p_equipped
	gacha = p_gacha if p_gacha != null else GachaConfig.new()


## 기본 캐릭터 → 등급순(희귀 → 신화) → 히든. 같은 등급은 로스터 순서.
func sorted() -> Array[CharacterData]:
	var list: Array[CharacterData] = roster.characters.duplicate()
	var order: Dictionary[CharacterData, int] = {}
	for i: int in list.size():
		order[list[i]] = i
	list.sort_custom(func(a: CharacterData, b: CharacterData) -> bool:
		return a.grade < b.grade or (a.grade == b.grade and order[a] < order[b]))
	return list


## 뽑기·다이아 상점에 나오는 캐릭터 (희귀~신화).
static func is_gacha(character: CharacterData) -> bool:
	return character.grade != CharacterData.Grade.BASIC and character.grade != CharacterData.Grade.HIDDEN


## grade 등급의 뽑기 캐릭터 (로스터 순서).
func gacha_pool(grade: int) -> Array[CharacterData]:
	var pool: Array[CharacterData] = []
	for character: CharacterData in roster.characters:
		if character.grade == grade and CharacterCollection.is_gacha(character):
			pool.append(character)
	return pool


## 지금 장착한 캐릭터 (해금하지 않은 캐릭터가 저장돼 있으면 기본 캐릭터).
func equipped_character() -> CharacterData:
	var selected: CharacterData = roster.find(equipped.selected_id)
	return selected if progress.is_unlocked(selected.id) else roster.default_character()


func status_of(character: CharacterData) -> Status:
	if progress.is_unlocked(character.id):
		return Status.EQUIPPED if character == equipped_character() else Status.OWNED
	return Status.HIDDEN if character.grade == CharacterData.Grade.HIDDEN else Status.UNOWNED


## 카드에 보이는 상태 문구.
func status_text(character: CharacterData) -> String:
	match status_of(character):
		Status.EQUIPPED:
			return "장착 중"
		Status.OWNED:
			return "보유"
		Status.HIDDEN:
			return "히든 업적"
	return "미보유"


func offer_for(character: CharacterData) -> Offer:
	var offer: Offer = Offer.new()
	offer.tickets = progress.ticket_count(character.grade)
	offer.diamond_price = gacha.shop_price(character.grade)
	offer.shop_level = gacha.shop_level(character.grade)
	offer.shop_open = gacha.is_shop_open(character.grade, progress.level)
	offer.affordable = progress.diamonds >= offer.diamond_price
	return offer


## 상점 설명창의 구매 자리: use_ticket = 그 등급의 [사용]이 켜져 있다 (선택권은 상점이 열리기 전에도 쓴다).
func purchase_action(character: CharacterData, use_ticket: bool) -> PurchaseAction:
	var action: PurchaseAction = PurchaseAction.new()
	var offer: Offer = offer_for(character)
	if progress.is_unlocked(character.id):
		action.text = "보유"
		action.card_text = action.text
	elif use_ticket and offer.tickets > 0:
		action.kind = Purchase.TICKET
		action.text = "선택권 사용"
		action.card_text = "선택"
		action.enabled = true
	elif offer.shop_open:
		action.kind = Purchase.DIAMOND
		action.text = "◆ %d" % offer.diamond_price
		action.card_text = action.text
		action.enabled = offer.affordable
	else:
		action.kind = Purchase.CLOSED
		action.text = "Lv %d에 열림" % offer.shop_level
		action.card_text = "Lv %d" % offer.shop_level
	return action


## 히든 캐릭터는 얻기 전까지 정체를 숨긴다.
func is_veiled(character: CharacterData) -> bool:
	return character.grade == CharacterData.Grade.HIDDEN and not progress.is_unlocked(character.id)


## 그 등급 선택권 1장으로 해금한다. 선택권이 없거나 이미 있거나 뽑기 캐릭터가 아니면 false.
## (선택권은 상점에 등급이 열리기 전에도 쓸 수 있다.)
func unlock_with_ticket(character: CharacterData) -> bool:
	if progress.is_unlocked(character.id) or not CharacterCollection.is_gacha(character):
		return false
	if not progress.spend_ticket(character.grade):
		return false
	progress.unlock(character.id)
	return true


## 다이아 상점에서 산다. 등급이 열리지 않았거나 다이아가 모자라면 false.
func buy_with_diamonds(character: CharacterData) -> bool:
	if progress.is_unlocked(character.id) or not CharacterCollection.is_gacha(character):
		return false
	if not gacha.is_shop_open(character.grade, progress.level):
		return false
	if not progress.spend_diamonds(gacha.shop_price(character.grade)):
		return false
	progress.unlock(character.id)
	return true


## 해금한 캐릭터만 장착한다.
func equip(character: CharacterData) -> bool:
	if not progress.is_unlocked(character.id):
		return false
	equipped.select(character.id)
	return true


## 등급별 [해금 수, 전체 수] (기본 캐릭터 제외).
func grade_counts(grade: CharacterData.Grade) -> Vector2i:
	var owned: int = 0
	var total: int = 0
	for character: CharacterData in roster.characters:
		if character.grade != grade:
			continue
		total += 1
		if progress.is_unlocked(character.id):
			owned += 1
	return Vector2i(owned, total)
