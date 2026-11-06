class_name WaitStep
extends TutorialStep
## 잠깐 기다린다 (판 기준 시간).

@export var seconds: float = 0.5

var _left: float = 0.0


func start(_director: TutorialDirector) -> void:
	_left = seconds


func tick(director: TutorialDirector, delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		director.finish_step()
