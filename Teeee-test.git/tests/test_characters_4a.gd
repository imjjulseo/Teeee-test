extends "res://tests/framework/test_case.gd"
## 4a 캐릭터 (기획서 5.2장): 쌍둥이 · 장인 · 벽 타는 자 · 마라토너 · 현상금 사냥꾼 · 화가 · 항해사 · 탐험가.
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


## 어디에도 매치가 없는 판: 색 = (x + 2y) mod 4 → 이웃끼리 색이 모두 다르다.
func _plain_board(size: int, player: Vector2i) -> Board:
	var board: Board = Board.new(size)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, (pos.x + 2 * pos.y) % 4)
	board.set_player(player)
	return board


func _paint(board: Board, cells: Array[Vector2i], color: int) -> void:
	for pos: Vector2i in cells:
		board.set_color_block(pos, color)


## 5x5, 플레이어 (2,3). UP 이동 시 (2,2)에서 color 매치.
func _match_ready_board(color: int = 1) -> Board:
	var board: Board = _plain_board(5, Vector2i(2, 3))
	_paint(board, [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)] as Array[Vector2i], color)
	return board


func _run(session: GameSession, total: float, step: float = 1.0 / 60.0) -> void:
	var left: float = total
	while left > 1e-9:
		var d: float = minf(step, left)
		session.advance(d)
		left -= d


func _gained(session: GameSession) -> Array[float]:
	var gained: Array[float] = []
	session.time_gained.connect(func(seconds: float) -> void: gained.append(seconds))
	return gained


# --- 공통 ---------------------------------------------------------------------

func test_passive_characters_have_an_ability_but_no_recipe() -> void:
	for id: StringName in [&"twins", &"artisan", &"wall", &"marathon", &"bounty", &"navigator", &"explorer"]:
		var character: CharacterData = _roster().find(id)
		assert_true(character.has_ability(), "%s has an ability" % id)
		assert_false(character.has_recipe(), "%s is passive" % id)
		var session: GameSession = _session(id)
		assert_true(session.ability != null, "%s session ability" % id)
		assert_eq(session.ability_recipe, null, "%s has no character recipe" % id)
		assert_false(session.ability.status_text().is_empty(), "%s card shows a status" % id)
	var painter: CharacterData = _roster().find(&"painter")
	assert_true(painter.has_recipe())
	assert_eq(painter.condition_colors, PackedInt32Array([0, 2, 1, 3]), "yellow → blue → red → green")


func test_html_colors() -> void:
	var expected: Dictionary = {
		&"twins": "FFB3C7", &"artisan": "E8C07D", &"wall": "7FE0A8", &"marathon": "7FB8FF",
		&"bounty": "F5A04A", &"painter": "FF8FB1", &"navigator": "6EC8FF", &"explorer": "7FD1B9",
	}
	for id: StringName in expected:
		assert_true(_roster().find(id).accent_color.is_equal_approx(Color(expected[id])), "%s color" % id)


# --- 쌍둥이 -------------------------------------------------------------------

func test_twins_advance_through_repeated_colors_with_one_match() -> void:
	var session: GameSession = _session(&"twins")
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([1, 1, 2]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([3, 3, 3, 3]))
	session.apply_clear_to_recipes(1)
	assert_eq(session.recipes.recipes[0].progress, 1, "no repeat → one step")
	assert_eq(session.recipes.recipes[1].progress, 2, "1, 1 filled at once")
	assert_eq(session.ability.status_text(), "두 칸 진행 1")
	session.apply_clear_to_recipes(3)
	assert_eq(session.score, 1050, "3,3,3,3 completes in one match, repeat bonus kept (600 × 1.75)")
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 0]))  # 새로 나온 족보를 고정
	session.apply_clear_to_recipes(2)
	assert_eq(session.score, 1050 + 100 + 375, "both remaining recipes complete")


# --- 장인 ---------------------------------------------------------------------

func test_artisan_has_two_recipes_of_3_and_4() -> void:
	var session: GameSession = _session(&"artisan")
	assert_eq(session.recipes.slot_count(), 2)
	assert_eq(session.recipes.recipes[0].length(), 3)
	assert_eq(session.recipes.recipes[1].length(), 4)


func test_artisan_scales_each_completed_recipe_by_1_5() -> void:
	var session: GameSession = _session(&"artisan")
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 1, 2]))  # 375 → 562.5 → 563
	session.recipes.recipes[0].progress = 2
	session.recipes.set_recipe_colors(1, PackedInt32Array([0, 0, 0, 2]))  # 900 → 1,350
	session.recipes.recipes[1].progress = 3
	var outcomes: Array[int] = []
	session.recipes_updated.connect(func(_r: RecipeSet, o: RecipeSet.ClearOutcome) -> void: outcomes.append(o.points))
	session.apply_clear_to_recipes(2)
	assert_eq(session.score, 563 + 1350, "rounded per recipe")
	assert_eq(outcomes, [1913] as Array[int])


# --- 벽 타는 자 ----------------------------------------------------------------

## 5x5, 플레이어 (1,2). LEFT로 (0,2)에 들어가면 위·아래·오른쪽 3칸이 color.
func _wall_board(color: int) -> Board:
	var board: Board = _plain_board(5, Vector2i(1, 2))
	_paint(board, [Vector2i(0, 1), Vector2i(0, 3), Vector2i(0, 2)] as Array[Vector2i], color)  # (0,2)의 블록이 (1,2)로 온다
	return board


func test_wall_matches_three_cells_against_a_wall_for_half_time() -> void:
	var session: GameSession = _session(&"wall", _wall_board(1))
	var gained: Array[float] = _gained(session)
	var matched: Array = []
	session.matched.connect(func(_c: Vector2i, color: int, cells: Array[Vector2i]) -> void: matched.append([color, cells]))
	session.request_move(Vector2i.LEFT)
	assert_eq(matched.size(), 1, "3-cell match against the wall")
	assert_eq(matched[0][0], 1)
	assert_eq((matched[0][1] as Array).size(), 3)
	assert_eq(gained, [1.25] as Array[float], "2.5 × 0.5")
	assert_eq(session.board.count_type(Board.CellType.SEED), 3)


func test_wall_match_needs_the_wall_and_not_a_corner() -> void:
	var plain: GameSession = _session(&"basic", _wall_board(1))
	plain.request_move(Vector2i.LEFT)
	assert_eq(plain.match_count, 0, "other characters need all four")
	var corner_board: Board = _plain_board(5, Vector2i(1, 0))
	_paint(corner_board, [Vector2i(0, 1), Vector2i(0, 0)] as Array[Vector2i], 2)  # (0,0): 아래·오른쪽만 판 안
	var corner: GameSession = _session(&"wall", corner_board)
	corner.request_move(Vector2i.LEFT)
	assert_eq(corner.match_count, 0, "corner has two walls → no match")


func test_wall_four_cell_match_keeps_full_time() -> void:
	var session: GameSession = _session(&"wall", _match_ready_board())
	var gained: Array[float] = _gained(session)
	session.request_move(Vector2i.UP)
	assert_eq(gained, [2.5] as Array[float])


# --- 항해사 -------------------------------------------------------------------

func test_navigator_moves_through_the_edge_to_the_other_side() -> void:
	var session: GameSession = _session(&"navigator", _plain_board(5, Vector2i(0, 2)))
	var results: Array[Board.MoveResult] = []
	session.move_started.connect(func(r: Board.MoveResult) -> void: results.append(r))
	session.request_move(Vector2i.LEFT)
	assert_eq(session.board.player_pos, Vector2i(4, 2))
	assert_true(results[0].wrapped)
	session.request_move(Vector2i.LEFT)
	assert_false(results[1].wrapped, "normal move")
	assert_eq(session.stats.blocked_moves, 0)
	var basic: GameSession = _session(&"basic", _plain_board(5, Vector2i(0, 2)))
	basic.request_move(Vector2i.LEFT)
	assert_eq(basic.stats.blocked_moves, 1, "others hit the wall")


func test_navigator_matches_across_the_edge() -> void:
	var board: Board = _plain_board(5, Vector2i(0, 2))
	# LEFT로 (4,2)에 나오면: 위 (4,1) · 아래 (4,3) · 왼쪽 (3,2) · 오른쪽 = 반대편 (0,2) (원래 (4,2)의 블록이 온다)
	_paint(board, [Vector2i(4, 1), Vector2i(4, 3), Vector2i(3, 2), Vector2i(4, 2)] as Array[Vector2i], 3)
	var session: GameSession = _session(&"navigator", board)
	var cells: Array = []
	session.matched.connect(func(_c: Vector2i, _col: int, matched: Array[Vector2i]) -> void: cells.append_array(matched))
	session.request_move(Vector2i.LEFT)
	assert_eq(session.match_count, 1)
	assert_true(cells.has(Vector2i(0, 2)), "the opposite cell is a neighbor")


# --- 마라토너 -----------------------------------------------------------------

func test_marathon_flag_needs_a_match_first_then_gives_time() -> void:
	var session: GameSession = _session(&"marathon", _plain_board(5, Vector2i(1, 0)))
	var marathon: MarathonAbility = session.ability as MarathonAbility
	var gained: Array[float] = _gained(session)
	assert_eq(marathon.corner(0), Vector2i(0, 0), "top-left first")
	assert_eq([marathon.corner(1), marathon.corner(2), marathon.corner(3)], [Vector2i(0, 4), Vector2i(4, 4), Vector2i(4, 0)],
		"then bottom-left, bottom-right, top-right")
	session.request_move(Vector2i.LEFT)  # 매치 없이 깃발
	assert_eq(gained.size(), 0, "no match yet → nothing")
	assert_eq(marathon.target, 0)
	session.request_move(Vector2i.RIGHT)
	marathon.on_match(session, 0, [] as Array[Vector2i])  # 매치했다
	assert_eq(marathon.status_text(), "깃발 ↖ 준비 / +2초")
	session.request_move(Vector2i.LEFT)
	assert_eq(gained, [2.0] as Array[float], "+2 s")
	assert_eq(marathon.target, 1, "next corner")
	assert_false(marathon.flag_ready, "needs another match")
	assert_eq(marathon.laps, 1)


func test_marathon_marks_follow_the_flag() -> void:
	var session: GameSession = _session(&"marathon", _plain_board(5, Vector2i(2, 2)))
	var sent: Array = []
	session.marks_changed.connect(func(marks: Array[BoardMark]) -> void: sent.append(marks))
	var marks: Array[BoardMark] = session.board_marks()
	assert_eq([marks[0].kind, marks[0].rect], [BoardMark.Kind.FLAG, Rect2i(0, 0, 1, 1)])
	assert_eq([marks[1].kind, marks[1].rect], [BoardMark.Kind.FLAG_NEXT, Rect2i(0, 4, 1, 1)])
	(session.ability as MarathonAbility).on_match(session, 0, [] as Array[Vector2i])
	assert_eq(sent.size(), 1)
	assert_eq((sent[0][0] as BoardMark).kind, BoardMark.Kind.FLAG_READY)


func test_board_channel_sends_marks_on_bind() -> void:
	var channel: BoardChannel = BoardChannel.new()
	var got: Array = []
	channel.marks_changed.connect(func(marks: Array[BoardMark]) -> void: got.append(marks.size()))
	channel.bind(_session(&"marathon"), _roster().find(&"marathon"))
	channel.bind(_session(&"basic"), _roster().find(&"basic"))
	assert_eq(got, [2, 0])
	channel.free()


# --- 현상금 사냥꾼 ---------------------------------------------------------------

func test_bounty_color_changes_every_10_seconds_to_a_different_color() -> void:
	var session: GameSession = _session(&"bounty")
	var bounty: BountyAbility = session.ability as BountyAbility
	var announced: Array[String] = []
	session.ability_announced.connect(func(text: String) -> void: announced.append(text))
	var colors: Array[int] = [bounty.bounty_color]
	for _i: int in 5:
		_run(session, 10.0)
		colors.append(bounty.bounty_color)
	for i: int in range(1, colors.size()):
		assert_ne(colors[i], colors[i - 1], "differs from the previous color")
		assert_true(colors[i] >= 0 and colors[i] < 4)
	assert_eq(announced.size(), 5)
	assert_eq(announced[0], "현상금: %s" % Board.COLOR_NAMES[colors[1]])


func test_bounty_change_is_frame_rate_independent_and_seeded() -> void:
	var results: Array = []
	for frame: float in [1.0 / 30.0, 1.0 / 120.0, 0.25, 7.0]:
		var session: GameSession = _session(&"bounty", null, 9)
		var times: Array[float] = []
		var session_ref: WeakRef = weakref(session)
		session.ability_announced.connect(func(_t: String) -> void: times.append(snappedf((session_ref.get_ref() as GameSession).elapsed, 1e-6)))
		_run(session, 35.0, frame)
		results.append([times, (session.ability as BountyAbility).bounty_color])
	assert_eq(results[0][0], [10.0, 20.0, 30.0] as Array[float])
	for result: Array in results:
		assert_eq(result, results[0])


func test_bounty_color_match_gives_two_more_seconds() -> void:
	var probe: GameSession = _session(&"bounty", _match_ready_board())
	var color: int = (probe.ability as BountyAbility).bounty_color  # 같은 seed면 같은 색
	var hit: GameSession = _session(&"bounty", _match_ready_board(color))
	var gained: Array[float] = _gained(hit)
	hit.request_move(Vector2i.UP)
	assert_eq(gained, [4.5] as Array[float], "2.5 + 2")
	var miss: GameSession = _session(&"bounty", _match_ready_board((color + 1) % 4))
	var missed: Array[float] = _gained(miss)
	miss.request_move(Vector2i.UP)
	assert_eq(missed, [2.5] as Array[float])


func test_bounty_background_is_the_bounty_color_and_blinks_two_seconds_before() -> void:
	var session: GameSession = _session(&"bounty")
	var bounty: BountyAbility = session.ability as BountyAbility
	_run(session, 3.0)
	assert_near(bounty.effect_remaining(), 7.0, 1e-6)
	assert_eq(bounty.effect_block_color(), bounty.bounty_color)
	assert_near(bounty.effect_blink_window(), 2.0)
	assert_eq(bounty.status_text(), "현상금 %s / 7초" % Board.COLOR_NAMES[bounty.bounty_color])


# --- 화가 ---------------------------------------------------------------------

func test_painter_paints_the_trail_first_with_the_most_advanced_recipe_color() -> void:
	var session: GameSession = _session(&"painter", _plain_board(7, Vector2i(3, 3)))
	var board: Board = session.board
	session.recipes.set_recipe_colors(0, PackedInt32Array([0, 1]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([2, 2, 1]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([1, 1, 3, 0]))
	session.recipes.recipes[2].progress = 2  # 0.5 → 가장 앞섬, 다음 색 초록(3)
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP]:
		session.request_move(dir)
	var trail: Array[Vector2i] = [Vector2i(5, 3), Vector2i(4, 3), Vector2i(3, 3)]  # 최근 것부터
	board.get_cell(Vector2i(4, 3)).attach_coin(10.0)
	var changed: Array = []
	session.cells_changed.connect(func(cells: Array[Vector2i]) -> void: changed.append_array(cells))
	var messages: Array[String] = []
	session.ability_triggered.connect(func(message: String) -> void: messages.append(message))
	var matches: int = session.match_count
	for color: int in session.character.condition_colors:
		session.advance_ability_condition(color)
	assert_eq(messages, ["칠하기: 블록 5개"] as Array[String])
	assert_eq(changed.size(), 5)
	var painted_trail: int = 0
	for pos: Vector2i in trail:
		assert_eq(board.get_color(pos), 3, "trail cell %s is green (painted or already green)" % pos)
		if changed.has(pos):
			painted_trail += 1
	assert_eq(changed.slice(0, painted_trail), trail.filter(func(p: Vector2i) -> bool: return changed.has(p)),
		"trail cells are painted first, most recent first")
	for pos: Vector2i in changed:
		assert_eq(board.get_color(pos), 3)
		assert_eq(board.get_cell_type(pos), Board.CellType.COLOR_BLOCK)
		assert_ne(pos, board.player_pos)
	assert_true(board.has_coin(Vector2i(4, 3)), "coin kept")
	assert_eq(session.match_count, matches, "no auto match")


func test_painter_skips_seeds_and_fills_up_from_the_nearest_cells() -> void:
	var session: GameSession = _session(&"painter", _plain_board(7, Vector2i(3, 3)))
	var board: Board = session.board
	for slot: int in 3:
		session.recipes.set_recipe_colors(slot, PackedInt32Array([2, 2]))  # 모두 같은 비율 → 앞 슬롯, 다음 색 파랑(2)
	session.request_move(Vector2i.LEFT)  # 지나온 길: (3,3)
	board.set_seed(Vector2i(3, 3), 1, 1.0, 1.0)
	var changed: Array = []
	session.cells_changed.connect(func(cells: Array[Vector2i]) -> void: changed.append_array(cells))
	for color: int in session.character.condition_colors:
		session.advance_ability_condition(color)
	assert_false(changed.has(Vector2i(3, 3)), "seed skipped")
	assert_eq(changed.size(), 5)
	var player: Vector2i = board.player_pos
	var farthest: int = 0
	for pos: Vector2i in changed:
		farthest = maxi(farthest, Board.distance(pos, player))
	assert_true(farthest <= 2, "nearest blocks (distance ≤ 2)")


# --- 탐험가 -------------------------------------------------------------------

func test_explorer_zone_is_3x3_inside_the_board_away_from_the_player() -> void:
	for seed_value: int in 10:
		var session: GameSession = _session(&"explorer", null, seed_value)
		var zone: Rect2i = (session.ability as ExplorerAbility).zone
		assert_eq(zone.size, Vector2i(3, 3))
		assert_true(Rect2i(0, 0, 9, 9).encloses(zone))
		assert_false(zone.has_point(session.board.player_pos))
		assert_eq(session.board_marks()[0].kind, BoardMark.Kind.ZONE)


func test_explorer_match_in_zone_advances_the_advanced_recipes_once_more() -> void:
	var session: GameSession = _session(&"explorer", _match_ready_board(1))
	var explorer: ExplorerAbility = session.ability as ExplorerAbility
	explorer.zone = Rect2i(1, 1, 3, 3)  # (2,2) 포함
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([1, 0, 0, 0]))
	session.request_move(Vector2i.UP)
	assert_eq(session.score, 100, "slot 0: 1 + bonus 1 → completed")
	assert_eq(session.recipes.recipes[1].progress, 0, "not advanced → no bonus")
	assert_eq(session.recipes.recipes[2].progress, 2, "1 + bonus 1")
	assert_false(explorer.has_zone(), "zone used")
	assert_eq(explorer.bonuses, 1)


func test_explorer_bonus_goes_to_the_most_advanced_recipe_when_none_advanced() -> void:
	var session: GameSession = _session(&"explorer", _match_ready_board(1))
	(session.ability as ExplorerAbility).zone = Rect2i(1, 1, 3, 3)
	session.recipes.set_recipe_colors(0, PackedInt32Array([2, 2]))
	session.recipes.recipes[0].progress = 1  # 0.5, 125점
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 0, 0]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 2]))
	session.recipes.recipes[2].progress = 2  # 0.5, 900점 → 같은 비율이면 점수 높은 쪽
	session.request_move(Vector2i.UP)
	assert_eq(session.recipes.recipes[2].progress, 3)
	assert_eq(session.recipes.recipes[0].progress, 1)


func test_explorer_match_outside_zone_is_normal_and_zone_respawns_after_5_seconds() -> void:
	# 7x7 (5x5에서는 모든 3x3 자리가 가운데를 덮어 새 구역을 놓을 곳이 없다 → 나중에 다시 시도)
	var board: Board = _plain_board(7, Vector2i(2, 3))
	_paint(board, [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)] as Array[Vector2i], 1)
	var session: GameSession = _session(&"explorer", board)
	var explorer: ExplorerAbility = session.ability as ExplorerAbility
	explorer.zone = Rect2i(0, 0, 1, 1)  # (2,2) 밖
	session.recipes.set_recipe_colors(0, PackedInt32Array([1, 2]))
	session.request_move(Vector2i.UP)
	assert_eq(session.recipes.recipes[0].progress, 1, "no bonus outside")
	assert_true(explorer.has_zone(), "zone kept")
	explorer.zone = Rect2i(1, 1, 3, 3)
	session.request_move(Vector2i.DOWN)
	_match_cross(session.board, 0)
	session.request_move(Vector2i.UP)
	assert_false(explorer.has_zone())
	assert_eq(explorer.status_text(), "새 구역까지 5초")
	_run(session, 4.9)
	assert_false(explorer.has_zone())
	_run(session, 0.2)
	assert_true(explorer.has_zone(), "respawned")
	assert_false(explorer.zone.has_point(session.board.player_pos))


## 플레이어 위 칸을 중심으로 한 십자를 color로 (UP 이동 시 매치).
func _match_cross(board: Board, color: int) -> void:
	var center: Vector2i = board.player_pos + Vector2i.UP
	_paint(board, [center, center + Vector2i.UP, center + Vector2i.LEFT, center + Vector2i.RIGHT] as Array[Vector2i], color)
