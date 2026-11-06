class_name SayStep
extends TutorialStep
## 설명 한 장 (스포트라이트 TAP): 볼 곳(holes)을 밝히고, 누르면(버튼이 있으면 그 버튼) 다음 단계. 그동안 판은 멈춘다.
## grow_seeds면 설명이 떠 있는 동안 씨앗이 하나씩 자란다 (다시 자라는 칸 설명).

@export var head: String = ""
@export_multiline var text: String = ""
## 밝힐 곳 이름 (TutorialDirector.holes_for: cards · score · coin · time · player · puzzle · board_coins · seeds).
@export var holes: PackedStringArray = PackedStringArray()
@export var button: String = ""
@export var top: bool = false
@export var grow_seeds: bool = false


func start(director: TutorialDirector) -> void:
	director.say(director.fill(head), director.fill(text), holes, button, top)
	if grow_seeds:
		director.grow_held_seeds()


func on_tap(director: TutorialDirector) -> void:
	director.finish_step()
