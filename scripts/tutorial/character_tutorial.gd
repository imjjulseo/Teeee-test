class_name CharacterTutorial
extends Resource
## 캐릭터 한 명의 튜토리얼 (기획서 8.8장, HTML CT · CTL): ① 소개 → ② 캐릭터 족보·발동해 보기 퍼즐(발동형만)
## → ③ 활용 연습(lessons) → 실전 판. 실전 판까지 처음 일어나는 순간(on_trigger · moments)을 한 번씩 설명한다.
## 공통 문구와 발동 퍼즐 모양은 CharacterTutorialBook.

@export var character_id: StringName = &""
## 한 줄 소개 제목 (예: "시간 정지").
@export var cap: String = ""
@export_multiline var description: String = ""
## 소개 때 밝힐 곳 (캐릭터 카드는 늘 함께 밝힌다).
@export var intro_holes: PackedStringArray = PackedStringArray()
## 처음 발동했을 때 (발동형만).
@export var on_trigger: TutorialMoment
## 그 뒤 처음 일어나는 순간들.
@export var moments: Array[TutorialMoment] = []
## moments 중 하나만 보여 주면 끝 (수선사: 성공이든 실패든 한 번).
@export var any_moment: bool = false
## 활용 연습 단계.
@export var lessons: Array[CharacterLessonStep] = []


func validate(book: PuzzleBook) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if character_id == &"":
		errors.append("character tutorial without character_id")
	for moment: TutorialMoment in moments:
		if moment == null or moment.event == &"":
			errors.append("%s: empty moment" % character_id)
	for lesson: CharacterLessonStep in lessons:
		if lesson == null:
			errors.append("%s: empty lesson" % character_id)
			continue
		for error: String in lesson.validate(book):
			errors.append("%s: %s" % [character_id, error])
	return errors
