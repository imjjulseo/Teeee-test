extends "res://tests/smoke/smoke_base.gd"
## 5d 업적 (기획서 8.6 · 8.7장). 모드:
<<<<<<< HEAD
## - result : 9판 해 둔 저장으로 정원사 한 판 → 결과 보상 목록에 "업적 단골 I"·"업적 정원사 입문", 보상은 아직 없음
=======
## - result : 9판 해 둔 저장으로 정원사 한 판 → 결과 보상 목록에 "업적 · 단골 I"·"업적 · 정원사 입문", 보상은 아직 없음
>>>>>>> Choi
##            → 메뉴(업적 버튼 빨간 점) → 업적 실제 클릭 → 공통 업적 6장, 히든 3장(???) → [받기] 실제 클릭 → 코인, 단골 II 10 / 100 → 메인
## - sheet  : 캐릭터 탭 — 정원사(입문 달성 · 숙련 진행 · 극한 잠김), 업적 없는 캐릭터·히든 등급은 없음, 미보유 표시
## - trial  : 체험 판은 업적·통계가 남지 않는다

var _result_ready_coins: int = 0


func _setup() -> void:
	config.game_duration = 2.0
	var store: AchievementStore = AchievementStore.new()
	match mode:
		"result":
			store.add_stat("games", 9)
			store.save()
			ProgressStore.new().unlock(&"gardener")
			CharacterStore.new().select(&"gardener")
			change_scene_to_file("res://scenes/main.tscn")
		"sheet":
			ProgressStore.new().unlock(&"gardener")
			store.mark_done("gardener_1")
			store.record_progress("gardener_2", 6)
			store.save()
			change_scene_to_file("res://scenes/achievements.tscn")
		"trial":
			TrialRequest.character_id = &"gardener"
			change_scene_to_file("res://scenes/main.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


func _tick() -> void:
	match mode:
		"result":
			_tick_result()
		"sheet":
			_tick_character_tab()
		"trial":
			_tick_trial()


func _tick_result() -> void:
	match step:
		0:
			if playing(0.5):
				session().metrics.record_max(GrowAllAbility.METRIC_GROWN_ONCE, 8)  # 정원사 입문 조건 (촉진 한 번에 씨앗 8개)
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if flow().state == S.RESULT and step_time > 0.4:
				var result: ResultPanel = node("ResultPanel")
				var names: PackedStringArray = PackedStringArray()
				for line: PackedStringArray in result.shown_rewards():
					names.append(line[0])
<<<<<<< HEAD
				expect(names.has("업적 단골 I") and names.has("업적 정원사 입문"), "achievements in the reward list (%s)" % [names])
=======
				expect(names.has("업적 · 단골 I") and names.has("업적 · 정원사 입문"), "achievements in the reward list (%s)" % [names])
>>>>>>> Choi
				_result_ready_coins = ProgressStore.new().coins
				next_step()
			elif step_time > 6.0:
				fail("game did not end")
				finish()
		2:
			if step_time > 1.5:  # 보유 코인이 차오른 뒤
				var result: ResultPanel = node("ResultPanel")
				expect((result.get_node("%CoinLabel") as Label).text == "보유 코인 ● %d" % _result_ready_coins, "coins without achievement rewards until claimed (%s)" % (result.get_node("%CoinLabel") as Label).text)
				shot("result")
				click_control(result.get_node("%MainMenuButton"))
				controller = null
				next_step()
		3:
			if in_scene("MainMenu"):
				expect((node("%BottomNav") as BottomNav).shows_achievement_dot(), "red dot: rewards to claim")
				click_control(node("%BottomNav/%AchievementsButton"))
				next_step()
		4:
			if in_scene("Achievements", 0.4):
				var screen: AchievementsScreen = current_scene as AchievementsScreen
				expect(screen.common_rows().size() == 6 and screen.hidden_rows().size() == 3, "6 common + 3 hidden")
				var games: AchievementRow = screen.common_rows()[3]
				expect(games.shown_name() == "단골 I" and games.can_claim(), "reached tier waits for the claim (%s)" % games.shown_name())
				expect(not screen.common_rows()[0].can_claim(), "not reached → no claim")
<<<<<<< HEAD
				expect(screen.hidden_rows()[0].shown_name() == "양손 쓰기" and not screen.hidden_rows()[0].can_claim(), "hidden conditions are shown (E42)")
=======
				expect(screen.hidden_rows()[0].shown_name() == "???" and not screen.hidden_rows()[0].can_claim(), "hidden conditions veiled")
>>>>>>> Choi
				shot("achievements")
				_result_ready_coins = ProgressStore.new().coins
				click_control(games.claim_button())
				next_step()
		5:
			if step_time > 0.3:
				var screen: AchievementsScreen = current_scene as AchievementsScreen
				expect(ProgressStore.new().coins == _result_ready_coins + 100, "paid on press")
				var games: AchievementRow = screen.common_rows()[3]
				expect(games.shown_name() == "단골 II" and games.shown_value() == "10 / 100", "next tier (%s %s)" % [games.shown_name(), games.shown_value()])
				expect((node("%TopBar/%WalletLabel") as WalletView).text.contains(str(ProgressStore.new().coins)), "top bar updated")
				expect((node("%BottomNav") as BottomNav).shows_achievement_dot(), "the character tier is still waiting")
				click_control(node("%BottomNav/%AchievementsButton"))  # 지금 화면 버튼을 다시 누르면 메인
				next_step()
		6:
			if in_scene("MainMenu"):
				finish()

func _tick_character_tab() -> void:
	var screen: AchievementsScreen = current_scene as AchievementsScreen
	match step:
		0:
			if in_scene("Achievements", 0.5):
				expect(screen.tab == AchievementsScreen.Tab.COMMON and (node("%CommonTab") as Button).button_pressed, "opens on the common tab")
				expect((node("%Scroll") as Control).visible and not (node("%CharacterScroll") as Control).is_visible_in_tree(), "common page only")
				expect(screen.character_groups().is_empty(), "built on first open of the tab")
				click_control(node("%CharacterTab"))
				next_step()
		1:
			if step_time > 0.3:
				expect(screen.tab == AchievementsScreen.Tab.CHARACTER and (node("%CharacterTab") as Button).button_pressed, "real click switches the tab")
				expect((node("%CharacterScroll") as Control).is_visible_in_tree() and not (node("%Scroll") as Control).visible, "character page only")
				var groups: Array[CharacterChainGroup] = screen.character_groups()
<<<<<<< HEAD
				expect(groups.size() == 31, "31 characters: everyone with a chain, hidden grade too (%d)" % groups.size())
				var ids: Array[StringName] = []
				for group: CharacterChainGroup in groups:
					ids.append(group.character.id)
				expect(ids.has(&"zeus") and ids.has(&"ambi") and not ids.has(&"basic"), "every character with a chain, hidden ones too (%s)" % [ids])
=======
				expect(groups.size() == 25, "25 characters: chains without hidden grade (%d)" % groups.size())
				var ids: Array[StringName] = []
				for group: CharacterChainGroup in groups:
					ids.append(group.character.id)
				expect(not ids.has(&"zeus") and not ids.has(&"ambi") and not ids.has(&"basic"), "no empty chains, no hidden (%s)" % [ids])
>>>>>>> Choi
				expect(groups[0].character.id == &"gardener", "grade order")
				var rows: Array[AchievementRow] = groups[0].rows()
				expect(rows.size() == 3, "three tiers")
				if rows.size() == 3:
					expect(rows[0].shown_value() == "달성", "입문 done")
					expect(rows[1].shown_value() == "6 / 15", "숙련 progress (%s)" % rows[1].shown_value())
<<<<<<< HEAD
					expect(rows[2].shown_value() == "" and rows[2].modulate.a < 1.0, "극한 locked (dimmed, no text)")
					expect(rows[1].shown_reward() == "◆ 10" and not rows[1].can_claim(), "reward chip waits dimmed")
				expect(not groups[0].shows_unowned(), "owned character")
				expect(groups[1].shows_unowned(), "unowned characters are shown and marked")
				expect(rows[0].can_claim(), "입문 can be claimed")
				expect(screen.section_for(CharacterData.Grade.BASIC).is_preparing() and not screen.section_for(CharacterData.Grade.HIDDEN).is_preparing(), "일반: 준비 중, 히든은 업적이 있다")
				var unowned: Array[AchievementRow] = groups[1].rows()
				expect(unowned[0].modulate.a < 1.0 and not unowned[0].can_claim(), "unowned character: even 입문 is locked")
=======
					expect(rows[2].shown_value() == "앞 단계를 먼저", "극한 locked")
				expect(not groups[0].shows_unowned(), "owned character")
				expect(groups[1].shows_unowned(), "unowned characters are shown and marked")
				expect(rows[0].can_claim(), "입문 can be claimed")
				expect(screen.section_for(CharacterData.Grade.BASIC).is_preparing() and screen.section_for(CharacterData.Grade.HIDDEN).is_preparing(), "일반 · 히든: 준비 중")
>>>>>>> Choi
				expect(not screen.section_for(CharacterData.Grade.RARE).is_preparing(), "희귀 has characters")
				shot("character_tab")
				click_control(node("%Chips").get_child(3))  # 전설
				next_step()
		2:
			if step_time > 0.3:
				var section: Control = screen.section_for(CharacterData.Grade.LEGEND)
				expect(absf(section.get_global_rect().position.y - (node("%CharacterScroll") as Control).get_global_rect().position.y) < 2.0, "chip scrolls to the grade")
				expect((node("%Chips").get_child(3) as Button).button_pressed, "chip selected")
				click_control(node("%Chips").get_child(5))  # 히든
				next_step()
		3:
			if step_time > 0.3:
				expect((node("%CharacterScroll") as ScrollContainer).get_global_rect().has_point(screen.section_for(CharacterData.Grade.HIDDEN).get_node("%PreparingLabel").get_global_rect().get_center()), "hidden: preparing is in view")
				shot("character_preparing")
				click_control(node("%CommonTab"))
				next_step()
		4:
			if step_time > 0.2:
				expect((node("%Scroll") as Control).visible, "back to the common tab")
				finish()


func _tick_trial() -> void:
	match step:
		0:
			if playing(0.5):
<<<<<<< HEAD
				expect(controller.is_trial() and controller.is_lesson(), "trial = the character tutorial")
				session().metrics.record_max(GrowAllAbility.METRIC_GROWN_ONCE, 8)
				auto_resume = false
				flow().pause()
				next_step()
		1:
			if step_time > 0.3:
				click_control(node("PauseOverlay/Center/MainMenuButton"))
				controller = null
				next_step()
		2:
			if in_scene("CharacterSelect", 0.3):
				var store: AchievementStore = AchievementStore.new()
				expect(store.stat("games") == 0 and not store.is_done("gardener_1"), "trial leaves no achievements or stats")
=======
				session().metrics.record_max(GrowAllAbility.METRIC_GROWN_ONCE, 8)
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if flow().state == S.RESULT and step_time > 0.4:
				var store: AchievementStore = AchievementStore.new()
				expect(store.stat("games") == 0 and not store.is_done("gardener_1"), "trial leaves no achievements or stats")
				expect((node("ResultPanel") as ResultPanel).shown_rewards().is_empty(), "no reward rows")
				finish()
			elif step_time > 6.0:
				fail("trial did not end")
>>>>>>> Choi
				finish()
