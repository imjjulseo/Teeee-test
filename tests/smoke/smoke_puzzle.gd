extends "res://tests/smoke/smoke_base.gd"
## 블럭 모으기 퍼즐 (기획서 8.8장, 메뉴 > 퍼즐 — 팀 결정 11/06). 모드:
## - menu  : 메인 메뉴 → 퍼즐 실제 클릭 → 목록(11판, 1~11번, 모두 열림 "● 20") → 1번 실제 클릭 → "퍼즐 1" →
##           실제 방향키로 최소 수 풀이 → ★★★ · "첫 클리어 보상 ● 20" → "다음 퍼즐" → "퍼즐 2" → 나가기 →
##           목록: 1번 별, 코인 +20 → 1번 다시 풀어도 보상 없음
## - board : 마지막 판(11번) → 가만히 6초(당길 블록 힌트) → 힌트 버튼(화살표) → 최소 수 풀이 → ★★★(힌트와 상관없이, HTML 11/04)·정답 보기 자동 없음 → "목록으로" → 목록 "★★★"

const KEYS: Dictionary[Vector2i, Key] = {Vector2i.UP: KEY_UP, Vector2i.DOWN: KEY_DOWN, Vector2i.LEFT: KEY_LEFT, Vector2i.RIGHT: KEY_RIGHT}
const LAST_BOARD: String = "4b"

var _path: Array[Vector2i] = []
var _coins_before: int = 0


func _setup() -> void:
	_coins_before = ProgressStore.new().coins
	match mode:
		"menu":
			change_scene_to_file("res://scenes/main_menu.tscn")
		"board":
			PuzzleRequest.board(LAST_BOARD)
			change_scene_to_file("res://scenes/puzzle_play.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


func _tick() -> void:
	match mode:
		"menu":
			_tick_menu()
		"board":
			_tick_board()


func _play() -> PuzzlePlayScreen:
	return current_scene as PuzzlePlayScreen


func _list() -> PuzzleMenuScreen:
	return current_scene as PuzzleMenuScreen


func _marks_of(kind: BoardMark.Kind) -> int:
	var count: int = 0
	for mark: BoardMark in (node("BoardView/Marks") as BoardMarksView).marks():
		count += 1 if mark.kind == kind else 0
	return count


## 남은 풀이를 한 프레임에 한 수씩 실제 키로 둔다. 다 두면 true.
func _press_next() -> bool:
	if _path.is_empty():
		return true
	press_key(KEYS[_path.pop_front()])
	return false


func _result_detail() -> String:
	return (node("UI/ResultPanel").get_node("%ResultDetail") as Label).text


func _tick_menu() -> void:
	match step:
		0:
			if in_scene("MainMenu", 0.3):
				expect((current_scene as MainMenu).is_entry_enabled(MenuUnlocks.Entry.PUZZLES), "puzzle button open")
				click_control(node("%PuzzlesButton"))
				next_step()
		1:
			if in_scene("PuzzleMenu", 0.4):
				var numbers: PackedStringArray = PackedStringArray()
				var texts: PackedStringArray = PackedStringArray()
				for button: PuzzleBoardButton in _list().buttons():
					numbers.append(button.number_text())
					texts.append(button.stars_text())
					expect(not button.disabled, "%s open" % button.board_id)
				expect(numbers == PackedStringArray(["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]), "numbered 1-11 (%s)" % ", ".join(numbers))
				expect(texts.count("● 20") == 11, "first-clear coins on every board (%s)" % ", ".join(texts))
				expect(_list().buttons()[0].board_id == "2a", "starts at Lv.2")
				shot("menu_list")
				click_control(_list().buttons()[0])
				next_step()
		2, 7:
			if in_scene("PuzzlePlay", 0.3) and _play().puzzle() != null and _play().runner.is_playing():
				expect((node("%PuzzleName") as Label).text == "퍼즐 1", "label (%s)" % (node("%PuzzleName") as Label).text)
				if step == 2:
					shot("menu_play")
				_path = _play().puzzle().solution.path.duplicate()
				next_step()
		3, 8:
			if _press_next() and step_time > 0.3:
				next_step()
		4:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT and step_time > 0.2:
				expect((node("UI/ResultPanel").get_node("%ResultStars") as Label).text == "★★★", "three stars")
				expect(_result_detail().ends_with("첫 클리어 보상 ● 20"), "reward on the result (%s)" % _result_detail())
				expect(ProgressStore.new().coins == _coins_before + 20 and PuzzleStore.new().is_rewarded("2a"), "coins and reward saved")
				expect((node("UI/ResultPanel").get_node("%NextButton") as Button).text == "다음 퍼즐", "next puzzle button")
				shot("menu_result")
				click_control(node("UI/ResultPanel").get_node("%NextButton"))
				next_step()
			elif step_time > 5.0:
				fail("no result")
				finish()
		5:
			if _play().puzzle() != null and _play().runner.is_playing() and step_time > 0.3:
				expect((node("%PuzzleName") as Label).text == "퍼즐 2" and _play().puzzle().def.id == "l1", "continues to puzzle 2")
				click_control(node("UI/SafeArea/Content/Bottom/Row2/ExitButton"))
				next_step()
		6:
			if in_scene("PuzzleMenu", 0.3):
				expect(_list().buttons()[0].stars_text() == "★★★", "list shows the stars (%s)" % _list().buttons()[0].stars_text())
				expect(_list().buttons()[1].stars_text() == "● 20", "puzzle 2 still has its reward")
				PuzzleRequest.board("2a")
				change_scene_to_file("res://scenes/puzzle_play.tscn")
				next_step()
		9:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT and step_time > 0.2:
				expect(not _result_detail().contains("첫 클리어 보상"), "no second reward")
				expect(ProgressStore.new().coins == _coins_before + 20, "still +20 coins")
				finish()
			elif step_time > 5.0:
				fail("no second result")
				finish()


func _tick_board() -> void:
	match step:
		0:
			if in_scene("PuzzlePlay", 0.3):
				expect((node("%PuzzleName") as Label).text == "퍼즐 11", "board label (%s)" % (node("%PuzzleName") as Label).text)
				expect(_marks_of(BoardMark.Kind.PULL) == 0, "no hint yet")
				next_step()
		1:
			if step_time > 6.3:
				expect(_marks_of(BoardMark.Kind.PULL) == 1 and _marks_of(BoardMark.Kind.STAND) == 1, "6 s idle → pull hint")
				shot("board_hint")
				click_control(node("%HintButton"))
				next_step()
		2:
			if step_time > 0.2:
				expect(_marks_of(BoardMark.Kind.ARROW) == 1, "hint button → arrow")
				expect((node("%HintButton") as Button).disabled, "no more hints")
				_path = _play().puzzle().solution.path.duplicate()
				next_step()
		3:
			if _press_next() and step_time > 0.3:
				next_step()
		4:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT:
				expect((node("UI/ResultPanel").get_node("%ResultStars") as Label).text == "★★★", "minimum moves → three stars even with hints (HTML 11/04)")
				expect((node("UI/ResultPanel").get_node("%ResultHead") as Label).text == "최소 수로 성공!", "head")
				expect(PuzzleStore.new().stars_of(LAST_BOARD) == 3, "board stars saved")
				expect((node("UI/ResultPanel").get_node("%NextButton") as Button).text == "목록으로", "last board → back to the list")
				shot("board_result")
				click_control(node("UI/ResultPanel").get_node("%NextButton"))
				step = 6
				step_time = 0.0
			elif _play().runner.phase == PuzzleRunner.Phase.REPLAY:
				fail("no automatic replay after a hint (HTML: !P.maxHint)")
				finish()
			elif step_time > 4.0:
				fail("no result")
				finish()
		6:
			if in_scene("PuzzleMenu", 0.3):
				expect(_list().buttons()[10].stars_text() == "★★★", "list shows the stars (%s)" % _list().buttons()[10].stars_text())
				finish()
