extends "res://tests/framework/test_case.gd"
## 기능별 RNG 분리: 한 기능이 난수를 더/덜 뽑아도 다른 기능의 결과는 같아야 한다.


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## 5x5, 플레이어 (2,3). UP 이동 시 (2,2)에서 색 1 매치.
func _match_ready_board() -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 3))
	return board


func _layout(board: Board) -> PackedInt32Array:
	var colors: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in board.all_positions():
		colors.append(board.get_color(pos))
	return colors


## 매치 1회 후 씨앗 4칸의 자랄 색 (심은 순서 포함).
func _refill_colors_after_match(session: GameSession) -> PackedInt32Array:
	session.request_move(Vector2i.UP)
	var colors: PackedInt32Array = PackedInt32Array()
	for pos: Vector2i in session.board.neighbors(Vector2i(2, 2)):
		colors.append(session.board.get_color(pos))
	return colors


func test_derive_is_deterministic_and_streams_differ() -> void:
	var a: RandomNumberGenerator = GameRng.derive(42, GameRng.Stream.REFILL)
	var b: RandomNumberGenerator = GameRng.derive(42, GameRng.Stream.REFILL)
	var c: RandomNumberGenerator = GameRng.derive(42, GameRng.Stream.RECIPES)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	var seq_c: Array[int] = []
	for _i: int in 8:
		seq_a.append(a.randi())
		seq_b.append(b.randi())
		seq_c.append(c.randi())
	assert_eq(seq_a, seq_b, "same seed + stream → same sequence")
	assert_ne(seq_a, seq_c, "different streams → different sequences")


func test_refill_colors_do_not_depend_on_recipe_draws() -> void:
	var config: GameConfig = make_config()
	config.board_size = 5
	var plain: GameSession = GameSession.new(config, _rng(77), _match_ready_board())
	for slot: int in 3:
		plain.recipes.set_recipe_colors(slot, PackedInt32Array([0, 0]))  # 이번 매치로 완성되지 않음
	var completing: GameSession = GameSession.new(config, _rng(77), _match_ready_board())
	for slot: int in 2:
		completing.recipes.set_recipe_colors(slot, PackedInt32Array([2, 2]))
		completing.recipes.recipes[slot].progress = 1
	completing.apply_clear_to_recipes(2)  # 매치 전에 족보 2개 완성 → 새 족보를 뽑음 (예전엔 같은 RNG를 소비했다)
	assert_eq(completing.score, 250, "recipes were regenerated before the match")
	for slot: int in 3:
		completing.recipes.set_recipe_colors(slot, PackedInt32Array([0, 0]))
	assert_eq(_refill_colors_after_match(completing), _refill_colors_after_match(plain),
		"recipe regeneration must not shift refill colors")


func test_board_does_not_depend_on_recipe_configuration() -> void:
	var a_config: GameConfig = make_config()
	var b_config: GameConfig = make_config()
	b_config.recipe_lengths = PackedInt32Array([4, 4, 4])  # 족보를 더 많이 뽑는 설정
	var a: GameSession = GameSession.new(a_config, _rng(2024))
	var b: GameSession = GameSession.new(b_config, _rng(2024))
	assert_eq(_layout(a.board), _layout(b.board))


## 능력 RNG를 쓰는 테스트용 능력 (발동할 때마다 난수를 여러 번 뽑는다).
class DrawingAbility:
	extends Ability

	func trigger(session: GameSession) -> String:
		for _i: int in 10:
			session.get_rng().randi()
		return ""


func test_ability_draws_do_not_shift_refill_colors() -> void:
	var config: GameConfig = make_config()
	config.board_size = 5
	var character: CharacterData = CharacterData.new()
	character.ability = DrawingAbility.new()
	character.condition_colors = PackedInt32Array([0])
	var drawing: GameSession = GameSession.new(config, _rng(5), _match_ready_board(), character)
	var plain: GameSession = GameSession.new(config, _rng(5), _match_ready_board(), character)
	drawing.ability.trigger(drawing)  # 능력 RNG를 소비
	assert_eq(_refill_colors_after_match(drawing), _refill_colors_after_match(plain))


func test_same_seed_still_reproduces_whole_session() -> void:
	var results: Array = []
	for _i: int in 2:
		var session: GameSession = GameSession.new(make_config(), _rng(31337))
		var colors: Array = []
		for recipe: RecipeSet.Recipe in session.recipes.recipes:
			colors.append(recipe.colors)
		results.append([_layout(session.board), colors])
	assert_eq(results[0], results[1])
