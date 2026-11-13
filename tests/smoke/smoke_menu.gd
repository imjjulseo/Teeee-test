extends "res://tests/smoke/smoke_base.gd"
## 메뉴 화면 (기획서 8.1장, E38). 모드:
## - intro : 인트로 실제 클릭 → 메인(위 줄·아래 줄·BEST) → 레벨 버튼 실제 클릭 → 레벨 탑(아래가 Lv1, 지금 레벨이 보이게 스크롤,
##           선택권은 큰 칸, 다음 레벨 기둥이 경험치만큼) → 뒤로 → 메인
<<<<<<< HEAD
## - swipe : 아래 줄 블록을 실제 터치로 위로 밀면 게임 시작
## - tap   : 아래 줄 블록을 그냥 누르면 캐릭터 화면, 다시 누르면 메인, 상점 → 위 줄 레벨 → 뒤로 → 상점
## - sheet : 캐릭터 화면 → 장착 → 화살표로 넘김 → 미보유 캐릭터의 튜토리얼 / 체험 → 건너뛰면 캐릭터 화면, 장착은 그대로
=======
## - swipe : 아래 줄 블럭을 실제 터치로 위로 밀면 게임 시작
## - tap   : 아래 줄 블럭을 그냥 누르면 캐릭터 화면, 다시 누르면 메인, 상점 → 위 줄 레벨 → 뒤로 → 상점
## - sheet : 캐릭터 화면 → 장착 → 화살표로 넘김 → 미보유 캐릭터의 튜토리얼 및 체험 → 건너뛰면 캐릭터 화면, 장착은 그대로
>>>>>>> Choi
## - trial_quit : 체험 판 일시정지 → 메뉴 실제 클릭 → 캐릭터 화면, 플레이 기록 없음
const Grade = CharacterData.Grade
const LEVEL: int = 12

var _pos: Vector2 = Vector2.ZERO


func _setup() -> void:
	keep_stages = mode == "intro"  # 레벨 보상 문구를 본다 (체험 판은 단계 없이 아래 짧은 시간으로)
	config.game_duration = 2.0
	match mode:
		"intro":
			var progress: ProgressStore = ProgressStore.new()
			progress.set_level(LEVEL)
			progress.add_currency(340, 25)
			change_scene_to_file("res://scenes/intro.tscn")
		"swipe", "tap":
			change_scene_to_file("res://scenes/main_menu.tscn")
		"sheet":
			ProgressStore.new().add_ticket(Grade.RARE)
			ProgressStore.new().unlock(&"gardener")
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
		"swipe":
			_tick_swipe()
		"tap":
			_tick_tap()
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
				expect((node("%TopBar/%LevelLabel") as Label).text == "Lv %d" % LEVEL, "level button")
				expect((node("%TopBar/%WalletLabel") as WalletView).text == "● 340  ◆ 25", "wallet (%s)" % (node("%TopBar/%WalletLabel") as WalletView).text)
				expect((node("%BestLabel") as Label).text == "0", "best score")
				expect(not (node("%BottomNav/%ShopButton") as Button).disabled and not (node("%BottomNav/%AchievementsButton") as Button).disabled, "shop and achievements open")
				expect((current_scene as MainMenu).shows_swipe_hint(), "swipe hint for new players")
				shot("menu")
				click_control(node("%TopBar/%LevelButton"))
				next_step()
		2:
			if in_scene("LevelRewards", 0.6):
				var screen: LevelRewardsScreen = current_scene as LevelRewardsScreen
				var rows: Array[LevelRewardRow] = screen.rows()
				expect(rows.size() == 30, "30 levels (%d)" % rows.size())
				expect(rows[0].level == 30 and rows[rows.size() - 1].level == 1, "Lv1 at the bottom")
<<<<<<< HEAD
				expect(rows[rows.size() - 1].rewards_text() == "시작 보드 / 3색, 족보 2칸", "Lv1 reward (%s)" % rows[rows.size() - 1].rewards_text())
=======
				expect(rows[rows.size() - 1].rewards_text() == "시작 보드 · 3색 · 족보 2칸", "Lv1 reward (%s)" % rows[rows.size() - 1].rewards_text())
>>>>>>> Choi
				expect(rows[30 - 10].rewards_text().contains("영웅 선택권") and rows[30 - 10].is_big(), "Lv10 hero ticket: big node")
				expect(not rows[30 - 9].is_big(), "normal level: small node")
				var current: LevelRewardRow = screen.current_row()
				expect(current != null and current.level == LEVEL, "current level row")
				var view: Rect2 = (node("%Scroll") as Control).get_global_rect()
				expect(view.grow(0.5).encloses(current.get_global_rect()), "scrolled to the current level")
				expect(rows[30 - LEVEL - 1].level == LEVEL + 1 and rows[30 - LEVEL - 1].stem_ratio() == 0.0, "no exp yet")
				expect(current.stem_ratio() == 1.0 and rows[0].stem_ratio() == 0.0, "stems full below, empty above")
				expect((node("%SummaryLabel") as Label).text == "레벨 %d" % LEVEL, "level (%s)" % (node("%SummaryLabel") as Label).text)
				shot("level_rewards")
				click_control(node("%BackButton"))
				next_step()
		3:
			if in_scene("MainMenu"):
				finish()


<<<<<<< HEAD
## 실제 터치로 블록을 위로 민다.
=======
## 실제 터치로 블럭을 위로 민다.
>>>>>>> Choi
func _tick_swipe() -> void:
	var gesture: Control = null if current_scene == null or current_scene.name != "MainMenu" else node("%BottomNav/%BlockGesture")
	match step:
		0:
			if in_scene("MainMenu", 0.5):
				_pos = gesture.get_global_rect().get_center()
				touch(_pos, true)
				next_step()
		1:
			if step_time > 0.03:
				_pos += Vector2.UP * 60.0
				drag(_pos)
				step_time = 0.0
				if _pos.y < gesture.get_global_rect().get_center().y - 200.0:
					next_step()
		2:
			if current_scene != null and current_scene.name == "Main":
				touch(_pos, false)
				finish()
			elif step_time > 2.0:
				fail("swipe did not start the game")
				finish()


func _tick_tap() -> void:
	match step:
		0:
			if in_scene("MainMenu", 0.5):
				click_control(node("%BottomNav/%BlockGesture"))
				next_step()
		1:
			if in_scene("CharacterSelect", 0.6):
				click_control(node("%BottomNav/%BlockGesture"))
				next_step()
		2:
			if in_scene("MainMenu", 0.4):
				click_control(node("%BottomNav/%ShopButton"))
				next_step()
		3:
			if in_scene("Shop", 0.4):
				expect((current_scene as ShopScreen).tab == ShopScreen.Tab.GACHA, "the shop opens on gacha")
				var active: Button = node("%BottomNav/%ShopButton")
				expect(active.scale.x > 1.0 and active.theme_type_variation == &"NavButtonActive", "this screen's button pops out")
				shot("nav_shop")
				click_control(node("%TopBar/%LevelButton"))
				next_step()
		4:
			if in_scene("LevelRewards", 0.4):
				click_control(node("%BackButton"))
				next_step()
		5:
			if in_scene("Shop", 0.3):
				click_control(node("%BottomNav/%ShopButton"))
				next_step()
		6:
			if in_scene("MainMenu", 0.3):
				finish()


func _page() -> CharacterInfo:
	return (current_scene as CharacterSelect).carousel().current_page()


func _skip_button() -> Control:
	return (node("Tutorial") as TutorialDirector).spotlight.get_node("%SkipButton")


func _tick_sheet() -> void:
	var select: CharacterSelect = current_scene as CharacterSelect
	match step:
		0:
			if in_scene("CharacterSelect", 0.7):
				expect(select.shown_character().id == &"basic", "opens on the equipped character")
				select.show_character(&"gardener")
				next_step()
		1:
			if step_time > 0.2:
<<<<<<< HEAD
				expect(_page().shown_actions() == PackedStringArray(["장착하기", "튜토리얼 / 체험"]), "owned → equip (%s)" % [_page().shown_actions()])
=======
				expect(_page().shown_actions() == PackedStringArray(["장착하기", "튜토리얼 및 체험"]), "owned → equip (%s)" % [_page().shown_actions()])
>>>>>>> Choi
				expect((_page().get_node("%CharacterBestLabel") as Label).text == "최고점 0", "character best")
				click_control(_page().get_node("%EquipButton"))
				next_step()
		2:
			if step_time > 0.3:
				expect(CharacterStore.new().selected_id == &"gardener", "equipped")
<<<<<<< HEAD
				expect(_page().shown_actions() == PackedStringArray(["장착 중", "튜토리얼 / 체험"]) and (_page().get_node("%EquipButton") as Button).disabled, "equipped button")
=======
				expect(_page().shown_actions() == PackedStringArray(["장착 중", "튜토리얼 및 체험"]) and (_page().get_node("%EquipButton") as Button).disabled, "equipped button")
>>>>>>> Choi
				expect((node("%BottomNav") as BottomNav).block().shown_letter() == "정", "nav block follows the equipped character")
				shot("sheet_equipped")
				click_control(node("SafeArea/Content/Layout/Carousel/RightButton"))
				next_step()
		3:
			if step_time > 0.5:
				expect(select.shown_character().id != &"gardener", "arrow turns the page")
				select.show_character(&"clock")
				next_step()
		4:
			if step_time > 0.2:
				expect(_page().character.id == &"clock", "clock page")
<<<<<<< HEAD
				expect(_page().shown_actions() == PackedStringArray(["미보유", "튜토리얼 / 체험"]) and (_page().get_node("%EquipButton") as Button).disabled, "unowned: no equip, no unlock (%s)" % [_page().shown_actions()])
=======
				expect(_page().shown_actions() == PackedStringArray(["미보유", "튜토리얼 및 체험"]) and (_page().get_node("%EquipButton") as Button).disabled, "unowned: no equip, no unlock (%s)" % [_page().shown_actions()])
>>>>>>> Choi
				expect(ProgressStore.new().ticket_count(Grade.RARE) == 1, "ticket stays for the shop")
				click_control(_page().get_node("%LessonButton"))
				next_step()
		5:
			if playing(0.5):
				expect(controller.is_trial() and controller.is_lesson() and session().character.id == &"clock", "trial = the character tutorial")
				click_control(_skip_button())
				controller = null
				next_step()
		6:
			if in_scene("CharacterSelect", 0.4):
				expect(CharacterStore.new().selected_id == &"gardener", "trial does not change the equipped character")
				var progress: ProgressStore = ProgressStore.new()
				expect(progress.coins == 0 and progress.experience == 0 and not progress.is_unlocked(&"clock"), "no rewards, no unlock")
				expect(BestScoreStore.new().best == 0 and smoke_log_rows().is_empty(), "no best score or playtest row")
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
