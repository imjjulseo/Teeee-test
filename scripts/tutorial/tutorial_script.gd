class_name TutorialScript
extends Resource
## 규칙 튜토리얼 (기획서 8.8장): 튜토리얼 판 규칙과 단계 목록. 튜토리얼 담당이 이 리소스만 고치면 된다.
## 판: 3색·족보 카드는 단계가 깐다·리필 refill_time초 고정·남은 시간은 흐르지 않는다.
## 튜토리얼 흐름 수치(첫 뽑기로 나올 캐릭터, 튜토리얼 완료 업적 코인)도 여기 둔다.

@export var color_count: int = 3
@export var refill_time: float = 2.0
## 시작 판의 고정 시드 (HTML TUT_SEED, TutorialStartBoard). 0이면 실제 판처럼 무작위.
@export var start_seed: int = 8907
@export var steps: Array[TutorialStep] = []

@export_group("Flow")
## 튜토리얼 흐름의 첫 뽑기로 나오는 캐릭터 (아직 없는 것 중 무작위).
@export var first_pull: Array[StringName] = [&"gardener", &"clock"]
## 첫 뽑기 전 상점에 처음 들어오면 1회분 코인을 준다.
@export var gift_first_pull: bool = true
## 첫 실전 판 안내.
@export var real_game_head: String = "실전"
<<<<<<< HEAD
@export_multiline var real_game_text: String = "시간 안에 족보를 완성해 점수를 모아 보세요.\n움직이면 시작!"
=======
@export_multiline var real_game_text: String = "이제 시간 안에 족보를 완성해 점수를 얻어요. 움직이면 시간이 흘러요"
>>>>>>> Choi


## base 설정의 사본에 튜토리얼 판 규칙을 덮어쓴 설정.
func apply_to(base: GameConfig) -> GameConfig:
	var config: GameConfig = base.duplicate() as GameConfig
	config.color_count = color_count
	config.refill_total_start = refill_time
	config.refill_total_end = refill_time
	config.recipe_lengths = PackedInt32Array([2])
	return config


func validate(book: PuzzleBook) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if steps.is_empty():
		errors.append("tutorial has no steps")
	for step: TutorialStep in steps:
		if step == null:
			errors.append("empty tutorial step")
			continue
		errors.append_array(step.validate(book))
	return errors
