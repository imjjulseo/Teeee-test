extends "res://tests/framework/test_case.gd"
## 12장 QA: 판 생성 / 랜덤 배치 / 기본 이동 / 교환 / 경계 (기획서 v1.0 2~3장)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _generate(board_size: int, seed_value: int, color_count: int = 4) -> Board:
	var config: GameConfig = make_config()
	config.board_size = board_size
	config.color_count = color_count
	return Board.generate(config, _rng(seed_value))


## 칸 전체 상태 스냅샷 (타입, 색, 씨앗 단계·남은 시간, 금화).
func _snapshot(board: Board) -> Array:
	var cells: Array = []
	for pos: Vector2i in board.all_positions():
		var cell: BoardCell = board.get_cell(pos)
		cells.append([cell.type, cell.color, cell.seed_stage, cell.seed_remaining, cell.coin_remaining])
	return cells


func _layout(board: Board) -> PackedInt32Array:
	var colors: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in board.all_positions():
		colors.append(board.get_color(pos))
	return colors


## 3x3 보드: 플레이어 중앙, 나머지는 색 0으로 채운 테스트용 보드.
func _small_board() -> Board:
	var board: Board = Board.new(3)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	board.set_player(Vector2i(1, 1))
	return board


# --- 판 생성 ----------------------------------------------------------------

func test_default_board_is_9x9_with_player_at_center() -> void:
	var board: Board = Board.generate(make_config(), _rng(1234))
	assert_eq(board.size, 9)
	assert_eq(board.player_pos, Vector2i(4, 4))
	assert_eq(board.get_cell_type(Vector2i(4, 4)), Board.CellType.PLAYER)
	assert_eq(board.count_type(Board.CellType.PLAYER), 1)
	assert_eq(board.count_type(Board.CellType.COLOR_BLOCK), 80)
	assert_eq(board.count_type(Board.CellType.SEED), 0)
	assert_eq(board.count_type(Board.CellType.EMPTY), 0)


func test_start_position_for_other_sizes() -> void:
	assert_eq(_generate(5, 1).player_pos, Vector2i(2, 2))
	assert_eq(_generate(7, 1).player_pos, Vector2i(3, 3))


func test_color_counts_follow_section_2_1_table() -> void:
	var cases: Array = [
		[9, 4, [20, 20, 20, 20]], [7, 4, [12, 12, 12, 12]], [9, 3, [27, 27, 26]],
	]
	for case: Array in cases:
		var board: Board = _generate(case[0], 42, case[1])
		for color: int in case[1]:
			assert_eq(board.count_color_blocks(color), case[2][color], "%dx%d %d colors, color %d" % [case[0], case[0], case[1], color])


func test_start_board_never_has_a_match_around_the_player() -> void:
	for seed_value: int in range(1, 201):
		var board: Board = _generate(9, seed_value)
		assert_eq(board.find_match(board.player_pos), Board.NO_COLOR, "seed %d" % seed_value)
		for color: int in 4:
			assert_eq(board.count_color_blocks(color), 20, "seed %d color %d keeps its count" % [seed_value, color])


func test_break_match_swaps_with_a_far_block_of_another_color() -> void:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 1 if (pos.x + pos.y) % 2 == 0 else 2)
	board.set_player(Vector2i(2, 2))
	for pos: Vector2i in board.neighbors(Vector2i(2, 2)):
		board.set_color_block(pos, 3)
	board.set_color_block(Vector2i(0, 0), 0)
	var before: PackedInt32Array = board.color_counts(4)
	board.break_match_at(Vector2i(2, 2), _rng(7), 50)
	assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR)
	assert_eq(board.color_counts(4), before, "only swaps colors")
	assert_ne(board.get_color(Vector2i(2, 1)), 3, "the upper neighbor changed")


# --- 랜덤 배치 -------------------------------------------------------------

func test_same_seed_gives_same_layout() -> void:
	assert_eq(_layout(_generate(9, 777)), _layout(_generate(9, 777)))


func test_different_seeds_change_layout() -> void:
	var base: PackedInt32Array = _layout(_generate(9, 1))
	var any_different: bool = false
	for seed_value: int in range(2, 6):
		if _layout(_generate(9, seed_value)) != base:
			any_different = true
	assert_true(any_different, "layouts should vary across seeds")


func test_random_seed_is_reproducible() -> void:
	var rng: RandomNumberGenerator = GameRng.create(0)
	var logged_seed: int = rng.seed
	var first: PackedInt32Array = _layout(Board.generate(make_config(), rng))
	assert_eq(_layout(Board.generate(make_config(), _rng(logged_seed))), first)


# --- 기본 이동 -------------------------------------------------------------

func test_each_direction_moves_exactly_one_cell() -> void:
	for dir: Vector2i in Board.DIRECTIONS:
		var board: Board = _generate(9, 5)
		var result: Board.MoveResult = board.try_move(dir)
		assert_true(result.is_accepted(), "dir %s" % dir)
		assert_eq(result.from, Vector2i(4, 4))
		assert_eq(result.to, Vector2i(4, 4) + dir)
		assert_eq(board.player_pos, Vector2i(4, 4) + dir, "dir %s" % dir)
		assert_eq(board.get_cell_type(board.player_pos), Board.CellType.PLAYER)
		assert_eq(board.count_type(Board.CellType.PLAYER), 1)


func test_invalid_directions_are_rejected() -> void:
	for dir: Vector2i in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, -2)]:
		var board: Board = _generate(9, 5)
		var before: Array = _snapshot(board)
		var result: Board.MoveResult = board.try_move(dir)
		assert_eq(result.outcome, Board.MoveOutcome.INVALID_DIRECTION, "dir %s" % dir)
		assert_false(result.is_accepted())
		assert_eq(board.player_pos, Vector2i(4, 4))
		assert_eq(_snapshot(board), before, "board must not change for dir %s" % dir)


func test_back_and_forth_restores_board() -> void:
	var board: Board = _generate(9, 9)
	var before: Array = _snapshot(board)
	board.try_move(Vector2i.RIGHT)
	board.try_move(Vector2i.LEFT)
	assert_eq(board.player_pos, Vector2i(4, 4))
	assert_eq(_snapshot(board), before)


func test_random_walk_keeps_board_consistent() -> void:
	var board: Board = _generate(9, 2024)
	var walk_rng: RandomNumberGenerator = _rng(99)
	for step: int in 2000:
		var dir: Vector2i = Board.DIRECTIONS[walk_rng.randi_range(0, 3)]
		var before_pos: Vector2i = board.player_pos
		var result: Board.MoveResult = board.try_move(dir)
		if result.is_accepted():
			assert_eq(board.player_pos, before_pos + dir, "step %d" % step)
		else:
			assert_eq(board.player_pos, before_pos, "step %d" % step)
	assert_eq(board.count_type(Board.CellType.PLAYER), 1)
	assert_eq(board.get_cell_type(board.player_pos), Board.CellType.PLAYER)
	for color: int in 4:
		assert_eq(board.count_color_blocks(color), 20, "color %d" % color)


# --- 교환 ------------------------------------------------------------------

func test_swap_with_color_block_exchanges_positions() -> void:
	var board: Board = _generate(9, 11)
	var target: Vector2i = Vector2i(4, 3)
	var target_color: int = board.get_color(target)
	var result: Board.MoveResult = board.try_move(Vector2i.UP)
	assert_eq(result.outcome, Board.MoveOutcome.SWAPPED)
	assert_eq(result.displaced_type, Board.CellType.COLOR_BLOCK)
	assert_eq(board.get_cell_type(target), Board.CellType.PLAYER)
	assert_eq(board.get_cell_type(Vector2i(4, 4)), Board.CellType.COLOR_BLOCK)
	assert_eq(board.get_color(Vector2i(4, 4)), target_color)
	assert_eq(board.get_color(target), Board.NO_COLOR)


func test_swap_with_seed_keeps_its_stage_time_and_next_color() -> void:
	var board: Board = _small_board()
	board.set_seed(Vector2i(2, 1), 3, 1.0, 2.0)
	board.get_cell(Vector2i(2, 1)).start_growing(0.25)
	var result: Board.MoveResult = board.try_move(Vector2i.RIGHT)
	assert_eq(result.outcome, Board.MoveOutcome.SWAPPED)
	assert_eq(result.displaced_type, Board.CellType.SEED)
	var moved: BoardCell = board.get_cell(Vector2i(1, 1))
	assert_eq(moved.type, Board.CellType.SEED)
	assert_eq(moved.color, 3)
	assert_eq(moved.seed_stage, BoardCell.SeedStage.GROWING)
	assert_near(moved.seed_remaining, 1.75)
	assert_near(board.get_grow_progress(Vector2i(1, 1)), 0.125)


func test_coin_moves_with_its_block() -> void:
	var board: Board = _small_board()
	board.get_cell(Vector2i(1, 0)).attach_coin(5.0)
	board.try_move(Vector2i.UP)
	assert_true(board.has_coin(Vector2i(1, 1)), "coin followed the block")
	assert_false(board.has_coin(Vector2i(1, 0)))
	assert_eq(board.coin_count(), 1)


func test_move_into_empty_leaves_empty_behind() -> void:
	var board: Board = _small_board()
	board.set_empty(Vector2i(1, 0))
	var result: Board.MoveResult = board.try_move(Vector2i.UP)
	assert_eq(result.outcome, Board.MoveOutcome.MOVED)
	assert_eq(board.player_pos, Vector2i(1, 0))
	assert_eq(board.get_cell_type(Vector2i(1, 1)), Board.CellType.EMPTY)
	assert_eq(board.get_color(Vector2i(1, 1)), Board.NO_COLOR)


func test_color_counts_include_seed_next_colors() -> void:
	var board: Board = _small_board()
	board.set_seed(Vector2i(0, 0), 2, 1.0, 1.0)
	board.set_color_block(Vector2i(2, 2), 3)
	assert_eq(board.color_counts(4), PackedInt32Array([6, 0, 1, 1]))


# --- 경계 ------------------------------------------------------------------

func test_wall_blocks_move_at_every_edge() -> void:
	var cases: Array = [
		[Vector2i(0, 0), Vector2i.LEFT], [Vector2i(0, 0), Vector2i.UP],
		[Vector2i(2, 0), Vector2i.RIGHT], [Vector2i(2, 0), Vector2i.UP],
		[Vector2i(0, 2), Vector2i.LEFT], [Vector2i(0, 2), Vector2i.DOWN],
		[Vector2i(2, 2), Vector2i.RIGHT], [Vector2i(2, 2), Vector2i.DOWN],
		[Vector2i(1, 0), Vector2i.UP], [Vector2i(1, 2), Vector2i.DOWN],
		[Vector2i(0, 1), Vector2i.LEFT], [Vector2i(2, 1), Vector2i.RIGHT],
	]
	for case: Array in cases:
		var pos: Vector2i = case[0]
		var dir: Vector2i = case[1]
		var board: Board = _small_board()
		board.set_color_block(Vector2i(1, 1), 0)
		board.set_player(pos)
		var before: Array = _snapshot(board)
		var result: Board.MoveResult = board.try_move(dir)
		assert_eq(result.outcome, Board.MoveOutcome.BLOCKED_BY_WALL, "pos %s dir %s" % [pos, dir])
		assert_eq(board.player_pos, pos)
		assert_eq(_snapshot(board), before, "board must not change at pos %s dir %s" % [pos, dir])


func test_player_never_leaves_board_when_pushing_wall() -> void:
	var board: Board = _generate(9, 3)
	for _i: int in 10:
		board.try_move(Vector2i.RIGHT)
	assert_eq(board.player_pos, Vector2i(8, 4))
	assert_eq(board.try_move(Vector2i.RIGHT).outcome, Board.MoveOutcome.BLOCKED_BY_WALL)
	assert_eq(board.player_pos, Vector2i(8, 4))
