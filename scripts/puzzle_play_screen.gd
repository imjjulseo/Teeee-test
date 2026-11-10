class_name PuzzlePlayScreen
extends Node2D
## 퍼즐 화면 (기획서 8.8장, 메뉴 > 퍼즐): 고른 판부터 풀고, 결과의 "다음 퍼즐"로 목록의 다음 판을 이어서 푼다
## (마지막 판이면 "목록으로"). 처음 푼 판은 첫 클리어 코인 (PuzzleMenu).
## 퍼즐 진행은 PuzzleRunner(규칙 BlockPuzzle, 판 그림 BoardView ← BoardChannel), 결과 카드는 PuzzleResultPanel.
## 이 화면은 판을 고르고 기록을 남기고 글자를 보여 준다.

signal exit_requested

@export var book: PuzzleBook
@export var board_channel: BoardChannel
@export var theme_data: BoardTheme
## 퍼즐 판의 색 수 (본 게임 4색).
@export var color_count: int = 4
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var runner: PuzzleRunner
var request: PuzzleRequest
var menu: PuzzleMenu

var _store: PuzzleStore
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _label: String = ""
var _sub: String = ""
var _recorded_for: BlockPuzzle
## 결과 카드에서 "다음 퍼즐"로 이어 풀 판 (마지막 판이면 null → 목록으로).
var _next: PuzzleDef

@onready var _name_label: Label = %PuzzleName
@onready var _sub_label: Label = %PuzzleSub
@onready var _count_label: Label = %MoveCount
@onready var _tip_label: Label = %TipLabel
@onready var _undo_button: Button = %UndoButton
@onready var _reset_button: Button = %ResetButton
@onready var _hint_button: Button = %HintButton
@onready var _result: PuzzleResultPanel = %ResultPanel


func _ready() -> void:
	book = PuzzleBook.ensure_valid(book)
	_store = PuzzleStore.new(save_path)
	menu = PuzzleMenu.new(book, _store)
	_rng.randomize()
	request = PuzzleRequest.take()
	runner = PuzzleRunner.new(board_channel, book)
	runner.solved.connect(_on_solved)
	runner.result_ready.connect(_on_result_ready)
	runner.finished.connect(_on_finished)
	runner.changed.connect(_refresh_labels)
	var def: PuzzleDef = book.find_board(request.board_id) if not request.board_id.is_empty() else null
	if def == null and request.board_id.is_empty() and not menu.boards().is_empty():
		def = menu.boards()[0]
	if def == null:
		push_error("PuzzlePlayScreen: unknown board %s" % request.board_id)
		exit_requested.emit.call_deferred()
		return
	_start(def)


## 지금 퍼즐 (시작 전이면 null).
func puzzle() -> BlockPuzzle:
	return runner.puzzle if runner != null else null


func _process(delta: float) -> void:
	if puzzle() != null:
		runner.advance(delta)


func _start(def: PuzzleDef) -> void:
	var number: int = menu.number_of(def.id)
	var level: PuzzleLevel = book.level_of(def.id)
	var board: Board = Board.new(book.window_size + PuzzleGenerator.MARGIN * 2)
	var puzzle_now: BlockPuzzle = BlockPuzzle.new(board, def, _rng.randi_range(0, color_count - 1),
		Vector2i.ONE * PuzzleGenerator.MARGIN, book, color_count, _rng)
	puzzle_now.hide_goal = level != null and level.hide_goal
	_label = "퍼즐 %d" % number if number > 0 else "퍼즐"
	_sub = "%d / %d" % [number, menu.boards().size()] if number > 0 else ""
	_next = null
	runner.begin(puzzle_now)


## InputRouter.move_requested (puzzle_play.tscn에서 연결).
func _on_move_requested(dir: Vector2i, _hand: int) -> void:
	if puzzle() != null:
		runner.step(dir)


## 옆 칸 탭 (BoardView.cell_tapped).
func _on_cell_tapped(cell: Vector2i) -> void:
	if puzzle() == null:
		return
	var dir: Vector2i = Board.direction_from(runner.puzzle.board.player_pos, cell)
	if dir != Vector2i.ZERO:
		runner.step(dir)


func _on_undo_pressed() -> void:
	if puzzle() != null:
		runner.undo()


func _on_reset_pressed() -> void:
	if puzzle() != null:
		runner.reset()


func _on_hint_pressed() -> void:
	if puzzle() != null:
		runner.raise_hint()


func _on_exit_pressed() -> void:
	exit_requested.emit()


## 풀린 순간: 매치 연출만 (판은 그대로).
func _on_solved(center: Vector2i, color: int) -> void:
	board_channel.matched.emit(center, color, runner.puzzle.board.neighbors(center))


func _on_result_ready(info: PuzzleRunner.ResultInfo) -> void:
	var coins: int = _record(info.stars)
	var note: String = "첫 클리어 보상 ● %d" % coins if coins > 0 else ""
	_next = menu.next_after(runner.puzzle.def.id)
	_result.show_result(info, "다음 퍼즐" if _next != null else "목록으로", note)


## 결과 기록은 퍼즐마다 처음 결과에서 한 번 (정답 보기·다시 해 보기 뒤에는 다시 세지 않는다).
## 처음 푼 판이면 첫 클리어 보상을 받는다 (E28). 받은 코인 (없으면 0).
func _record(stars: int) -> int:
	if _recorded_for == runner.puzzle:
		return 0
	_recorded_for = runner.puzzle
	_store.record_board(runner.puzzle.def.id, stars)
	return menu.claim(runner.puzzle.def.id, ProgressStore.new(save_path))


func _on_finished(_stars: int) -> void:
	if _next != null:
		_start(_next)
	else:
		exit_requested.emit()


## 결과 카드 버튼 (puzzle_play.tscn에서 연결).
func _on_result_replay() -> void:
	runner.start_replay()


func _on_result_retry() -> void:
	runner.retry()


func _on_result_next() -> void:
	runner.accept()


func _refresh_labels() -> void:
	if puzzle() == null:
		return
	var puzzle_now: BlockPuzzle = runner.puzzle
	var replaying: bool = runner.phase == PuzzleRunner.Phase.REPLAY
	_name_label.text = "정답 다시 보기" if replaying else _label
	_sub_label.text = _sub + (" · 되돌리기 %d번" % puzzle_now.undos if puzzle_now.undos > 0 and not replaying else "")
	_count_label.text = "%d수 · 최소 %d수" % [runner.shown_moves(), puzzle_now.min_moves]
	_tip_label.text = runner.tip_text()
	_tip_label.add_theme_color_override("font_color", theme_data.puzzle_pull_color if runner.tip_emphasized() else Color.WHITE)
	var playing: bool = runner.is_playing()
	_undo_button.disabled = not playing or not puzzle_now.can_undo()
	_reset_button.disabled = not playing or puzzle_now.moves.is_empty()
	_hint_button.disabled = not playing or puzzle_now.hint >= BlockPuzzle.Hint.ARROW


## 지금 보이는 안내 문구 (테스트/디버그용).
func tip_text() -> String:
	return _tip_label.text
