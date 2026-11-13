extends "res://tests/framework/test_case.gd"
## 6b 튜토리얼 (기획서 8.8장): 튜토리얼 저장(기존 저장 처리), 튜토리얼 흐름(메뉴 단계), 튜토리얼 데이터, 매치 길 찾기,
## 세션 훅(시계 멈춤·바깥 매치 처리), 족보 카드 바꾸기, 첫 뽑기 고정, 튜토리얼 완료 업적, 메인 메뉴 잠금.

const TEST_SAVE: String = "user://test_tutorial_save.cfg"
const Flow = TutorialStore.Flow
const Stage = TutorialFlow.Stage


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


func before_each() -> void:
	_clean()


func after_each() -> void:
	_clean()


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _plain_board(size: int, player: Vector2i) -> Board:
	var board: Board = Board.new(size)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, (pos.x + 2 * pos.y) % 4)
	board.set_player(player)
	return board


# --- 저장 ------------------------------------------------------------------------

func test_fresh_save_starts_the_tutorial() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	assert_eq([store.done, store.flow, store.seen.size()], [false, Flow.BEFORE, 0])


func test_existing_progress_counts_as_finished() -> void:
	ProgressStore.new(TEST_SAVE).set_level(2)
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	assert_true(store.done and store.flow == Flow.DONE, "save with progress → tutorial done")
	assert_true(store.has_seen(TutorialStore.SEEN_ACHIEVEMENTS) and store.has_seen(TutorialStore.SEEN_REAL_GAME), "all guides seen")
	_clean()
	BestScoreStore.new(TEST_SAVE).submit(300)
	assert_true(TutorialStore.new(TEST_SAVE).done, "a best score also counts")


func test_flow_steps_persist() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	store.complete_rule_tutorial()
	store.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	store.got_first_character(&"clock")
	var again: TutorialStore = TutorialStore.new(TEST_SAVE)
	assert_eq([again.done, again.flow, again.want_character, again.has_seen(TutorialStore.SEEN_LEVEL_SCREEN)], [true, Flow.FIRST_CHARACTER, &"clock", true])
	again.started_with_character()
	assert_eq([TutorialStore.new(TEST_SAVE).flow, TutorialStore.new(TEST_SAVE).want_character], [Flow.DONE, &""])
	again.restart_all()
	assert_false(TutorialStore.new(TEST_SAVE).done, "restart is saved (no progress inference once the section exists)")


# --- 흐름 ------------------------------------------------------------------------

func test_menu_opens_step_by_step() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	var stages: Array[int] = []
	var opened: Array[int] = []
	var glow: Array[int] = []
	var record: Callable = func(games: int) -> void:
		var flow: TutorialFlow = TutorialFlow.new(store, games)
		stages.append(flow.stage())
		opened.append(flow.unlocks().opened)
		glow.append(flow.highlighted_entry())
	record.call(0)  # 튜토리얼 전
	store.complete_rule_tutorial()
	record.call(0)  # 첫 실전 판 전
	record.call(1)  # 첫 실전 판 뒤 → 레벨 버튼
	store.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	record.call(1)  # → 상점 (첫 뽑기)
	store.got_first_character(&"gardener")
	record.call(1)  # → 캐릭터 화면
	store.mark_seen(TutorialStore.SEEN_CHARACTERS)
	record.call(1)  # → 그 캐릭터로 시작
	store.started_with_character()
	record.call(2)  # → 업적
	store.mark_seen(TutorialStore.SEEN_ACHIEVEMENTS)
	record.call(2)  # → 퍼즐 (11/06)
	store.mark_seen(TutorialStore.SEEN_PUZZLES)
	record.call(2)  # → 모두
	assert_eq(stages, [Stage.START, Stage.START, Stage.LEVEL, Stage.SHOP, Stage.CHARACTERS, Stage.PLAY, Stage.ACHIEVEMENTS, Stage.PUZZLES, Stage.ALL] as Array[int])
	assert_eq(opened, [1, 1, 2, 3, 4, 4, 5, 6, 6] as Array[int], "start → level → shop → characters → achievements → puzzles")
	var E = MenuUnlocks.Entry
	assert_eq(glow, [E.START, E.START, E.LEVEL, E.SHOP, E.CHARACTERS, E.START, E.ACHIEVEMENTS, E.PUZZLES, -1] as Array[int])
	assert_true(MenuUnlocks.new(1).is_open(MenuUnlocks.Entry.OPTIONS), "options always open")


func test_gacha_stage_routes_start_to_the_shop() -> void:
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	store.complete_rule_tutorial()
	assert_true(TutorialFlow.new(store, 1).guides_to_menu(), "after the first real game → result guides to the menu")
	assert_false(TutorialFlow.new(store, 0).guides_to_menu())
	assert_false(TutorialFlow.new(store, 1).start_goes_to_shop(), "level screen first")
	store.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	var flow: TutorialFlow = TutorialFlow.new(store, 1)
	assert_true(flow.start_goes_to_shop() and flow.is_first_pull())
	store.got_first_character(&"clock")
	assert_false(TutorialFlow.new(store, 1).is_first_pull(), "only the first pull is fixed")


# --- 데이터 · 도구 --------------------------------------------------------------------

func test_tutorial_script_is_valid() -> void:
	var tutorial: TutorialScript = load("res://resources/tutorial.tres") as TutorialScript
	var book: PuzzleBook = load("res://resources/puzzles.tres") as PuzzleBook
	assert_true(tutorial.validate(book).is_empty(), "%s" % [tutorial.validate(book)])
	var first: PuzzleLevelStep = tutorial.steps[0] as PuzzleLevelStep
	assert_true(first != null and first.level == 0 and first.rule and first.swipe_first and not first.hold_text.is_empty(),
		"starts with the Lv.0 puzzle on the board itself: swipe hint, hold the first match (HTML runRuleTut)")
	assert_eq(tutorial.start_seed, 8907, "HTML TUT_SEED")
	var levels: Array[int] = []
	for step: TutorialStep in tutorial.steps:
		if step is PuzzleLevelStep:
			levels.append((step as PuzzleLevelStep).level)
	assert_eq(levels, [0, 1] as Array[int], "only Lv.0 and Lv.1 — Lv.2~4 are menu puzzles (E28)")
	var last: PuzzleLevelStep = tutorial.steps[tutorial.steps.size() - 1] as PuzzleLevelStep
	assert_true(last != null and last.level == 1 and last.target == PuzzleLevelStep.Target.RECIPE_NEXT,
		"ends with Lv.1 (moving one block) toward the recipe, then the first real game (11/06)")
	assert_eq([PuzzleLevelStep.progress_dots(0, 3), PuzzleLevelStep.progress_dots(2, 3)], ["●○○", "●●●"], "progress bar, no level number")
	var config: GameConfig = tutorial.apply_to(make_config())
	assert_eq([config.color_count, config.refill_total_start, config.refill_total_end], [3, 2.0, 2.0])
	assert_eq(tutorial.first_pull, [&"gardener", &"clock"] as Array[StringName])


func test_match_planner_finds_the_shortest_match() -> void:
	var board: Board = _plain_board(5, Vector2i(2, 3))
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	var plan: MatchPlanner.Plan = MatchPlanner.best(board, 4, 10000)
	assert_true(plan != null)
	assert_eq([plan.path, plan.color, plan.center], [[Vector2i.UP] as Array[Vector2i], 1, Vector2i(2, 2)])
	assert_eq(board.player_pos, Vector2i(2, 3), "board untouched")
	var only_blue: MatchPlanner.Plan = MatchPlanner.best(board, 4, 10000, func(p: MatchPlanner.Plan) -> bool: return p.color == 2)
	assert_true(only_blue == null or only_blue.color == 2, "filter respected")
	assert_true(MatchPlanner.best(_plain_board(5, Vector2i(2, 2)), 1, 1000) == null, "no match in one move on a plain board")


func test_object_particle() -> void:
	assert_eq([TutorialDirector.with_object_particle("노랑"), TutorialDirector.with_object_particle("파리"), TutorialDirector.color_name(2)],
		["노랑을", "파리를", "파랑"])


# --- 세션 · 족보 ----------------------------------------------------------------------

func test_frozen_timer_and_outside_match() -> void:
	var board: Board = _plain_board(5, Vector2i(2, 2))
	for pos: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		board.set_color_block(pos, 1)
	var config: GameConfig = make_config()
	config.board_size = 5
	var session: GameSession = GameSession.new(config, _rng(), board)
	session.frozen_clocks = [TimedSystem.Clock.TIMER] as Array[TimedSystem.Clock]
	session.start()
	var before: float = session.remaining_time()
	session.advance(5.0)
	assert_eq(session.remaining_time(), before, "time does not flow")
	assert_true(session.resolve_player_match(), "match at the player after an outside move")
	assert_eq([session.match_count, session.stats.moves], [1, 0], "a match, not a move")
	assert_true(session.remaining_time() > before, "match time still given")


func test_replace_all_recipes() -> void:
	var session: GameSession = GameSession.new(make_config(), _rng())
	session.recipes.replace_all([PackedInt32Array([1, 2]), PackedInt32Array([1, 3, 0])] as Array[PackedInt32Array], PackedInt32Array([1, 0]))
	assert_eq([session.recipes.slot_count(), session.recipes.recipes[0].progress, session.recipes.recipes[1].length()], [2, 1, 3])
	session.apply_clear_to_recipes(2)
	assert_eq(session.recipes.recipes[0].length(), 2, "completed card comes back with the same length")
	assert_eq(session.score, 100)
	session.recipes.replace_all([] as Array[PackedInt32Array])
	assert_eq(session.recipes.slot_count(), 0, "no cards")


# --- 흐름 보상 ------------------------------------------------------------------------

func test_first_pull_is_fixed_until_both_are_owned() -> void:
	var collection: CharacterCollection = CharacterCollection.new(_roster(), ProgressStore.new(TEST_SAVE), CharacterStore.new(TEST_SAVE),
		(load("res://resources/gacha.tres") as GachaConfig))
	var shop: CharacterShop = CharacterShop.new(collection, _rng(4))
	collection.progress.add_currency(500 * 3, 0)
	var forced: Array[StringName] = [&"gardener", &"clock"]
	var first: CharacterShop.PullResult = shop.pull(forced)
	assert_true(forced.has(first.character.id) and first.is_new, "first pull from the fixed pair")
	var second: CharacterShop.PullResult = shop.pull(forced)
	assert_true(forced.has(second.character.id) and second.character != first.character, "the other one")
	var third: CharacterShop.PullResult = shop.pull(forced)
	assert_true(third != null, "both owned → normal pull")


func test_tutorial_achievement_pays_once() -> void:
	var tracker: AchievementTracker = AchievementTracker.new(load("res://resources/achievements.tres"), AchievementStore.new(TEST_SAVE), ProgressStore.new(TEST_SAVE))
	var done: AchievementTracker.Completion = tracker.complete_tutorial()
	assert_eq([done.name, done.reward], ["규칙 익히기", "● 50"])
	assert_true(tracker.complete_tutorial() == null, "once")
	assert_eq(ProgressStore.new(TEST_SAVE).coins, 50)


func test_main_menu_locks_follow_the_flow() -> void:
	var menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	menu.save_path = TEST_SAVE
	menu.notification(Node.NOTIFICATION_READY)
	assert_true(menu.is_entry_enabled(MenuUnlocks.Entry.START) and menu.is_entry_enabled(MenuUnlocks.Entry.OPTIONS))
	for entry: MenuUnlocks.Entry in [MenuUnlocks.Entry.LEVEL, MenuUnlocks.Entry.SHOP, MenuUnlocks.Entry.CHARACTERS, MenuUnlocks.Entry.ACHIEVEMENTS]:
		assert_false(menu.is_entry_enabled(entry), "entry %d locked before the tutorial" % entry)
	assert_eq(menu.highlighted_entry(), MenuUnlocks.Entry.START)
	menu.free()
	var store: TutorialStore = TutorialStore.new(TEST_SAVE)
	store.complete_rule_tutorial()
	store.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	var stats: AchievementStore = AchievementStore.new(TEST_SAVE)
	stats.add_stat("games", 1)
	stats.save()
	var gacha_menu: MainMenu = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	gacha_menu.save_path = TEST_SAVE
	gacha_menu.notification(Node.NOTIFICATION_READY)
	assert_false(gacha_menu.shows_swipe_hint(), "the shop glows instead of the swipe hint")
	assert_true(gacha_menu.is_entry_enabled(MenuUnlocks.Entry.SHOP) and not gacha_menu.is_entry_enabled(MenuUnlocks.Entry.CHARACTERS))
	for sig: Signal in [gacha_menu.shop_requested, gacha_menu.start_game_requested]:  # 씬 전환 노드는 떼어 둔다 (트리 밖)
		for connection: Dictionary in sig.get_connections():
			sig.disconnect(connection["callable"])
	var routed: Array[String] = []
	gacha_menu.shop_requested.connect(func() -> void: routed.append("shop"))
	gacha_menu.start_game_requested.connect(func() -> void: routed.append("game"))
	(gacha_menu.get_node("%BottomNav") as BottomNav).start_swiped.emit()
	assert_eq(routed, ["shop"] as Array[String], "start goes to the shop for the first pull")
	gacha_menu.free()


# --- HTML 규칙 튜토리얼 이식 (11/06): 고정 시드 · 5×5 깔기 · 배운 모양 ----------------------------

func test_html_rng_matches_mulberry32() -> void:
	var start: TutorialStartBoard = TutorialStartBoard.find(8907, 9, 3)
	assert_eq(start.seed_used, 8907)
	# node로 HTML tutStartBoard를 그대로 돌린 결과
	assert_eq(start.rows(), PackedStringArray(["110011122", "202002221", "011002222", "110122210", "1020P2010",
		"100002102", "001021120", "222111001", "220111012"]))
	var next: Array[String] = []
	for _i: int in 3:
		next.append("%.10f" % start.rng.next_float())
	assert_eq(next, ["0.4444477938", "0.0886482724", "0.2087823255"] as Array[String], "the RNG keeps going like HTML")


func test_sym_rows_rotates_and_flips() -> void:
	var rows: PackedStringArray = PackedStringArray(["P....", ".....", ".....", ".....", "....T"])
	assert_eq(BlockPuzzle.sym_rows(rows, 0), rows)
	assert_eq(BlockPuzzle.sym_rows(rows, 1)[0][4], "P", "one turn clockwise: top-left → top-right")
	assert_eq(BlockPuzzle.sym_rows(rows, 4)[0][4], "P", "flip: top-left → top-right")
	assert_eq(BlockPuzzle.sym_rows(rows, 5)[0][0], "P", "turn + flip of a corner on the diagonal")


func test_stamp_keeps_the_board_and_puts_p_on_the_player() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	for pos: Vector2i in board.all_positions():
		if pos != board.player_pos:
			board.set_color_block(pos, 2)
	var book: PuzzleBook = load("res://resources/puzzles.tres") as PuzzleBook
	var stamp: BlockPuzzle.Stamp = BlockPuzzle.stamp(board, book.find_board("0a"), 0, 3, HtmlRng.new(1))
	assert_eq(board.player_pos, Vector2i(4, 4), "the player does not move when P fits")
	assert_eq(stamp.origin, Vector2i(2, 0), "0a: P at the bottom middle of the window")
	var puzzle: BlockPuzzle = BlockPuzzle.new(board, stamp.def, 0, stamp.origin, book, 3, RandomNumberGenerator.new(), false, true)
	assert_eq(puzzle.target_positions().size(), 4)
	assert_eq(puzzle.min_moves, 2, "0a: walk around into the T")
	assert_eq(board.get_color(Vector2i(0, 8)), 2, "outside the window and its ring the board stays")
	for y: int in range(0, 7):  # 창 둘레 한 칸에는 모을 색이 남지 않는다
		for x: int in [1, 7]:
			assert_true(board.get_color(Vector2i(x, y)) != 0)


func test_stamp_rotates_when_the_player_is_at_an_edge() -> void:
	var board: Board = _plain_board(9, Vector2i(8, 4))
	var book: PuzzleBook = load("res://resources/puzzles.tres") as PuzzleBook
	var stamp: BlockPuzzle.Stamp = BlockPuzzle.stamp(board, book.find_board("0a"), 1, 3, HtmlRng.new(5))
	var p: Vector2i = stamp.def.player_cell()
	assert_eq(stamp.origin + p, board.player_pos, "rotated so that P is where I stand")
	assert_eq(board.player_pos, Vector2i(8, 4))


func test_planner_counts_built_blocks() -> void:
	var board: Board = _plain_board(5, Vector2i(2, 3))
	for pos: Vector2i in [Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 2)]:  # 아래로 열린 T, 나는 그 아래
		board.set_color_block(pos, 1)
	var planner: TutorialPlanner = TutorialPlanner.new(board, 3, HtmlRng.new(3))
	var plan: TutorialPlanner.Plan = planner.best(4)
	assert_true(plan != null and plan.color == 1 and plan.built == 0, "walking into an existing T builds nothing")
	planner.note_move(Vector2i(2, 2))  # 가운데 블록을 옮긴 적이 있다
	planner.level = 0
	assert_true(planner.best(4) == null or planner.best(4).built == 0)
	planner.level = 1
	assert_true(planner.best(4) != null, "level 1 may use a moved block")


## 씨앗 색 조합을 한 번의 탐색으로 푼 결과가 조합마다 따로 찾은 결과와 같다 (튜토리얼 판 고치기 속도, 끊김 수정).
func test_planner_seed_combos_match_the_slow_search() -> void:
	var config: GameConfig = make_config()
	config.color_count = 3
	for seed_value: int in range(1, 7):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var board: Board = Board.generate(config, rng)
		var me: Vector2i = board.player_pos
		var seeds: Array[Vector2i] = []
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 2), Vector2i(2, -1), Vector2i(0, -2)]:
			board.set_seed(me + d, rng.randi() % 3, 1.0, 1.0)
			seeds.append(me + d)
		var planner: TutorialPlanner = TutorialPlanner.new(board, 3, HtmlRng.new(seed_value))
		planner.level = seed_value % 2
		planner.note_move(me + Vector2i(1, 0))
		var fast: Array[TutorialPlanner.Plan] = planner.best_per_seed_combo(seeds, 6)
		var slow: Array[TutorialPlanner.Plan] = planner.best_per_seed_combo_reference(seeds, 6)
		assert_eq(fast.size(), slow.size())
		for m: int in slow.size():
			var a: TutorialPlanner.Plan = fast[m]
			var b: TutorialPlanner.Plan = slow[m]
			assert_eq(a == null, b == null, "seed %d combo %d found" % [seed_value, m])
			if a != null and b != null:
				assert_eq([a.path, a.color, a.built, a.center], [b.path, b.color, b.built, b.center], "seed %d combo %d same plan" % [seed_value, m])
