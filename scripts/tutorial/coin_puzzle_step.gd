class_name CoinPuzzleStep
extends TutorialStep
## 금화 블럭 퍼즐 (규칙 튜토리얼 5): 모을 블록 몇 개에 금화를 붙인 빠른 퍼즐(힌트·결과 없음).
## 먼저 설명(TAP, 금화 칸·코인 표시를 밝힘)을 보여 주고, 누르면 조작 설명으로 바꿔 풀게 한다.

@export var board_id: String = "0a"
@export var coins: int = 1
@export var label: String = "코인 블럭"
@export var caption: String = "코인 블럭을 매치해 보세요"
@export var intro_head: String = ""
@export_multiline var intro_text: String = ""
@export var intro_holes: PackedStringArray = PackedStringArray(["board_coins", "coin"])

var _playing: bool = false


func start(director: TutorialDirector) -> void:
	_playing = false
	director.start_puzzle(director.book.find_board(board_id), director.random_color(), false, true, coins, label, "",
		PackedStringArray(["coin"]), false, caption)
	director.say(intro_head, intro_text, intro_holes)


func on_tap(director: TutorialDirector) -> void:
	if not _playing:
		_playing = true
		director.show_puzzle_caption()


func on_puzzle_finished(director: TutorialDirector, _stars: int) -> void:
	director.finish_step()


func validate(book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray() if book.find_board(board_id) != null else PackedStringArray(["coin puzzle board %s missing" % board_id])
