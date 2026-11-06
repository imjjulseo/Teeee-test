class_name MatchStep
extends TutorialStep
## 자유 매치 목표 (실제 판에서 직접): 조작 설명(ACT)을 띄우고 목표를 채우면 다음 단계.
## 목표: MATCHES 매치 count번 / ADVANCE_TOGETHER 한 번 매치로 족보 count장 이상 진행 /
## COMPLETIONS 족보 완성 누적 count장 / COMPLETE_TOGETHER 한 번에 족보 count장 완성.
## filter를 통과하지 못한 매치는 세지 않고 wrong_text를 보여 준다. 가만히 있으면 만들 자리 → 첫 수 화살표 힌트 (hints).

enum Goal { MATCHES, ADVANCE_TOGETHER, COMPLETIONS, COMPLETE_TOGETHER }
enum Filter { ANY, NOT_NEXT, RECIPE_NEXT, LETTER_A }

@export var goal: Goal = Goal.MATCHES
@export var count: int = 1
@export var filter: Filter = Filter.ANY
@export var head: String = ""
## {done} / {count} 진행을 넣을 수 있다.
@export_multiline var text: String = ""
## 진행이 오를 때마다 바꿀 설명 (비어 있으면 text 그대로).
@export var progress_text: String = ""
@export_multiline var wrong_text: String = ""
@export var holes: PackedStringArray = PackedStringArray()
@export var hints: bool = true
## 규칙 튜토리얼 힌트 (HTML tFree): 배운 모양(있는 T로 들어가기)만, 판을 고쳐서라도 만들 수 있게. 칭찬은 수에 따라 자동.
@export var rule_hints: bool = false
## 진행할 때 떠오르는 말, 다 채웠을 때의 말.
@export var cheer: String = "좋아요!"
@export var cheer_done: String = "좋아요!"
## 다 채운 뒤 다음 단계까지(초).
@export var done_pause: float = 0.5

var _done: int = 0
var _wait: float = -1.0


func start(director: TutorialDirector) -> void:
	_done = 0
	_wait = -1.0
	director.act(director.fill(head), _text(director), holes)
	if rule_hints:
		director.begin_rule_free(0, _color_filter(director))
	else:
		director.begin_free(hints, _hint_filter(director))


func on_match(director: TutorialDirector, info: TutorialDirector.MatchInfo) -> void:
	if _wait >= 0.0:
		return
	if not _accepts(director, info):
		if not wrong_text.is_empty():
			director.set_caption(director.fill(wrong_text))
		return
	match goal:
		Goal.MATCHES:
			_done += 1
		Goal.ADVANCE_TOGETHER:
			_done = count if info.advanced >= count else _done
		Goal.COMPLETIONS:
			_done += info.completed
		Goal.COMPLETE_TOGETHER:
			_done = count if info.completed >= count else _done
	if _done >= count:
		director.cheer(cheer_done)
		_wait = done_pause
		director.end_free()
		return
	if goal == Goal.COMPLETIONS and info.completed == 0:
		return
	director.cheer(cheer)
	director.set_caption(_text(director))


func tick(director: TutorialDirector, delta: float) -> void:
	if _wait < 0.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		director.finish_step()


func _text(director: TutorialDirector) -> String:
	var template: String = progress_text if _done > 0 and not progress_text.is_empty() else text
	return director.fill(template).replace("{done}", str(mini(_done, count))).replace("{count}", str(count))


## 매치 정보 info.next_before = 매치 전 첫 족보의 다음 색.
func _accepts(director: TutorialDirector, info: TutorialDirector.MatchInfo) -> bool:
	match filter:
		Filter.NOT_NEXT:
			return info.color != info.next_before
		Filter.RECIPE_NEXT:
			return info.advanced > 0
		Filter.LETTER_A:
			return info.color == director.letter("A")
	return true


## 규칙 튜토리얼 힌트의 색 조건 (색 -> bool). HTML needF = 진행 중인 족보가 기다리는 색.
func _color_filter(director: TutorialDirector) -> Callable:
	match filter:
		Filter.RECIPE_NEXT:
			return func(color: int) -> bool: return director.recipe_nexts().has(color)
		Filter.NOT_NEXT:
			return func(color: int) -> bool: return color != director.first_recipe_next()
		Filter.LETTER_A:
			return func(color: int) -> bool: return color == director.letter("A")
	return Callable()


## 힌트가 고를 매치 (MatchPlanner.Plan) 조건.
func _hint_filter(director: TutorialDirector) -> Callable:
	match filter:
		Filter.NOT_NEXT:
			return func(plan: MatchPlanner.Plan) -> bool: return plan.color != director.first_recipe_next()
		Filter.RECIPE_NEXT:
			return func(plan: MatchPlanner.Plan) -> bool: return director.recipe_nexts().has(plan.color)
		Filter.LETTER_A:
			return func(plan: MatchPlanner.Plan) -> bool: return plan.color == director.letter("A")
	return Callable()
