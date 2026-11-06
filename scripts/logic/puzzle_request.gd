class_name PuzzleRequest
extends RefCounted
## 블럭 모으기 화면에 무엇을 풀지 넘기는 값 (설정 > 블럭 모으기 → 퍼즐 화면). 씬 전환 사이에만 쓰고 take()로 비운다.

enum Mode { PRACTICE, BOARD }

## 다음 퍼즐 화면이 풀 것 (비어 있으면 연습 쉬움).
static var pending_mode: Mode = Mode.PRACTICE
static var pending_difficulty: StringName = &""
static var pending_board: String = ""

var mode: Mode = Mode.PRACTICE
var difficulty: StringName = &"easy"
var board_id: String = ""


static func practice(difficulty_id: StringName) -> void:
	pending_mode = Mode.PRACTICE
	pending_difficulty = difficulty_id
	pending_board = ""


static func board(id: String) -> void:
	pending_mode = Mode.BOARD
	pending_board = id
	pending_difficulty = &""


static func is_pending() -> bool:
	return pending_difficulty != &"" or pending_board != ""


## 넘겨받고 비운다.
static func take() -> PuzzleRequest:
	var request: PuzzleRequest = PuzzleRequest.new()
	request.mode = pending_mode
	request.board_id = pending_board
	if pending_difficulty != &"":
		request.difficulty = pending_difficulty
	pending_mode = Mode.PRACTICE
	pending_difficulty = &""
	pending_board = ""
	return request
