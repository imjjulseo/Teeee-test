class_name CharacterMomentGuide
extends RefCounted
## 캐릭터 튜토리얼에서 처음 일어난 순간을 한 번씩 고른다 (기획서 8.8장, HTML ctEv). 순수 규칙:
## - 발동형은 발동 설명(on_trigger)이 먼저, 그 전의 다른 순간은 건너뛴다.
## - 같은 순간은 한 번만. 발동 설명 뒤 moments가 없으면, 또는 moments를 다 보였거나 any_moment면 끝.
## 튜토리얼 판에서 시작해 이어지는 실전 판까지 같은 인스턴스로 이어 간다.

var tutorial: CharacterTutorial
var keyed: bool = false
var done: bool = false
var shown: Dictionary[StringName, bool] = {}


func _init(p_tutorial: CharacterTutorial, p_keyed: bool) -> void:
	tutorial = p_tutorial
	keyed = p_keyed


## 이 사건으로 띄울 설명 (없으면 null). 고르면 본 것으로 적는다.
func moment_for(event: StringName) -> TutorialMoment:
	if done or tutorial == null or shown.has(event):
		return null
	var moment: TutorialMoment = _find(event)
	if moment == null:
		return null
	var is_trigger: bool = event == TutorialMoment.ABILITY
	if not is_trigger and keyed and not shown.has(TutorialMoment.ABILITY):
		return null
	shown[event] = true
	if is_trigger:
		done = tutorial.moments.is_empty()
	else:
		done = tutorial.any_moment or _all_shown()
	return moment


func _find(event: StringName) -> TutorialMoment:
	if event == TutorialMoment.ABILITY:
		return tutorial.on_trigger if keyed else null
	for moment: TutorialMoment in tutorial.moments:
		if moment.event == event:
			return moment
	return null


func _all_shown() -> bool:
	for moment: TutorialMoment in tutorial.moments:
		if not shown.has(moment.event):
			return false
	return true
