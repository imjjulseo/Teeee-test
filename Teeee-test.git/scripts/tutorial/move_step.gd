class_name MoveStep
extends TutorialStep
## 첫 이동 배우기: 조작 설명(ACT)과 움직일 방향 화살표를 띄우고, 한 번 움직이면 다음 단계.

@export var head: String = "스와이프해 보세요"
@export_multiline var text: String = "판 위에서 손가락을 밀면 움직여요"


func start(director: TutorialDirector) -> void:
	director.act(head, text, PackedStringArray())
	director.show_move_arrow()


func on_move(director: TutorialDirector) -> void:
	director.finish_step()


func on_match(director: TutorialDirector, _match: TutorialDirector.MatchInfo) -> void:
	director.finish_step()
