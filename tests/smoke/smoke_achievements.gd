extends "res://tests/smoke/smoke_base.gd"
## 5d 업적 (기획서 8.6 · 8.7장). 모드:
## - result : 9판 해 둔 저장으로 정원사 한 판 → 결과 보상 목록에 "업적 · 단골 I"·"업적 · 정원사 입문", 보상이 지갑에 반영
##            → 메뉴 → 업적 실제 클릭 → 공통 업적 6장(단골은 II 단계 10 / 100), 히든 3장(???) → 뒤로
## - sheet  : 캐릭터 상세 시트 — 정원사(입문 달성 · 숙련 진행 · 극한 잠김), 제우스("준비 중")
## - trial  : 체험 판은 업적·통계가 남지 않는다

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
			change_scene_to_file("res://scenes/character_select.tscn")
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
			_tick_sheet()
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
				expect(names.has("업적 · 단골 I") and names.has("업적 · 정원사 입문"), "achievements in the reward list (%s)" % [names])
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.coins >= 200, "two tier-I rewards paid (● %d)" % progress.coins)
				expect((result.get_node("%WalletLabel") as Label).text.begins_with("보유 ● %d" % progress.coins), "wallet includes the rewards")
				shot("result")
				click_control(result.get_node("%MainMenuButton"))
				controller = null
				next_step()
			elif step_time > 6.0:
				fail("game did not end")
				finish()
		2:
			if in_scene("MainMenu"):
				click_control(node("%AchievementsButton"))
				next_step()
		3:
			if in_scene("Achievements", 0.4):
				var screen: AchievementsScreen = current_scene as AchievementsScreen
				expect(screen.common_rows().size() == 6 and screen.hidden_rows().size() == 3, "6 common + 3 hidden")
				var games: AchievementRow = screen.common_rows()[3]
				expect(games.shown_name() == "단골 II" and games.shown_value() == "10 / 100", "단골 next tier (%s %s)" % [games.shown_name(), games.shown_value()])
				expect(screen.hidden_rows()[0].shown_name() == "???", "hidden conditions veiled")
				shot("achievements")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		4:
			if in_scene("MainMenu"):
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
				var rows: Array[AchievementRow] = sheet.achievement_rows()
				expect(rows.size() == 3, "three tiers")
				if rows.size() == 3:
					expect(rows[0].shown_value() == "달성", "입문 done")
					expect(rows[1].shown_value() == "6 / 15", "숙련 progress (%s)" % rows[1].shown_value())
					expect(rows[2].shown_value() == "앞 단계를 먼저", "극한 locked")
				expect(not (sheet.get_node("%AchievementsLabel") as Control).visible, "no 준비 중")
				shot("sheet")
				sheet.close()
				(node("%Scroll") as ScrollContainer).ensure_control_visible(select.card_for(&"zeus"))
				next_step()
		2:
			if step_time > 0.3:
				click_control(select.card_for(&"zeus"))
				next_step()
		3:
			if step_time > 0.3:
				var sheet: CharacterSheet = node("%CharacterSheet")
				expect(sheet.character.id == &"zeus", "zeus sheet")
				expect(sheet.achievement_rows().is_empty() and (sheet.get_node("%AchievementsLabel") as Control).visible, "zeus: 준비 중")
				finish()


func _tick_trial() -> void:
	match step:
		0:
			if playing(0.5):
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
				finish()
