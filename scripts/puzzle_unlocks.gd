class_name PuzzleUnlocks
extends RefCounted
## 블럭 모으기 단계 판의 열림과 첫 클리어 보상 (기획서 8.8장, 팀 결정 11/04, E27).
## - 판은 PuzzleBook 순서(Lv.0 → Lv.4, 단계 안의 판 순서)대로 하나씩 열린다: 첫 판은 늘 열려 있고,
##   그다음 판은 바로 앞 판을 한 번이라도 풀었으면(별 1개 이상) 열린다.
## - 보상 단계(PuzzleLevel.clear_coins > 0)의 판을 처음 풀면 그 코인을 한 번 준다 (PuzzleStore.rewarded).
## 저장은 PuzzleStore(별·보상 기록)와 ProgressStore(코인)가 한다. 화면은 이 결과를 보여 주기만 한다.

var book: PuzzleBook
var store: PuzzleStore
var _order: Array[PuzzleDef] = []
var _coins: Dictionary[String, int] = {}


func _init(p_book: PuzzleBook, p_store: PuzzleStore) -> void:
	book = p_book
	store = p_store
	for level: PuzzleLevel in book.levels:
		for def: PuzzleDef in level.boards:
			_order.append(def)
			_coins[def.id] = level.clear_coins


## 판이 열렸는지 (없는 id면 false).
func is_open(id: String) -> bool:
	var index: int = _index_of(id)
	if index < 0:
		return false
	return index == 0 or store.stars_of(_order[index - 1].id) > 0


## 이 판의 첫 클리어 보상 코인 (보상 없는 판이면 0).
func reward_of(id: String) -> int:
	return _coins.get(id, 0)


## 아직 받지 않은 보상 (받았거나 보상이 없으면 0).
func pending_reward(id: String) -> int:
	return 0 if store.is_rewarded(id) else reward_of(id)


## 판을 풀었으면 남은 보상을 준다. 준 코인 (없으면 0).
func claim(id: String, progress: ProgressStore) -> int:
	var coins: int = pending_reward(id)
	if coins <= 0 or store.stars_of(id) <= 0:
		return 0
	progress.add_currency(coins, 0)
	store.mark_rewarded(id)
	return coins


func _index_of(id: String) -> int:
	for i: int in _order.size():
		if _order[i].id == id:
			return i
	return -1
