extends "res://tests/smoke/smoke_base.gd"
## 진행 기반 (5a, 기획서 8.2 · 8.4장). 모드:
## - stage   : Lv1 보드 단계(3색 · 족보 2장) → 0초 → 결과의 코인·경험치 바·레벨업·보드 업그레이드 → 실제 클릭 "다시 하기"
##             → 다음 판이 Lv2 단계(45초)
## - revive  : 다이아 30 → 0초에 부활 창 → 실제 클릭 "부활" → +10초·다이아 −20 → 다시 0초면 부활 없이 결과
## - decline : 부활 창에서 실제 클릭 "끝내기" → 결과, 다이아 그대로
## - timeout : 부활 창에서 아무것도 안 누르면 게이지가 줄고 시간이 다 되면 결과, 다이아 그대로
## - claim   : 메뉴의 받기 표시 → 레벨 보상 화면에서 눌러서 받기
## - debug   : 설정의 디버그(개발 빌드) 실제 클릭 → 재화 지급이 저장됨

var _score_before: int = 0


func _setup() -> void:
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.SWIPE)
	match mode:
		"stage":
			keep_stages = true
			progression.stages[0].game_duration = 1.0  # Lv1 판을 빨리 끝낸다 (메모리에서만)
			var store: ProgressStore = ProgressStore.new()
			store.experience = 29  # 점수 500 → 경험치 500 + 125 → Lv2 (Lv2는 600 필요라 한 레벨만)
			store.save()
			change_scene_to_file("res://scenes/main.tscn")
		"revive", "decline", "timeout":
			config.game_duration = 1.0
			config.revive_decision_time = 1.0 if mode == "timeout" else 5.0
			ProgressStore.new().add_currency(0, 30)
			change_scene_to_file("res://scenes/main.tscn")
		"claim":
			ProgressStore.new().set_level(10)
			change_scene_to_file("res://scenes/main_menu.tscn")
		"debug":
			change_scene_to_file("res://scenes/options.tscn")


func _tick() -> void:
	match mode:
		"stage":
			_tick_stage()
		"revive":
			_tick_revive(true)
		"decline":
			_tick_revive(false)
		"timeout":
			_tick_timeout()
		"claim":
			_tick_claim()
		"debug":
			_tick_debug()


func _result() -> ResultPanel:
	return node("ResultPanel") as ResultPanel


func _tick_stage() -> void:
	match step:
		0:
			if playing():
				expect(session().get_config().color_count == 3, "Lv1: 3 colors")
				expect(session().recipes.slot_count() == 2 and not (node("Hud/%Recipe2") as Control).visible, "Lv1: two recipe cards")
				expect(session().board.color_counts(4)[3] == 0, "no 4th color on the board")
				shot("stage1")
				flow().request_move(Vector2i.UP)
				session().score = 500
				next_step()
		1:
			if flow().state == S.RESULT and step_time > 0.3:
				var result: ResultPanel = _result()
				expect(result.visible, "result shown")
				expect((result.get_node("%CoinLabel") as Label).text.begins_with("보유 코인 ● "), "held coins, no \"+N\" (%s)" % (result.get_node("%CoinLabel") as Label).text)
				var lines: Array[PackedStringArray] = result.shown_rewards()
				expect(lines.size() == 1 and lines[0][0] == "보드 업그레이드", "no level rewards in the list (%s)" % [lines])
				expect(ProgressStore.new().level == 2, "level saved")
				expect(ProgressStore.new().diamonds == 0, "level rewards are not paid automatically")
				expect(result.find_child("WalletLabel", true, false) == null, "no held diamonds")
				next_step()
		2:
			if step_time > 1.5:  # 연출이 끝난 뒤
				var result: ResultPanel = _result()
				expect((result.get_node("%CoinLabel") as Label).text == "보유 코인 ● %d" % ProgressStore.new().coins, "coins counted up to the held amount (%s)" % (result.get_node("%CoinLabel") as Label).text)
				expect((result.get_node("%LevelLabel") as Label).text == "Lv 2 · 다음 4색 · 4칸 족보", "level and next stage (%s)" % (result.get_node("%LevelLabel") as Label).text)
				expect((result.get_node("%LevelUpLabel") as Control).visible, "level up shown")
				shot("result_levelup")
				click_control(result.get_node("Center/RetryButton"))
				next_step()
		3:
			if playing(0.2):
				expect(is_equal_approx(session().remaining_time(), 45.0), "retry uses the Lv2 stage (45 s, %.1f)" % session().remaining_time())
				finish()


func _tick_revive(accept: bool) -> void:
	var panel: RevivePanel = node("RevivePanel") as RevivePanel
	match step:
		0:
			if playing():
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if flow().state == S.REVIVE and step_time > 0.3:
				expect(panel.visible, "revive window")
				expect((panel.get_node("%ReviveWalletLabel") as Label).text == "보유 ◆ 30", "shows diamonds")
				expect((panel.get_node("%ReviveButton") as Button).text == "◆ 20  부활 +10초", "cost and time")
				shot("revive")
				click_control(panel.get_node("%ReviveButton") if accept else panel.get_node("Center/EndButton"))
				next_step()
		2:
			if step_time > 0.3:
				if not accept:
					expect(flow().state == S.RESULT, "declined → result")
					expect(ProgressStore.new().diamonds == 30, "diamonds kept")
					finish()
					return
				expect(flow().state == S.PLAYING, "revived")
				expect(not panel.visible, "window closed")
				expect(ProgressStore.new().diamonds == 10, "20 diamonds spent")
				expect(session().remaining_time() > 9.0, "+10 s (%.1f)" % session().remaining_time())
				session().take_time(100.0, 0.0)  # 다시 0초로
				next_step()
		3:
			if step_time > 0.3:
				expect(flow().state == S.RESULT, "no second revive in the same game")
				expect(ProgressStore.new().diamonds == 10, "diamonds unchanged by the result")
				finish()


## 메뉴의 받기 표시 → 레벨 화면 → 지금 레벨 줄의 "받기" 실제 클릭 → 재화·선택권 지급, 버튼 사라짐.
func _tick_claim() -> void:
	match step:
		0:
			if in_scene("MainMenu", 0.4):
				expect((node("%TopBar/%ClaimMark") as Control).visible, "menu shows there is something to claim")
				click_control(node("%TopBar/%LevelButton"))
				next_step()
		1:
			if in_scene("LevelRewards", 0.5):
				var row: LevelRewardRow = (current_scene as LevelRewardsScreen).current_row()
				expect(row.level == 10 and row.is_claimable(), "reached level has a claim button")
				shot("claim")
				click_control(row.node_button())
				next_step()
		2:
			if step_time > 0.3:
				var store: ProgressStore = ProgressStore.new()
				expect([store.coins, store.diamonds, store.ticket_count(CharacterData.Grade.HERO)] == [100, 10, 1], "paid on press (%d, %d)" % [store.coins, store.diamonds])
				var row: LevelRewardRow = (current_scene as LevelRewardsScreen).current_row()
				expect(not row.is_claimable(), "the button is gone")
				finish()


func _tick_timeout() -> void:
	var panel: RevivePanel = node("RevivePanel") as RevivePanel
	match step:
		0:
			if playing():
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if flow().state == S.REVIVE:
				next_step()
		2:
			if step_time > 0.3:
				expect(panel.visible and panel.gauge_ratio() < 1.0 and panel.gauge_ratio() > 0.0, "gauge runs down (%.2f)" % panel.gauge_ratio())
				shot("revive_gauge")
				next_step()
		3:
			if flow().state == S.RESULT and step_time > 0.1:
				expect(not panel.visible, "window closed on timeout")
				expect(ProgressStore.new().diamonds == 30, "diamonds kept")
				finish()
			elif step_time > 3.0:
				fail("revive did not time out")
				finish()


func _tick_debug() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				var panel: DebugPanel = node("SafeArea/Content/Layout/Page/Box/Scroll/Inner/DebugPanel") as DebugPanel
				expect(panel.visible, "debug panel in a dev build")
				(node("SafeArea/Content/Layout/Page/Box/Scroll") as ScrollContainer).ensure_control_visible(panel.get_node("%GrantButton"))  # 스크롤 아래쪽
				next_step()
		1:
			if step_time > 0.3:
				click_control(node("SafeArea/Content/Layout/Page/Box/Scroll/Inner/DebugPanel").get_node("%GrantButton"))
				next_step()
		2:
			if step_time > 0.3:
				var store: ProgressStore = ProgressStore.new()
				expect(store.coins == 1000 and store.diamonds == 100, "grant saved (%d, %d)" % [store.coins, store.diamonds])
				var panel: DebugPanel = node("SafeArea/Content/Layout/Page/Box/Scroll/Inner/DebugPanel") as DebugPanel
				expect(panel.status_text().contains("● 1000"), "status updated (%s)" % panel.status_text())
				shot("debug_panel")
				finish()
