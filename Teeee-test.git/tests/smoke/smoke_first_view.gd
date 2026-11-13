extends "res://tests/smoke/smoke_base.gd"
## 6d 처음 볼 때 안내 (기획서 8.8장). 모드:
## - multi   : 실전 판에서 두 족보가 같은 색을 기다리게 된 매치 → "족보 동시 진행" 스포트라이트(그 두 카드, 판 멈춤) → 실제 클릭으로 닫기,
##             다시 그런 순간이 와도 안 뜸
## - result  : 첫 결과 화면 → "경험치" 안내(경험치 바) → 실제 클릭 → 다음 결과에는 안 뜸
## - screens : 업적 화면 → "업적" → "히든 업적"(위쪽, 히든 줄이 보이게 스크롤) → 캐릭터 화면 → "캐릭터" → 다시 열면 안 뜸

func _setup() -> void:
	var store: TutorialStore = TutorialStore.new()
	store.restart_all()
	store.complete_rule_tutorial()
	store.mark_seen(TutorialStore.SEEN_REAL_GAME)
	store.mark_seen(TutorialStore.SEEN_ALL_CHARACTERS)
	match mode:
		"multi":
			store.mark_seen(TutorialStore.SEEN_EXPERIENCE)
			change_scene_to_file("res://scenes/main.tscn")
		"result":
			config.game_duration = 1.0
			store.mark_seen(TutorialStore.SEEN_MULTI_RECIPES)
			change_scene_to_file("res://scenes/main.tscn")
		"screens":
			change_scene_to_file("res://scenes/achievements.tscn")


func _director() -> TutorialDirector:
	return node("Tutorial") as TutorialDirector


func _tick() -> void:
	match mode:
		"multi":
			_tick_multi()
		"result":
			_tick_result()
		"screens":
			_tick_screens()


func _tick_multi() -> void:
	match step:
		0:
			if playing(0.4):
				var recipes: RecipeSet = session().recipes
				recipes.replace_all([PackedInt32Array([1, 2]), PackedInt32Array([0, 1, 3])] as Array[PackedInt32Array], PackedInt32Array([0, 0]))
				# 노랑(0)으로 매치하면 둘째 족보가 빨강을 기다리게 되어 첫 족보와 같은 색
				var board: Board = session().board
				board.teleport_player(board.center())
				prepare_match_above(0)
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if step_time > 0.3:
				var spot: SpotlightOverlay = node("SpotlightOverlay") as SpotlightOverlay
				expect(_director().is_moment_open() and spot.caption_head() == "족보 동시 진행", "multi recipe guide (%s)" % spot.caption_head())
				expect(_director().halts_game(), "the guide holds the game")
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_MULTI_RECIPES), "seen")
				shot("multi")
				click_control(spot.get_node("%Caption"))
				next_step()
		2:
			if step_time > 0.3:
				expect(not _director().is_moment_open() and not (node("SpotlightOverlay") as SpotlightOverlay).is_open(), "tap closes it")
				var recipes: RecipeSet = session().recipes
				recipes.replace_all([PackedInt32Array([2, 1]), PackedInt32Array([0, 2])] as Array[PackedInt32Array], PackedInt32Array([0, 0]))
				var board: Board = session().board
				board.teleport_player(board.center())
				prepare_match_above(0)
				flow().request_move(Vector2i.UP)
				next_step()
		3:
			if step_time > 0.3:
				expect(not _director().is_moment_open(), "only once")
				finish()


func _result_panel() -> ResultPanel:
	return node("ResultPanel") as ResultPanel


func _tick_result() -> void:
	match step:
		0:
			if playing(0.4):
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if flow().state == S.RESULT and step_time > 0.2 and _result_panel().is_guiding():
				var spot: SpotlightOverlay = _result_panel().get_node("%Spotlight")
				expect(spot.caption_head() == "경험치" and spot.is_blocking(), "experience guide on the first result")
				expect(TutorialStore.new().has_seen(TutorialStore.SEEN_EXPERIENCE), "seen")
				shot("result")
				click_control(spot.get_node("%Caption"))
				next_step()
			elif step_time > 5.0:
				fail("no experience guide")
				finish()
		2:
			if step_time > 0.3:
				expect(not _result_panel().is_guiding(), "tap closes it")
				controller = null
				change_scene_to_file("res://scenes/main.tscn")  # 다음 판 (첫 판 뒤라 다시 하기는 숨겨져 있다)
				next_step()
		3:
			if current_scene != null and current_scene.name == "Main" and playing(0.5):
				flow().request_move(Vector2i.UP)
				next_step()
		4:
			if flow().state == S.RESULT and step_time > 0.6:
				expect(not _result_panel().is_guiding(), "not again")
				finish()


func _tick_screens() -> void:
	match step:
		0:
			if in_scene("Achievements", 0.3) and (current_scene as AchievementsScreen).guide_key() != "":
				expect((current_scene as AchievementsScreen).guide_key() == TutorialStore.SEEN_ACHIEVEMENTS, "achievements guide first")
				expect((node("Spotlight") as SpotlightOverlay).caption_head() == "업적", "head")
				shot("achievements")
				click_control(node("Spotlight").get_node("%Caption"))
				next_step()
		1:
			if step_time > 0.3:
				var screen: AchievementsScreen = current_scene as AchievementsScreen
				expect(screen.guide_key() == TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS, "then hidden achievements")
				var row: Control = screen.hidden_rows()[0]
				var view: Rect2 = (node("%Scroll") as Control).get_global_rect()
				expect(view.intersects(row.get_global_rect()), "hidden rows scrolled into view")
				shot("hidden")
				click_control(node("Spotlight").get_node("%Caption"))
				next_step()
		2:
			if step_time > 0.3:
				expect((current_scene as AchievementsScreen).guide_key() == "" and not (node("Spotlight") as SpotlightOverlay).is_open(), "done")
				change_scene_to_file("res://scenes/character_select.tscn")
				next_step()
		3:
			if in_scene("CharacterSelect", 0.3) and (current_scene as CharacterSelect).is_guiding():
				expect((node("Spotlight") as SpotlightOverlay).caption_head() == "캐릭터", "characters guide")
				shot("characters")
				click_control(node("Spotlight").get_node("%Caption"))
				next_step()
		4:
			if step_time > 0.3:
				expect(not (current_scene as CharacterSelect).is_guiding(), "tap closes it")
				change_scene_to_file("res://scenes/achievements.tscn")
				next_step()
		5:
			if in_scene("Achievements", 0.6):
				expect((current_scene as AchievementsScreen).guide_key() == "", "not again")
				finish()
