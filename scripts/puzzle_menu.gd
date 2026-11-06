class_name PuzzleMenu
extends RefCounted
## 메뉴 > 퍼즐의 판 목록과 첫 클리어 보상 (기획서 8.8장, 팀 결정 11/06, E28).
## - 판은 PuzzleBook.menu_boards() 순서(Lv.2~4, 단계 구분 없이)로 1번부터 번호를 붙인다. 모든 판이 처음부터 열려 있다.
## - 판을 처음 풀면 PuzzleBook.menu_clear_coins를 한 번 준다 (PuzzleStore.rewarded).
## 저장은 PuzzleStore(별·보상 기록)와 ProgressStore(코인)가 한다. 화면은 이 결과를 보여 주기만 한다.

var book: PuzzleBook
var store: PuzzleStore
var _boards: Array[PuzzleDef] = []


func _init(p_book: PuzzleBook, p_store: PuzzleStore) -> void:
	book = p_book
	store = p_store
	_boards = book.menu_boards()


## 목록의 판 (순서대로).
func boards() -> Array[PuzzleDef]:
	return _boards


## 목록 번호 (1부터, 목록에 없으면 0).
func number_of(id: String) -> int:
	return _index_of(id) + 1


## 다음 판 (마지막이거나 목록에 없으면 null).
func next_after(id: String) -> PuzzleDef:
	var index: int = _index_of(id)
	return _boards[index + 1] if index >= 0 and index + 1 < _boards.size() else null


## 이 판의 첫 클리어 보상 코인 (목록에 없는 판이면 0).
func reward_of(id: String) -> int:
	return book.menu_clear_coins if _index_of(id) >= 0 else 0


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
	for i: int in _boards.size():
		if _boards[i].id == id:
			return i
	return -1
