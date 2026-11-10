class_name PuzzleBook
extends Resource
## 블록 모으기 퍼즐 데이터와 규칙 수치 (기획서 8.8장, HTML 블록 모으기 엔진). 튜토리얼 담당이 판·문구를 바꿀 수 있게 데이터로 둔다.

## 퍼즐 단계 (Lv.0·1 = 규칙 튜토리얼, in_menu 단계 = 메뉴 > 퍼즐).
@export var levels: Array[PuzzleLevel] = []
## 무작위 연습 난이도 (PuzzleGenerator). 11/06 메뉴 > 퍼즐에는 없다 — 생성기는 남겨 둔다.
@export var difficulties: Array[PuzzleDifficulty] = []
## 속 빈 모양 문제의 바탕 모양들 (4×4 안 좌표 4칸, 가운데(1,1)는 다른 색으로 남는다).
@export var hollow_shapes: Array[PackedVector2Array] = []

@export_group("Menu")
## 메뉴 > 퍼즐 판을 처음 풀면 판마다 한 번 받는 코인 (HTML PZ_COIN, 임시).
@export var menu_clear_coins: int = 20

@export_group("Rules")
## 퍼즐 창 크기 (칸).
@export var window_size: int = 5
## ★★ = 최소 + star_extra수 이내.
@export var star_extra: int = 3
## 가만히 있으면 이만큼 뒤 힌트가 한 단계 오른다(초, 판 기준 시간).
@export var idle_hint: float = 6.0
## 헛수를 이만큼 연달아 두면 힌트가 한 단계 오른다.
@export var waste_hint: int = 3
## 한 수에 남은 최소 수가 이만큼 이상 늘면 "모양이 깨졌어요".
@export var break_jump: int = 3
## 정답 다시 보기 한 수 간격(초).
@export var replay_step: float = 0.4
## 풀이기 한도: 기본 최대 깊이, 지금 남은 수 + 여유, 탐색 노드 수.
@export var solve_depth: int = 14
@export var solve_slack: int = 6
@export var solve_depth_cap: int = 20
@export var solve_nodes: int = 250000
## 연습 문제 생성 시도 수 (그래도 못 만들면 튜토리얼 판 하나).
@export var generate_tries: int = 400


func find_board(id: String) -> PuzzleDef:
	for level: PuzzleLevel in levels:
		for board: PuzzleDef in level.boards:
			if board.id == id:
				return board
	return null


func level_of(id: String) -> PuzzleLevel:
	for level: PuzzleLevel in levels:
		for board: PuzzleDef in level.boards:
			if board.id == id:
				return level
	return null


## 메뉴 > 퍼즐 판 (in_menu 단계의 판을 순서대로, 단계 구분 없이).
func menu_boards() -> Array[PuzzleDef]:
	var boards: Array[PuzzleDef] = []
	for level: PuzzleLevel in levels:
		if level.in_menu:
			boards.append_array(level.boards)
	return boards


func find_difficulty(id: StringName) -> PuzzleDifficulty:
	for difficulty: PuzzleDifficulty in difficulties:
		if difficulty.id == id:
			return difficulty
	return difficulties[0] if not difficulties.is_empty() else null


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	for level: PuzzleLevel in levels:
		for board: PuzzleDef in level.boards:
			if board.size() != window_size or board.target_cells().size() != 4:
				errors.append("board %s must be %d rows with 4 targets" % [board.id, window_size])
	if menu_clear_coins < 0:
		errors.append("menu_clear_coins must be >= 0")
	if idle_hint <= 0.0 or waste_hint <= 0:
		errors.append("hint timing must be > 0")
	return errors


static func ensure_valid(book: PuzzleBook) -> PuzzleBook:
	if book == null:
		push_error("PuzzleBook: book is null, using an empty book")
		return PuzzleBook.new()
	var errors: PackedStringArray = book.validate()
	if errors.is_empty():
		return book
	push_error("PuzzleBook: invalid settings, using an empty book instead: %s" % ", ".join(errors))
	return PuzzleBook.new()
