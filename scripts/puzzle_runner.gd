class_name PuzzleRunner
extends RefCounted
## 블럭 모으기 퍼즐 한 판을 진행한다 (연습 화면·튜토리얼이 함께 쓴다): 수를 BlockPuzzle에 넘기고 판 그림 이벤트를
## BoardChannel로 보낸다. 풀리면 solved를 보내고(매치 처리는 주인이: 연습 = 연출만, 튜토리얼 = 본게임 매치),
## 잠깐 뒤 결과를 정한다 — quick이면 finished, 아니면 result_ready (★ 하나로 처음 풀면 정답 다시 보기 먼저).
## 시간은 주인이 advance(delta)로 넘긴다.

## 풀린 순간 (center = 내 칸, color = 모을 색). 주인이 매치를 처리한다.
signal solved(center: Vector2i, color: int)
## 결과 카드를 보여 줄 때.
signal result_ready(info: ResultInfo)
## quick 퍼즐이 끝났거나 결과에서 "다음"을 골랐다.
signal finished(stars: int)
## 안내 문구·버튼 상태가 바뀌었다 (주인이 다시 그린다).
signal changed

enum Phase { PLAYING, SOLVED, REPLAY, RESULT, DONE }

const ARROW_TEXT: Dictionary[Vector2i, String] = {Vector2i.UP: "↑", Vector2i.DOWN: "↓", Vector2i.LEFT: "←", Vector2i.RIGHT: "→"}
## 규칙 튜토리얼 결과·칭찬 (HTML CHEER, 별 1~3).
const CHEER_WORDS: PackedStringArray = ["Good", "Great!", "Awesome!"]

## 결과 카드에 보일 것.
class ResultInfo:
	var stars: int = 0
	var head: String = ""
	var detail: String = ""
	var show_replay: bool = false
	var replay_text: String = ""
	var show_retry: bool = false

var puzzle: BlockPuzzle
var phase: Phase = Phase.PLAYING
## 퍼즐 창 테두리를 그린다 (판 전체가 퍼즐이 아니면).
var show_window: bool = true
## 힌트·결과 없이 풀리면 바로 끝 (튜토리얼 금화 퍼즐).
var quick: bool = false
## 안내 줄 (비어 있으면 판의 tip).
var tip_override: String = ""
## 결과 제목을 별 수의 칭찬(CHEER_WORDS)으로 (규칙 튜토리얼).
var cheer_heads: bool = false
## 퍼즐 안내에 덧붙여 그릴 표시 (튜토리얼 첫 판의 손가락 안내).
var extra_marks: Array[BoardMark] = []
## 풀린 뒤 결과까지(초), 정답 다시 보기에서 내가 벗어난 자리에 멈추는 시간(초).
var solved_pause: float = 0.7
var diverge_pause: float = 1.6

var _channel: BoardChannel
var _book: PuzzleBook
var _wait: float = 0.0
var _after_replay: bool = false
var _replay: BlockPuzzle.Replay
var _replay_index: int = 0
var _paused_at_diverge: bool = false
var _result_stars: int = 0


func _init(channel: BoardChannel, book: PuzzleBook) -> void:
	_channel = channel
	_book = book


## 퍼즐을 시작한다 (판은 이미 깔려 있다). redraw면 판을 다시 그린다.
func begin(p_puzzle: BlockPuzzle, redraw: bool = true) -> void:
	puzzle = p_puzzle
	puzzle.quick = quick
	phase = Phase.PLAYING
	_after_replay = false
	tip_override = ""
	if redraw:
		_channel.board_created.emit(puzzle.board)
	refresh_marks()
	changed.emit()


func is_playing() -> bool:
	return phase == Phase.PLAYING


func advance(delta: float) -> void:
	match phase:
		Phase.PLAYING:
			var hint: int = puzzle.hint
			puzzle.advance(delta)
			if puzzle.hint != hint:
				refresh_marks()
				changed.emit()
		Phase.SOLVED:
			_wait -= delta
			if _wait <= 0.0:
				_decide_result(not _after_replay)
		Phase.REPLAY:
			_wait -= delta
			if _wait <= 0.0:
				_replay_step()


## 이동 입력. 퍼즐을 진행 중이 아니면 무시.
func step(dir: Vector2i) -> void:
	if phase != Phase.PLAYING:
		return
	var result: BlockPuzzle.StepResult = puzzle.step(dir)
	if result.move == null:
		return
	if not result.accepted:
		_channel.move_blocked.emit(result.move)
		return
	_channel.move_started.emit(result.move)
	tip_override = ""
	if not result.recolored.is_empty():
		_channel.cells_changed.emit(result.recolored)
		tip_override = "다른 색이 매치됐어요. 퍼즐은 계속돼요"
	if result.solved:
		_on_solved("최소 수!" if puzzle.moves.size() <= puzzle.min_moves else "좋아요!")
	refresh_marks()
	changed.emit()


func undo() -> void:
	if phase == Phase.PLAYING and puzzle.can_undo():
		puzzle.undo()
		_redraw()


func reset() -> void:
	if phase == Phase.PLAYING and not puzzle.moves.is_empty():
		puzzle.reset()
		_redraw()


func raise_hint() -> void:
	if phase == Phase.PLAYING:
		puzzle.raise_hint()
		refresh_marks()
		changed.emit()


## 결과에서 "다시 해 보기".
func retry() -> void:
	if phase != Phase.RESULT:
		return
	puzzle.restart()
	phase = Phase.PLAYING
	tip_override = ""
	_redraw()


## 결과에서 "다음".
func accept() -> void:
	if phase != Phase.RESULT:
		return
	phase = Phase.DONE
	_channel.marks_changed.emit([] as Array[BoardMark])
	finished.emit(_result_stars)


## 결과에서 "정답 보기".
func start_replay() -> void:
	if phase != Phase.RESULT and phase != Phase.SOLVED:
		return
	_replay = puzzle.replay_plan()
	_replay_index = 0
	_paused_at_diverge = false
	_channel.board_created.emit(puzzle.board)
	_channel.marks_changed.emit(_window_marks())
	tip_override = "최소 수 길을 보여 줄게요" if _replay.diverge < 0 else "내가 둔 길을 따라가다가, 처음 벗어난 곳에서 멈춰요"
	phase = Phase.REPLAY
	_wait = _book.replay_step + 0.1
	changed.emit()


## 지금 그릴 판 위 안내.
func refresh_marks() -> void:
	if phase == Phase.PLAYING or phase == Phase.SOLVED:
		var marks: Array[BoardMark] = PuzzleMarks.for_puzzle(puzzle, show_window)
		if phase == Phase.PLAYING:
			marks.append_array(extra_marks)
		_channel.marks_changed.emit(marks)


## 지금 보일 안내 문구.
func tip_text() -> String:
	return tip_override if not tip_override.is_empty() else puzzle.def.tip


## 안내를 강조할지 (힌트를 하나 이상 봤다).
func tip_emphasized() -> bool:
	return tip_override.is_empty() and puzzle.tip_emphasized()


## 지금 보일 수 (정답 다시 보기 중이면 그 수).
func shown_moves() -> int:
	return _replay_index if phase == Phase.REPLAY else puzzle.moves.size()


## 결과 제목 (HTML 문구).
static func result_head(stars: int, over: int, replayed: bool) -> String:
	if stars == 3:
		return "최소 수로 성공!"
	if stars == 2:
		return "%d수 더 짧은 길이 있어요" % over if over > 0 else "최소 수예요! 되돌리기 없이 하면 ★★★"
	return "정답 길을 봤어요" if replayed else "다음엔 더 짧게 해 봐요"


func _redraw() -> void:
	_channel.board_created.emit(puzzle.board)
	refresh_marks()
	changed.emit()


func _on_solved(cheer: String) -> void:
	tip_override = cheer
	phase = Phase.SOLVED
	_wait = solved_pause
	_channel.marks_changed.emit(_window_marks())
	solved.emit(puzzle.board.player_pos, puzzle.target_color)


func _decide_result(first: bool) -> void:
	_result_stars = puzzle.stars()
	if quick:
		phase = Phase.DONE
		_channel.marks_changed.emit([] as Array[BoardMark])
		finished.emit(_result_stars)
		return
	if first and _result_stars == 1 and not puzzle.replayed and puzzle.max_hint == BlockPuzzle.Hint.GOAL:  # 힌트로 길을 봤으면 자동으로 안 띄움
		start_replay()
		return
	var info: ResultInfo = ResultInfo.new()
	info.stars = _result_stars
	info.head = CHEER_WORDS[_result_stars - 1] if cheer_heads \
		else PuzzleRunner.result_head(_result_stars, puzzle.moves.size() - puzzle.min_moves, puzzle.replayed)
	var detail: String = "%d / %d수" % [puzzle.moves.size(), puzzle.min_moves]
	if _result_stars < 3:
		detail += "\n" + puzzle.def.tip
	info.detail = detail
	info.show_replay = _result_stars < 3
	info.replay_text = "정답 다시 보기" if puzzle.replayed else "정답 보기"
	info.show_retry = _result_stars < 3
	phase = Phase.RESULT
	result_ready.emit(info)
	changed.emit()


func _replay_step() -> void:
	if _replay_index >= _replay.path.size():
		_after_replay = true
		tip_override = "이렇게!"
		phase = Phase.SOLVED
		_wait = solved_pause
		var center: Vector2i = puzzle.board.player_pos
		_channel.matched.emit(center, puzzle.target_color, puzzle.board.neighbors(center))  # 연출만
		changed.emit()
		return
	var dir: Vector2i = _replay.path[_replay_index]
	if _replay_index == _replay.diverge and not _paused_at_diverge:
		_paused_at_diverge = true
		tip_override = "여기서는 %s 쪽이 더 좋아요 · 내가 둔 수는 %s였어요" % [ARROW_TEXT.get(dir, ""), ARROW_TEXT.get(_replay.my_move, "")]
		var marks: Array[BoardMark] = _window_marks()
		var arrow: BoardMark = BoardMark.at_cell(BoardMark.Kind.ARROW, puzzle.board.player_pos + dir)
		arrow.direction = dir
		marks.append(arrow)
		_channel.marks_changed.emit(marks)
		_wait = diverge_pause
		changed.emit()
		return
	_channel.marks_changed.emit(_window_marks())
	_channel.move_started.emit(puzzle.replay_move(dir))
	_replay_index += 1
	_wait = _book.replay_step
	changed.emit()


func _window_marks() -> Array[BoardMark]:
	var marks: Array[BoardMark] = []
	if show_window:
		marks.append(BoardMark.new(BoardMark.Kind.ZONE, puzzle.window))
	return marks
