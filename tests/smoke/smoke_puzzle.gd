extends "res://tests/smoke/smoke_base.gd"
## 6a 블럭 모으기 (기획서 8.8장). 모드:
## - practice : 설정 → 블럭 모으기 연습 실제 클릭 → 목록(난이도 4, 튜토리얼 판 12개 "안 함") → 연습 시작 → 문제 생성 →
##              실제 방향키로 최소 수 풀이 → ★★★ 결과 → 다음 문제(2번째) → 나가기 → 기록(푼 문제 1 · 별 3 · 최소 수 1)
## - reward   : Lv.0·1을 푼 저장 → 목록에서 2a만 열림("● 50") → 2a 실제 클릭 → 최소 수 풀이 → 결과에 "첫 클리어 보상 ● 50" →
##              코인 +50 → 목록으로: 2a 별, 2b 열림 → 2a 다시 풀어도 보상 없음
## - board    : 튜토리얼 판 1a → 가만히 6초(당길 블록 힌트) → 힌트 버튼(화살표) → 풀이 → ★ → 정답 보기 자동 → 결과 → 목록 "★☆☆"

const KEYS: Dictionary[Vector2i, Key] = {Vector2i.UP: KEY_UP, Vector2i.DOWN: KEY_DOWN, Vector2i.LEFT: KEY_LEFT, Vector2i.RIGHT: KEY_RIGHT}

var _path: Array[Vector2i] = []


func _setup() -> void:
	match mode:
		"practice":
			change_scene_to_file("res://scenes/options.tscn")
		"reward":
			var store: PuzzleStore = PuzzleStore.new()
			for id: String in ["0a", "0b", "1a"]:
				store.record_board(id, 3)
			change_scene_to_file("res://scenes/puzzle_practice.tscn")
		"board":
			for id: String in ["0a", "0b"]:  # 1a가 열려 있게 (판은 순서대로 열린다)
				PuzzleStore.new().record_board(id, 3)
			PuzzleRequest.board("1a")
			change_scene_to_file("res://scenes/puzzle_play.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


func _tick() -> void:
	match mode:
		"practice":
			_tick_practice()
		"board":
			_tick_board()
		"reward":
			_tick_reward()


func _play() -> PuzzlePlayScreen:
	return current_scene as PuzzlePlayScreen


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


func _tick_practice() -> void:
	match step:
		0:
			if in_scene("OptionsMenu"):
				click_control(node("%PuzzleButton"))
				next_step()
		1:
			if in_scene("PuzzlePractice", 0.4):
				var screen: PuzzlePracticeScreen = current_scene as PuzzlePracticeScreen
				expect(node("%Difficulties").get_child_count() == 4, "4 difficulties")
				var texts: PackedStringArray = PackedStringArray()
				for row: PuzzleLevelRow in screen.level_rows():
					for button: PuzzleBoardButton in row.buttons():
						texts.append(button.stars_text())
						if button.board_id != "0a":
							expect(button.disabled, "%s locked" % button.board_id)
				expect(texts.size() == 12, "12 boards (%d)" % texts.size())
				expect(texts[0] == "안 함" and texts.count("잠김") == 11, "only the first board is open (%s)" % ", ".join(texts))
				expect((node("%StatsLabel") as Label).text == "푼 문제 0 · 모은 별 0 · 최소 수 성공 0", "empty stats")
				shot("practice_list")
				click_control(node("SafeArea/Content/Layout/StartButton"))
				next_step()
		2:
			if in_scene("PuzzlePlay", 0.3) and _play().puzzle() != null and _play().runner.is_playing():
				expect(_play().problem_number == 1, "first problem")
				var puzzle: BlockPuzzle = _play().puzzle()
				expect(puzzle.min_moves >= 3 and puzzle.min_moves <= 5, "easy band (%d)" % puzzle.min_moves)
				expect(_marks_of(BoardMark.Kind.TARGET) == 4 and _marks_of(BoardMark.Kind.GOAL_SLOT) + _marks_of(BoardMark.Kind.GOAL_SLOT_FILLED) == 4, "targets and goal shape shown (easy)")
				shot("practice_play")
				_path = puzzle.solution.path.duplicate()
				next_step()
			elif step_time > 8.0:
				fail("problem not generated")
				finish()
		3:
			if _press_next() and step_time > 0.3:
				next_step()
		4:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT:
				expect((node("UI/ResultPanel").get_node("%ResultStars") as Label).text == "★★★", "three stars")
				expect((node("UI/ResultPanel").get_node("%ResultHead") as Label).text == "최소 수로 성공!", "head")
				expect(PuzzleStore.new().solved == 1, "practice saved")
				shot("practice_result")
				click_control(node("UI/ResultPanel").get_node("%NextButton"))
				next_step()
			elif step_time > 4.0:
				fail("no result")
				finish()
		5:
			if _play().puzzle() != null and _play().runner.is_playing() and step_time > 0.3:
				expect(_play().problem_number == 2, "next problem")
				click_control(node("UI/SafeArea/Content/Bottom/Row2/ExitButton"))
				next_step()
		6:
			if in_scene("PuzzlePractice", 0.3):
				expect((node("%StatsLabel") as Label).text == "푼 문제 1 · 모은 별 3 · 최소 수 성공 1", "stats (%s)" % (node("%StatsLabel") as Label).text)
				finish()


func _tick_board() -> void:
	match step:
		0:
			if in_scene("PuzzlePlay", 0.3):
				expect((node("%PuzzleName") as Label).text == "블럭 모으기 Lv.1 · 한 칸 당기기", "board label")
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
			if _play().runner.phase == PuzzleRunner.Phase.REPLAY:
				expect(true, "one star → replay first")
				shot("board_replay")
				next_step()
			elif step_time > 3.0:
				fail("no replay")
				finish()
		5:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT:
				expect((node("UI/ResultPanel").get_node("%ResultStars") as Label).text == "★☆☆", "one star")
				expect((node("UI/ResultPanel").get_node("%ResultHead") as Label).text == "정답 길을 봤어요", "replayed head")
				expect((node("UI/ResultPanel").get_node("%ReplayButton") as Button).text == "정답 다시 보기", "replay again button")
				expect(PuzzleStore.new().stars_of("1a") == 1, "board stars saved")
				click_control(node("UI/ResultPanel").get_node("%NextButton"))
				next_step()
			elif step_time > 8.0:
				fail("replay did not finish")
				finish()
		6:
			if in_scene("PuzzlePractice", 0.3):
				var row: PuzzleLevelRow = (current_scene as PuzzlePracticeScreen).level_rows()[1]
				expect(row.buttons()[0].stars_text() == "★☆☆", "list shows the stars")
				finish()


func _button(id: String) -> PuzzleBoardButton:
	for row: PuzzleLevelRow in (current_scene as PuzzlePracticeScreen).level_rows():
		for button: PuzzleBoardButton in row.buttons():
			if button.board_id == id:
				return button
	return null


func _tick_reward() -> void:
	match step:
		0, 5:
			if in_scene("PuzzlePractice", 0.4):
				var first: bool = step == 0
				expect(_button("2a").stars_text() == ("● 50" if first else "★★★"), "2a (%s)" % _button("2a").stars_text())
				expect(_button("2b").disabled == first, "2b opens only after 2a (%s)" % _button("2b").stars_text())
				if first:
					expect(_button("3a").disabled and _button("2b").stars_text() == "잠김", "later boards locked")
					shot("reward_list")
					(node("%Scroll") as ScrollContainer).ensure_control_visible(_button("2a"))  # 목록 아래쪽
				else:
					expect(_button("2b").stars_text() == "● 50", "next reward shown")
					expect(ProgressStore.new().coins == 50, "coins kept after the list (%d)" % ProgressStore.new().coins)
					shot("reward_list_after")
					PuzzleRequest.board("2a")
					change_scene_to_file("res://scenes/puzzle_play.tscn")
				next_step()
		1:
			if step_time > 0.3:
				click_control(_button("2a"))
				next_step()
		2, 6:
			if in_scene("PuzzlePlay", 0.3) and _play().puzzle() != null and _play().runner.is_playing():
				_path = _play().puzzle().solution.path.duplicate()
				next_step()
		3, 7:
			if _press_next() and step_time > 0.3:
				next_step()
		4, 8:
			if _play().runner.phase == PuzzleRunner.Phase.RESULT and step_time > 0.2:
				var detail: String = (node("UI/ResultPanel").get_node("%ResultDetail") as Label).text
				if step == 4:
					expect(detail.ends_with("첫 클리어 보상 ● 50"), "reward on the result (%s)" % detail)
					expect(ProgressStore.new().coins == 50 and PuzzleStore.new().is_rewarded("2a"), "coins and reward saved")
					shot("reward_result")
					click_control(node("UI/ResultPanel").get_node("%NextButton"))
				else:
					expect(not detail.contains("첫 클리어 보상"), "no second reward")
					expect(ProgressStore.new().coins == 50, "still 50 coins")
					finish()
				next_step()
			elif step_time > 5.0:
				fail("no result at step %d" % step)
				finish()
