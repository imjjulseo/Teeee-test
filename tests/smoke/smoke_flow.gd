extends "res://tests/smoke/smoke_base.gd"
## 게임 흐름. 모드:
## - result : 메뉴 → START → 첫 이동 전 시간 정지 → 족보 완성 점수 → 포커스 이탈 자동 일시정지(보드 숨김, 시간 정지) → 5초 경고
##            → RESULT(최고 기록, 최고점 저장, 주운 코인) → 다시 하기(화면·HUD 초기화) → 두 번째 결과(최고점 유지) → 메뉴
## - abandon: 일시정지 → 다시 시작 실제 클릭(새 판, 결과 없음) → 일시정지 → 메뉴 실제 클릭 → 메뉴로, 최고 점수 미반영

var _points: int = 0
var _old_session: GameSession


func _setup() -> void:
	config.game_duration = 11.0  # 메모리에서만
	CharacterStore.new().select(&"basic")
	SaveData.write_value("", "score", "best", 100)
	change_scene_to_file("res://scenes/main_menu.tscn" if mode == "result" else "res://scenes/main.tscn")


func _tick() -> void:
	match mode:
		"result":
			_tick_result()
		"abandon":
			_tick_abandon()
		_:
			fail("unknown mode " + mode)
			finish()


func _tick_result() -> void:
	match step:
		0:
			if in_scene("MainMenu"):
				(node("%BottomNav") as BottomNav).start_swiped.emit()
				next_step()
		1:
			if playing(1.0):
				expect(flow().state == S.WAITING and session().remaining_time() == 11.0, "clock waits for the first move")
<<<<<<< HEAD
				expect((node("Hud/%MessageLabel") as Label).text.is_empty(), "no message before the first move")
=======
				expect((node("Hud/%MessageLabel") as Label).text == Hud.WAITING_CUE, "waiting message shown")
>>>>>>> Choi
				prepare_match_above(1)
				_points = prime_recipe(0, 1)
				flow().request_move(Vector2i.UP)
				next_step()
		2:
			if step_time > 0.4:
				expect(flow().state == S.PLAYING and (node("Hud/%MessageLabel") as Label).text == "", "first move starts the game")
				expect(session().score == _points, "recipe completed → %d" % _points)
				controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
				expect(flow().state == S.PAUSED, "focus out → auto pause")
				expect(not (node("BoardView") as Node2D).visible, "board hidden while paused")
				var remaining: float = session().remaining_time()
				flow().advance(5.0)
				expect(session().remaining_time() == remaining, "timer frozen while paused")
				flow().resume()
				next_step()
		3:
			if session().remaining_time() < 4.5:
				expect(node("Hud").call("is_time_warning"), "<5s timer warning")
				expect((node("Hud") as Hud).shown_score() == _points, "HUD score counted up to %d" % _points)
				expect((node("Hud/%ScoreLabel") as Label).text == str(_points), "score label")
				shot("warning")
				next_step()
		4:
			if flow().state == S.RESULT and ((node("ResultPanel/%FinalScoreLabel") as Label).text == str(_points) or step_time > 16.0):  # 점수가 차오른 뒤
				expect((node("ResultPanel/%FinalScoreLabel") as Label).text == str(_points), "final score %d" % _points)
				expect((node("ResultPanel/%CharacterBestLabel") as Label).text == "기본 최고점\n%d" % _points, "character best (%s)" % (node("ResultPanel/%CharacterBestLabel") as Label).text)
				expect(BestScoreStore.new().best_of(&"basic") == _points, "character best saved")
				expect((node("ResultPanel/%BestScoreLabel") as Label).text == "전체 최고점\n%d" % _points, "best 100 → %d" % _points)
				expect(not (node("ResultPanel/%CoinLabel") as Label).text.contains("+"), "held coins, not the earned amount (%s)" % (node("ResultPanel/%CoinLabel") as Label).text)
				var run_coins: int = RunRewards.compute(_points, session().collected_coins(), 1, 0, progression).coins  # 레벨 보상은 레벨 화면에서
				expect(ProgressStore.new().coins == run_coins, "coins saved (%d, expected %d)" % [ProgressStore.new().coins, run_coins])
				expect((node("ResultPanel/%NewBestLabel") as Label).visible, "NEW BEST shown")
				expect(BestScoreStore.new().best == _points, "best saved")
				var rows: Array[PackedStringArray] = smoke_log_rows()
				expect(rows.size() == 1, "one playtest log row (%d)" % rows.size())
				if rows.size() == 1:
					expect(rows[0][2] == "basic" and rows[0][3] == "result" and rows[0][4] == str(_points),
						"log row: basic / result / %d (%s)" % [_points, ",".join(rows[0])])
					expect(int(rows[0][8]) >= 1 and int(rows[0][9]) >= 1, "log counts the match and the recipe")
				shot("result")
				(node("ResultPanel/Center/RetryButton") as Button).pressed.emit()
				next_step()
		5:
			if step_time > 0.3:
				expect(flow().state == S.WAITING, "retry → WAITING")
				expect(_views_match_board(), "board view rebuilt")
				expect((node("Hud/%ScoreLabel") as Label).text == "0", "HUD score reset")
				expect((node("Hud/%CoinLabel") as Label).text == "● 0", "HUD coins reset")
				expect((node("Hud/%TimeLabel") as Label).text.begins_with("11.0"), "HUD time reset")
				expect(not node("Hud").call("is_time_warning"), "warning cleared")
				flow().request_move(Vector2i.ZERO)  # 두 번째 판 시작 (판은 그대로)
				next_step()
		6:
			if flow().state == S.RESULT and step_time > 0.2:
				expect((node("ResultPanel/%BestScoreLabel") as Label).text == "전체 최고점\n%d" % _points, "best kept")
				expect(not (node("ResultPanel/%NewBestLabel") as Label).visible, "no NEW BEST")
				(node("ResultPanel/Center/MainMenuButton") as Button).pressed.emit()
				controller = null
				next_step()
		7:
			if in_scene("MainMenu"):
				expect(true, "MAIN MENU → menu scene")
				finish()


func _tick_abandon() -> void:
	match step:
		0:
			if playing():
				auto_resume = false
				session().score = 99999
				(node("Hud/%PauseButton") as Button).pressed.emit()
				next_step()
		1:
			if step_time > 0.2:
				expect(flow().state == S.PAUSED, "paused")
				var restart: Button = node("PauseOverlay/Center/RestartButton")
				expect(restart.is_visible_in_tree(), "Restart on pause screen")
				_old_session = session()
				click_control(restart)
				next_step()
		2:
			if step_time > 0.3:
				expect(flow().state == S.WAITING and session() != _old_session, "restart → a new game, waiting (state %d, new %s)" % [flow().state, session() != _old_session])
				expect(session().score == 0 and BestScoreStore.new().best == 100, "no score recorded")
				(node("Hud/%PauseButton") as Button).pressed.emit()
				next_step()
		3:
			if step_time > 0.2:
				expect(flow().state == S.PAUSED, "can pause before the first move")
				var button: Button = node("PauseOverlay/Center/MainMenuButton")
				expect(button.is_visible_in_tree(), "Menu on pause screen")
				click_control(button)
				controller = null
				next_step()
		4:
			if in_scene("MainMenu"):
				expect(BestScoreStore.new().best == 100, "best score unchanged (%d)" % BestScoreStore.new().best)
				var rows: Array[PackedStringArray] = smoke_log_rows()
				expect(rows.size() == 1 and rows[0][3] == "abandoned", "abandoned game is logged as 'abandoned'")
				finish()


func _views_match_board() -> bool:
	var board: Board = session().board
	var view: BoardView = node("BoardView")
	var views: Dictionary = view.get("_views")
	var theme_data: BoardTheme = view.theme_data
	for pos: Vector2i in views:
		var cell: CellView = views[pos]
		if not cell.position.is_equal_approx(Vector2(pos) * (theme_data.cell_size + theme_data.cell_gap)):
			return false
		if board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK \
				and not (cell.get_node("Fill") as ColorRect).color.is_equal_approx(theme_data.color_for(board.get_color(pos))):
			return false
	return views.size() == board.size * board.size
