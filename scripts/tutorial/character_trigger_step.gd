class_name CharacterTriggerStep
extends TutorialStep
## 캐릭터 튜토리얼 "발동해 보기" (기획서 8.8장, HTML runCtLesson ③): 캐릭터 족보를 마지막 한 칸만 남기고,
<<<<<<< HEAD
## 그 색으로 블록 모으기 퍼즐 한 판(실제 판처럼 채움, 결과 카드 없음). 풀면 본게임 매치로 처리되어 능력이 발동한다.
=======
## 그 색으로 블럭 모으기 퍼즐 한 판(실제 판처럼 채움, 결과 카드 없음). 풀면 본게임 매치로 처리되어 능력이 발동한다.
>>>>>>> Choi
## CharacterTutorialBook이 공통 문구로 만든다. caption의 {target}·{target을}은 모을 색 이름.

@export var puzzle: PuzzleDef
@export var label: String = ""
@export var sub: String = ""
@export_multiline var caption: String = ""


func start(director: TutorialDirector) -> void:
	var session: GameSession = director.session
	session.prime_ability_condition()
	var target: int = session.ability_recipe.next_color()
	var word: String = TutorialDirector.color_name(target)
	var text: String = caption.replace("{target을}", TutorialDirector.with_object_particle(word)).replace("{target}", word)
	director.start_puzzle(puzzle, target, false, true, 0, label, sub, PackedStringArray(["chr"]), false, text, true)


func on_puzzle_finished(director: TutorialDirector, _stars: int) -> void:
	director.finish_step()


func validate(_book: PuzzleBook) -> PackedStringArray:
	return PackedStringArray() if puzzle != null and puzzle.target_cells().size() == 4 else PackedStringArray(["trigger puzzle needs 4 targets"])
