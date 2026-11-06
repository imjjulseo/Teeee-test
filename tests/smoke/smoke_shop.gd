extends "res://tests/smoke/smoke_base.gd"
## 5c 뽑기·상점 (기획서 8.5장). 모드:
## - gacha  : 메뉴 → 상점 실제 클릭 → 뽑기 탭(가격·확률·단계·나오는 캐릭터 28) → 상자 실제 클릭 → 흔들림·열림 → 결과 카드(NEW)
##            → 확인 → 열기 버튼으로 한 번 더 → 코인 부족 안내 → 광고 보상(◆ 5)
## - store  : 상점 탭 → 선택권 합성(희귀 5 → 영웅 1) → 영웅 선택권으로 해금(상점이 안 열린 등급) → 다이아로 희귀 구매 → 다이아 부족 버튼
## - sheet  : 캐릭터 화면 상세 시트의 "◆ 80로 해금" 실제 클릭
## - reduce : 효과 줄이기면 상자를 누르자마자 결과 카드

const Grade = CharacterData.Grade


func _setup() -> void:
	var progress: ProgressStore = ProgressStore.new()
	match mode:
		"gacha":
			progress.add_currency(1000, 0)
			change_scene_to_file("res://scenes/main_menu.tscn")
		"store":
			progress.add_currency(0, 100)
			for _i: int in 5:
				progress.add_ticket(Grade.RARE)
			change_scene_to_file("res://scenes/shop.tscn")
		"sheet":
			progress.add_currency(0, 100)
			change_scene_to_file("res://scenes/character_select.tscn")
		"reduce":
			progress.add_currency(500, 0)
			OptionsStore.new().set_reduce_motion(true)
			change_scene_to_file("res://scenes/shop.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


func _tick() -> void:
	match mode:
		"gacha":
			_tick_gacha()
		"store":
			_tick_store()
		"sheet":
			_tick_sheet()
		"reduce":
			_tick_reduce()


func _screen() -> ShopScreen:
	return current_scene as ShopScreen


func _reveal() -> GachaReveal:
	return node("%Reveal") as GachaReveal


func _tick_gacha() -> void:
	match step:
		0:
			if in_scene("MainMenu"):
				click_control(node("%ShopButton"))
				next_step()
		1:
			if in_scene("Shop", 0.4):
				expect((node("%PullButton") as Button).text == "열기 · ● 500", "fixed price")
				expect((node("%RateLabel") as Label).text == "신화 0.1% · 전설 0.9% · 영웅 34% · 희귀 65%", "rates (%s)" % (node("%RateLabel") as Label).text)
				expect((node("%TierLabel") as Label).text == "뽑기 머신 1단계 · 중복이면 같은 등급 선택권 · Lv 8에 업그레이드", "tier (%s)" % (node("%TierLabel") as Label).text)
				expect(node("%Pool").get_child_count() == 28, "28 gacha characters")
				shot("gacha")
				click_control(node("%Chest"))
				next_step()
		2:
			if step_time < 0.05:
				return
			if _screen().busy and not _reveal().visible and step_time < 0.3:
				expect(ProgressStore.new().coins == 500, "500 spent at once")
				expect((node("%PullButton") as Button).disabled, "no second pull while opening")
				var pulled: StringName = _screen().last_result().character.id
				for chip: Node in node("%Pool").get_children():
					if (chip as PoolChip).character.id == pulled:
						expect(chip.modulate.a < 1.0, "pool does not spoil the result while opening")
				shot("chest_opening")
				step_time = 0.3
			elif _reveal().visible and step_time > 2.5:
				var result: CharacterShop.PullResult = _screen().last_result()
				expect(result.is_new and _reveal().tag() == "NEW", "first pull is new (%s)" % _reveal().tag())
				expect(ProgressStore.new().is_unlocked(result.character.id), "unlocked %s" % result.character.id)
				shot("reveal")
				click_control(node("Reveal/Center/OkButton"))
				next_step()
			elif step_time > 6.0:
				fail("chest did not open")
				finish()
		3:
			if step_time > 0.3:
				expect(not _reveal().visible and not _screen().busy, "result closed")
				for chip: Node in node("%Pool").get_children():
					if (chip as PoolChip).character.id == _screen().last_result().character.id:
						expect(chip.modulate.a == 1.0, "pool shows the new character after closing")
				click_control(node("%PullButton"))
				next_step()
		4:
			if _reveal().visible and step_time > 2.5:
				click_control(node("Reveal/Center/OkButton"))
				next_step()
			elif step_time > 6.0:
				fail("second pull did not open")
				finish()
		5:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.coins == 0, "two pulls")
				expect((node("%PullButton") as Button).disabled, "pull disabled without coins")
				click_control(node("%Chest"))
				next_step()
		6:
			if step_time > 0.2:
				expect((node("%TapLabel") as Label).text == "코인이 부족해요", "tapping the chest without coins")
				expect(not _reveal().visible, "nothing pulled")
				click_control(node("%AdButton"))
				next_step()
		7:
			if step_time > 0.2:
				expect(ProgressStore.new().diamonds == 5, "ad reward ◆ 5")
				expect((node("%AdButton") as Button).text.ends_with("오늘 1/3"), "ad count (%s)" % (node("%AdButton") as Button).text)
				finish()


func _tick_store() -> void:
	match step:
		0:
			if in_scene("Shop", 0.4):
				click_control(node("%ShopTab"))
				next_step()
		1:
			if step_time > 0.3:
				expect((node("%ShopPage") as Control).visible and not (node("%GachaPage") as Control).visible, "shop tab shown")
				var rare: TicketRow = _screen().ticket_rows()[0]
				expect(rare.count_text() == "5장" and not (rare.get_node("%FuseButton") as Button).disabled, "5 rare tickets → fuse")
				expect(_screen().ticket_rows().size() == 4 and not (_screen().ticket_rows()[3].get_node("%FuseButton") as Control).visible, "no fuse above myth")
				shot("store")
				click_control(rare.get_node("%FuseButton"))
				next_step()
		2:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.ticket_count(Grade.RARE) == 0 and progress.ticket_count(Grade.HERO) == 1, "fused into a hero ticket")
				var wall: ShopRow = _screen().shop_row_for(&"wall")
				expect(wall.shown_actions() == PackedStringArray(["선택권"]), "hero shop closed, ticket usable (%s)" % [wall.shown_actions()])
				(node("%ShopPage") as ScrollContainer).ensure_control_visible(wall)
				next_step()
		3:
			if step_time > 0.3:
				click_control(_screen().shop_row_for(&"wall").get_node("%TicketButton"))
				next_step()
		4:
			if step_time > 0.3:
				expect(ProgressStore.new().is_unlocked(&"wall"), "unlocked with the hero ticket")
				expect(_screen().shop_row_for(&"wall").shown_actions() == PackedStringArray(["보유"]), "row shows owned")
				var gardener: ShopRow = _screen().shop_row_for(&"gardener")
				(node("%ShopPage") as ScrollContainer).ensure_control_visible(gardener)
				next_step()
		5:
			if step_time > 0.3:
				click_control(_screen().shop_row_for(&"gardener").get_node("%RowBuyButton"))
				next_step()
		6:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.is_unlocked(&"gardener") and progress.diamonds == 20, "bought with ◆ 80")
				var twins: ShopRow = _screen().shop_row_for(&"twins")
				expect((twins.get_node("%RowBuyButton") as Button).disabled, "◆ 20 left → can't buy another")
				expect((node("%WalletLabel") as WalletView).text == "● 0  ◆ 20", "wallet updated")
				shot("store_bought")
				finish()


func _tick_sheet() -> void:
	var select: CharacterSelect = current_scene as CharacterSelect
	match step:
		0:
			if in_scene("CharacterSelect", 0.5):
				click_control(select.card_for(&"gardener"))
				next_step()
		1:
			if step_time > 0.3:
				var sheet: CharacterSheet = node("%CharacterSheet")
				expect(not (sheet.get_node("%BuyButton") as Button).disabled, "◆ 100 → can buy")
				click_control(sheet.get_node("%BuyButton"))
				next_step()
		2:
			if step_time > 0.3:
				expect(ProgressStore.new().is_unlocked(&"gardener") and ProgressStore.new().diamonds == 20, "bought from the sheet")
				var sheet: CharacterSheet = node("%CharacterSheet")
				expect(sheet.shown_actions() == PackedStringArray(["장착하기", "튜토리얼 다시 하기"]), "owned → equip (%s)" % [sheet.shown_actions()])
				expect(select.card_for(&"gardener").shown_status() == "보유", "card status")
				finish()


func _tick_reduce() -> void:
	match step:
		0:
			if in_scene("Shop", 0.4):
				click_control(node("%Chest"))
				next_step()
		1:
			if step_time > 0.1:
				expect(_reveal().visible, "reduce motion → result right away")
				expect(not (node("Reveal/Center/OkButton") as Button).disabled, "no flip wait")
				finish()
