class_name BoardStep
extends TutorialStep
## 판·족보 카드 준비 (바로 다음 단계로): fresh면 실제 판처럼 새로 섞고(플레이어 자리 매치 없음),
## cards가 있으면 족보 카드를 그 글자 색으로 깐다. 글자: A = pick(지금 판에서 가장 빨리 매치할 수 있는 색 / 무작위),
## B · C = A와 다른 색들. 같은 단계 안에서 고른 글자 색은 다음 단계 문구에서도 쓴다. clear_cards면 카드를 모두 치운다.

enum Pick { PLAN, RANDOM, KEEP }

@export var fresh: bool = false
@export var cards: Array[PackedStringArray] = []
## 카드별로 이미 채운 칸 수.
@export var progress: PackedInt32Array = PackedInt32Array()
@export var pick: Pick = Pick.PLAN
@export var clear_cards: bool = false


func start(director: TutorialDirector) -> void:
	if fresh:
		director.random_board()
	if clear_cards:
		director.clear_cards()
	elif not cards.is_empty():
		if pick != Pick.KEEP:
			director.pick_letters(pick == Pick.PLAN)
		director.set_letter_cards(cards, progress, true)
	director.finish_step()
