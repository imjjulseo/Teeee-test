class_name SayStep
extends TutorialStep
## 설명 한 장 (스포트라이트 TAP): 볼 곳(holes)을 밝히고, 누르면(버튼이 있으면 그 버튼) 다음 단계. 그동안 판은 멈춘다.
## grow_seeds면 설명이 떠 있는 동안 씨앗이 하나씩 자란다 (다시 자라는 칸 설명).
## release_seeds면 누른 뒤 묶어 둔 씨앗을 평소처럼 자라게 하고 다 자랄 때까지(최소 seed_min초, 최대 seed_max초) 기다린다
## (HTML: 자라는 칸 설명 → p.at = gclock → seedsGrown(ids, 400)).

@export var head: String = ""
@export_multiline var text: String = ""
## 밝힐 곳 이름 (TutorialDirector.holes_for: cards · score · coin · time · player · puzzle · board_coins · seeds).
@export var holes: PackedStringArray = PackedStringArray()
@export var button: String = ""
@export var top: bool = false
@export var grow_seeds: bool = false
@export var release_seeds: bool = false
@export var seed_min: float = 0.4
@export var seed_max: float = 3.5

var _waiting: float = -1.0


func start(director: TutorialDirector) -> void:
	_waiting = -1.0
	director.say(director.fill(head), director.fill(text), holes, button, top)
	if grow_seeds:
		director.grow_held_seeds()


func on_tap(director: TutorialDirector) -> void:
	if not release_seeds:
		director.finish_step()
		return
	if _waiting >= 0.0:
		return
	director.spotlight.close()
	director.release_held_seeds()
	_waiting = 0.0


func tick(director: TutorialDirector, delta: float) -> void:
	if _waiting < 0.0:
		return
	_waiting += delta
	var growing: bool = director.session.board.count_type(Board.CellType.SEED) > 0
	if (not growing and _waiting >= seed_min) or _waiting >= seed_max:
		_waiting = -1.0
		director.finish_step()
