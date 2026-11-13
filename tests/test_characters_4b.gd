extends "res://tests/framework/test_case.gd"
## 4b 캐릭터 (기획서 5.2장): 폭파범 · 포세이돈 · 색약 · 레트로 · 건축가 · 떠돌이 · 묘수꾼.
## 색 ID: 0 노랑, 1 빨강, 2 파랑, 3 초록 (E16).


func _roster() -> CharacterRoster:
	return load("res://resources/character_roster.tres") as CharacterRoster


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _session(id: StringName, board: Board = null, seed_value: int = 1) -> GameSession:
	var config: GameConfig = make_config()
	if board != null:
		config.board_size = board.size
	var session: GameSession = GameSession.new(config, _rng(seed_value), board, _roster().find(id))
	session.start()
	return session


## 매치가 없고 빨강(1)이 없는 판: 색 = [노랑, 파랑, 초록][(x + y) mod 3].
## 위·왼쪽 이웃과 아래·오른쪽 이웃의 색이 서로 달라 4칸이 같아지지 않는다 (좌우로 오가도 그대로).
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


## 플레이어 위 칸을 중심으로 한 십자 (UP 이동 시 매치). colors는 [중심, 위, 왼쪽, 오른쪽] 색.
func _cross_above(board: Board, colors: Array[int]) -> void:
	var center: Vector2i = board.player_pos + Vector2i.UP
	var cells: Array[Vector2i] = [center, center + Vector2i.UP, center + Vector2i.LEFT, center + Vector2i.RIGHT]
	for i: int in cells.size():
		board.set_color_block(cells[i], colors[i])


func _trigger(session: GameSession) -> void:
	for color: int in session.character.condition_colors:
		session.advance_ability_condition(color)


func _run(session: GameSession, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


func test_recipes_and_colors_as_specified() -> void:
	var expected: Dictionary = {
		&"bomber": [[0, 3, 0], "FF5A5A"], &"poseidon": [[2, 2, 0], "3FA9F5"], &"colorblind": [[1, 2, 3, 0, 1], "C9A27E"],
		&"retro": [[3, 0, 1, 2], "D9D9D9"], &"architect": [[3, 1], "B9C2CF"], &"wanderer": [[], "E08BFF"],
		&"runner": [[1, 0, 3, 2], "FF8A3D"],
	}
	for id: StringName in expected:
		var character: CharacterData = _roster().find(id)
		assert_eq(character.condition_colors, PackedInt32Array(expected[id][0]), "%s recipe" % id)
		assert_true(character.accent_color.is_equal_approx(Color(expected[id][1])), "%s color" % id)


# --- 폭파범 -------------------------------------------------------------------

## 7x7, 플레이어 (3,3). UP → (3,2)에서 빨강 매치, 깨진 (3,1) 옆으로 빨강 (4,1)·(5,1)이 이어져 있다.
func _bomber_board() -> Board:
	var board: Board = _plain_board(7, Vector2i(3, 3))
	_cross_above(board, [1, 1, 1, 1] as Array[int])
	_paint(board, [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i], 1)
	return board


func test_bomber_next_match_chains_connected_blocks_with_shrinking_gaps() -> void:
	var session: GameSession = _session(&"bomber", _bomber_board())
	var bomber: BomberAbility = session.ability as BomberAbility
	_trigger(session)
	assert_eq(bomber.charges, 1)
	var blasted: Array = []
	var session_ref: WeakRef = weakref(session)
	session.cells_blasted.connect(func(cells: Array[Vector2i], color: int) -> void:
		blasted.append([cells[0], color, (session_ref.get_ref() as GameSession).elapsed]))
	var announced: Array[String] = []
	session.ability_announced.connect(func(text: String) -> void: announced.append(text))
	session.request_move(Vector2i.UP)
	assert_eq(bomber.charges, 0)
	assert_true(bomber.is_chaining())
	assert_eq(bomber.chain, [Vector2i(4, 1), Vector2i(5, 1)] as Array[Vector2i], "connected red, nearest first")
	var remaining: float = session.remaining_time()
	assert_false(session.request_move(Vector2i.LEFT), "input locked while chaining")
	_run(session, 0.17)
	assert_near(session.remaining_time(), remaining, 1e-9, "time stops while chaining")
	assert_eq(blasted.size(), 2)
	assert_eq([blasted[0][0], blasted[0][1], blasted[1][0]], [Vector2i(4, 1), 1, Vector2i(5, 1)])
	assert_near(blasted[0][2], 0.07, 1e-9, "first block after 0.07 s")
	assert_near(blasted[1][2], 0.07 + 0.07 * 0.85, 1e-9, "then × 0.85")
	assert_eq(session.board.get_cell_type(Vector2i(5, 1)), Board.CellType.SEED)
	_run(session, 0.02)
	assert_false(bomber.is_chaining(), "ends one gap after the last block (0.180075 s)")
	assert_eq(announced, ["2연쇄!"] as Array[String])
	assert_true(session.request_move(Vector2i.LEFT), "input back")
	_run(session, 1.0)
	assert_true(session.remaining_time() < remaining, "time runs again")


func test_bomber_each_blast_advances_the_most_advanced_recipe_regardless_of_color() -> void:
	var session: GameSession = _session(&"bomber", _bomber_board())
	session.recipes.set_recipe_colors(0, PackedInt32Array([2, 2]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 3, 0]))
	session.recipes.recipes[2].progress = 2  # 0.5 → 가장 앞섬
	_trigger(session)
	session.request_move(Vector2i.UP)  # 빨강 매치: 일반 족보 진행 없음
	_run(session, 0.1)
	assert_eq(session.recipes.recipes[2].progress, 3, "first blast: +1 (any color)")
	_run(session, 0.1)
	assert_eq(session.score, 750, "second blast completes 0,0,3,0 (600 × 1.25)")


func test_bomber_end_time_is_frame_rate_independent() -> void:
	var results: Array = []
	for frame: float in [1.0 / 30.0, 1.0 / 240.0, 0.5]:
		var session: GameSession = _session(&"bomber", _bomber_board())
		_trigger(session)
		var at: Array[float] = [-1.0]
		var session_ref: WeakRef = weakref(session)
		session.ability_announced.connect(func(_t: String) -> void: at[0] = snappedf((session_ref.get_ref() as GameSession).elapsed, 1e-6))
		session.request_move(Vector2i.UP)
		_run(session, 2.0, frame)
		results.append([at[0], snappedf(session.remaining_time(), 1e-6)])
	assert_near(results[0][0], 0.07 + 0.07 * 0.85 + 0.07 * 0.85 * 0.85, 1e-6, "ends one gap after the last block")
	for result: Array in results:
		assert_eq(result, results[0])


func test_bomber_triggering_match_does_not_explode() -> void:
	var session: GameSession = _session(&"bomber", _bomber_board())
	session.ability_recipe.progress = 2
	session.ability_recipe.colors[2] = 1  # 이번 빨강 매치로 발동
	session.request_move(Vector2i.UP)
	var bomber: BomberAbility = session.ability as BomberAbility
	assert_false(bomber.is_chaining())
	assert_eq(bomber.charges, 1, "saved for the next match")


# --- 포세이돈 -----------------------------------------------------------------

func test_poseidon_sinks_blue_blocks_to_the_bottom_keeping_counts() -> void:
	var session: GameSession = _session(&"poseidon", _plain_board(5, Vector2i(2, 2)))
	var board: Board = session.board
	board.set_seed(Vector2i(0, 4), 1, 1.0, 1.0)
	board.get_cell(Vector2i(4, 4)).attach_coin(10.0)
	var before: PackedInt32Array = board.color_counts(4)
	var blocks_before: int = board.count_type(Board.CellType.COLOR_BLOCK)
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
<<<<<<< HEAD
	assert_eq(messages, ["해일: 파란 블록이 가라앉음"] as Array[String])
=======
	assert_eq(messages, ["해일: 파란 블럭이 가라앉음"] as Array[String])
>>>>>>> Choi
	assert_eq(board.color_counts(4), before, "color counts kept")
	assert_eq(board.count_type(Board.CellType.COLOR_BLOCK), blocks_before)
	assert_eq(board.get_cell_type(Vector2i(0, 4)), Board.CellType.SEED, "seed untouched")
	assert_true(board.has_coin(Vector2i(4, 4)), "coin stays on its cell")
	# 아래 줄부터(같은 줄은 왼쪽부터) 파랑으로 채워진다: 어떤 파랑 블록보다도 앞(더 아래, 같은 줄이면 더 왼쪽)에
	# 파랑이 아닌 블록이 있으면 안 된다.
	var blocks: Array[Vector2i] = board.positions_of_type(Board.CellType.COLOR_BLOCK)
	var blue_count: int = 0
	for blue: Vector2i in blocks:
		if board.get_color(blue) != 2:
			continue
		blue_count += 1
		for other: Vector2i in blocks:
			var before_blue: bool = other.y > blue.y or (other.y == blue.y and other.x < blue.x)
			if before_blue:
				assert_eq(board.get_color(other), 2, "%s sits below blue %s, so it must be blue" % [other, blue])
	assert_true(blue_count > 0)
	assert_eq(board.get_color(Vector2i(1, 4)), 2, "bottom row (seed at (0,4) aside) is blue")


# --- 색약 ---------------------------------------------------------------------

func test_colorblind_merges_two_colors_for_matches_and_recipes() -> void:
	var board: Board = _plain_board(7, Vector2i(3, 3))
	var session: GameSession = _session(&"colorblind", board)
	var colorblind: ColorblindAbility = session.ability as ColorblindAbility
	var styles: Array = []
	session.display_style_changed.connect(func(s: DisplayStyle) -> void: styles.append(s))
	_trigger(session)
	var base: int = colorblind.base_color
	var merged: int = colorblind.merged_color
	assert_ne(base, merged)
	assert_eq(colorblind.canonical_color(merged), base)
	assert_eq(colorblind.canonical_color(base), base)
	assert_eq((styles[0] as DisplayStyle).fill_color_id(merged), base, "merged color drawn as the base color")
	_cross_above(board, [merged, base, merged, base] as Array[int])
	session.recipes.set_recipe_colors(0, PackedInt32Array([merged, 0]))
	var matched: Array[int] = []
	session.matched.connect(func(_c: Vector2i, color: int, _cells: Array[Vector2i]) -> void: matched.append(color))
	session.request_move(Vector2i.UP)
	assert_eq(matched, [base] as Array[int], "mixed cross matches as the base color")
	assert_eq(session.recipes.recipes[0].progress, 1, "recipe needing the merged color advances")
	_run(session, 10.1)
	assert_false(colorblind.is_active())
	assert_eq(colorblind.canonical_color(merged), merged, "back to normal")
	assert_eq(styles.back(), null, "display back to normal")


func test_colorblind_character_recipe_also_merges() -> void:
	var session: GameSession = _session(&"colorblind")
	var colorblind: ColorblindAbility = session.ability as ColorblindAbility
	_trigger(session)
	session.ability_recipe.colors[0] = colorblind.merged_color
	session.advance_ability_condition(colorblind.base_color)
	assert_eq(session.ability_recipe.progress, 1)


# --- 레트로 -------------------------------------------------------------------

func test_retro_doubles_recipe_points_and_turns_monochrome_for_10_seconds() -> void:
	var session: GameSession = _session(&"retro")
	var styles: Array = []
	session.display_style_changed.connect(func(s: DisplayStyle) -> void: styles.append(s))
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
	assert_eq(messages, ["레트로: 10초 동안 점수 ×2"] as Array[String])
	assert_true((styles[0] as DisplayStyle).monochrome)
	session.apply_clear_to_recipes(1)
	assert_eq(session.score, 250, "125 × 2")
	_run(session, 4.0)
	_trigger(session)
	assert_near((session.ability as RetroAbility).time_left, 16.0, 1e-6, "retrigger adds 10 s")
	assert_eq(styles.size(), 1, "already monochrome")
	_run(session, 16.1)
	assert_eq(styles.back(), null)
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1]))
	session.recipes.recipes[0].progress = 1
	session.apply_clear_to_recipes(1)
	assert_eq(session.score, 375, "normal points after it ends")


func test_display_style_reaches_both_channels_on_bind() -> void:
	var board_channel: BoardChannel = BoardChannel.new()
	var hud_channel: HudChannel = HudChannel.new()
	var got: Array = []
	board_channel.display_style_changed.connect(func(s: DisplayStyle) -> void: got.append(["board", s]))
	hud_channel.display_style_changed.connect(func(s: DisplayStyle) -> void: got.append(["hud", s]))
	var session: GameSession = _session(&"retro")
	board_channel.bind(session, session.character)
	hud_channel.bind(session, session.character)
	_trigger(session)
	assert_eq(got.size(), 4, "initial (null) + change, on both channels")
	assert_eq([got[0][1], got[1][1]], [null, null])
	assert_true((got[2][1] as DisplayStyle).monochrome and (got[3][1] as DisplayStyle).monochrome)
	board_channel.free()
	hud_channel.free()


# --- 건축가 -------------------------------------------------------------------

func test_architect_extends_the_most_advanced_recipe_and_rescores() -> void:
	var session: GameSession = _session(&"architect")
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.recipes.recipes[0].progress = 1  # 0.5, 100점
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 1, 2, 3]))
	session.recipes.recipes[2].progress = 2  # 0.5, 600점 → 같은 비율이면 점수 높은 쪽
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
	var recipe: RecipeSet.Recipe = session.recipes.recipes[2]
	assert_eq(recipe.length(), 5)
	assert_eq(recipe.progress, 2, "progress kept")
	assert_eq(recipe.points, session.recipes.points_for(recipe.colors), "rescored (1,000 base for 5 steps)")
	assert_true(recipe.points >= 1000)
	assert_eq(messages, ["증축: 족보 한 장 +1칸 (5칸 %d점)" % recipe.points] as Array[String])
	for color: int in recipe.colors.slice(2):
		session.apply_clear_to_recipes(color)
	assert_eq(session.recipes.recipes[2].length(), 4, "next recipe in the slot is the normal length")


func test_architect_stops_at_5_steps() -> void:
	var session: GameSession = _session(&"architect")
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	for _i: int in 8:  # 2→5, 3→5, 4→5 = 3 + 2 + 1 = 6번이면 다 찬다
		_trigger(session)
	for recipe: RecipeSet.Recipe in session.recipes.recipes:
		assert_eq(recipe.length(), 5)
	assert_eq(messages.back(), "증축: 더 늘릴 족보 없음")


# --- 떠돌이 -------------------------------------------------------------------

func test_wanderer_scales_recipe_points_by_1_5() -> void:
	var session: GameSession = _session(&"wanderer")
	session.recipes.set_recipe_colors(1, PackedInt32Array([1, 1, 2]))
	session.recipes.recipes[1].progress = 2
	session.apply_clear_to_recipes(2)
	assert_eq(session.score, 563, "375 × 1.5 rounded")


func test_wanderer_teleports_after_10_moves_without_a_match() -> void:
	var session: GameSession = _session(&"wanderer", _plain_board(9, Vector2i(4, 4)))
	var wanderer: WandererAbility = session.ability as WandererAbility
	var jumps: Array[Board.MoveResult] = []
	session.move_started.connect(func(r: Board.MoveResult) -> void:
		if r.teleported:
			jumps.append(r))
	for i: int in 9:
		session.request_move(Vector2i.LEFT if i % 2 == 0 else Vector2i.RIGHT)
	assert_eq(wanderer.status_text(), "1수 뒤 이동")
	assert_eq(jumps.size(), 0)
	var before: Vector2i = session.board.player_pos
	session.request_move(Vector2i.RIGHT)
	assert_eq(jumps.size(), 1, "10th move without a match → teleport")
	assert_true(Board.distance(jumps[0].from, jumps[0].to) > 1, "lands at distance 2 or more")
	assert_eq(jumps[0].from, before + Vector2i.RIGHT)
	assert_eq(session.board.player_pos, jumps[0].to)
	assert_eq(session.stats.moves, 10, "teleport is not a move")
	assert_eq(wanderer.moves_left, 10)
	assert_eq(wanderer.teleports, 1)


func test_wanderer_match_resets_the_count() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	var session: GameSession = _session(&"wanderer", board)
	for i: int in 5:
		session.request_move(Vector2i.LEFT if i % 2 == 0 else Vector2i.RIGHT)
	assert_eq((session.ability as WandererAbility).moves_left, 5)
	_cross_above(board, [1, 1, 1, 1] as Array[int])
	session.request_move(Vector2i.UP)
	assert_eq(session.match_count, 1)
	assert_eq((session.ability as WandererAbility).moves_left, 10)


# --- 묘수꾼 -------------------------------------------------------------------

func test_runner_stops_time_grows_seeds_and_ends_after_8_moves() -> void:
	var session: GameSession = _session(&"runner", _plain_board(9, Vector2i(4, 4)))
	var runner: RunnerAbility = session.ability as RunnerAbility
	session.board.set_seed(Vector2i(0, 0), 1, 1.0, 1.0)
	var announced: Array[String] = []
	session.ability_announced.connect(func(t: String) -> void: announced.append(t))
	_trigger(session)
	assert_eq(session.board.count_type(Board.CellType.SEED), 0, "all seeds grown")
	assert_true(session.is_clock_stopped())
	var remaining: float = session.remaining_time()
	for i: int in 7:
		session.request_move(Vector2i.LEFT if i % 2 == 0 else Vector2i.RIGHT)
	assert_true(runner.active)
<<<<<<< HEAD
	assert_eq(runner.status_text(), "1수 / 6초")
=======
	assert_eq(runner.status_text(), "1수 · 6초")
>>>>>>> Choi
	session.request_move(Vector2i.RIGHT)
	assert_false(runner.active, "8 moves → ends")
	assert_eq(announced, ["수읽기 끝"] as Array[String])
	assert_near(session.remaining_time(), remaining, 1e-9)


func test_runner_ends_after_6_seconds_and_is_capped_at_10() -> void:
	var session: GameSession = _session(&"runner")
	var runner: RunnerAbility = session.ability as RunnerAbility
	_trigger(session)
	_run(session, 5.9)
	assert_true(runner.active)
	_run(session, 0.2)
	assert_false(runner.active, "6 s → ends")
	_trigger(session)
	_run(session, 5.0)
	_trigger(session)  # 다시 6초지만 처음 발동부터 10초 한도
	_run(session, 4.9)
	assert_true(runner.active)
	_run(session, 0.2)
	assert_false(runner.active, "capped at 10 s from the first trigger")


func test_runner_match_gives_no_time_but_resets_and_grows_its_seeds() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	var session: GameSession = _session(&"runner", board)
	var runner: RunnerAbility = session.ability as RunnerAbility
	_trigger(session)
	session.request_move(Vector2i.LEFT)
	session.request_move(Vector2i.RIGHT)
	_run(session, 3.0)
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	_cross_above(board, [1, 1, 1, 1] as Array[int])
	var remaining: float = session.remaining_time()
	session.request_move(Vector2i.UP)
	assert_eq(session.match_count, 1)
	assert_eq(gained.size(), 0, "no time from a match during the stop")
	assert_near(session.remaining_time(), remaining, 1e-9)
	assert_eq(session.board.count_type(Board.CellType.SEED), 0, "broken cells grow at once")
	assert_eq(runner.moves_left, 7, "reset to 8, then this move counts")
	assert_near(runner.time_left, 6.0, 1e-9)


func test_runner_triggering_match_still_gives_time() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	_cross_above(board, [1, 1, 1, 1] as Array[int])
	var session: GameSession = _session(&"runner", board)
	session.ability_recipe.progress = 3
	session.ability_recipe.colors[3] = 1
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	session.request_move(Vector2i.UP)
	assert_eq(gained, [2.5] as Array[float])
	assert_true((session.ability as RunnerAbility).active)
	assert_eq((session.ability as RunnerAbility).moves_left, 7)
