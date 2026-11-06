class_name PuzzleRequest
extends RefCounted
## 퍼즐 화면에 무엇을 풀지 넘기는 값 (메뉴 > 퍼즐 → 퍼즐 화면). 씬 전환 사이에만 쓰고 take()로 비운다.

## 다음 퍼즐 화면이 풀 판 id (비어 있으면 목록의 첫 판).
static var pending_board: String = ""

var board_id: String = ""


static func board(id: String) -> void:
	pending_board = id


static func is_pending() -> bool:
	return pending_board != ""


## 넘겨받고 비운다.
static func take() -> PuzzleRequest:
	var request: PuzzleRequest = PuzzleRequest.new()
	request.board_id = pending_board
	pending_board = ""
	return request
