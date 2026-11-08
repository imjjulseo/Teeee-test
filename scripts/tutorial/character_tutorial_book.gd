class_name CharacterTutorialBook
extends Resource
## 캐릭터 튜토리얼 모음 (기획서 8.8장, HTML CT · CTL · runCtLesson): 캐릭터별 CharacterTutorial과 공통 문구·발동 퍼즐 모양.
## steps_for가 한 캐릭터의 튜토리얼 단계 목록을 만든다: 소개 → (발동형) 캐릭터 족보 설명 · 발동해 보기 → 활용 연습 → 준비 끝.
## 문구의 %s는 캐릭터 이름.

@export var tutorials: Array[CharacterTutorial] = []
## 발동해 보기 퍼즐 (캐릭터 족보 마지막 칸 색으로 ㅗ 만들기).
@export var trigger_puzzle: PuzzleDef

@export_group("Texts")
@export var recipe_head: String = "캐릭터 족보"
@export_multiline var recipe_text: String = "이 순서대로 매치하면 능력이 발동해요. 족보는 그대로 반복돼요"
@export var trigger_label: String = "%s · 발동해 보기"
@export var trigger_sub: String = "캐릭터 족보 마지막 칸"
@export_multiline var trigger_caption: String = "캐릭터 족보가 한 칸 남았어요. 흰 테두리 블럭으로 ㅗ를 만들어 {target을} 매치!"
@export var lesson_head: String = "%s · 활용"
@export var practice_label: String = "%s · 연습 판"
@export var ready_head: String = "%s 준비 끝"
@export_multiline var ready_text: String = "이제 실전이에요. 움직이면 시간이 흘러요"
## "준비 끝" 칸의 버튼 문구. 비어 있으면 다른 설명 칸처럼 화면을 눌러 넘긴다.
@export var ready_button: String = ""
@export var cheer: String = "좋아요!"
## 처음 쓰는 캐릭터에게 묻기 (HTML coach).
@export var offer_button: String = "튜토리얼"
@export var offer_skip_button: String = "바로 시작"


## 캐릭터의 튜토리얼 (없으면 null).
func find(id: StringName) -> CharacterTutorial:
	for tutorial: CharacterTutorial in tutorials:
		if tutorial != null and tutorial.character_id == id:
			return tutorial
	return null


## 소개 카드 제목 ("시계공 · 시간 정지").
func title_for(tutorial: CharacterTutorial, character: CharacterData) -> String:
	return "%s · %s" % [character.display_name, tutorial.cap]


## 한 캐릭터의 튜토리얼 단계 (발동형 = 캐릭터 족보가 있는 캐릭터).
func steps_for(tutorial: CharacterTutorial, character: CharacterData) -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	var keyed: bool = character.has_recipe()
	var intro_holes: PackedStringArray = PackedStringArray(["chr"]) if keyed else tutorial.intro_holes + PackedStringArray(["chr"])
	steps.append(CharacterTutorialBook._say(title_for(tutorial, character), tutorial.description, intro_holes))
	if keyed:
		steps.append(CharacterTutorialBook._say(recipe_head, recipe_text, PackedStringArray(["chr"])))
		var trigger: CharacterTriggerStep = CharacterTriggerStep.new()
		trigger.puzzle = trigger_puzzle
		trigger.label = trigger_label % character.display_name
		trigger.sub = trigger_sub
		trigger.caption = trigger_caption
		steps.append(trigger)
	for lesson: CharacterLessonStep in tutorial.lessons:
		steps.append(lesson)
	steps.append(CharacterTutorialBook._say(ready_head % character.display_name, ready_text, PackedStringArray(), ready_button))
	return steps


func validate(book: PuzzleBook) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if trigger_puzzle == null or trigger_puzzle.target_cells().size() != 4:
		errors.append("trigger puzzle needs 4 targets")
	var ids: Dictionary[StringName, bool] = {}
	for tutorial: CharacterTutorial in tutorials:
		if tutorial == null:
			errors.append("empty character tutorial")
			continue
		if ids.has(tutorial.character_id):
			errors.append("duplicate character tutorial %s" % tutorial.character_id)
		ids[tutorial.character_id] = true
		errors.append_array(tutorial.validate(book))
	return errors


static func _say(head: String, text: String, holes: PackedStringArray, button: String = "") -> SayStep:
	var step: SayStep = SayStep.new()
	step.head = head
	step.text = text
	step.holes = holes
	step.button = button
	return step
