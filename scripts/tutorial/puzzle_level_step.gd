class_name PuzzleLevelStep
extends TutorialStep
## 블럭 모으기 단계 하나를 차례로 푼다 (규칙 튜토리얼 Lv.0·1, HTML tutLevel): 판 가운데 창에 퍼즐을 깔고, 풀리면 본게임 매치로 처리
## (시간·씨앗·족보·금화). 결과 카드(별)를 보고 "다음"으로 다음 판. 튜토리얼에는 단계 번호·이름을 보이지 않고
## 진행 막대("●●○" = 3판 중 2번째)만 보인다 (팀 결정 11/06, E28). 모을 색은:
## RANDOM 무작위 / RECIPE_NEXT 족보가 기다리는 색(규칙 튜토리얼은 HTML tg: 카드가 다 찼으면 새로 깖) / PAIR_CARDS 판마다 [X, ?] 두 장을 깔고 X.
## rule이면 HTML 규칙 튜토리얼처럼 판은 그대로 두고 내 주변 5×5에만 깐다 (TutorialDirector.start_rule_puzzle):
## 첫 판은 first_delay초 기다린 뒤 시작하고, 첫 판 문구·손가락 안내(first_caption · swipe_first), 풀린 첫 매치를 멈추는 설명(hold_text).

enum Target { RANDOM, RECIPE_NEXT, PAIR_CARDS }

@export var level: int = 0
@export var target: Target = Target.RANDOM
## 마지막 판을 풀고 나면 씨앗이 자라지 않게 둔다 (다음 설명에서 자라는 모습을 보여 준다).
@export var hold_seeds_after: bool = false
## 퍼즐 설명에 족보 카드도 밝힌다.
@export var show_cards: bool = false
## 규칙 튜토리얼 방식(내 주변 5×5에 깔기, 목표 점선 없음, 칭찬 결과).
@export var rule: bool = false
## 첫 판: 깐 뒤 조작을 받기까지(초, HTML 800ms).
@export var first_delay: float = 0.0
## 첫 판 안내 문구 (첫 수를 두면 판의 안내 문구로). 비어 있으면 판의 안내.
@export var first_caption: String = ""
## 첫 판: 첫 수 쪽으로 미는 손가락 안내.
@export var swipe_first: bool = false
## 첫 판이 풀리면 매치 전에 멈추고 띄울 설명 (둘러싼 4칸을 밝힌다). 비어 있으면 바로 매치.
@export_multiline var hold_text: String = ""

var _board_index: int = 0


func start(director: TutorialDirector) -> void:
	_board_index = 0
	_start_board(director)


func on_puzzle_finished(director: TutorialDirector, _stars: int) -> void:
	_board_index += 1
	var puzzle_level: PuzzleLevel = director.book.levels[level]
	if _board_index >= puzzle_level.boards.size():
		director.finish_step()
	else:
		_start_board(director)


## 몇 번째 판인지: n칸 중 index + 1칸을 칠한다 (HTML 11/06 pzSeg, 단계 번호·구분자 없음).
static func progress_dots(index: int, count: int) -> String:
	var filled: int = clampi(index + 1, 0, count)
	return "●".repeat(filled) + "○".repeat(count - filled)


func validate(book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray() if level >= 0 and level < book.levels.size() else PackedStringArray(["puzzle level %d missing" % level])


func _start_board(director: TutorialDirector) -> void:
	var puzzle_level: PuzzleLevel = director.book.levels[level]
	var color: int = _target_color(director)
	var last: bool = _board_index == puzzle_level.boards.size() - 1
	var first: bool = _board_index == 0
	var sub: String = PuzzleLevelStep.progress_dots(_board_index, puzzle_level.boards.size())
	var holes: PackedStringArray = PackedStringArray(["cards"]) if show_cards else PackedStringArray()
	if rule:
		director.start_rule_puzzle(puzzle_level.boards[_board_index], color, false, 0, sub, holes, hold_seeds_after and last,
			first_caption if first else "", first_delay if first else 0.0, swipe_first and first, hold_text if first else "")
		return
	director.start_puzzle(puzzle_level.boards[_board_index], color, puzzle_level.hide_goal, false, 0, "", sub,
		holes, hold_seeds_after and last)


func _target_color(director: TutorialDirector) -> int:
	match target:
		Target.RECIPE_NEXT:
			if rule:
				return director.recipe_target()
			if director.first_recipe_next() == Board.NO_COLOR:
				director.set_letter_cards([PackedStringArray(["A", "B"])], PackedInt32Array(), false)
			return director.first_recipe_next()
		Target.PAIR_CARDS:
			director.set_letter_cards([PackedStringArray(["A", "B"]), PackedStringArray(["A", "C"])], PackedInt32Array(), false)
			return director.letter("A")
	return director.random_color()
