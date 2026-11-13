extends "res://tests/framework/test_case.gd"
## 기획서 4.2~4.3장, E6: 씨앗 색 분산 규칙(RefillColorPicker), 씨앗 대기 → 자람 → 블록(RefillSystem), 리필 총시간.


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 5x5, 모든 칸 색 0, 플레이어 (4,4).
func _board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	board.set_player(Vector2i(4, 4))
	return board


func _cells(list: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(list)
	return cells


# --- 리필 총시간 -------------------------------------------------------------

func test_refill_total_ramps_from_8_to_2_over_90_seconds() -> void:
	var config: GameConfig = make_config()
	assert_near(config.refill_total_at(0.0), 8.0)
	assert_near(config.refill_total_at(45.0), 5.0)
	assert_near(config.refill_total_at(90.0), 2.0)
	assert_near(config.refill_total_at(200.0), 2.0, 1e-9, "stays at the end value")
	assert_near(config.refill_wait_share(), 3.0 / 8.0)


# --- 색 분산 규칙 -------------------------------------------------------------

func test_a_four_cell_match_plants_one_of_each_color() -> void:
	for seed_value: int in range(1, 30):
		var colors: Array[int] = RefillColorPicker.pick(2, 4, 4, PackedInt32Array([20, 20, 20, 20]), 20.0, _rng(seed_value))
		var sorted: Array[int] = colors.duplicate()
		sorted.sort()
		assert_eq(sorted, [0, 1, 2, 3] as Array[int], "seed %d" % seed_value)
		assert_eq(colors[3], 2, "the cleared color comes last")


func test_a_three_cell_match_plants_the_other_colors() -> void:
	var colors: Array[int] = RefillColorPicker.pick(1, 3, 4, PackedInt32Array([20, 17, 20, 20]), 20.0, _rng())
	var sorted: Array[int] = colors.duplicate()
	sorted.sort()
	assert_eq(sorted, [0, 2, 3] as Array[int])


func test_extra_cells_take_the_most_lacking_color() -> void:
	# 2색 판에서 5칸: 다른 색 1, 깬 색 1, 남은 3칸은 가장 모자란 색(깬 색 제외 → 색 1).
	var colors: Array[int] = RefillColorPicker.pick(0, 5, 2, PackedInt32Array([10, 5]), 10.0, _rng())
	assert_eq(colors, [1, 0, 1, 1, 1] as Array[int])


func test_most_lacking_breaks_ties_randomly_and_skips_the_excluded_color() -> void:
	var seen: Dictionary = {}
	for seed_value: int in range(1, 40):
		seen[RefillColorPicker.most_lacking(PackedInt32Array([1, 1, 1]), 0, 5.0, _rng(seed_value))] = true
	assert_eq(seen.keys().size(), 2, "ties between colors 1 and 2")
	assert_false(seen.has(0), "excluded color")


# --- 씨앗 단계 ----------------------------------------------------------------

func test_plant_sets_seeds_with_ramped_wait_and_grow() -> void:
	var board: Board = _board()
	var refill: RefillSystem = RefillSystem.new(board, make_config(), _rng())
	var cells: Array[Vector2i] = _cells([Vector2i(2, 1), Vector2i(2, 3), Vector2i(1, 2), Vector2i(3, 2)])
	refill.plant(cells, 0, 45.0)  # 총 5초 → 대기 1.875 + 자람 3.125
	for pos: Vector2i in cells:
		var cell: BoardCell = board.get_cell(pos)
		assert_eq(cell.type, Board.CellType.SEED)
		assert_eq(cell.seed_stage, BoardCell.SeedStage.WAITING)
		assert_near(cell.seed_remaining, 1.875)
		assert_near(cell.seed_grow_duration, 3.125)
	assert_near(refill.time_to_next_event(), 1.875)


func test_seed_waits_then_grows_then_matures_with_its_next_color() -> void:
	var board: Board = _board()
	board.set_seed(Vector2i(1, 1), 3, 1.0, 2.0)
	var refill: RefillSystem = RefillSystem.new(board, make_config(), _rng())
	var growing: Array = []
	var matured: Array = []
	refill.seeds_growing.connect(func(cells: Array[Vector2i]) -> void: growing.append_array(cells))
	refill.cells_matured.connect(func(cells: Array[Vector2i]) -> void: matured.append_array(cells))
	refill.advance(0.5)
	assert_near(board.get_grow_progress(Vector2i(1, 1)), 0.0, 1e-9, "no growth while waiting")
	refill.advance(0.5)
	assert_eq(growing, [Vector2i(1, 1)])
	assert_near(refill.time_to_next_event(), 2.0)
	refill.advance(1.0)
	assert_near(board.get_grow_progress(Vector2i(1, 1)), 0.5)
	refill.advance(1.0)
	assert_eq(matured, [Vector2i(1, 1)])
	assert_eq(board.get_cell_type(Vector2i(1, 1)), Board.CellType.COLOR_BLOCK)
	assert_eq(board.get_color(Vector2i(1, 1)), 3)
	assert_eq(refill.time_to_next_event(), INF)


func test_a_long_step_carries_over_into_growing() -> void:
	var board: Board = _board()
	board.set_seed(Vector2i(1, 1), 2, 1.0, 2.0)
	var refill: RefillSystem = RefillSystem.new(board, make_config(), _rng())
	refill.advance(1.5)
	assert_near(board.get_grow_progress(Vector2i(1, 1)), 0.25, 1e-9, "the extra 0.5 counts as growing")
	refill.advance(5.0)
	assert_eq(board.get_cell_type(Vector2i(1, 1)), Board.CellType.COLOR_BLOCK)


func test_mature_all_turns_every_seed_into_a_block() -> void:
	var board: Board = _board()
	board.set_seed(Vector2i(1, 1), 2, 3.0, 5.0)
	board.set_seed(Vector2i(3, 3), 1, 0.0, 0.1)
	var refill: RefillSystem = RefillSystem.new(board, make_config(), _rng())
	var matured: Array[Vector2i] = refill.mature_all()
	assert_eq(matured.size(), 2)
	assert_eq(board.count_type(Board.CellType.SEED), 0)
	assert_eq(board.get_color(Vector2i(1, 1)), 2)
	assert_eq(refill.mature_all().size(), 0, "nothing left to grow")


func test_advance_ignores_blocks() -> void:
	var board: Board = _board()
	var refill: RefillSystem = RefillSystem.new(board, make_config(), _rng())
	refill.advance(100.0)
	assert_eq(board.count_color_blocks(0), 24)
	assert_eq(refill.time_to_next_event(), INF)
