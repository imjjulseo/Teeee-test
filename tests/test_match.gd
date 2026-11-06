extends "res://tests/framework/test_case.gd"
## 기획서 4.1 매치 조건 / 12장 매치 성공·실패 (Board 단위)


## 5x5, 모든 칸 color, 플레이어 (4,4) 구석 (중앙 주변 판정에 영향 없도록).
func _board_all(color: int) -> Board:
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, color)
	board.set_player(Vector2i(4, 4))
	return board


## center 주변 4칸을 지정 색으로 칠한 보드 (나머지는 filler 색).
func _cross(center: Vector2i, color: int, filler: int) -> Board:
	var board: Board = _board_all(filler)
	for pos: Vector2i in board.neighbors(center):
		board.set_color_block(pos, color)
	return board


func test_four_same_color_matches() -> void:
	var board: Board = _cross(Vector2i(2, 2), 3, 0)
	assert_eq(board.find_match(Vector2i(2, 2)), 3)


func test_center_cell_itself_is_not_checked() -> void:
	var board: Board = _cross(Vector2i(2, 2), 1, 0)
	board.set_color_block(Vector2i(2, 2), 2)
	assert_eq(board.find_match(Vector2i(2, 2)), 1)


func test_three_same_fails() -> void:
	var board: Board = _cross(Vector2i(2, 2), 1, 0)
	board.set_color_block(Vector2i(2, 1), 2)
	assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR)


func test_diagonal_only_fails() -> void:
	var board: Board = _board_all(0)
	for pos: Vector2i in [Vector2i(1, 1), Vector2i(3, 1), Vector2i(1, 3), Vector2i(3, 3)]:
		board.set_color_block(pos, 2)
	board.set_color_block(Vector2i(2, 1), 1)
	board.set_color_block(Vector2i(2, 3), 2)
	board.set_color_block(Vector2i(1, 2), 3)
	board.set_color_block(Vector2i(3, 2), 2)
	assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR)


func test_seed_neighbor_fails_even_with_same_next_color() -> void:
	for stage_growing: bool in [false, true]:
		var board: Board = _cross(Vector2i(2, 2), 1, 0)
		board.set_seed(Vector2i(1, 2), 1, 1.0, 1.0)
		if stage_growing:
			board.get_cell(Vector2i(1, 2)).start_growing(0.9)
		assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR, "growing=%s" % stage_growing)


func test_empty_neighbor_fails() -> void:
	var board: Board = _cross(Vector2i(2, 2), 1, 0)
	board.set_empty(Vector2i(3, 2))
	assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR)


func test_player_neighbor_fails() -> void:
	var board: Board = _cross(Vector2i(2, 2), 1, 0)
	board.set_color_block(Vector2i(4, 4), 0)
	board.set_player(Vector2i(2, 3))
	assert_eq(board.find_match(Vector2i(2, 2)), Board.NO_COLOR)


func test_edges_and_corners_never_match() -> void:
	var board: Board = _board_all(0)  # 모든 칸이 같은 색이어도
	for i: int in 5:
		for pos: Vector2i in [Vector2i(i, 0), Vector2i(i, 4), Vector2i(0, i), Vector2i(4, i)]:
			assert_eq(board.find_match(pos), Board.NO_COLOR, "edge %s" % pos)
	assert_eq(board.find_match(Vector2i(2, 2)), 0, "interior matches on uniform board")


func test_a_coin_does_not_change_matching() -> void:
	var board: Board = _cross(Vector2i(2, 2), 2, 0)
	board.get_cell(Vector2i(2, 1)).attach_coin(10.0)
	assert_eq(board.find_match(Vector2i(2, 2)), 2)
