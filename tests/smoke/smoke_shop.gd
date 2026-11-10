extends "res://tests/smoke/smoke_base.gd"
## 뽑기·상점 (기획서 8.5장, E38). 모드:
## - gacha  : 메인 → 상점 실제 클릭 → 뽑기 탭(머신 단계·가격·확률) → 상자 실제 클릭 → 흔들림·열림 → 결과 카드(NEW)
##            → 확인 → 뽑기 버튼으로 한 번 더 → 코인 부족 안내, 광고는 숨김
## - store  : 선택 탭(등급 구역, 4열 카드) → 합성 확인창(취소·합성) → 카드 → 설명창 가격 → 구매 확인 → 보유(비활성) → [사용] 켜고 끄기(카드 문구) → 선택권 사용 → 해금
## - trial_back : 상점 설명창의 튜토리얼 · 체험을 건너뛰면 선택 탭으로
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
		"reduce":
			progress.add_currency(500, 0)
			OptionsStore.new().set_reduce_motion(true)
			change_scene_to_file("res://scenes/shop.tscn")
		"trial_back":
			config.game_duration = 2.0
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
		"reduce":
			_tick_reduce()
		"trial_back":
			_tick_trial_back()


func _screen() -> ShopScreen:
	return current_scene as ShopScreen


func _reveal() -> GachaReveal:
	return node("%Reveal") as GachaReveal


func _tick_gacha() -> void:
	match step:
		0:
			if in_scene("MainMenu"):
				click_control(node("%BottomNav/%ShopButton"))
				next_step()
		1:
			if in_scene("Shop", 0.4):
				expect((node("%PullButton") as Button).text == "뽑기 · ● 500", "fixed price")
				expect((node("%RateLabel") as Label).text == "신화 0.1% · 전설 0.9% · 영웅 34% · 희귀 65%", "rates (%s)" % (node("%RateLabel") as Label).text)
				expect((node("%TierLabel") as Label).text == "뽑기 머신 1단계", "tier (%s)" % (node("%TierLabel") as Label).text)
				expect(not (node("%AdButton") as Control).visible, "ad hidden for now")
				shot("gacha")
				click_control(node("%Chest"))
				next_step()
		2:
			if step_time < 0.05:
				return
			if _screen().busy and not _reveal().visible and step_time < 0.3:
				expect(ProgressStore.new().coins == 500, "500 spent at once")
				expect((node("%PullButton") as Button).disabled, "no second pull while opening")
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
				finish()


func _sheet() -> CharacterSheet:
	return node("%CharacterSheet") as CharacterSheet


func _confirm() -> ConfirmDialog:
	return node("%ConfirmDialog") as ConfirmDialog


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
				expect((_screen().ticket_rows()[1].get_node("%FuseButton") as Button).disabled, "under 5 → fuse disabled")
				expect((node("%Sections").get_child(0).get_node("%Header") as Label).text == "희귀", "no price on the header (%s)" % (node("%Sections").get_child(0).get_node("%Header") as Label).text)
				expect((node("%Sections").get_child(1).get_node("%Header") as Label).text == "영웅 · Lv 8에 열림", "closed grade (%s)" % (node("%Sections").get_child(1).get_node("%Header") as Label).text)
				shot("store")
				click_control(rare.get_node("%FuseButton"))
				next_step()
		2:
			if step_time > 0.3:
				expect(_confirm().visible and _confirm().message().contains("5장") and _confirm().message().contains("영웅"), "fuse asks first (%s)" % _confirm().message())
				expect(ProgressStore.new().ticket_count(Grade.RARE) == 5, "nothing spent yet")
				shot("fuse_confirm")
				click_control(node("%ConfirmDialog/%CancelButton"))
				next_step()
		3:
			if step_time > 0.3:
				expect(not _confirm().visible and ProgressStore.new().ticket_count(Grade.RARE) == 5, "cancel keeps the tickets")
				click_control(_screen().ticket_rows()[0].get_node("%FuseButton"))
				next_step()
		4:
			if step_time > 0.3:
				click_control(node("%ConfirmDialog/%AcceptButton"))
				next_step()
		5:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.ticket_count(Grade.RARE) == 0 and progress.ticket_count(Grade.HERO) == 1, "fused into a hero ticket")
				expect((_screen().ticket_rows()[0].get_node("%UseButton") as Button).disabled, "no rare ticket → use disabled")
				click_control(_screen().shop_card_for(&"gardener"))
				next_step()
		6:
			if step_time > 0.3:
				expect(_sheet().visible and _sheet().character.id == &"gardener", "row opens the sheet")
				expect(_sheet().shown_actions() == PackedStringArray(["◆ 80", "튜토리얼 · 체험"]), "price where equip was (%s)" % [_sheet().shown_actions()])
				shot("sheet_price")
				click_control(_sheet().info().get_node("%PurchaseButton"))
				next_step()
		7:
			if step_time > 0.3:
				expect(_confirm().visible and _confirm().message().contains("정원사"), "buying asks first (%s)" % _confirm().message())
				expect(ProgressStore.new().diamonds == 100, "not paid yet")
				click_control(node("%ConfirmDialog/%AcceptButton"))
				next_step()
		8:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.is_unlocked(&"gardener") and progress.diamonds == 20, "bought with ◆ 80")
				expect(_sheet().shown_actions() == PackedStringArray(["보유", "튜토리얼 · 체험"]), "owned in the shop (%s)" % [_sheet().shown_actions()])
				expect((_sheet().info().get_node("%PurchaseButton") as Button).disabled, "owned button is disabled")
				expect(_screen().shop_card_for(&"gardener").shows_owned() and _screen().shop_card_for(&"gardener").price_text() == "보유", "card shows owned")
				expect((node("%TopBar/%WalletLabel") as WalletView).text == "● 0  ◆ 20", "wallet updated")
				_sheet().close()
				(node("%ShopPage") as ScrollContainer).ensure_control_visible(_screen().ticket_rows()[1])
				next_step()
		9:
			if step_time > 0.3:
				click_control(_screen().ticket_rows()[1].get_node("%UseButton"))
				next_step()
		10:
			if step_time > 0.2:
				expect((_screen().ticket_rows()[1].get_node("%UseButton") as Button).button_pressed, "use is on")
				expect(_screen().shop_card_for(&"wall").price_text() == "선택", "card price becomes select (%s)" % _screen().shop_card_for(&"wall").price_text())
				click_control(_screen().ticket_rows()[1].get_node("%UseButton"))
				next_step()
		11:
			if step_time > 0.2:
				expect(not (_screen().ticket_rows()[1].get_node("%UseButton") as Button).button_pressed, "pressing again cancels")
				expect(_screen().shop_card_for(&"wall").price_text() == "Lv 8", "card back to closed (%s)" % _screen().shop_card_for(&"wall").price_text())
				click_control(_screen().ticket_rows()[1].get_node("%UseButton"))
				(node("%ShopPage") as ScrollContainer).ensure_control_visible(_screen().shop_card_for(&"wall"))
				next_step()
		12:
			if step_time > 0.3:
				click_control(_screen().shop_card_for(&"wall"))
				next_step()
		13:
			if step_time > 0.3:
				expect(_sheet().character.id == &"wall", "wall sheet")
				expect(_sheet().shown_actions() == PackedStringArray(["선택권 사용", "튜토리얼 · 체험"]), "ticket instead of the price, before the shop opens (%s)" % [_sheet().shown_actions()])
				expect((_sheet().info().get_node("%AbilityKind") as Label).text == "상시형" and not (_sheet().info().get_node("%SheetCondition") as Control).visible, "passive character: no recipe")
				shot("sheet_ticket")
				click_control(_sheet().info().get_node("%PurchaseButton"))
				next_step()
		14:
			if step_time > 0.3:
				expect(_confirm().visible, "ticket use asks first")
				click_control(node("%ConfirmDialog/%AcceptButton"))
				next_step()
		15:
			if step_time > 0.3:
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.is_unlocked(&"wall") and progress.ticket_count(Grade.HERO) == 0, "unlocked with the hero ticket")
				expect(not (_screen().ticket_rows()[1].get_node("%UseButton") as Button).button_pressed, "use turns off after use")
				expect(_sheet().shown_actions()[0] == "보유", "sheet shows owned")
				shot("store_bought")
				finish()


## 상점 설명창의 튜토리얼 · 체험 → 건너뛰면 선택 탭으로 돌아온다.
func _tick_trial_back() -> void:
	match step:
		0:
			if in_scene("Shop", 0.4):
				click_control(node("%ShopTab"))
				next_step()
		1:
			if step_time > 0.3:
				click_control(_screen().shop_card_for(&"gardener"))
				next_step()
		2:
			if step_time > 0.3:
				click_control(_sheet().info().get_node("%LessonButton"))
				next_step()
		3:
			if playing(0.5):
				expect(controller.is_trial() and controller.is_lesson(), "trial = the character tutorial")
				click_control((node("Tutorial") as TutorialDirector).spotlight.get_node("%SkipButton"))
				controller = null
				next_step()
		4:
			if in_scene("Shop", 0.4):
				expect(_screen().tab == ShopScreen.Tab.SHOP, "back on the select tab")
				expect(not TrialRequest.back_to_shop, "request cleared")
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
