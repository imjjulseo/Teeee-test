extends "res://tests/framework/test_case.gd"
## 기획서 4.4장, E9: 금화가 붙는 확률·최대 수, 수명, 줍기와 연속 보너스.


func _rng(seed_value: int = 1) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	board.set_player(Vector2i(4, 4))
	return board


func _always_config() -> GameConfig:
	var config: GameConfig = make_config()
	config.coin_chance = 1.0
	return config


func _cells(list: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(list)
	return cells


func test_matured_blocks_get_coins_up_to_the_maximum() -> void:
	var board: Board = _board()
	var coins: CoinSystem = CoinSystem.new(board, _always_config(), _rng())
	var changed: Array = []
	coins.coins_changed.connect(func(cells: Array[Vector2i]) -> void: changed.append_array(cells))
	coins.on_cells_matured(_cells([Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1)]))
	assert_eq(board.coin_count(), 3, "at most coin_max on the board")
	assert_eq(changed.size(), 3)
	assert_near(board.get_cell(Vector2i(0, 0)).coin_remaining, 15.0)


func test_coin_chance_zero_never_attaches_and_disabled_system_skips() -> void:
	var board: Board = _board()
	var config: GameConfig = make_config()
	config.coin_chance = 0.0
	CoinSystem.new(board, config, _rng()).on_cells_matured(_cells([Vector2i(0, 0), Vector2i(1, 0)]))
	assert_eq(board.coin_count(), 0)
	var disabled: CoinSystem = CoinSystem.new(board, _always_config(), _rng())
	disabled.enabled = false
	disabled.on_cells_matured(_cells([Vector2i(0, 0)]))
	assert_eq(board.coin_count(), 0)


func test_default_chance_is_about_ten_percent() -> void:
	var hits: int = 0
	var rng: RandomNumberGenerator = _rng(5)
	for _i: int in 2000:
		if GameRng.roll(rng, make_config().coin_chance):
			hits += 1
	assert_true(hits > 150 and hits < 250, "10%% of 2000 ≈ 200 (got %d)" % hits)


func test_coins_expire_after_their_life() -> void:
	var board: Board = _board()
	var coins: CoinSystem = CoinSystem.new(board, _always_config(), _rng())
	coins.on_cells_matured(_cells([Vector2i(1, 1)]))
	assert_near(coins.time_to_next_event(), 15.0)
	coins.advance(14.0)
	assert_true(board.has_coin(Vector2i(1, 1)))
	var expired: Array = []
	coins.coins_changed.connect(func(cells: Array[Vector2i]) -> void: expired.append_array(cells))
	coins.advance(1.0)
	assert_eq(expired, [Vector2i(1, 1)])
	assert_false(board.has_coin(Vector2i(1, 1)))
	assert_eq(coins.time_to_next_event(), INF)


func test_collect_chains_within_the_gap() -> void:
	var board: Board = _board()
	var coins: CoinSystem = CoinSystem.new(board, _always_config(), _rng())
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		board.get_cell(pos).attach_coin(100.0)
	assert_eq(coins.collect(_cells([Vector2i(0, 0), Vector2i(3, 3)])), 10, "first coin = 10")
	coins.advance(3.0)
	assert_eq(coins.collect(_cells([Vector2i(1, 0)])), 20, "within 4 s = second in a row")
	coins.advance(4.5)
	assert_eq(coins.collect(_cells([Vector2i(2, 0)])), 10, "chain broken after the gap")
	assert_eq(coins.collected, 40)
	assert_eq(board.coin_count(), 0)


func test_two_coins_in_one_match_chain_together() -> void:
	var board: Board = _board()
	var coins: CoinSystem = CoinSystem.new(board, _always_config(), _rng())
	board.get_cell(Vector2i(0, 0)).attach_coin(100.0)
	board.get_cell(Vector2i(1, 0)).attach_coin(100.0)
	var got: Array = []
	coins.coins_collected.connect(func(amount: int, chain: int) -> void: got.append([amount, chain]))
	assert_eq(coins.collect(_cells([Vector2i(0, 0), Vector2i(1, 0)])), 30, "10 + 20")
	assert_eq(got, [[30, 2]])
