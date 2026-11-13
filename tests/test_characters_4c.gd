extends "res://tests/framework/test_case.gd"
## 4c 캐릭터 (기획서 5.2장): 거울 · 예지안 · 수선사 · 뱀파이어.
## 색 ID: 0 노랑, 1 빨강, 2 파랑, 3 초록 (E16).


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _session(id: StringName, board: Board = null) -> GameSession:
	var config: GameConfig = make_config()
	if board != null:
		config.board_size = board.size
	var session: GameSession = GameSession.new(config, _rng(), board, _roster().find(id))
	session.start()
	return session


## 매치가 없고 빨강(1)이 없는 판: 색 = [노랑, 파랑, 초록][(x + y) mod 3]. 곧게 움직여도 매치가 생기지 않는다.
func _plain_board(size: int, player: Vector2i) -> Board:
	var board: Board = Board.new(size)
	var palette: Array[int] = [0, 2, 3]
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, palette[(pos.x + pos.y) % 3])
	board.set_player(player)
	return board


func _paint(board: Board, cells: Array[Vector2i], color: int) -> void:
	for pos: Vector2i in cells:
		board.set_color_block(pos, color)


func _trigger(session: GameSession) -> void:
	for color: int in session.character.condition_colors:
		session.advance_ability_condition(color)


func _run(session: GameSession, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


func _moves(session: GameSession, dirs: Array[Vector2i]) -> void:
	for dir: Vector2i in dirs:
		session.request_move(dir)


func test_recipes_and_colors_as_specified() -> void:
	var expected: Dictionary = {
		&"mirror": [[], "BFE0FF"], &"seer": [[3, 2, 0, 1], "9A82FF"], &"sewer": [[3, 2], "2FCF74"],
		&"vampire": [[1, 1, 1, 1], "E0304A"],
	}
	for id: StringName in expected:
		var character: CharacterData = _roster().find(id)
		assert_eq(character.condition_colors, PackedInt32Array(expected[id][0]), "%s recipe" % id)
		assert_true(character.accent_color.is_equal_approx(Color(expected[id][1])), "%s color" % id)


# --- 뱀파이어 -----------------------------------------------------------------

func test_vampire_matches_any_four_blocks_for_no_time_and_fills_recipes_in_order() -> void:
	var board: Board = _plain_board(7, Vector2i(3, 3))  # 위 (3,2)를 중심으로 이웃 색이 모두 다르다
	var session: GameSession = _session(&"vampire", board)
	var styles: Array = []
	session.display_style_changed.connect(func(s: DisplayStyle) -> void: styles.append(s))
	session.recipes.set_recipe_colors(0, PackedInt32Array([3, 3]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([0, 2, 0]))
	_trigger(session)
	assert_eq((styles[0] as DisplayStyle).fill_color_id(2), 1, "every block drawn red")
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	var matched: Array[int] = []
	session.matched.connect(func(_c: Vector2i, color: int, _cells: Array[Vector2i]) -> void: matched.append(color))
	session.request_move(Vector2i.UP)
	assert_eq(matched, [1] as Array[int], "colors differ but all four are blocks → red match")
	assert_eq(gained.size(), 0, "no time")
	assert_eq(session.recipes.recipes[0].progress, 1, "the 2-step recipe fills first (any color)")
	assert_eq(session.recipes.recipes[1].progress, 0)
	assert_eq(session.ability_recipe.progress, 0, "character recipe frozen during the blood time")
	session.apply_clear_to_recipes(2)
	assert_eq(session.score, 125, "slot 0 completed (3,3 = 125)")
	session.apply_clear_to_recipes(2)
	assert_eq(session.recipes.recipes[1].progress, 1, "then the 3-step recipe")


func test_vampire_needs_four_grown_blocks() -> void:
	var board: Board = _plain_board(7, Vector2i(3, 3))
	board.set_seed(Vector2i(2, 2), 1, 1.0, 1.0)
	var session: GameSession = _session(&"vampire", board)
	_trigger(session)
	session.request_move(Vector2i.UP)
	assert_eq(session.match_count, 0, "a seed neighbor still blocks the match")


func test_vampire_speeds_refill_and_ends_after_6_seconds() -> void:
	var session: GameSession = _session(&"vampire")
	session.board.set_seed(Vector2i(0, 0), 2, 0.0, 5.0)
	var announced: Array[String] = []
	session.ability_announced.connect(func(t: String) -> void: announced.append(t))
	_trigger(session)
	_run(session, 2.05)
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.COLOR_BLOCK, "5 s of growth in 2 s (×2.5)")
	_run(session, 4.0)
	assert_eq(announced, ["피의 시간 종료"] as Array[String])
	var vampire: VampireAbility = session.ability as VampireAbility
	assert_false(vampire.is_active())
	assert_eq(vampire.canonical_color(2), 2, "colors back")
	assert_eq(session.display_style(), null)


func test_vampire_retrigger_adds_time() -> void:
	var session: GameSession = _session(&"vampire")
	_trigger(session)
	_run(session, 2.0)
	(session.ability as VampireAbility).trigger(session)
	assert_near((session.ability as VampireAbility).time_left, 10.0, 1e-6)


# --- 거울 ---------------------------------------------------------------------

func test_board_mirror_flips_every_cell_and_the_player() -> void:
	var board: Board = _plain_board(5, Vector2i(1, 3))
	var before: Dictionary = {}
	for pos: Vector2i in board.all_positions():
		before[pos] = [board.get_cell_type(pos), board.get_color(pos)]
	board.mirror(true)
	assert_eq(board.player_pos, Vector2i(3, 3))
	for pos: Vector2i in board.all_positions():
		assert_eq([board.get_cell_type(pos), board.get_color(pos)], before[Vector2i(4 - pos.x, pos.y)])
	board.mirror(false)
	assert_eq(board.player_pos, Vector2i(3, 1))


func test_mirror_passes_through_the_wall_into_the_mirror_world() -> void:
	var session: GameSession = _session(&"mirror", _plain_board(5, Vector2i(0, 2)))
	var mirror: MirrorAbility = session.ability as MirrorAbility
	var rearranged: Array[int] = [0]
	session.board_rearranged.connect(func(_b: Board) -> void: rearranged[0] += 1)
	session.request_move(Vector2i.LEFT)
	assert_true(mirror.in_mirror)
	assert_eq(session.board.player_pos, Vector2i(4, 2), "left wall → left-right flip, player on the right edge")
	assert_eq(session.stats.moves, 1, "counts as a move")
	assert_eq(session.stats.blocked_moves, 0)
	assert_eq(rearranged[0], 1)
	assert_eq(mirror.status_text(), "거울세계")
	assert_true(session.display_style().reversed_recipes)
	assert_eq(mirror.effect_remaining(), INF, "background on while in the mirror world")
	session.request_move(Vector2i.UP)
	session.request_move(Vector2i.UP)
	session.request_move(Vector2i.UP)  # 위 벽 → 상하반전, 현실로
	assert_false(mirror.in_mirror)
	assert_eq(session.board.player_pos, Vector2i(4, 4))
	assert_eq(session.display_style(), null)


func test_mirror_world_fills_recipes_from_the_back_and_doubles_on_meeting() -> void:
	var session: GameSession = _session(&"mirror", _plain_board(5, Vector2i(0, 2)))
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))  # 아래 색들로는 완성되지 않게 고정
	session.recipes.set_recipe_colors(1, PackedInt32Array([1, 2, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 2]))
	session.apply_clear_to_recipes(1)  # 현실: 앞에서 1칸
	session.request_move(Vector2i.LEFT)  # 거울세계
	assert_eq(session.recipes.recipes[1].next_color(), 3, "next is the last step now")
	assert_eq(session.recipes.recipes[2].next_color(), 2)
	session.apply_clear_to_recipes(3)
	assert_eq(session.recipes.recipes[1].back_progress, 1)
	session.apply_clear_to_recipes(2)  # 1,2,3 앞뒤가 가운데서 만나 완성 → ×2. 0,0,0,2는 뒤 1칸
	assert_eq(session.score, 600, "300 × 2 for meeting in the middle")
	assert_true(session.recipes.recipes[1].from_back, "new recipes also fill from the back")
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))  # 새로 나온 족보를 고정
	for color: int in [0, 0, 0]:
		session.apply_clear_to_recipes(color)
	assert_eq(session.score, 600 + 900, "filled only from the back → no bonus (0,0,0,2 = 900)")


# --- 예지안 -------------------------------------------------------------------

func test_seer_reveals_seed_colors() -> void:
	var session: GameSession = _session(&"seer")
	assert_true(session.display_style().reveal_seeds)


func test_seer_matches_every_shape_including_seeds_and_advances_all_recipes() -> void:
	var board: Board = _plain_board(9, Vector2i(8, 8))
	_paint(board, [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)] as Array[Vector2i], 1)  # ㅗ
	for pos: Vector2i in [Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 6), Vector2i(6, 5)]:  # ㅏ (씨앗, 자랄 색 빨강)
		board.set_seed(pos, 1, 1.0, 1.0)
	var session: GameSession = _session(&"seer", board)
	var shapes: Array[MatchRule.Found] = SeerAbility.find_shapes(board)
	assert_eq(shapes.size(), 2)
	for color: int in [3, 2, 0]:
		session.advance_ability_condition(color)
	session.recipes.set_recipe_colors(0, PackedInt32Array([3, 3]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([3, 3, 3, 3]))
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	session.advance_ability_condition(1)
<<<<<<< HEAD
	assert_eq(messages, ["예언 실현: 모양 2개 / 족보 모두 2칸"] as Array[String])
=======
	assert_eq(messages, ["예언 실현: 모양 2개 · 족보 모두 2칸"] as Array[String])
>>>>>>> Choi
	assert_eq(session.match_count, 2, "one match per shape")
	assert_eq(gained.size(), 2)
	assert_near(gained[0], 2.5, 1e-9)
	assert_near(gained[1], 2.42, 1e-9, "match time decays per shape")
	assert_eq(session.score, 125, "the 2-step recipe completes (125), the others advance 2")
	assert_eq(session.recipes.recipes[1].progress, 2)
	assert_eq(session.recipes.recipes[2].progress, 2)
	for pos: Vector2i in shapes[0].cells + shapes[1].cells:
		assert_eq(session.board.get_cell_type(pos), Board.CellType.SEED, "%s replanted" % pos)
	assert_eq(session.ability_recipe.progress, 0, "character recipe restarts, not advanced by the shapes")


func test_seer_picks_non_overlapping_shapes_preferring_less_shared_cells() -> void:
	var board: Board = _plain_board(9, Vector2i(8, 8))
	# 십자(+) 모양: 가운데 (3,3)에 ㅗ·ㅜ·ㅓ·ㅏ 4개가 모두 겹친다 → 하나만
	_paint(board, [Vector2i(3, 3), Vector2i(3, 2), Vector2i(3, 4), Vector2i(2, 3), Vector2i(4, 3)] as Array[Vector2i], 1)
	var shapes: Array[MatchRule.Found] = SeerAbility.find_shapes(board)
	assert_eq(shapes.size(), 1)
	assert_eq(shapes[0].cells[0], Vector2i(3, 3))
	var with_player: Board = _plain_board(9, Vector2i(3, 2))  # 플레이어 칸은 모양에 들 수 없다
	_paint(with_player, [Vector2i(3, 3), Vector2i(2, 3), Vector2i(4, 3)] as Array[Vector2i], 1)
	assert_eq(SeerAbility.find_shapes(with_player).size(), 0)


func test_seer_without_shapes() -> void:
	var session: GameSession = _session(&"seer", _plain_board(9, Vector2i(4, 4)))
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
	assert_eq(messages, ["예언: 맞는 모양이 없어요"] as Array[String])
	assert_eq(session.match_count, 0)


# --- 수선사 -------------------------------------------------------------------

const LOOP: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.DOWN, Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP]


func test_sewer_loop_pulls_the_inside_blocks_as_one_match() -> void:
	var session: GameSession = _session(&"sewer", _plain_board(9, Vector2i(2, 2)))
	var sewer: SewerAbility = session.ability as SewerAbility
	var inside: Vector2i = Vector2i(3, 3)
	var color: int = session.board.get_color(inside)
	var drawn: Array[int] = []
	# View처럼 타입 있는 인자로 받는다 (타입 없는 배열이 오면 호출이 실패해 스크립트 오류로 잡힌다)
	session.marks_changed.connect(func(marks: Array[BoardMark]) -> void: drawn.append(marks.size()))
	_trigger(session)
	assert_true(sewer.armed)
	assert_eq(session.board_marks()[0].kind, BoardMark.Kind.PATH)
	assert_eq(drawn, [1] as Array[int], "rope sent to the view as typed marks")
	_moves(session, LOOP)
	assert_true(sewer.armed, "not back yet")
	session.recipes.set_recipe_colors(0, PackedInt32Array([color, 1]))
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	var announced: Array[String] = []
	session.ability_announced.connect(func(t: String) -> void: announced.append(t))
	session.request_move(Vector2i.UP)  # 8칸째: 시작 칸
	assert_false(sewer.armed)
	assert_eq(sewer.closes, 1)
	assert_eq(session.board.get_cell_type(inside), Board.CellType.SEED, "inside block pulled out")
	assert_eq(session.match_count, 1)
	assert_eq(gained, [2.5] as Array[float])
	assert_eq(session.recipes.recipes[0].progress, 1, "its color advances the recipes")
	assert_eq(session.ability_recipe.progress, 0, "sewer clears do not advance the character recipe")
<<<<<<< HEAD
	assert_eq(announced, ["수선: 블록 1개"] as Array[String])
=======
	assert_eq(announced, ["수선: 블럭 1개"] as Array[String])
>>>>>>> Choi
	assert_eq(session.board_marks().size(), 0, "rope gone")


func test_sewer_inside_cells() -> void:
	var session: GameSession = _session(&"sewer", _plain_board(9, Vector2i(2, 2)))
	var sewer: SewerAbility = session.ability as SewerAbility
	_trigger(session)
	_moves(session, LOOP)
	assert_eq(sewer.inside_cells(session.board), [Vector2i(3, 3)] as Array[Vector2i])


func test_sewer_fails_on_timeout_rope_or_empty_loop() -> void:
	var timeout: GameSession = _session(&"sewer", _plain_board(9, Vector2i(2, 2)))
	var announced: Array[String] = []
	timeout.ability_announced.connect(func(t: String) -> void: announced.append(t))
	_trigger(timeout)
	_run(timeout, 3.05)
	assert_false((timeout.ability as SewerAbility).armed)
	assert_eq(announced, ["시간 끝"] as Array[String])
	var rope: GameSession = _session(&"sewer", _plain_board(9, Vector2i(1, 4)))
	_trigger(rope)
	for i: int in 12:
		rope.request_move(Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT)  # 시작 칸으로 돌아오지만 끈만 쓴다 (안쪽 없음)
	assert_false((rope.ability as SewerAbility).armed, "back on the start with nothing inside, or rope used up")
	var square: GameSession = _session(&"sewer", _plain_board(9, Vector2i(2, 2)))
	var said: Array[String] = []
	square.ability_announced.connect(func(t: String) -> void: said.append(t))
	_trigger(square)
	_moves(square, [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP] as Array[Vector2i])
<<<<<<< HEAD
	assert_eq(said, ["안에 블록이 없어요"] as Array[String], "2x2 loop has no inside")
=======
	assert_eq(said, ["안에 블럭이 없어요"] as Array[String], "2x2 loop has no inside")
>>>>>>> Choi


func test_sewer_character_recipe_frozen_while_armed() -> void:
	var session: GameSession = _session(&"sewer")
	_trigger(session)
	session.advance_ability_condition(3)
	assert_eq(session.ability_recipe.progress, 0)


func test_sewer_best_order_favors_the_highest_scoring_recipe() -> void:
	var session: GameSession = _session(&"sewer")
	var sewer: SewerAbility = session.ability as SewerAbility
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 3]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([0, 0, 0]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([2, 1, 0, 0]))  # 가장 높은 점수: 2 다음 1
	var order: Array[int] = sewer.best_order([1, 2] as Array[int], session.recipes, sewer.canonical_color)
	assert_eq(order, [2, 1] as Array[int], "2 first lets the 4-step recipe take both")
