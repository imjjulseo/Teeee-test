extends "res://tests/smoke/smoke_base.gd"
## 6b 규칙 튜토리얼 (기획서 8.8장). 모드:
## - rule : 새 저장 → 게임 화면이 튜토리얼 판(시간 안 흐름) → 단계를 끝까지 자동으로 진행
##          (설명은 실제 클릭, 퍼즐은 실제 방향키로 최소 수, 결과 카드 "다음" 클릭, 자유 매치는 판을 칠해 실제 이동으로 매치)
##          → 실전 판으로 다시 열림 + 첫 실전 판 안내 → 튜토리얼 완료 업적 ● 50, 튜토리얼 퍼즐 별 기록
## - skip : 첫 설명의 건너뛰기 실제 클릭 → 실전 판, 튜토리얼 끝냄
## - flow : 튜토리얼 뒤 메뉴(시작만) → 첫 실전 판(결과에서 다시 하기 숨김) → 레벨 버튼 → 레벨 보상 안내 → 시작 = 상점(첫 뽑기:
##          1회분 코인, 정원사·시계공 고정, 장착) → 캐릭터 버튼 → 캐릭터 화면 → 그 캐릭터로 시작(캐릭터 튜토리얼 판) → 업적 → 퍼즐 안내 → 모두 열림

const KEYS: Dictionary[Vector2i, Key] = {Vector2i.UP: KEY_UP, Vector2i.DOWN: KEY_DOWN, Vector2i.LEFT: KEY_LEFT, Vector2i.RIGHT: KEY_RIGHT}

var _last_index: int = -2
var _path: Array[Vector2i] = []
var _cooldown: float = 0.0
var _reloaded: bool = false
var _shots: Dictionary[String, bool] = {}
var _swipe_seen_at: float = -1.0


func _setup() -> void:
	if mode == "flow":
		config.game_duration = 2.0
		var store: TutorialStore = TutorialStore.new()
		store.restart_all()
		store.complete_rule_tutorial()
		store.mark_seen(TutorialStore.SEEN_REAL_GAME)
		change_scene_to_file("res://scenes/main_menu.tscn")
		return
	keep_stages = true  # 첫 실전 판 = Lv1 보드
	TutorialStore.new().restart_all()
	change_scene_to_file("res://scenes/main.tscn")


func _director() -> TutorialDirector:
	return node("Tutorial") as TutorialDirector


func _spot() -> SpotlightOverlay:
	return node("SpotlightOverlay") as SpotlightOverlay


func _tick() -> void:
	if mode == "flow":
		_tick_flow()
		return
	if current_scene == null or current_scene.name != "Main" or controller == null:
		return
	match mode:
		"rule":
			_tick_rule()
		"skip":
			_tick_skip()


func _tick_skip() -> void:
	match step:
		0:
			if _spot().is_open() and step_time > 0.5:
				expect(controller.is_tutorial(), "tutorial game")
				click_control(_spot().get_node("%SkipButton"))
				controller = null
				next_step()
		1:
			if controller != null and step_time > 0.5:
				expect(not controller.is_tutorial() and TutorialStore.new().done, "skipped → real game")
				expect(ProgressStore.new().coins == 50, "tutorial achievement ● 50 (%d)" % ProgressStore.new().coins)
				finish()


func _tick_rule() -> void:
	if _reloaded:
		_check_real_game()
		return
	var director: TutorialDirector = _director()
	if step == 0:
		if step_time < 0.5:
			return
		expect(controller.is_tutorial(), "fresh save → tutorial game")
		expect(session().get_config().color_count == 3, "3 colors")
		expect(session().frozen_clocks.has(TimedSystem.Clock.TIMER), "time does not flow")
		next_step()
		return
	if not controller.is_tutorial() or not director.is_running():
		# 끝났다: 실전 판으로 다시 열린다 (같은 프레임에 다시 열렸을 수도 있다 — 새 판의 안내는 누르지 않는다)
		if controller.is_tutorial():
			controller = null
		_reloaded = true
		step_time = 0.0
		return
	if director.step_index != _last_index:  # 단계가 바뀌면 시간 제한을 새로
		_last_index = director.step_index
		step_time = 0.0
		_path.clear()
	_cooldown -= 1.0 / 60.0
	if _cooldown > 0.0:
		return
	_drive(director)


func _drive(director: TutorialDirector) -> void:
	var result: PuzzleResultPanel = node("TutorialUI/PuzzleResult")
	if result.visible:
		_shot_once("puzzle_result")
		click_control(result.get_node("%NextButton"))
		_cooldown = 0.2
		return
	if _spot().is_blocking():
		_shot_once("say_%d" % director.step_index)
		var button: Button = _spot().get_node("%CaptionButton")
		click_control(button if button.visible else _spot().get_node("%Caption"))
		_cooldown = 0.25
		return
	var runner: PuzzleRunner = director.runner()
	if runner != null:
		if director.is_waiting_to_start():
			return
		if runner.is_playing():
			if director.step_index == 0 and runner.puzzle.moves.is_empty() and not _shots.has("swipe"):
				if _swipe_seen_at < 0.0:
					_swipe_seen_at = step_time
					var marks: Array[BoardMark] = (node("BoardView/Marks") as BoardMarksView).marks()
					expect(marks.any(func(m: BoardMark) -> bool: return m.kind == BoardMark.Kind.SWIPE), "first board: swipe hint (HTML tswipe)")
				if step_time - _swipe_seen_at < 0.6:
					return
				_shot_once("swipe")
			if _path.is_empty():
				_path = runner.puzzle.solution.path.duplicate()
				_shot_once("puzzle_%s" % runner.puzzle.def.id)
			press_key(KEYS[_path.pop_front()])
			_cooldown = 0.08
		return
	var current: TutorialStep = director.current_step()
	if current is MoveStep:
		press_key(KEY_RIGHT)
		_cooldown = 0.3
	elif current is TimeStep or (current is MatchStep and (current as MatchStep).rule_hints):
		_walk_learned_plan(director)
	elif current is MatchStep:
		_make_match(director, current as MatchStep)
		_cooldown = 0.35


## 규칙 튜토리얼 자유 매치: 배운 모양 힌트(TutorialPlanner)가 고른 길을 실제 방향키로 따라간다 (판을 칠하지 않는다).
func _walk_learned_plan(director: TutorialDirector) -> void:
	if _path.is_empty():
		var plan: TutorialPlanner.Plan = director.planner.best(9)
		if plan == null and director.planner.best(9, false, true) != null:
			_cooldown = 0.2  # 씨앗이 자라면 생기는 모양 (HTML tutEnsure도 씨앗을 자랄 색으로 친다) — 기다린다
			return
		if plan == null:  # 매치 직후 다음 프레임에 판을 고친다(tutEnsure). 그래도 없으면 6초 힌트가 고친다 (tutFreeIdle)
			_cooldown = 0.3
			return
		_shot_once("free_%d" % director.step_index)
		_path = plan.path.duplicate()
	press_key(KEYS[_path.pop_front()])
	_cooldown = 0.15


## 목표에 맞는 색으로 플레이어 바로 위에 십자를 칠하고 실제로 위로 움직여 매치한다.
func _make_match(director: TutorialDirector, match_step: MatchStep) -> void:
	_shot_once("match_%d" % director.step_index)
	var color: int = 0
	match match_step.filter:
		MatchStep.Filter.LETTER_A:
			color = director.letter("A")
		MatchStep.Filter.RECIPE_NEXT:
			var nexts: Array[int] = director.recipe_nexts()
			if nexts.is_empty():
				fail("step %d: no recipe to advance (%d cards)" % [director.step_index, session().recipes.slot_count()])
				finish()
				return
			color = nexts[0]
		MatchStep.Filter.NOT_NEXT:
			color = (director.first_recipe_next() + 1) % session().get_config().color_count
	var board: Board = session().board
	board.teleport_player(board.center())
	prepare_match_above(color)
	flow().request_move(Vector2i.UP)


func _check_real_game() -> void:
	if controller == null or step_time < 0.6 and step != 100:
		return
	if step == 100:
		_intro_closed()
		return
	if _shots.has("done"):
		return
	_shots["done"] = true
	expect(not controller.is_tutorial(), "real game after the tutorial")
	var store: TutorialStore = TutorialStore.new()
	expect(store.done and store.flow == TutorialStore.Flow.FIRST_GAMES, "tutorial done, flow = first games")
	expect(_spot().is_open() and _spot().caption_head() == "실전", "first real game intro (%s)" % _spot().caption_head())
	expect(_director().halts_game(), "the intro holds the game until tapped")
	click_control(_spot().get_node("%CaptionButton"))
	_shots["intro_clicked"] = true
	expect(flow().state == S.WAITING, "game waits for the first move")
	expect(ProgressStore.new().coins == 50, "tutorial achievement ● 50 (%d)" % ProgressStore.new().coins)
	expect(PuzzleStore.new().stars_of("1a") > 0 and PuzzleStore.new().stars_of("2a") == 0, "tutorial puzzle stars saved (Lv.0·1 only)")
	expect(session().get_config().color_count == 3, "first real game = Lv1 board (3 colors)")
	shot("real_game_intro")
	step = 100
	step_time = 0.0


func _intro_closed() -> void:
	if step_time > 0.4:
		expect(not _spot().is_open() and not _director().is_running(), "start button closes the intro")
		finish()


func _menu() -> MainMenu:
	return current_scene as MainMenu


func _tick_flow() -> void:
	var E = MenuUnlocks.Entry
	match step:
		0:
			if in_scene("MainMenu", 0.4):
				expect(_menu().is_entry_enabled(E.START) and not _menu().is_entry_enabled(E.LEVEL), "only start after the tutorial")
				expect(_menu().highlighted_entry() == E.START, "start glows")
				click_control(node("%StartButton"))
				next_step()
		1:
			if playing(0.4):
				flow().request_move(Vector2i.UP)
				next_step()
		2:
			var result_panel: ResultPanel = node("ResultPanel") as ResultPanel if flow() != null else null
			if result_panel != null and result_panel.is_guiding() and step_time > 0.4:
				expect((result_panel.get_node("%Spotlight") as SpotlightOverlay).caption_head() == "경험치", "first result → experience guide")
				shot("flow_experience_guide")
				click_control(result_panel.get_node("%Spotlight").get_node("%Caption"))
				step_time = 0.0
			elif flow() != null and flow().state == S.RESULT and step_time > 0.4 and not result_panel.is_guiding() \
					and TutorialStore.new().has_seen(TutorialStore.SEEN_EXPERIENCE):  # 경험치 안내를 보고 닫은 뒤
				expect(not (node("ResultPanel/Center/RetryButton") as Control).visible, "first real game → no retry, go to the menu")
				click_control(node("ResultPanel/Center/MainMenuButton"))
				controller = null
				next_step()
			elif step_time > 6.0:
				fail("game did not end")
				finish()
		3:
			if in_scene("MainMenu", 0.4):
				expect(_menu().is_entry_enabled(E.LEVEL) and not _menu().is_entry_enabled(E.SHOP), "level button opens")
				expect(_menu().highlighted_entry() == E.LEVEL, "level button glows")
				click_control(node("%LevelButton"))
				next_step()
		4:
			if in_scene("LevelRewards", 0.6):
				var screen: LevelRewardsScreen = current_scene as LevelRewardsScreen
				expect(screen.is_guiding(), "level rewards guide")
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_LEVEL_SCREEN), "level screen seen")
				shot("flow_level_guide")
				click_control(node("SpotlightOverlay").get_node("%Caption"))
				next_step()
		5:
			if step_time > 0.3:
				expect(not (current_scene as LevelRewardsScreen).is_guiding(), "tap closes the guide")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		6:
			if in_scene("MainMenu", 0.4):
				expect((node("%StageLabel") as Label).text == "첫 캐릭터 뽑기", "stage label")
				expect(_menu().is_entry_enabled(E.SHOP) and _menu().highlighted_entry() == E.SHOP, "shop opens and glows")
				click_control(node("%StartButton"))
				next_step()
		7:
			if in_scene("Shop", 0.6):
				var shop: ShopScreen = current_scene as ShopScreen
				expect(shop.is_guiding(), "gacha guide")
				expect(ProgressStore.new().coins >= 500, "one pull of coins gifted (%d)" % ProgressStore.new().coins)
				shot("flow_gacha_guide")
				click_control(node("%Chest"))
				next_step()
		8:
			var reveal: GachaReveal = node("%Reveal")
			if reveal.visible and step_time > 2.5:
				var id: StringName = (current_scene as ShopScreen).last_result().character.id
				expect(id == &"gardener" or id == &"clock", "first pull fixed (%s)" % id)
				click_control(reveal.get_node("Center/OkButton"))
				next_step()
			elif step_time > 6.0:
				fail("first pull did not open")
				finish()
		9:
			if step_time > 0.4:
				var spot: SpotlightOverlay = node("SpotlightOverlay")
				expect(spot.is_open() and spot.caption_head().ends_with("획득!"), "got guide (%s)" % spot.caption_head())
				var got: StringName = (current_scene as ShopScreen).last_result().character.id
				expect(CharacterStore.new().selected_id == got, "equipped right away")
				expect(TutorialStore.new().flow == TutorialStore.Flow.FIRST_CHARACTER, "flow: first character")
				shot("flow_got")
				click_control(spot.get_node("%Caption"))
				next_step()
		10:
			if step_time > 0.3:
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		11:
			if in_scene("MainMenu", 0.4):
				expect(_menu().is_entry_enabled(E.CHARACTERS) and _menu().highlighted_entry() == E.CHARACTERS, "characters open and glow")
				click_control(node("%CharactersButton"))
				next_step()
		12:
			if in_scene("CharacterSelect", 0.4) and (current_scene as CharacterSelect).is_guiding():
				shot("flow_characters_guide")
				click_control(node("Spotlight").get_node("%Caption"))
				step_time = 0.0
			elif in_scene("CharacterSelect", 0.4):
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_CHARACTERS), "characters seen")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		13:
			if in_scene("MainMenu", 0.4):
				expect(_menu().highlighted_entry() == E.START, "now start glows (play with the new character)")
				click_control(node("%StartButton"))
				next_step()
		14:
			if playing(0.4):
				var want: StringName = CharacterStore.new().selected_id
				expect(session().character.id == want, "game with the new character")
				expect(TutorialStore.new().flow == TutorialStore.Flow.DONE, "flow done")
				expect(controller.is_lesson(), "the first game with it is the character tutorial")
				expect(controller.is_lesson(), "the first game with it is the character tutorial")
				auto_resume = false
				flow().pause()
				next_step()
		15:
			if step_time > 0.3:
				click_control(node("PauseOverlay/Center/MainMenuButton"))
				controller = null
				next_step()
		16:
			if in_scene("MainMenu", 0.4):
				expect(_menu().is_entry_enabled(E.ACHIEVEMENTS) and _menu().highlighted_entry() == E.ACHIEVEMENTS, "achievements open and glow")
				click_control(node("%AchievementsButton"))
				next_step()
		17:
			if in_scene("Achievements", 0.4) and (current_scene as AchievementsScreen).guide_key() != "":
				shot("flow_%s_guide" % (current_scene as AchievementsScreen).guide_key())
				click_control(node("Spotlight").get_node("%Caption"))
				step_time = 0.0
			elif in_scene("Achievements", 0.4):
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS), "hidden achievements guide seen")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		18:
			if in_scene("MainMenu", 0.4):
				expect(_menu().is_entry_enabled(E.PUZZLES) and _menu().highlighted_entry() == E.PUZZLES, "puzzles open and glow (11/06)")
				click_control(node("%PuzzlesButton"))
				next_step()
		19:
			if in_scene("PuzzleMenu", 0.4) and (current_scene as PuzzleMenuScreen).guide_key() != "":
				expect((node("Spotlight") as SpotlightOverlay).caption_head() == "퍼즐", "puzzle guide")
				shot("flow_puzzles_guide")
				click_control(node("Spotlight").get_node("%Caption"))
				step_time = 0.0
			elif in_scene("PuzzleMenu", 0.4):
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_PUZZLES), "puzzle guide seen")
				click_control(node("SafeArea/Content/Layout/BackButton"))
				next_step()
		20:
			if in_scene("MainMenu", 0.4):
				expect(_menu().highlighted_entry() == -1, "all open, nothing glows")
				shot("flow_all")
				finish()


func _shot_once(shot_name: String) -> void:
	if not _shots.has(shot_name):
		_shots[shot_name] = true
		shot(shot_name)
