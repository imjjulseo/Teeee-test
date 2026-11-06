extends "res://tests/smoke/smoke_base.gd"
## 5b 메뉴 화면 (기획서 8.1장). 모드:
## - intro : 인트로 실제 클릭 → 메뉴(레벨·지갑·보드 단계 안내) → 레벨 버튼 실제 클릭 → 레벨 보상(아래가 Lv1, 지금 레벨 줄이 보이게 스크롤,
##           다음 레벨 줄에 경험치 바) → 뒤로 → 메뉴
## - sheet : 캐릭터 화면 → 선택권으로 해금(실제 클릭) → 장착 → 다른 캐릭터 체험 → 체험 결과("체험 끝", 보상·기록 없음)
##           → 캐릭터 버튼 → 캐릭터 화면, 장착은 그대로
## - trial_quit : 체험 판 일시정지 → 메뉴 실제 클릭 → 캐릭터 화면, 플레이 기록 없음

const Grade = CharacterData.Grade
const LEVEL: int = 12


func _setup() -> void:
	keep_stages = mode == "intro"  # 레벨 보상 문구를 본다 (체험 판은 단계 없이 아래 짧은 시간으로)
	config.game_duration = 2.0
	match mode:
		"intro":
			var progress: ProgressStore = ProgressStore.new()
			progress.set_level(LEVEL)
			progress.add_currency(340, 25)
			change_scene_to_file("res://scenes/intro.tscn")
		"sheet":
			ProgressStore.new().add_ticket(Grade.RARE)
			change_scene_to_file("res://scenes/character_select.tscn")
		"trial_quit":
			TrialRequest.character_id = &"clock"
			change_scene_to_file("res://scenes/main.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


func _tick() -> void:
	match mode:
		"intro":
			_tick_intro()
		"sheet":
			_tick_sheet()
		"trial_quit":
			_tick_trial_quit()


func _tick_intro() -> void:
	match step:
		0:
			if in_scene("Intro", 0.5):
				shot("intro")
				click_control(node("TapArea"))
				next_step()
		1:
			if in_scene("MainMenu", 0.4):
				expect((node("%LevelLabel") as Label).text == "Lv %d" % LEVEL, "level button")
				expect((node("%WalletLabel") as WalletView).text == "● 340  ◆ 25", "wallet (%s)" % (node("%WalletLabel") as WalletView).text)
				expect((node("%StageLabel") as Label).text == "최고점 0", "main board → best score")
				expect(not (node("%ShopButton") as Button).disabled and not (node("%AchievementsButton") as Button).disabled, "shop and achievements open")
				shot("menu")
				click_control(node("%LevelButton"))
				next_step()
		2:
			if in_scene("LevelRewards", 0.6):
				var screen: LevelRewardsScreen = current_scene as LevelRewardsScreen
				var rows: Array[LevelRewardRow] = screen.rows()
				expect(rows.size() == 30, "30 levels (%d)" % rows.size())
				expect(rows[0].level == 30 and rows[rows.size() - 1].level == 1, "Lv1 at the bottom")
				expect(rows[rows.size() - 1].rewards_text() == "시작 보드 · 3색 · 족보 2칸", "Lv1 reward (%s)" % rows[rows.size() - 1].rewards_text())
				expect(rows[30 - 10].rewards_text().contains("영웅 선택권"), "Lv10 hero ticket")
				var current: LevelRewardRow = screen.current_row()
				expect(current != null and current.level == LEVEL, "current level row")
				var view: Rect2 = (node("%Scroll") as Control).get_global_rect()
				expect(view.grow(0.5).encloses(current.get_global_rect()), "scrolled to the current level")
				var next: LevelRewardRow = rows[30 - LEVEL - 1]
				expect(next.level == LEVEL + 1 and (next.get_node("%ExpBar") as Control).visible, "exp bar on the next level")
				expect(not (current.get_node("%ExpBar") as Control).visible, "no exp bar elsewhere")
				shot("level_rewards")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		3:
			if in_scene("MainMenu"):
				finish()


func _sheet() -> CharacterSheet:
	return node("%CharacterSheet") as CharacterSheet


func _tick_sheet() -> void:
	var select: CharacterSelect = current_scene as CharacterSelect
	match step:
		0:
			if in_scene("CharacterSelect", 0.5):
				expect(select.card_for(&"gardener").shown_status() == "선택권", "rare ticket → rare cards unlockable")
				click_control(select.card_for(&"gardener"))
				next_step()
		1:
			if step_time > 0.3:
				expect(_sheet().shown_actions() == PackedStringArray(["희귀 선택권으로 해금 · 1장", "◆ 80로 해금", "한 판 체험하기"]), "ticket actions (%s)" % [_sheet().shown_actions()])
				click_control(_sheet().get_node("%UnlockButton"))
				next_step()
		2:
			if step_time > 0.3:
				expect(ProgressStore.new().is_unlocked(&"gardener") and ProgressStore.new().ticket_count(Grade.RARE) == 0, "unlocked with the ticket")
				expect(_sheet().shown_actions() == PackedStringArray(["장착하기", "튜토리얼 다시 하기"]), "owned → equip (%s)" % [_sheet().shown_actions()])
				expect(select.card_for(&"twins").shown_status() == "◆ 80", "other rares back to the shop price (ticket spent)")
				click_control(_sheet().get_node("%EquipButton"))
				next_step()
		3:
			if step_time > 0.3:
				expect(CharacterStore.new().selected_id == &"gardener", "equipped")
				expect(_sheet().shown_actions() == PackedStringArray(["장착 중", "튜토리얼 다시 하기"]) and (_sheet().get_node("%EquipButton") as Button).disabled, "equipped button")
				expect(select.card_for(&"gardener").shown_status() == "장착 중" and select.card_for(&"basic").shown_status() == "보유", "card status")
				expect((node("%EquippedLabel") as Label).text == "장착 중 · 정원사", "header shows the equipped character")
				shot("sheet_equipped")
				click_control(_sheet().get_node("Panel/VBox/Header/CloseButton"))
				next_step()
		4:
			if step_time > 0.3:
				(node("%Scroll") as ScrollContainer).ensure_control_visible(select.card_for(&"clock"))  # 화면 밖 카드
				next_step()
		5:
			if step_time > 0.3:
				click_control(select.card_for(&"clock"))
				next_step()
		6:
			if step_time > 0.3:
				expect(_sheet().character.id == &"clock", "clock sheet")
				click_control(_sheet().get_node("%TrialButton"))
				next_step()
		7:
			if playing(0.5):
				expect(controller.is_trial() and session().character.id == &"clock", "trial game with the clock maker")
				flow().request_move(Vector2i.UP)  # 시계 시작 → 2초 뒤 끝
				next_step()
		8:
			if flow() != null and flow().state == S.RESULT and step_time > 0.4:
				var result: ResultPanel = node("ResultPanel")
				expect((result.get_node("%Title") as Label).text == "시계공 체험 끝", "trial result title")
				expect(result.is_trial_result() and not (result.get_node("%RewardsList") as Control).visible, "no rewards shown")
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.coins == 0 and progress.experience == 0, "no coins or exp")
				expect(BestScoreStore.new().best == 0 and smoke_log_rows().is_empty(), "no best score or playtest row")
				shot("trial_result")
				click_control(result.get_node("%MainMenuButton"))
				controller = null
				next_step()
			elif step_time > 6.0:
				fail("trial did not end")
				finish()
		9:
			if in_scene("CharacterSelect", 0.4):
				expect(CharacterStore.new().selected_id == &"gardener", "trial does not change the equipped character")
				expect(select.card_for(&"clock").shown_status() == "◆ 80", "trial does not unlock")
				finish()


func _tick_trial_quit() -> void:
	match step:
		0:
			if playing(0.5):
				expect(controller.is_trial(), "trial game")
				auto_resume = false
				flow().request_move(Vector2i.UP)
				flow().pause()
				next_step()
		1:
			if step_time > 0.3:
				click_control(node("PauseOverlay/Center/MainMenuButton"))
				controller = null
				next_step()
		2:
			if in_scene("CharacterSelect", 0.3):
				expect(smoke_log_rows().is_empty(), "abandoned trial not logged")
				finish()
