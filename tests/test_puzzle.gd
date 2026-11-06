extends "res://tests/framework/test_case.gd"
## 6a 블럭 모으기 퍼즐 엔진 (기획서 8.8장): 풀이기, 수 판정, 힌트, 되돌리기, 별점, 정답 다시 보기, 문제 생성, 기록.
## 연습 판 = 7×7 (창 5×5 + 둘레 한 칸), 창은 (1,1)부터.

const TEST_SAVE: String = "user://test_puzzle_save.cfg"
const ORIGIN: Vector2i = Vector2i(1, 1)
const TARGET: int = 2


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _book() -> PuzzleBook:
	return load("res://resources/puzzles.tres") as PuzzleBook


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _puzzle(id: String, seed_value: int = 1) -> BlockPuzzle:
	return BlockPuzzle.new(Board.new(7), _book().find_board(id), TARGET, ORIGIN, _book(), 4, _rng(seed_value))


## 판에서 지금 최소 수 길을 그대로 두어 푼다.
func _follow_solution(puzzle: BlockPuzzle) -> BlockPuzzle.StepResult:
	var last: BlockPuzzle.StepResult = null
	for dir: Vector2i in puzzle.solution.path.duplicate():
		last = puzzle.step(dir)
	return last


# --- 데이터 · 풀이기 --------------------------------------------------------------

func test_book_has_the_html_tutorial_puzzles() -> void:
	var book: PuzzleBook = _book()
	assert_true(book.validate().is_empty(), "%s" % [book.validate()])
	var ids: PackedStringArray = PackedStringArray()
	for level: PuzzleLevel in book.levels:
		for board: PuzzleDef in level.boards:
			ids.append(board.id)
	assert_eq(ids, PackedStringArray(["0a", "0b", "0c", "1a", "1b", "1c", "2a", "l1", "n1", "i1", "n2", "3c", "1x", "3b", "4a", "2c", "4b"]))
	var menu_ids: PackedStringArray = PackedStringArray()
	for board: PuzzleDef in book.menu_boards():
		menu_ids.append(board.id)
	assert_eq(menu_ids, ids.slice(6), "Lv.2~4 are the menu puzzles, in order (11/06)")
	assert_eq(book.difficulties.size(), 4)


func test_every_tutorial_board_is_solvable() -> void:
	for level: PuzzleLevel in _book().levels:
		for board: PuzzleDef in level.boards:
			var puzzle: BlockPuzzle = _puzzle(board.id)
			assert_true(puzzle.min_moves > 0 and puzzle.min_moves <= 14, "%s min %d" % [board.id, puzzle.min_moves])
			var result: BlockPuzzle.StepResult = _follow_solution(puzzle)
			assert_true(result != null and result.solved, "%s solved by its solution" % board.id)
			assert_eq(puzzle.board.find_match(puzzle.board.player_pos), TARGET, "%s target color matched" % board.id)


func test_solver_minimum_for_the_first_board() -> void:
	# 0a: ㅗ 아래 두 칸 밑에 나 → 위로 두 번 (가운데 블록이 밀려 아래 칸을 채운다)
	var puzzle: BlockPuzzle = _puzzle("0a")
	assert_eq(puzzle.min_moves, 2)
	assert_eq(puzzle.solution.path, [Vector2i.UP, Vector2i.UP] as Array[Vector2i])
	assert_eq(puzzle.solution.center, Vector2i(3, 3))


func test_solver_rejects_edge_centers() -> void:
	var solution: PuzzleSolver.Solution = PuzzleSolver.solve(Rect2i(0, 0, 5, 5), 5, Vector2i(0, 0), [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 1)], 6, 10000)
	assert_true(solution != null and solution.center.x >= 1 and solution.center.y >= 1 and solution.center.x <= 3 and solution.center.y <= 3, "center inside")


# --- 판정 · 힌트 · 별 -------------------------------------------------------------

func test_perfect_solve_gives_three_stars() -> void:
	var puzzle: BlockPuzzle = _puzzle("0a")
	puzzle.step(Vector2i.UP)
	var last: BlockPuzzle.StepResult = puzzle.step(Vector2i.UP)
	assert_true(last.solved and puzzle.finished)
	assert_eq(puzzle.judgments, [BlockPuzzle.Judgment.GOOD, BlockPuzzle.Judgment.GOOD] as Array[BlockPuzzle.Judgment])
	assert_eq(puzzle.stars(), 3)
	assert_false(puzzle.step(Vector2i.DOWN).accepted, "no moves after solving")


func test_wasted_moves_raise_the_hint() -> void:
	var puzzle: BlockPuzzle = _puzzle("0a")
	for _i: int in 3:
		puzzle.step(Vector2i.LEFT)  # 멀어지기만 한다 (최소 수 +1씩)
	assert_eq(puzzle.judgments, [BlockPuzzle.Judgment.WASTE, BlockPuzzle.Judgment.WASTE, BlockPuzzle.Judgment.WASTE] as Array[BlockPuzzle.Judgment])
	assert_eq(puzzle.hint, BlockPuzzle.Hint.PULL, "3 wasted moves → hint")
	assert_true(puzzle.tip_emphasized())


func test_idle_hints_up_to_the_arrow() -> void:
	var puzzle: BlockPuzzle = _puzzle("1a")
	assert_true(puzzle.pull_hint().is_empty() and puzzle.arrow_hint() == Vector2i.ZERO, "no hint at first")
	puzzle.advance(5.9)
	assert_eq(puzzle.hint, BlockPuzzle.Hint.GOAL)
	puzzle.advance(0.2)
	assert_eq(puzzle.hint, BlockPuzzle.Hint.PULL, "6 s idle")
	var pull: Array[Vector2i] = puzzle.pull_hint()
	assert_eq(pull.size(), 2, "stand cell + block to pull")
	assert_true(puzzle.target_positions().has(pull[1]), "pull a target block")
	puzzle.advance(6.0)
	assert_eq(puzzle.arrow_hint(), puzzle.solution.path[0], "arrow = first move")
	_follow_solution(puzzle)
	assert_eq(puzzle.stars(), 3, "minimum moves → three stars even with hints (HTML 11/04)")


func test_hidden_goal_shows_after_the_first_hint() -> void:
	var puzzle: BlockPuzzle = _puzzle("4a")
	puzzle.hide_goal = true
	assert_false(puzzle.goal_visible())
	puzzle.raise_hint()
	assert_true(puzzle.goal_visible())


func test_quick_puzzle_has_no_hints() -> void:
	var puzzle: BlockPuzzle = _puzzle("1a")
	puzzle.quick = true
	puzzle.advance(30.0)
	assert_eq(puzzle.hint, BlockPuzzle.Hint.GOAL)


func test_undo_restores_board_and_targets() -> void:
	var puzzle: BlockPuzzle = _puzzle("1a")
	var start_player: Vector2i = puzzle.board.player_pos
	var start_targets: Array[Vector2i] = puzzle.target_positions()
	puzzle.step(Vector2i.UP)
	puzzle.step(Vector2i.LEFT)
	puzzle.undo()
	puzzle.undo()
	assert_eq(puzzle.board.player_pos, start_player)
	assert_eq(puzzle.target_positions(), start_targets)
	assert_eq([puzzle.moves.size(), puzzle.undos, puzzle.distance], [0, 2, puzzle.min_moves])
	_follow_solution(puzzle)
	assert_eq(puzzle.stars(), 3, "minimum moves → three stars even after undo (HTML 11/04)")


func test_reset_and_restart() -> void:
	var puzzle: BlockPuzzle = _puzzle("2a")
	puzzle.step(Vector2i.LEFT)
	puzzle.raise_hint()
	puzzle.reset()
	assert_eq([puzzle.moves.size(), puzzle.distance, puzzle.hint], [0, puzzle.min_moves, BlockPuzzle.Hint.PULL], "reset keeps the hint")
	_follow_solution(puzzle)
	puzzle.restart()
	assert_eq([puzzle.finished, puzzle.hint, puzzle.max_hint, puzzle.moves.size()], [false, BlockPuzzle.Hint.GOAL, BlockPuzzle.Hint.GOAL, 0])


## 한 수는 반대 방향 한 수로 되돌릴 수 있으므로 남은 최소 수는 많아야 1 는다. "모양이 깨졌어요"(+3 이상)는
## 풀이기가 한도 안에서 못 풀 때(99)만 나온다 — HTML과 같다.
func test_one_move_raises_the_distance_by_at_most_one() -> void:
	for level: PuzzleLevel in _book().levels:
		for board: PuzzleDef in level.boards:
			for dir: Vector2i in Board.DIRECTIONS:
				var puzzle: BlockPuzzle = _puzzle(board.id)
				var before: int = puzzle.distance
				var result: BlockPuzzle.StepResult = puzzle.step(dir)
				if result.accepted and not result.solved:
					assert_true(puzzle.distance <= before + 1, "%s %s: %d → %d" % [board.id, dir, before, puzzle.distance])
					assert_ne(result.judgment, BlockPuzzle.Judgment.BREAK)


func test_accidental_other_color_match_is_recolored() -> void:
	var puzzle: BlockPuzzle = _puzzle("0a")
	var board: Board = puzzle.board
	var p: Vector2i = board.player_pos  # (3,5)
	var color: int = 0
	for pos: Vector2i in [p + Vector2i(-1, 0), p + Vector2i(-2, 0), p + Vector2i(-1, -1), p + Vector2i(-1, 1)]:
		board.set_color_block(pos, color)
	var result: BlockPuzzle.StepResult = puzzle.step(Vector2i.LEFT)
	assert_eq(result.recolored.size(), 4)
	for pos: Vector2i in result.recolored:
		assert_true(board.get_color(pos) != color and board.get_color(pos) != TARGET, "recolored away from both colors")
	assert_false(puzzle.finished)


func test_replay_follows_good_moves_then_the_best_path() -> void:
	var puzzle: BlockPuzzle = _puzzle("2a")
	var first: Vector2i = puzzle.solution.path[0]
	puzzle.step(first)  # 좋은 수
	var wasted: Vector2i = Vector2i.ZERO
	for dir: Vector2i in Board.DIRECTIONS:  # 헛수 하나를 찾아 둔다
		var probe: BlockPuzzle = _puzzle("2a")
		probe.step(first)
		if probe.step(dir).judgment != BlockPuzzle.Judgment.GOOD:
			wasted = dir
			break
	puzzle.step(wasted)
	_follow_solution(puzzle)
	var plan: BlockPuzzle.Replay = puzzle.replay_plan()
	assert_eq(plan.diverge, 1, "second move went wrong")
	assert_eq(plan.my_move, wasted)
	assert_eq(plan.path[0], first, "my good move kept")
	assert_eq(puzzle.board.player_pos, ORIGIN + _book().find_board("2a").player_cell(), "board back at the start")
	for dir: Vector2i in plan.path:
		puzzle.replay_move(dir)
	assert_eq(puzzle.board.find_match(puzzle.board.player_pos), TARGET, "replay path solves")


# --- 문제 생성 · 기록 -------------------------------------------------------------

## 문제를 끝내 못 만들면 대신 쓰는 튜토리얼 판도 그 난이도 구간 안이다 (쉬움 생성 성공률이 낮아 가끔 쓰인다).
func test_fallback_board_is_in_the_band() -> void:
	for difficulty: PuzzleDifficulty in _book().difficulties:
		var def: PuzzleDef = PuzzleGenerator.fallback(difficulty, _book())
		assert_true(def != null, "%s fallback" % difficulty.id)
		var puzzle: BlockPuzzle = BlockPuzzle.new(Board.new(7), def, TARGET, ORIGIN, _book(), 4, _rng())
		assert_eq(puzzle.min_moves, PuzzleGenerator.min_moves_of(def, _book()), "%s: same minimum as the play board" % difficulty.id)
		assert_true(puzzle.min_moves >= difficulty.min_moves and puzzle.min_moves <= difficulty.max_moves,
			"%s fallback %s min %d in %d~%d" % [difficulty.id, def.id, puzzle.min_moves, difficulty.min_moves, difficulty.max_moves])


func test_generator_makes_problems_in_the_band() -> void:
	var rng: RandomNumberGenerator = _rng(5)
	for id: StringName in [&"easy", &"normal", &"hollow"]:
		var difficulty: PuzzleDifficulty = _book().find_difficulty(id)
		var def: PuzzleDef = null
		for _i: int in _book().generate_tries:
			def = PuzzleGenerator.try_once(difficulty, _book(), rng)
			if def != null:
				break
		assert_true(def != null, "%s problem made" % id)
		if def == null:
			continue
		var puzzle: BlockPuzzle = BlockPuzzle.new(Board.new(7), def, TARGET, ORIGIN, _book(), 4, _rng())
		assert_true(puzzle.min_moves >= difficulty.min_moves and puzzle.min_moves <= difficulty.max_moves,
			"%s min %d in %d~%d" % [id, puzzle.min_moves, difficulty.min_moves, difficulty.max_moves])


func test_hollow_problem_leaves_the_center_another_color() -> void:
	var difficulty: PuzzleDifficulty = _book().find_difficulty(&"hollow")
	var rng: RandomNumberGenerator = _rng(9)
	for _i: int in 200:
		var def: PuzzleDef = PuzzleGenerator.try_once(difficulty, _book(), rng)
		if def == null:
			continue
		var targets: Array[Vector2i] = def.target_cells()
		var has_hollow: bool = false
		for x: int in range(1, 4):
			for y: int in range(1, 4):
				var c: Vector2i = Vector2i(x, y)
				var around: int = 0
				for dir: Vector2i in Board.DIRECTIONS:
					around += 1 if targets.has(c + dir) else 0
				has_hollow = has_hollow or (around >= 3 and not targets.has(c))
		assert_true(has_hollow, "a hollow shape around another color (%s)" % [def.rows])
		return
	fail_test("no hollow problem made")


func fail_test(message: String) -> void:
	assert_true(false, message)


func test_store_keeps_best_stars_and_practice_stats() -> void:
	var store: PuzzleStore = PuzzleStore.new(TEST_SAVE)
	store.record_board("1a", 2)
	store.record_board("1a", 1)
	store.record_practice(3)
	store.record_practice(1)
	store.set_difficulty(&"hard")
	var again: PuzzleStore = PuzzleStore.new(TEST_SAVE)
	assert_eq([again.stars_of("1a"), again.stars_of("2a"), again.solved, again.star_total, again.perfect, again.difficulty],
		[2, 0, 2, 4, 1, &"hard"])


# --- 메뉴 > 퍼즐: 번호 · 다음 판 · 첫 클리어 보상 (11/06, E28) ------------------------

func test_menu_numbers_boards_without_levels() -> void:
	var menu: PuzzleMenu = PuzzleMenu.new(_book(), PuzzleStore.new(TEST_SAVE))
	assert_eq(menu.boards().size(), 11, "Lv.2~4: 3 + 3 + 5")
	assert_eq([menu.number_of("2a"), menu.number_of("i1"), menu.number_of("4b"), menu.number_of("1a"), menu.number_of("nope")], [1, 4, 11, 0, 0],
		"numbered 1… across levels; tutorial boards are not in the menu")
	assert_eq(menu.next_after("n1").id, "i1", "next crosses into the next level")
	assert_true(menu.next_after("4b") == null and menu.next_after("1a") == null, "no next after the last (or outside the menu)")


func test_first_clear_reward_once() -> void:
	var store: PuzzleStore = PuzzleStore.new(TEST_SAVE)
	var menu: PuzzleMenu = PuzzleMenu.new(_book(), store)
	assert_eq([menu.reward_of("1a"), menu.reward_of("2a"), menu.reward_of("3b"), menu.reward_of("4b")], [0, 20, 20, 20], "● 20 per menu board")
	var progress: ProgressStore = ProgressStore.new(TEST_SAVE)
	assert_eq(menu.claim("2a", progress), 0, "not solved yet")
	store.record_board("2a", 1)
	assert_eq(menu.claim("2a", progress), 20)
	assert_eq(menu.claim("2a", progress), 0, "only once")
	assert_eq(menu.pending_reward("2a"), 0)
	var saved: PuzzleStore = PuzzleStore.new(TEST_SAVE)
	assert_eq([ProgressStore.new(TEST_SAVE).coins, saved.is_rewarded("2a"), saved.stars_of("2a")], [20, true, 1], "saved")
