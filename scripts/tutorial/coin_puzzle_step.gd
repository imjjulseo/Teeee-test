class_name CoinPuzzleStep
extends TutorialStep
## 금화 블록 퍼즐 (규칙 튜토리얼 코인): 모을 블록 몇 개에 금화를 붙인 빠른 퍼즐(힌트·결과 없음).
## intro_text가 있으면 먼저 설명(TAP, 금화 칸·코인 표시를 밝힘)을 보여 주고, 누르면 조작 설명으로 바꿔 풀게 한다.
## rule이면 HTML 규칙 튜토리얼처럼 내 주변 5×5에 깔고(설명 없이 바로), target_recipe면 족보가 기다리는 색을 모은다 (HTML tg).
## reset_chain이면 시작할 때 금화 연속을 처음부터 (HTML coinChain = 0).

@export var board_id: String = "0a"
@export var coins: int = 1
@export var label: String = "코인 블록"
@export var caption: String = "코인 블록을 매치해 보세요"
@export var intro_head: String = ""
@export_multiline var intro_text: String = ""
@export var intro_holes: PackedStringArray = PackedStringArray(["board_coins", "coin"])
@export var rule: bool = false
@export var target_recipe: bool = false
@export var reset_chain: bool = false

var _playing: bool = false


func start(director: TutorialDirector) -> void:
	if reset_chain:
		director.session.coins.reset_chain()
	var color: int = director.recipe_target() if target_recipe else director.random_color()
	var def: PuzzleDef = director.book.find_board(board_id)
	if rule:
		_playing = true
		director.start_rule_puzzle(def, color, true, coins, Vector2i.ZERO, PackedStringArray(["coin"]), false, caption)
		return
	_playing = false
	director.start_puzzle(def, color, false, true, coins, label, "", PackedStringArray(["coin"]), false, caption)
	if intro_text.is_empty():
		_playing = true
		director.show_puzzle_caption()
	else:
		director.say(intro_head, intro_text, intro_holes)


func on_tap(director: TutorialDirector) -> void:
	if not _playing:
		_playing = true
		director.show_puzzle_caption()


func on_puzzle_finished(director: TutorialDirector, _stars: int) -> void:
	director.finish_step()


func validate(book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray() if book.find_board(board_id) != null else PackedStringArray(["coin puzzle board %s missing" % board_id])
