class_name PuzzlePlayScreen
extends Node2D
## 블럭 모으기 퍼즐 화면 (기획서 8.8장, 설정 > 블럭 모으기): 연습(난이도별 무작위 문제를 계속) 또는 튜토리얼 판 하나.
## 퍼즐 진행은 PuzzleRunner(규칙 BlockPuzzle, 판 그림 BoardView ← BoardChannel), 결과 카드는 PuzzleResultPanel.
## 이 화면은 문제를 고르고(만들기는 프레임마다 몇 번씩) 기록을 남기고 글자를 보여 준다.

signal exit_requested

enum Phase { GENERATING, PUZZLE }

@export var book: PuzzleBook
@export var board_channel: BoardChannel
@export var theme_data: BoardTheme
## 연습 판의 색 수 (본 게임 4색).
@export var color_count: int = 4
## 문제 만들기: 한 프레임에 시도하는 수.
@export var generate_per_frame: int = 6
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var phase: Phase = Phase.GENERATING
var runner: PuzzleRunner
var request: PuzzleRequest
## 연습에서 지금까지 낸 문제 수.
var problem_number: int = 0

var _store: PuzzleStore
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _difficulty: PuzzleDifficulty
var _label: String = ""
var _sub: String = ""
var _tries: int = 0
var _recorded_for: BlockPuzzle

@onready var _name_label: Label = %PuzzleName
@onready var _sub_label: Label = %PuzzleSub
@onready var _count_label: Label = %MoveCount
@onready var _tip_label: Label = %TipLabel
@onready var _undo_button: Button = %UndoButton
@onready var _reset_button: Button = %ResetButton
@onready var _hint_button: Button = %HintButton
@onready var _new_button: Button = %NewButton
@onready var _result: PuzzleResultPanel = %ResultPanel


func _ready() -> void:
	book = PuzzleBook.ensure_valid(book)
	_store = PuzzleStore.new(save_path)
	_rng.randomize()
	request = PuzzleRequest.take()
	_difficulty = book.find_difficulty(request.difficulty)
	runner = PuzzleRunner.new(board_channel, book)
	runner.show_window = not is_practice()
	runner.solved.connect(_on_solved)
	runner.result_ready.connect(_on_result_ready)
	runner.finished.connect(_on_finished)
	runner.changed.connect(_refresh_labels)
	_begin_next()


func is_practice() -> bool:
	return request.mode == PuzzleRequest.Mode.PRACTICE


## 지금 퍼즐 (만드는 중이면 null).
func puzzle() -> BlockPuzzle:
	return runner.puzzle if phase == Phase.PUZZLE else null


func _process(delta: float) -> void:
	if phase == Phase.GENERATING:
		_generate_some()
	else:
		runner.advance(delta)


func _begin_next() -> void:
	if is_practice():
		phase = Phase.GENERATING
		_tries = 0
		_name_label.text = "블럭 모으기 · %s" % _difficulty.name
		_sub_label.text = "문제 만드는 중…"
		_tip_label.text = _difficulty.description
		return
	var def: PuzzleDef = book.find_board(request.board_id)
	var level: PuzzleLevel = book.level_of(request.board_id)
	if def == null or level == null:
		push_error("PuzzlePlayScreen: unknown board %s" % request.board_id)
		exit_requested.emit()
		return
	_start(def, level.hide_goal, "블럭 모으기 Lv.%d · %s" % [level.level, level.name], "%d / %d판" % [level.boards.find(def) + 1, level.boards.size()])


func _generate_some() -> void:
	for _i: int in generate_per_frame:
		_tries += 1
		var def: PuzzleDef = PuzzleGenerator.try_once(_difficulty, book, _rng)
		if def == null and _tries >= book.generate_tries:  # 못 만들면 난이도 구간에 맞는 튜토리얼 판 하나
			def = PuzzleGenerator.fallback(_difficulty, book)
		if def != null:
			problem_number += 1
			_start(def, _difficulty.hide_goal, "블럭 모으기 · %s" % _difficulty.name, "%d번째 문제" % problem_number)
			return


func _start(def: PuzzleDef, hide_goal: bool, label: String, sub: String) -> void:
	var board: Board = Board.new(book.window_size + PuzzleGenerator.MARGIN * 2)
	var puzzle_now: BlockPuzzle = BlockPuzzle.new(board, def, _rng.randi_range(0, color_count - 1),
		Vector2i.ONE * PuzzleGenerator.MARGIN, book, color_count, _rng)
	puzzle_now.hide_goal = hide_goal
	_label = label
	_sub = sub
	phase = Phase.PUZZLE
	runner.begin(puzzle_now)


## InputRouter.move_requested (puzzle_play.tscn에서 연결).
func _on_move_requested(dir: Vector2i, _hand: int) -> void:
	if phase == Phase.PUZZLE:
		runner.step(dir)


## 옆 칸 탭 (BoardView.cell_tapped).
func _on_cell_tapped(cell: Vector2i) -> void:
	if phase != Phase.PUZZLE:
		return
	var dir: Vector2i = Board.direction_from(runner.puzzle.board.player_pos, cell)
	if dir != Vector2i.ZERO:
		runner.step(dir)


func _on_undo_pressed() -> void:
	if phase == Phase.PUZZLE:
		runner.undo()


func _on_reset_pressed() -> void:
	if phase == Phase.PUZZLE:
		runner.reset()


func _on_hint_pressed() -> void:
	if phase == Phase.PUZZLE:
		runner.raise_hint()


## 연습: 이 문제를 건너뛰고 새 문제 (기록 없음).
func _on_new_pressed() -> void:
	if is_practice() and phase == Phase.PUZZLE and runner.is_playing():
		_begin_next()


func _on_exit_pressed() -> void:
	exit_requested.emit()


## 풀린 순간: 연습은 매치 연출만 (판은 그대로).
func _on_solved(center: Vector2i, color: int) -> void:
	board_channel.matched.emit(center, color, runner.puzzle.board.neighbors(center))


func _on_result_ready(info: PuzzleRunner.ResultInfo) -> void:
	var coins: int = _record(info.stars)
	var note: String = "첫 클리어 보상 ● %d" % coins if coins > 0 else ""
	_result.show_result(info, "다음 문제" if is_practice() else "목록으로", note)


## 결과 기록은 퍼즐마다 처음 결과에서 한 번 (정답 보기·다시 해 보기 뒤에는 다시 세지 않는다).
## 단계 판이면 첫 클리어 보상을 받는다 (E27). 받은 코인 (없으면 0).
func _record(stars: int) -> int:
	if _recorded_for == runner.puzzle:
		return 0
	_recorded_for = runner.puzzle
	if is_practice():
		_store.record_practice(stars)
		return 0
	_store.record_board(runner.puzzle.def.id, stars)
	return PuzzleUnlocks.new(book, _store).claim(runner.puzzle.def.id, ProgressStore.new(save_path))


func _on_finished(_stars: int) -> void:
	if is_practice():
		_begin_next()
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
	if phase != Phase.PUZZLE:
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
	_new_button.visible = is_practice()
	_new_button.disabled = not playing


## 지금 보이는 안내 문구 (테스트/디버그용).
func tip_text() -> String:
	return _tip_label.text
