class_name PuzzleMarks
extends RefCounted
<<<<<<< HEAD
## 블록 모으기 퍼즐의 판 위 안내 (BoardMark 목록): 퍼즐 창(점선), 모을 블록 테두리, 목표 모양, 힌트(설 칸·당길 블록·화살표).
=======
## 블럭 모으기 퍼즐의 판 위 안내 (BoardMark 목록): 퍼즐 창(점선), 모을 블록 테두리, 목표 모양, 힌트(설 칸·당길 블록·화살표).
>>>>>>> Choi
## 퍼즐 상태를 읽기만 한다.


## show_window = 퍼즐 창 테두리를 그린다 (판 전체가 퍼즐이면 끈다).
static func for_puzzle(puzzle: BlockPuzzle, show_window: bool) -> Array[BoardMark]:
	var marks: Array[BoardMark] = []
	if show_window:
		marks.append(BoardMark.new(BoardMark.Kind.ZONE, puzzle.window))
	if puzzle.finished:
		return marks
	var targets: Array[Vector2i] = puzzle.target_positions()
	for pos: Vector2i in targets:
		marks.append(BoardMark.at_cell(BoardMark.Kind.TARGET, pos))
	if puzzle.goal_visible():
		var center: Vector2i = puzzle.goal_center()
		marks.append(BoardMark.at_cell(BoardMark.Kind.GOAL_CENTER, center))
		for dir: Vector2i in Board.DIRECTIONS:
			var slot: Vector2i = center + dir
			marks.append(BoardMark.at_cell(BoardMark.Kind.GOAL_SLOT_FILLED if targets.has(slot) else BoardMark.Kind.GOAL_SLOT, slot))
	var pull: Array[Vector2i] = puzzle.pull_hint()
	if pull.size() == 2:
		marks.append(BoardMark.at_cell(BoardMark.Kind.STAND, pull[0]))
		marks.append(BoardMark.at_cell(BoardMark.Kind.PULL, pull[1]))
	var arrow: Vector2i = puzzle.arrow_hint()
	if arrow != Vector2i.ZERO:
		var mark: BoardMark = BoardMark.at_cell(BoardMark.Kind.ARROW, puzzle.board.player_pos + arrow)
		mark.direction = arrow
		marks.append(mark)
	return marks
