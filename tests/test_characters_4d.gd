extends "res://tests/framework/test_case.gd"
## 4d 캐릭터 (기획서 5.2장): 제우스 · 사진사 · 방화광 · 마탄 · 레이서 · 파키케팔로사우르스 · 양손잡이.
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


## center를 중심으로 한 십자 4칸 (center 자신 포함, from 방향 칸 제외 = 그쪽에서 들어올 때 매치).
func _cross(board: Board, center: Vector2i, from: Vector2i, color: int) -> void:
	var cells: Array[Vector2i] = [center]
	for dir: Vector2i in Board.DIRECTIONS:
		if dir != from:
			cells.append(center + dir)
	_paint(board, cells, color)


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
		&"zeus": [[0, 0, 0, 0], "FFE14A"], &"photo": [[2, 0, 3, 1], "F4F4F4"], &"arson": [[], "FF7A3D"],
		&"madan": [[1, 3, 2, 0, 3], "C77DFF"], &"racer": [[], "FF9F45"], &"pachy": [[], "B8A06A"], &"ambi": [[], "FFB38A"],
	}
	for id: StringName in expected:
		var character: CharacterData = _roster().find(id)
		assert_eq(character.condition_colors, PackedInt32Array(expected[id][0]), "%s recipe" % id)
		assert_true(character.accent_color.is_equal_approx(Color(expected[id][1])), "%s color" % id)
	assert_eq(_roster().characters.size(), 32, "basic + 31")


# --- 제우스 -------------------------------------------------------------------

func test_zeus_absorbs_yellow_stops_time_and_strikes_recipes_in_order() -> void:
	var session: GameSession = _session(&"zeus", _plain_board(5, Vector2i(2, 2)))
	var zeus: ZeusAbility = session.ability as ZeusAbility
	var yellow: int = session.board.count_color_blocks(0)
	session.recipes.set_recipe_colors(1, PackedInt32Array([3, 3, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([3, 3, 3, 3]))
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
	assert_eq(messages, ["낙뢰: 노랑 %d개 흡수" % yellow] as Array[String])
	assert_eq(session.board.count_color_blocks(0), 0, "all yellow absorbed")
	assert_eq(zeus.strikes_left, yellow)
	assert_false(session.request_move(Vector2i.UP), "no input during the strikes")
	var remaining: float = session.remaining_time()
	_run(session, 0.99)
	assert_eq(session.recipes.recipes[2].progress, 0, "first strike after 1 s")
	_run(session, 0.02)
	assert_eq(session.recipes.recipes[2].progress, 1, "4-step recipe first")
	_run(session, 1.5)  # 1.5 · 2.0 · 2.5 초
	assert_eq(session.score, 1050, "4-step recipe completed (3,3,3,3 = 1,050)")
	_run(session, 0.5)
	assert_eq(session.recipes.recipes[1].progress, 1, "then the 3-step recipe")
	assert_near(session.remaining_time(), remaining, 1e-9, "time stopped")
	_run(session, 0.5 * yellow)
	assert_false(zeus.active, "ends one interval after the last strike")
	assert_true(session.request_move(Vector2i.UP))


func test_zeus_without_yellow_ends_quickly() -> void:
	var board: Board = _plain_board(5, Vector2i(2, 2))
	for pos: Vector2i in board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if board.get_color(pos) == 0:
			board.set_color_block(pos, 3)
	var session: GameSession = _session(&"zeus", board)
	var messages: Array[String] = []
	session.ability_triggered.connect(func(m: String) -> void: messages.append(m))
	_trigger(session)
	assert_eq(messages, ["낙뢰: 노랑이 없어요"] as Array[String])
	_run(session, 0.65)
	assert_false((session.ability as ZeusAbility).active)


func test_zeus_refill_stops_during_strikes() -> void:
	var session: GameSession = _session(&"zeus")
	session.board.set_seed(Vector2i(0, 0), 1, 0.0, 1.0)
	_trigger(session)
	_run(session, 1.0)
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.SEED, "refill clock stopped")


# --- 사진사 -------------------------------------------------------------------

func test_photo_plans_moves_while_time_and_refill_stop() -> void:
	var session: GameSession = _session(&"photo", _plain_board(9, Vector2i(4, 4)))
	var photo: PhotoAbility = session.ability as PhotoAbility
	session.board.set_seed(Vector2i(0, 0), 1, 0.0, 1.0)
	_trigger(session)
	assert_true(photo.planning)
	var start: Vector2i = session.board.player_pos
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP]:
		session.request_move(dir)
	assert_eq(session.board.player_pos, start, "planning does not move")
	assert_eq(photo.plan, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP] as Array[Vector2i])
	assert_eq(session.board_marks()[0].cells, [start, start + Vector2i(1, 0), start + Vector2i(2, 0), start + Vector2i(2, -1)] as Array[Vector2i])
	var remaining: float = session.remaining_time()
	_run(session, 6.9)
	assert_near(session.remaining_time(), remaining, 1e-9, "time stopped in the photo")
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.SEED, "refill stopped in the photo")
<<<<<<< HEAD
	assert_eq(photo.status_text(), "계획 3수 / 0.1초")
=======
	assert_eq(photo.status_text(), "계획 3수 · 0.1초")
>>>>>>> Choi


func test_photo_plan_stays_inside_the_board_and_is_capped() -> void:
	var session: GameSession = _session(&"photo", _plain_board(9, Vector2i(0, 4)))
	var photo: PhotoAbility = session.ability as PhotoAbility
	_trigger(session)
	session.request_move(Vector2i.LEFT)
	assert_eq(photo.plan.size(), 0, "no planning through the wall")
	for i: int in 70:
		session.request_move(Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT)
	assert_eq(photo.plan.size(), 60, "at most 60 moves")


func test_photo_replays_the_plan_with_speeding_gaps_then_pays_per_match() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	_cross(board, Vector2i(5, 3), Vector2i.DOWN, 1)  # RIGHT → UP 하면 (5,3)에서 빨강 매치
	var session: GameSession = _session(&"photo", board)
	var photo: PhotoAbility = session.ability as PhotoAbility
	_trigger(session)
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]:
		session.request_move(dir)
	var moved_at: Array[float] = []
	var session_ref: WeakRef = weakref(session)
	session.move_started.connect(func(_r: Board.MoveResult) -> void: moved_at.append((session_ref.get_ref() as GameSession).elapsed))
	var bonuses: Array = []
	session.bonus_scored.connect(func(points: int, label: String) -> void: bonuses.append([points, label]))
	var remaining: float = session.remaining_time()
	_run(session, 7.0)
	assert_true(photo.replaying)
	assert_false(session.request_move(Vector2i.DOWN), "input ignored while replaying")
	_run(session, 0.5)
	assert_eq(moved_at.size(), 3)
	assert_near(moved_at[0], 7.12, 1e-6, "first step after 0.12 s")
	assert_near(moved_at[1], 7.12 + 0.06 * 0.8, 1e-6, "then 0.06 × 0.8")
	assert_near(moved_at[2], 7.12 + 0.048 + 0.13, 1e-6, "a match pauses 0.13 s")
	assert_eq(session.match_count, 1)
	assert_eq(bonuses, [[250, "1연속!"]], "1 match → 250")
	assert_false(photo.replaying)
	assert_true(session.remaining_time() > remaining, "the replayed match gave time; the clock stood still otherwise")
	assert_eq(photo.bonus_for(2), 500)
	assert_eq(photo.bonus_for(6), 8000)
	assert_eq(photo.bonus_for(9), 8000, "capped at 6")


func test_photo_retrigger_while_replaying_takes_another_photo() -> void:
	var session: GameSession = _session(&"photo", _plain_board(9, Vector2i(4, 4)))
	var photo: PhotoAbility = session.ability as PhotoAbility
	_trigger(session)
	session.request_move(Vector2i.RIGHT)
	_run(session, 7.0)
	assert_true(photo.replaying)
	photo.trigger(session)
	_run(session, 0.5)
	assert_true(photo.planning, "a new photo after the replay")


# --- 마탄 ---------------------------------------------------------------------

func test_madan_shots_move_into_the_target_and_advance_recipes_without_matching() -> void:
	var session: GameSession = _session(&"madan", _plain_board(9, Vector2i(4, 4)))
	var madan: MadanAbility = session.ability as MadanAbility
	session.board.set_seed(Vector2i(0, 0), 1, 1.0, 1.0)
	session.recipes.set_recipe_colors(0, PackedInt32Array([0, 2]))  # (5,4) 노랑, (6,4) 파랑
	_trigger(session)
	assert_eq(session.board.get_cell_type(Vector2i(0, 0)), Board.CellType.COLOR_BLOCK, "seeds grown at once")
	assert_true(session.is_clock_stopped())
	session.request_move(Vector2i.RIGHT)
	assert_eq(session.board.player_pos, Vector2i(5, 4), "moved into the shot cell")
	assert_eq(session.board.get_cell_type(Vector2i(4, 4)), Board.CellType.SEED, "a seed where the player left")
	session.request_move(Vector2i.RIGHT)
	assert_eq(session.score, 125, "shot completion × 1.25 (100 → 125)")
	assert_eq(session.match_count, 0, "shots are not matches")
	assert_eq(session.ability_recipe.progress, 0, "character recipe not advanced by shots")
	assert_eq(madan.shots_used, 2)
	assert_eq(madan.hits, 2)


func test_madan_seventh_bullet_curses_after_six_shots() -> void:
	for curse: MadanAbility.Curse in [MadanAbility.Curse.TIME, MadanAbility.Curse.SCORE, MadanAbility.Curse.REGEN]:
		var session: GameSession = _session(&"madan", _plain_board(9, Vector2i(1, 4)))
		var madan: MadanAbility = session.ability as MadanAbility
		for slot: int in 3:  # 쏜 색으로 완성되지 않게 (빨강은 이 판에 없다)
			session.recipes.set_recipe_colors(slot, PackedInt32Array([1, 1]))
		_trigger(session)
		madan.curse = curse
		session.score = 1500
		var remaining: float = session.remaining_time()
		for _i: int in 6:
			session.request_move(Vector2i.RIGHT)
		assert_eq(madan.shots_used, 6)
		session.request_move(Vector2i.RIGHT)
		assert_eq(session.board.player_pos, Vector2i(7, 4), "no 7th shot")
		_run(session, 0.6)
		assert_true(madan.armed, "curse comes 0.65 s after the 6th shot")
		_run(session, 0.1)
		assert_false(madan.armed)
		match curse:
			MadanAbility.Curse.TIME:
				assert_near(session.remaining_time(), remaining - 8.0, 0.1, "−8 s (then the clock runs again)")
			MadanAbility.Curse.SCORE:
				assert_eq(session.score, 500, "−1,000")
			MadanAbility.Curse.REGEN:
				var seed_cell: BoardCell = session.board.get_cell(Vector2i(6, 4))
				assert_true(seed_cell.is_seed())
				assert_near(seed_cell.seed_remaining, 30.0, 0.1, "shot seeds wait 30 s")


func test_madan_time_limit_fires_the_curse() -> void:
	var session: GameSession = _session(&"madan")
	var madan: MadanAbility = session.ability as MadanAbility
	_trigger(session)
	madan.curse = MadanAbility.Curse.SCORE
	_run(session, 17.9)
	assert_true(madan.armed)
	_run(session, 0.2)
	assert_false(madan.armed, "18 s → 7th bullet")


func test_madan_curse_name_follows_the_values() -> void:
	var madan: MadanAbility = MadanAbility.new()
	madan.curse = MadanAbility.Curse.TIME
	assert_eq(madan.curse_name(), "시간 −8초")
	madan.curse = MadanAbility.Curse.SCORE
	assert_eq(madan.curse_name(), "점수 −1000")
	madan.curse = MadanAbility.Curse.REGEN
	assert_eq(madan.curse_name(), "재생 30초")


# --- 방화광 -------------------------------------------------------------------

func test_arson_starts_with_one_fire_away_from_the_player() -> void:
	var session: GameSession = _session(&"arson", _plain_board(9, Vector2i(4, 4)))
	var fires: Array[Vector2i] = []
	for pos: Vector2i in session.board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if session.board.get_color(pos) == 1:
			fires.append(pos)
	assert_eq(fires.size(), 1)
	assert_true(Board.distance(fires[0], Vector2i(4, 4)) >= 3)


## 보통 판(빨강 20개)에서 시작해도 불은 불씨 하나뿐이고 나머지 세 색이 고르다 (HTML: 방화광 판은 노랑·파랑·초록으로 만든다).
func test_arson_generated_board_starts_with_a_single_spark() -> void:
	for seed_value: int in 5:
		var config: GameConfig = make_config()
		var session: GameSession = GameSession.new(config, _rng(seed_value), null, _roster().find(&"arson"))
		var counts: PackedInt32Array = session.board.color_counts(4)
		assert_eq(counts[1], 1, "seed %d: one fire" % seed_value)
		for color: int in [0, 2, 3]:
			assert_true(counts[color] >= 25 and counts[color] <= 27, "seed %d: color %d even (%d)" % [seed_value, color, counts[color]])
		assert_eq(session.board.find_match(session.board.player_pos), Board.NO_COLOR, "no match around the player")


func test_arson_red_does_not_refill_and_red_matches_leave_embers() -> void:
	var arson: ArsonAbility = _session(&"arson").ability as ArsonAbility
	var rng: RandomNumberGenerator = _rng(3)
	assert_eq(arson.refill_colors([0, 1, 2, 3] as Array[int], 1, rng), [1, 1, 1, 1] as Array[int], "red match → embers")
	var other: Array[int] = arson.refill_colors([1, 1, 2, 3] as Array[int], 2, rng)
	assert_false(other.has(1), "red never refills (%s)" % [other])
	assert_eq(other.slice(2), [2, 3] as Array[int])


func test_arson_fire_spreads_every_4_seconds_after_a_warning() -> void:
	var session: GameSession = _session(&"arson", _plain_board(9, Vector2i(4, 4)))
	var arson: ArsonAbility = session.ability as ArsonAbility
	_run(session, 2.95)
	assert_eq(arson.warned.size(), 0)
	_run(session, 0.1)
	assert_true(arson.warned.size() > 0 and arson.warned.size() <= 3, "warned 1 s before (%d)" % arson.warned.size())
	assert_eq(session.board_marks().size(), arson.warned.size(), "warning marks")
	var targets: Array[Vector2i] = arson.warned.duplicate()
	_run(session, 1.0)
	for pos: Vector2i in targets:
		assert_eq(session.board.get_color(pos), 1, "%s caught fire" % pos)
	assert_eq(arson.warned.size(), 0)


func test_arson_red_match_advances_red_steps_twice_and_blue_gives_water() -> void:
	var session: GameSession = _session(&"arson")
	var arson: ArsonAbility = session.ability as ArsonAbility
	session.recipes.set_recipe_colors(1, PackedInt32Array([1, 2, 3]))
	session.recipes.set_recipe_colors(2, PackedInt32Array([0, 0, 0, 0]))
	session.apply_clear_to_recipes(1)
	assert_eq(session.recipes.recipes[1].progress, 2, "red step filled with red → 2 steps")
	arson.on_match(session, 2, [] as Array[Vector2i])
	assert_eq(arson.water, 1)
	for _i: int in 10:
		arson.on_match(session, 2, [] as Array[Vector2i])
	assert_eq(arson.water, 6, "max 6 drops")


func test_arson_long_press_puts_out_half_the_fire() -> void:
	var session: GameSession = _session(&"arson", _plain_board(9, Vector2i(4, 4)))
	var arson: ArsonAbility = session.ability as ArsonAbility
	var announced: Array[String] = []
	session.ability_announced.connect(func(t: String) -> void: announced.append(t))
	session.long_press()
	assert_eq(announced.back(), "물방울 0/2")
	arson.water = 4
	session.long_press()
	assert_eq(announced.back(), "불이 1칸뿐")
	_paint(session.board, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)] as Array[Vector2i], 1)
	var fires: int = session.board.count_color_blocks(1)
	session.long_press()
	assert_eq(announced.back(), "소화 %d칸" % (fires / 2), "half put out")
	assert_eq(arson.water, 2)
	assert_eq(session.board.count_color_blocks(1), fires - fires / 2)


func test_arson_reignites_3_seconds_after_the_fire_dies_out() -> void:
	var session: GameSession = _session(&"arson", _plain_board(9, Vector2i(0, 0)))
	for pos: Vector2i in session.board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if session.board.get_color(pos) == 1:
			session.board.set_color_block(pos, 3)
	_run(session, 2.9)
	assert_eq(session.board.count_color_blocks(1), 0)
	_run(session, 0.3)
	assert_eq(session.board.count_color_blocks(1), 1, "re-ignited after 3 s")
	for pos: Vector2i in session.board.positions_of_type(Board.CellType.COLOR_BLOCK):
		if session.board.get_color(pos) == 1:
			assert_eq(Board.distance(pos, Vector2i(0, 0)), 15, "farthest non-blue block ((8,8) is blue)")


# --- 레이서 -------------------------------------------------------------------

func test_racer_runs_by_itself_and_input_only_steers() -> void:
	var session: GameSession = _session(&"racer", _plain_board(9, Vector2i(4, 4)))
	var racer: RacerAbility = session.ability as RacerAbility
	session.request_move(Vector2i.UP)
	assert_eq(session.board.player_pos, Vector2i(4, 4), "input only turns")
	assert_eq(racer.direction, Vector2i.UP)
	_run(session, 0.14)
	assert_eq(session.board.player_pos, Vector2i(4, 3), "one cell per 0.13 s")
	_run(session, 0.13 * 6)
	assert_eq(session.board.player_pos, Vector2i(4, 0), "stops at the wall")
	assert_eq(session.stats.blocked_moves, 0, "standing at the wall is not a blocked input")


func test_racer_match_adds_half_a_second_per_cell_run() -> void:
	var board: Board = _plain_board(9, Vector2i(2, 4))
	_cross(board, Vector2i(5, 4), Vector2i.LEFT, 1)  # 오른쪽으로 3칸 달려 (5,4)에서 매치
	var session: GameSession = _session(&"racer", board)
	var gained: Array[float] = []
	session.time_gained.connect(func(s: float) -> void: gained.append(s))
	session.request_move(Vector2i.RIGHT)
	_run(session, 0.13 * 3 + 0.01)
	assert_eq(session.match_count, 1)
	assert_eq(gained.size(), 1)
	assert_near(gained[0], 2.5 + 3 * 0.5, 1e-9, "3 cells × 0.5 s")
	assert_eq((session.ability as RacerAbility).streak, 0)


func test_racer_turning_resets_the_streak() -> void:
	var session: GameSession = _session(&"racer", _plain_board(9, Vector2i(4, 4)))
	var racer: RacerAbility = session.ability as RacerAbility
	session.request_move(Vector2i.RIGHT)
	_run(session, 0.27)
	assert_eq(racer.streak, 2)
	session.request_move(Vector2i.DOWN)
	assert_eq(racer.streak, 0)
	assert_eq(racer.turns, 1)


# --- 파키케팔로사우르스 ------------------------------------------------------------

func test_pachy_holding_dashes_faster_and_faster_until_released() -> void:
	var session: GameSession = _session(&"pachy", _plain_board(9, Vector2i(0, 4)))
	var pachy: PachyAbility = session.ability as PachyAbility
	session.hold_direction(Vector2i.RIGHT)
	session.request_move(Vector2i.RIGHT)  # 누르기 시작한 입력의 한 칸
	session.request_move(Vector2i.RIGHT)  # 키 반복: 무시
	assert_eq(session.board.player_pos, Vector2i(1, 4))
	_run(session, 0.17)
	assert_false(pachy.dashing)
	_run(session, 0.02)
	assert_true(pachy.dashing, "held 0.18 s → dash")
	_run(session, 0.25)
	assert_eq(session.board.player_pos, Vector2i(2, 4), "first cell after 0.25 s")
	_run(session, 0.2)
	assert_eq(session.board.player_pos, Vector2i(3, 4), "then × 0.8")
	session.release_hold()
	_run(session, 1.0)
	assert_eq(session.board.player_pos, Vector2i(3, 4), "released → stops")


func test_pachy_dash_into_a_match_is_a_headbutt() -> void:
	var board: Board = _plain_board(9, Vector2i(0, 4))
	_cross(board, Vector2i(3, 4), Vector2i.LEFT, 1)
	var session: GameSession = _session(&"pachy", board)
	var bonuses: Array = []
	session.bonus_scored.connect(func(points: int, label: String) -> void: bonuses.append([points, label]))
	session.hold_direction(Vector2i.RIGHT)
	session.request_move(Vector2i.RIGHT)
	_run(session, 0.18 + 0.25 + 0.2 + 0.01)
	assert_eq(session.match_count, 1)
	assert_eq(bonuses, [[80, "박치기 2칸!"]], "20 × 2²")
	assert_false((session.ability as PachyAbility).dashing, "stops after the headbutt")
	assert_eq((session.ability as PachyAbility).headbutt_points(9), 500, "capped at 5 cells")


func test_pachy_dash_stops_at_the_wall() -> void:
	var session: GameSession = _session(&"pachy", _plain_board(9, Vector2i(7, 4)))
	session.hold_direction(Vector2i.RIGHT)
	session.request_move(Vector2i.RIGHT)
	_run(session, 0.18 + 0.25 + 0.01)
	assert_false((session.ability as PachyAbility).dashing)
	assert_eq(session.board.player_pos, Vector2i(8, 4))


# --- 양손잡이 -----------------------------------------------------------------

func test_ambi_has_two_players_controlled_by_hand() -> void:
	var session: GameSession = _session(&"ambi", _plain_board(9, Vector2i(4, 4)))
	var board: Board = session.board
	assert_eq(board.player_count(), 2)
	assert_eq([board.player_position(0), board.player_position(1)], [Vector2i(1, 4), Vector2i(7, 4)])
	assert_eq(board.count_type(Board.CellType.PLAYER), 2)
	assert_eq(board.count_type(Board.CellType.COLOR_BLOCK), 79)
	session.request_move(Vector2i.UP, 1)
	assert_eq(board.player_position(1), Vector2i(7, 3), "right hand moved")
	assert_eq(board.player_position(0), Vector2i(1, 4), "left hand stayed")
	session.request_move(Vector2i.DOWN, 0)
	assert_eq(board.player_position(0), Vector2i(1, 5))


func test_ambi_players_block_each_other_and_taps_pick_the_neighbor() -> void:
	var session: GameSession = _session(&"ambi", _plain_board(5, Vector2i(2, 2)))
	var board: Board = session.board
	assert_eq([board.player_position(0), board.player_position(1)], [Vector2i(1, 2), Vector2i(3, 2)])
	session.request_move(Vector2i.RIGHT, 0)
	assert_eq(board.player_position(0), Vector2i(2, 2), "left player into the middle")
	session.request_move(Vector2i.LEFT, 1)
	assert_eq(session.stats.blocked_moves, 1, "right player cannot step onto the left player")
	assert_eq(board.player_position(1), Vector2i(3, 2))
	var flow: GameFlow = GameFlow.new(make_config(), _roster().find(&"ambi"))
	flow.start_new_game(_rng())
	var right: Vector2i = flow.session.board.player_position(1)
	assert_true(flow.request_move_toward(right + Vector2i.UP), "tap next to the right player moves it")
	assert_eq(flow.session.board.player_position(1), right + Vector2i.UP)


func test_ambi_counts_matches_per_hand() -> void:
	var board: Board = _plain_board(9, Vector2i(4, 4))
	var session: GameSession = _session(&"ambi", board)
	_cross(board, Vector2i(7, 3), Vector2i.DOWN, 1)
	session.request_move(Vector2i.UP, 1)
	assert_eq(session.match_count, 1)
<<<<<<< HEAD
	assert_eq(session.ability.status_text(), "왼 0 / 오 1")
=======
	assert_eq(session.ability.status_text(), "왼 0 · 오 1")
>>>>>>> Choi
