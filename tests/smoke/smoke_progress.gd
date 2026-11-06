extends "res://tests/smoke/smoke_base.gd"
## 진행 기반 (5a, 기획서 8.2 · 8.4장). 모드:
## - stage   : Lv1 보드 단계(3색 · 족보 2장) → 0초 → 결과의 코인·경험치 바·레벨업·보드 업그레이드 → 실제 클릭 "다시 하기"
##             → 다음 판이 Lv2 단계(45초)
## - revive  : 다이아 30 → 0초에 부활 창 → 실제 클릭 "부활" → +10초·다이아 −20 → 다시 0초면 부활 없이 결과
## - decline : 부활 창에서 실제 클릭 "끝내기" → 결과, 다이아 그대로
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
		"revive", "decline":
			config.game_duration = 1.0
			ProgressStore.new().add_currency(0, 30)
			change_scene_to_file("res://scenes/main.tscn")
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
				expect((result.get_node("%CoinLabel") as Label).text.begins_with("● +5"), "coins ⌊500 ÷ 100⌋ (+ picked)")
				expect((result.get_node("%LevelLabel") as Label).text == "Lv 2 · 다음 4색 · 4칸 족보", "level and next stage (%s)" % (result.get_node("%LevelLabel") as Label).text)
				var lines: Array[PackedStringArray] = result.shown_rewards()
				expect(lines.size() == 2 and lines[0][0] == "레벨 2" and lines[1][0] == "보드 업그레이드", "rewards list (%s)" % [lines])
				expect(ProgressStore.new().level == 2, "level saved")
				shot("result_levelup")
				click_control(result.get_node("Center/RetryButton"))
				next_step()
		2:
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
					expect(ProgressStore.new().diamonds == 30 + _level_up_diamonds(), "diamonds kept (+ level-up %d)" % _level_up_diamonds())
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
				expect((_result().get_node("%WalletLabel") as Label).text.ends_with("◆ %d" % (10 + _level_up_diamonds())), "wallet on the result (%s)" % (_result().get_node("%WalletLabel") as Label).text)
				finish()


## 이 판의 레벨업 다이아 (Lv1에서 시작, 경험치 = 500 + 0.25 × 점수라 결과까지 간 판은 늘 레벨이 오른다).
func _level_up_diamonds() -> int:
	return RunRewards.compute(session().score, session().collected_coins(), 1, 0, progression).total_diamonds()


func _tick_debug() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				var panel: DebugPanel = node("SafeArea/Content/Layout/Scroll/Inner/DebugPanel") as DebugPanel
				expect(panel.visible, "debug panel in a dev build")
				(node("SafeArea/Content/Layout/Scroll") as ScrollContainer).ensure_control_visible(panel.get_node("%GrantButton"))  # 스크롤 아래쪽
				next_step()
		1:
			if step_time > 0.3:
				click_control(node("SafeArea/Content/Layout/Scroll/Inner/DebugPanel").get_node("%GrantButton"))
				next_step()
		2:
			if step_time > 0.3:
				var store: ProgressStore = ProgressStore.new()
				expect(store.coins == 1000 and store.diamonds == 100, "grant saved (%d, %d)" % [store.coins, store.diamonds])
				var panel: DebugPanel = node("SafeArea/Content/Layout/Scroll/Inner/DebugPanel") as DebugPanel
				expect(panel.status_text().contains("● 1000"), "status updated (%s)" % panel.status_text())
				shot("debug_panel")
				finish()
