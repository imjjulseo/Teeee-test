class_name PuzzleLevelStep
extends TutorialStep
## 블럭 모으기 단계 하나를 차례로 푼다 (규칙 튜토리얼 Lv.0~4): 판 가운데 창에 퍼즐을 깔고, 풀리면 본게임 매치로 처리
## (시간·씨앗·족보·금화). 결과 카드(별)를 보고 "다음"으로 다음 판. 모을 색은:
## RANDOM 무작위 / RECIPE_NEXT 첫 족보의 다음 색(족보가 없으면 [A, B] 한 장을 새로) / PAIR_CARDS 판마다 [X, ?] 두 장을 깔고 X.

enum Target { RANDOM, RECIPE_NEXT, PAIR_CARDS }

@export var level: int = 0
@export var target: Target = Target.RANDOM
## 마지막 판을 풀고 나면 씨앗이 자라지 않게 둔다 (다음 설명에서 자라는 모습을 보여 준다).
@export var hold_seeds_after: bool = false
## 퍼즐 설명에 족보 카드도 밝힌다.
@export var show_cards: bool = false

var _board_index: int = 0


func start(director: TutorialDirector) -> void:
	_board_index = 0
	var puzzle_level: PuzzleLevel = director.book.levels[level]
	director.banner("Lv.%d" % puzzle_level.level, "블럭 모으기 · %s" % puzzle_level.name, _start_board)


func on_puzzle_finished(director: TutorialDirector, _stars: int) -> void:
	_board_index += 1
	var puzzle_level: PuzzleLevel = director.book.levels[level]
	if _board_index >= puzzle_level.boards.size():
		director.finish_step()
	else:
		_start_board(director)


func validate(book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray() if level >= 0 and level < book.levels.size() else PackedStringArray(["puzzle level %d missing" % level])


func _start_board(director: TutorialDirector) -> void:
	var puzzle_level: PuzzleLevel = director.book.levels[level]
	var color: int = _target_color(director)
	var last: bool = _board_index == puzzle_level.boards.size() - 1
	director.start_puzzle(puzzle_level.boards[_board_index], color, puzzle_level.hide_goal, false, 0,
		"블럭 모으기 Lv.%d · %s" % [puzzle_level.level, puzzle_level.name], "%d / %d판" % [_board_index + 1, puzzle_level.boards.size()],
		PackedStringArray(["cards"]) if show_cards else PackedStringArray(), hold_seeds_after and last)


func _target_color(director: TutorialDirector) -> int:
	match target:
		Target.RECIPE_NEXT:
			if director.first_recipe_next() == Board.NO_COLOR:
				director.set_letter_cards([PackedStringArray(["A", "B"])], PackedInt32Array(), false)
			return director.first_recipe_next()
		Target.PAIR_CARDS:
			director.set_letter_cards([PackedStringArray(["A", "B"]), PackedStringArray(["A", "C"])], PackedInt32Array(), false)
			return director.letter("A")
	return director.random_color()
