class_name ShopScreen
extends Control
## 상점 화면 (기획서 8.1 · 8.5장). 탭 두 개:
## - 뽑기: 상자(누르거나 "열기"), 지금 단계 가격·등급 확률, 다음 단계 안내, 나오는 캐릭터, 광고 보상(자리만).
## - 상점: 등급별 선택권 수와 합성(GachaConfig.fuse_count장 → 다음 등급), 등급별 다이아 상점(열리기 전엔 "Lv N에 열림").
## 규칙은 CharacterShop(뽑기·합성·광고)과 CharacterCollection(선택권·다이아 해금)이 정하고, 이 화면은 보여 주기만 한다.
## 줄·칩 수는 데이터로 정해지므로 코드에서 인스턴스화한다.

enum Tab { GACHA, SHOP }

## 다이아 상점·선택권 등급 순서.
const SHOP_GRADES: Array[int] = [CharacterData.Grade.RARE, CharacterData.Grade.HERO, CharacterData.Grade.LEGEND, CharacterData.Grade.MYTH]

@export var roster: CharacterRoster
@export var progression: ProgressionConfig
@export var theme_data: BoardTheme
@export var pool_chip_scene: PackedScene
@export var ticket_row_scene: PackedScene
@export var grade_header_scene: PackedScene
@export var shop_row_scene: PackedScene
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
var _chips: Array[PoolChip] = []
var _tickets: Array[TicketRow] = []
var _headers: Array[GradeHeader] = []
var _rows: Array[ShopRow] = []
var _last: CharacterShop.PullResult
var _tutorial_store: TutorialStore
var _flow: TutorialFlow
## 방금 뽑은 것이 튜토리얼 흐름의 첫 뽑기였다 (결과를 닫으면 안내).
var _first_pull: bool = false

@onready var _wallet_label: WalletView = %WalletLabel
@onready var _gacha_tab: Button = %GachaTab
@onready var _shop_tab: Button = %ShopTab
@onready var _gacha_page: Control = %GachaPage
@onready var _shop_page: Control = %ShopPage
@onready var _chest: GachaChest = %Chest
@onready var _tap_label: Label = %TapLabel
@onready var _pull_button: Button = %PullButton
@onready var _rate_label: Label = %RateLabel
@onready var _tier_label: Label = %TierLabel
@onready var _tier_fill: ColorRect = %TierFill
@onready var _pool_box: HFlowContainer = %Pool
@onready var _ad_button: Button = %AdButton
@onready var _tickets_box: VBoxContainer = %Tickets
@onready var _characters_box: VBoxContainer = %Characters
@onready var _reveal: GachaReveal = %Reveal


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	collection = CharacterCollection.new(roster, ProgressStore.new(save_path), CharacterStore.new(save_path), progression.gacha)
	shop = CharacterShop.new(collection)
	_reduce_motion = OptionsStore.new(save_path).reduce_motion
	_tutorial_store = TutorialStore.new(save_path)
	_flow = TutorialFlow.new(_tutorial_store, AchievementStore.new(save_path).stat("games"))
	_give_first_pull_coins()
	_build_pool()
	_build_shop_list()
	set_tab(Tab.GACHA)
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
	return _tickets


func shop_row_for(id: StringName) -> ShopRow:
	for row: ShopRow in _rows:
		if row.character.id == id:
			return row
	return null


# --- 만들기 --------------------------------------------------------------------

func _gacha_characters() -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	for character: CharacterData in collection.sorted():
		if CharacterCollection.is_gacha(character):
			list.append(character)
	return list


func _build_pool() -> void:
	for character: CharacterData in _gacha_characters():
		var chip: PoolChip = pool_chip_scene.instantiate() as PoolChip
		_pool_box.add_child(chip)
		chip.show_character(character, theme_data.grade_color(character.grade), false)
		_chips.append(chip)


func _build_shop_list() -> void:
	var gacha: GachaConfig = progression.gacha
	for grade: int in SHOP_GRADES:
		var ticket: TicketRow = ticket_row_scene.instantiate() as TicketRow
		_tickets_box.add_child(ticket)
		ticket.setup(grade, theme_data.grade_color(grade), gacha.next_grade(grade), gacha.fuse_count)
		ticket.fuse_requested.connect(_on_fuse_requested)
		_tickets.append(ticket)
		var header: GradeHeader = grade_header_scene.instantiate() as GradeHeader
		_characters_box.add_child(header)
		header.setup(grade, theme_data.grade_color(grade))
		_headers.append(header)
		for character: CharacterData in collection.gacha_pool(grade):
			var row: ShopRow = shop_row_scene.instantiate() as ShopRow
			_characters_box.add_child(row)
			row.setup(character, theme_data.grade_color(grade))
			row.ticket_requested.connect(_on_ticket_requested)
			row.buy_requested.connect(_on_buy_requested)
			_rows.append(row)


# --- 보이기 --------------------------------------------------------------------

func _refresh() -> void:
	var progress: ProgressStore = collection.progress
	_wallet_label.show_amounts(progress.coins, progress.diamonds)
	_refresh_gacha(progress)
	_refresh_shop(progress)


func _refresh_gacha(progress: ProgressStore) -> void:
	var gacha: GachaConfig = progression.gacha
	var tier: GachaTier = gacha.tier_for(progress.level)
	var price: int = shop.pull_price()
	_pull_button.text = "열기 · ● %d" % price
	_pull_button.disabled = busy or not shop.can_pull()
	if not busy:
		_tap_label.text = "상자를 눌러 열기" if shop.can_pull() else "코인이 부족해요"
	_rate_label.text = ShopScreen.rate_text(tier)
	_tier_label.text = ShopScreen.tier_text(gacha, progress.level)
	var next: GachaTier = gacha.next_tier(progress.level)
	_tier_fill.get_parent().visible = next != null
	if next != null:
		_tier_fill.anchor_right = clampf(float(progress.level) / next.min_level, 0.0, 1.0)
	if not busy:  # 상자가 열리는 동안 결과가 미리 보이지 않게
		for chip: PoolChip in _chips:
			chip.set_owned(progress.is_unlocked(chip.character.id))
	var left: int = shop.ads_left(CharacterShop.today())
	_ad_button.text = "광고 보고 ◆ %d · 오늘 %d/%d" % [gacha.ad_diamonds, gacha.ad_daily_max - left, gacha.ad_daily_max]
	_ad_button.disabled = left <= 0


func _refresh_shop(progress: ProgressStore) -> void:
	var gacha: GachaConfig = progression.gacha
	for ticket: TicketRow in _tickets:
		ticket.show_count(progress.ticket_count(ticket.grade), shop.can_fuse(ticket.grade))
	for header: GradeHeader in _headers:
		header.show_shop(gacha.is_shop_open(header.grade, progress.level), gacha.shop_price(header.grade), gacha.shop_level(header.grade))
	for row: ShopRow in _rows:
		row.show_offer(progress.is_unlocked(row.character.id), collection.offer_for(row.character))


## "신화 0.1% · 전설 0.9% · 영웅 34% · 희귀 65%"
static func rate_text(tier: GachaTier) -> String:
	if tier == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for grade: int in GachaTier.ROLL_ORDER:
		parts.append("%s %s%%" % [CharacterData.GRADE_NAMES[grade], Ability.format_number(tier.rate_of(grade))])
	return " · ".join(parts)


## "뽑기 머신 1단계 · 중복이면 같은 등급 선택권 · Lv 8에 업그레이드"
static func tier_text(gacha: GachaConfig, level: int) -> String:
	var text: String = "뽑기 머신 %d단계 · 중복이면 같은 등급 선택권" % gacha.tier_number(level)
	var next: GachaTier = gacha.next_tier(level)
	if next != null:
		text += " · Lv %d에 업그레이드" % next.min_level
	return text


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


func _on_fuse_requested(grade: int) -> void:
	if shop.fuse(grade):
		_refresh()


func _on_ticket_requested(character: CharacterData) -> void:
	if collection.unlock_with_ticket(character):
		_refresh()


func _on_buy_requested(character: CharacterData) -> void:
	if collection.buy_with_diamonds(character):
		_refresh()
