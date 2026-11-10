class_name ShopScreen
extends Control
## 상점 화면 (기획서 8.1 · 8.5장, E38). 위 줄 · 아래 줄 + 탭 두 개 (열면 늘 뽑기부터):
## - 뽑기: 머신 단계, 상자(누르거나 "뽑기"), 등급 확률. 광고 보상은 자리가 정해질 때까지 숨긴다 (%AdButton).
## - 선택: 등급 구역(ShopGradeSection, 씬에 등급마다): 머리줄, 선택권 수·[사용]·[합성], 그 등급 캐릭터 카드 (E37·E38).
##   카드 아래에 가격(◆ 80) · 선택([사용]이 켜졌을 때) · 보유. 누르면 캐릭터 설명창(CharacterSheet.open_for_shop)이 열리고 장착 자리에 구매 자리.
##   합성·구매·선택권 사용은 ConfirmDialog로 묻는다.
## 규칙은 CharacterShop(뽑기·합성·광고)과 CharacterCollection(선택권·다이아 해금)이 정하고, 이 화면은 보여 주기만 한다.
## 캐릭터 카드 수는 로스터로 정해지므로 코드에서 인스턴스화한다.

signal trial_started

enum Tab { GACHA, SHOP }

@export var roster: CharacterRoster
@export var progression: ProgressionConfig
@export var theme_data: BoardTheme
## 설명창의 "튜토리얼 및 체험" (튜토리얼이 있는 캐릭터만).
@export var lessons: CharacterTutorialBook
## 튜토리얼 흐름 (첫 뽑기 고정·1회분 코인)과 그 안내.
@export var tutorial: TutorialScript
@export var spotlight: SpotlightOverlay
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var shop: CharacterShop
var collection: CharacterCollection
var tab: Tab = Tab.GACHA
## 상자가 열리는 중 (결과 카드를 닫을 때까지 다시 뽑지 않는다).
var busy: bool = false
var _reduce_motion: bool = false
var _sections: Array[ShopGradeSection] = []
var _ticket_use: TicketSelection = TicketSelection.new()
## 확인창에서 "확인"을 누르면 할 일.
var _pending_confirm: Callable
var _last: CharacterShop.PullResult
var _tutorial_store: TutorialStore
var _flow: TutorialFlow
## 방금 뽑은 것이 튜토리얼 흐름의 첫 뽑기였다 (결과를 닫으면 안내).
var _first_pull: bool = false

@onready var _top_bar: TopBar = %TopBar
@onready var _nav: BottomNav = %BottomNav
@onready var _gacha_tab: Button = %GachaTab
@onready var _shop_tab: Button = %ShopTab
@onready var _gacha_page: Control = %GachaPage
@onready var _shop_page: Control = %ShopPage
@onready var _chest: GachaChest = %Chest
@onready var _tap_label: Label = %TapLabel
@onready var _pull_button: Button = %PullButton
@onready var _rate_label: Label = %RateLabel
@onready var _tier_label: Label = %TierLabel
@onready var _ad_button: Button = %AdButton
@onready var _sections_box: VBoxContainer = %Sections
@onready var _reveal: GachaReveal = %Reveal
@onready var _sheet: CharacterSheet = %CharacterSheet
@onready var _confirm: ConfirmDialog = %ConfirmDialog


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	collection = CharacterCollection.new(roster, ProgressStore.new(save_path), CharacterStore.new(save_path), progression.gacha)
	shop = CharacterShop.new(collection)
	_reduce_motion = OptionsStore.new(save_path).reduce_motion
	_tutorial_store = TutorialStore.new(save_path)
	_flow = TutorialFlow.new(_tutorial_store, AchievementStore.new(save_path).stat("games"))
	_give_first_pull_coins()
	_top_bar.setup(save_path)
	_nav.setup(save_path)
	_build_shop_list()
	set_tab(Tab.SHOP if TrialRequest.take_back_to_shop() else Tab.GACHA)
	if _flow.is_first_pull():
		_show_pull_guide.call_deferred()


## 튜토리얼 흐름의 첫 뽑기 전 처음 들어오면 1회분 코인 (한 번만).
func _give_first_pull_coins() -> void:
	if tutorial == null or not tutorial.gift_first_pull or not _flow.is_first_pull():
		return
	if _tutorial_store.has_seen(TutorialStore.SEEN_GACHA_GIFT):
		return
	_tutorial_store.mark_seen(TutorialStore.SEEN_GACHA_GIFT)
	collection.progress.add_currency(shop.pull_price(), 0)


func _show_pull_guide() -> void:
	if spotlight == null or not is_inside_tree():
		return
	await get_tree().process_frame  # 버튼 자리가 정해진 뒤
	spotlight.open(SpotlightOverlay.Mode.ACT, "뽑기", "코인으로 상자를 열면 캐릭터가 나와요",
		[_pull_button.get_global_rect()] as Array[Rect2], "", false, true)


## 첫 뽑기 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return spotlight != null and spotlight.is_open()


func _on_spotlight_tapped() -> void:
	spotlight.close()


func set_tab(p_tab: Tab) -> void:
	tab = p_tab
	_gacha_page.visible = tab == Tab.GACHA
	_shop_page.visible = tab == Tab.SHOP
	_gacha_tab.set_pressed_no_signal(tab == Tab.GACHA)
	_shop_tab.set_pressed_no_signal(tab == Tab.SHOP)
	_refresh()


## 마지막 뽑기 결과 (테스트/디버그용).
func last_result() -> CharacterShop.PullResult:
	return _last


func ticket_rows() -> Array[TicketRow]:
	var rows: Array[TicketRow] = []
	for section: ShopGradeSection in _sections:
		rows.append(section.ticket_row())
	return rows


func shop_card_for(id: StringName) -> ShopCard:
	for section: ShopGradeSection in _sections:
		for card: ShopCard in section.cards():
			if card.character.id == id:
				return card
	return null


# --- 만들기 --------------------------------------------------------------------

func _build_shop_list() -> void:
	for node: Node in _sections_box.get_children():
		var section: ShopGradeSection = node as ShopGradeSection
		section.setup(theme_data.grade_color(section.grade), progression.gacha.next_grade(section.grade), collection.gacha_pool(section.grade))
		_sections.append(section)


# --- 보이기 --------------------------------------------------------------------

func _refresh() -> void:
	var progress: ProgressStore = collection.progress
	_top_bar.refresh()
	_refresh_gacha(progress)
	_refresh_shop(progress)


func _refresh_gacha(progress: ProgressStore) -> void:
	var gacha: GachaConfig = progression.gacha
	var tier: GachaTier = gacha.tier_for(progress.level)
	var price: int = shop.pull_price()
	_pull_button.text = "뽑기 · ● %d" % price
	_pull_button.disabled = busy or not shop.can_pull()
	if not busy:
		_tap_label.text = "상자를 눌러 뽑기" if shop.can_pull() else "코인이 부족해요"
	_rate_label.text = ShopScreen.rate_text(tier)
	_tier_label.text = ShopScreen.tier_text(gacha, progress.level)
	var left: int = shop.ads_left(CharacterShop.today())
	_ad_button.text = "광고 보고 ◆ %d · 오늘 %d/%d" % [gacha.ad_diamonds, gacha.ad_daily_max - left, gacha.ad_daily_max]
	_ad_button.disabled = left <= 0


func _refresh_shop(progress: ProgressStore) -> void:
	var gacha: GachaConfig = progression.gacha
	for section: ShopGradeSection in _sections:
		var tickets: int = progress.ticket_count(section.grade)
		_ticket_use.sync(section.grade, tickets)
		section.show_shop(gacha.is_shop_open(section.grade, progress.level), gacha.shop_level(section.grade))
		section.ticket_row().show_count(tickets, shop.can_fuse(section.grade), _ticket_use.is_on(section.grade))
		for card: ShopCard in section.cards():
			card.show_action(collection.purchase_action(card.character, _ticket_use.is_on(section.grade)))


## "신화 0.1% · 전설 0.9% · 영웅 34% · 희귀 65%"
static func rate_text(tier: GachaTier) -> String:
	if tier == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for grade: int in GachaTier.ROLL_ORDER:
		parts.append("%s %s%%" % [CharacterData.GRADE_NAMES[grade], Ability.format_number(tier.rate_of(grade))])
	return " · ".join(parts)


## "뽑기 머신 1단계"
static func tier_text(gacha: GachaConfig, level: int) -> String:
	return "뽑기 머신 %d단계" % gacha.tier_number(level)


# --- 입력 ----------------------------------------------------------------------

## 상자나 "열기" 버튼 (shop.tscn에서 연결).
func _on_pull_requested() -> void:
	if busy:
		return
	if not shop.can_pull():
		_tap_label.text = "코인이 부족해요"
		return
	_first_pull = tutorial != null and _flow.is_first_pull()
	_last = shop.pull(tutorial.first_pull if _first_pull else ([] as Array[StringName]))
	if _last == null:
		return
	if _first_pull:  # 첫 캐릭터: 바로 장착하고 흐름을 넘긴다
		collection.equip(_last.character)
		_tutorial_store.got_first_character(_last.character.id)
		_flow = TutorialFlow.new(_tutorial_store, _flow.games_played)
	if spotlight != null:
		spotlight.close()
	busy = true
	_tap_label.text = ""
	_refresh()
	var charge: float = 0.0 if _reduce_motion else theme_data.chest_charge_times[_last.grade]
	_chest.play_open(theme_data.grade_color(_last.grade), charge, 0.0 if _reduce_motion else theme_data.chest_open_time)


func _on_chest_opened() -> void:
	_reveal.show_result(_last, 0.0 if _reduce_motion else theme_data.card_flip_time)


func _on_reveal_closed() -> void:
	busy = false
	_chest.reset()
	_refresh()
	_nav.refresh()
	if _first_pull and spotlight != null:
		_first_pull = false
		spotlight.open(SpotlightOverlay.Mode.TAP, "%s 획득!" % _last.character.display_name,
			"%s · 장착했어요. 캐릭터 화면에서 능력을 확인해 보세요" % _last.character.ability_description, [] as Array[Rect2], "", false, true)


func _on_gacha_tab_pressed() -> void:
	set_tab(Tab.GACHA)


func _on_shop_tab_pressed() -> void:
	set_tab(Tab.SHOP)


func _on_ad_button_pressed() -> void:
	if shop.claim_ad(CharacterShop.today()):
		_refresh()


func _on_use_toggled(grade: int) -> void:
	_ticket_use.toggle(grade, collection.progress.ticket_count(grade))
	_refresh()


## [합성]: 정말 할지 묻는다.
func _on_fuse_requested(grade: int) -> void:
	if not shop.can_fuse(grade):
		return
	_ask("%s 선택권 %d장을 %s 선택권 1장으로 합성할까요?" % [CharacterData.GRADE_NAMES[grade], progression.gacha.fuse_count,
		CharacterData.GRADE_NAMES[progression.gacha.next_grade(grade)]], "합성", _fuse.bind(grade))


func _fuse(grade: int) -> void:
	if shop.fuse(grade):
		_refresh()


## 캐릭터 줄을 눌렀다: 설명창.
func _on_character_chosen(character: CharacterData) -> void:
	_open_sheet(character)


func _open_sheet(character: CharacterData) -> void:
	_sheet.open_for_shop(character, collection.purchase_action(character, _ticket_use.is_on(character.grade)),
		BestScoreStore.new(save_path).best_of(character.id), lessons != null and lessons.find(character.id) != null)


## 설명창의 구매 자리: 정말 할지 묻는다.
func _on_purchase_requested(character: CharacterData) -> void:
	var action: CharacterCollection.PurchaseAction = collection.purchase_action(character, _ticket_use.is_on(character.grade))
	match action.kind:
		CharacterCollection.Purchase.DIAMOND:
			_ask("%s로 %s을(를) 구매할까요?" % [action.text, character.display_name], "구매", _buy.bind(character))
		CharacterCollection.Purchase.TICKET:
			_ask("%s 선택권 1장으로 %s을(를) 해금할까요?" % [CharacterData.GRADE_NAMES[character.grade], character.display_name],
				"사용", _use_ticket.bind(character))


func _buy(character: CharacterData) -> void:
	if collection.buy_with_diamonds(character):
		_after_purchase(character)


func _use_ticket(character: CharacterData) -> void:
	if collection.unlock_with_ticket(character):
		_ticket_use.clear(character.grade)  # 다음 캐릭터에 무심코 쓰지 않게
		_after_purchase(character)


func _after_purchase(character: CharacterData) -> void:
	_refresh()
	_nav.refresh()
	_open_sheet(character)


func _ask(message: String, accept_text: String, on_accept: Callable) -> void:
	_pending_confirm = on_accept
	_confirm.ask(message, accept_text)


func _on_confirm_accepted() -> void:
	if _pending_confirm.is_valid():
		_pending_confirm.call()
	_pending_confirm = Callable()


## 설명창의 튜토리얼 및 체험: 끝나면 상점으로 돌아온다.
func _on_lesson_requested(character: CharacterData) -> void:
	TrialRequest.character_id = character.id
	TrialRequest.with_lesson = true
	TrialRequest.back_to_shop = true
	trial_started.emit()
