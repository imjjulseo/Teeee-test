class_name TimeStep
extends TutorialStep
## 시간 배우기 (HTML 규칙 튜토리얼 "시간"): 남은 시간을 제한시간 × time_ratio로 맞추고 실제로 흐르게 한 채 자유 매치 한 번.
## 매치하면 다시 멈추고 done_pause초 뒤 다음 단계. 0초가 돼도 판은 끝나지 않는다 (HTML timeOn).

@export_multiline var text: String = "매치해서 시간을 늘려 보세요"
@export var holes: PackedStringArray = PackedStringArray()
@export var time_ratio: float = 0.6
@export var done_pause: float = 1.2

var _wait: float = -1.0


func start(director: TutorialDirector) -> void:
	_wait = -1.0
	director.begin_rule_free(0, Callable())
	director.run_tutorial_time(time_ratio)
	director.caption_icon(CaptionIcon.Kind.TIME)
	director.act("", text, holes)


func on_match(director: TutorialDirector, _match: TutorialDirector.MatchInfo) -> void:
	if _wait >= 0.0:
		return
	director.stop_tutorial_time()
	director.end_free()
	_wait = done_pause


func tick(director: TutorialDirector, delta: float) -> void:
	if _wait < 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		director.finish_step()
