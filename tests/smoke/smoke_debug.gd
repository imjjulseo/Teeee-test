extends "res://tests/smoke/smoke_base.gd"
## 설정 화면의 튜토리얼 다시 보기와 디버그 패널 (E41). 모드:
## - replay : 설정 → 튜토리얼 다시 보기 실제 클릭 → 규칙 튜토리얼 판 → 건너뛰기 → 메인, 기록·보상은 그대로
## - unlock : 튜토리얼 전 저장 → 설정 → 디버그의 "튜토리얼 건너뛰고 메뉴 모두 열기" 실제 클릭 → 아래 줄이 바로 열림
## - short  : 디버그의 "짧은 판" 실제 클릭 → 몇 초 뒤 결과 화면

const PANEL: String = "SafeArea/Content/Layout/Page/Box/Scroll/Inner/DebugPanel"
const SCROLL: String = "SafeArea/Content/Layout/Page/Box/Scroll"

var _coins: int = 0


func _setup() -> void:
	if mode == "unlock":
		TutorialStore.new().restart_all()
	change_scene_to_file("res://scenes/options.tscn")


func _tick() -> void:
	match mode:
		"replay":
			_tick_replay()
		"unlock":
			_tick_unlock()
		"short":
			_tick_short()
		_:
			fail("unknown mode " + mode)
			finish()


func _tick_replay() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				_coins = ProgressStore.new().coins
				(node(SCROLL) as ScrollContainer).ensure_control_visible(node("%TutorialButton"))
				shot("options")
				next_step()
		1:
			if step_time > 0.3:
				click_control(node("%TutorialButton"))
				controller = null
				next_step()
		2:
			if in_scene("Main", 0.6) and controller != null:
				var spot: SpotlightOverlay = node("SpotlightOverlay") as SpotlightOverlay
				if spot.is_open():
					expect(controller.is_tutorial(), "the rule tutorial again")
					click_control(spot.get_node("%SkipButton"))
					controller = null
					next_step()
		3:
			if in_scene("MainMenu", 0.3):
				var tutorial: TutorialStore = TutorialStore.new()
				expect(tutorial.done and tutorial.flow == TutorialStore.Flow.DONE, "tutorial record untouched")
				expect(ProgressStore.new().coins == _coins, "no reward for watching again")
				expect(not PlayRequest.is_pending(), "request cleared")
				finish()


func _tick_unlock() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				expect(not TutorialFlow.current().unlocks().is_open(MenuUnlocks.Entry.SHOP), "shop locked before the tutorial")
				(node(SCROLL) as ScrollContainer).ensure_control_visible(node(PANEL).get_node("%ShortGameButton"))
				next_step()
		1:
			if step_time > 0.3:
				shot("debug_panel")
				click_control(node(PANEL).get_node("%UnlockMenusButton"))
				next_step()
		2:
			if step_time > 0.3:
				expect(TutorialStore.new().done, "tutorial skipped")
				for entry: int in MenuUnlocks.Entry.values():
					expect(TutorialFlow.current().unlocks().is_open(entry), "entry %d open" % entry)
				expect(not (node("%BottomNav/%ShopButton") as Button).disabled, "bottom bar redrawn right away")
				finish()


func _tick_short() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				(node(SCROLL) as ScrollContainer).ensure_control_visible(node(PANEL).get_node("%ShortGameButton"))
				next_step()
		1:
			if step_time > 0.3:
				click_control(node(PANEL).get_node("%ShortGameButton"))
				controller = null
				next_step()
		2:
			if in_scene("Main", 0.5) and playing():
				flow().request_move(Vector2i.UP)
				next_step()
		3:
			if flow() != null and flow().state == S.RESULT:
				expect(step_time < 9.0, "result came quickly (%.1f s)" % step_time)
				finish()
			elif step_time > 12.0:
				fail("short game did not end")
				finish()
