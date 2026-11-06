class_name TutorialDirector
extends Node
## 규칙 튜토리얼 진행 (기획서 8.8장): TutorialScript의 단계를 차례로 실행한다. 판은 본게임 세션 그대로 쓰고
## (매치·시간·씨앗·족보·금화가 본게임 규칙), 남은 시간은 흐르지 않는다. 단계가 쓰는 도구를 공개 API로 연다:
## 설명(스포트라이트 TAP)·조작 설명(ACT), 블럭 모으기 퍼즐(PuzzleRunner), 자유 매치 힌트(MatchPlanner), 족보 카드·판 준비.
## GameController가 튜토리얼 판이면 begin(session)을 부르고, 이동 입력을 넘기고(intercepts_moves), 설명 중엔 판을 멈춘다(halts_game).
## 끝나거나 건너뛰면 finished. 첫 실전 판 안내(show_intro)도 여기서 띄운다.
## 캐릭터 튜토리얼(6c, CharacterTutorialBook): begin_lesson으로 같은 도구에 캐릭터별 단계를 돌리고, 끝나면 lesson_finished.
## 처음 쓰는 캐릭터에는 offer_lesson으로 "튜토리얼 / 바로 시작"을 묻는다. 그 캐릭터가 처음 일으킨 순간은
## CharacterMomentGuide가 골라 한 번씩 설명한다 — 튜토리얼 판에서도, 이어지는 실전 판(watch_moments)에서도.
## 판 위 안내 표시(힌트·연습 판 자리·수선 길)는 능력의 표시(깃발·구역)에 덧붙여 보낸다.
## 실전 판의 처음 볼 때 안내(6d): 두 족보가 같은 색을 기다리는 순간 "족보 동시 진행"을 한 번 (watch_multi_recipes).

signal finished
## 캐릭터 튜토리얼이 끝났다 (끝까지 또는 건너뛰기) — 실전 판으로.
signal lesson_finished

## 매치 한 번의 정보 (단계가 목표를 센다).
class MatchInfo:
	var color: int = Board.NO_COLOR
	## 이 매치로 진행된 족보 장 수, 완성된 장 수.
	var advanced: int = 0
	var completed: int = 0
	## 매치 전 첫 족보의 다음 색.
	var next_before: int = Board.NO_COLOR

## 연습 판 창 크기 (CharacterLessonStep.practice_rows).
const PRACTICE_SIZE: int = 5

@export var tutorial: TutorialScript
## 캐릭터 튜토리얼 (비어 있으면 캐릭터 튜토리얼 없음).
@export var lessons: CharacterTutorialBook
## 처음 볼 때 안내 문구.
@export var tips: FirstViewTips
@export var book: PuzzleBook
@export var board_channel: BoardChannel
@export var spotlight: SpotlightOverlay
@export var hud: Hud
@export var board_view: BoardView
@export var puzzle_bar: TutorialPuzzleBar
@export var result_panel: PuzzleResultPanel
## 자유 매치: 가만히 있으면 이만큼 뒤 힌트(초), 힌트 탐색 깊이·노드 수.
@export var hint_idle: float = 6.0
@export var plan_depth: int = 8
@export var plan_nodes: int = 20000
## 단계 배너가 떠 있는 시간(초), 씨앗이 하나씩 자라는 간격(초).
@export var banner_time: float = 1.1
@export var seed_grow_delay: float = 0.9
@export var seed_grow_gap: float = 0.35

var session: GameSession
var running: bool = false
## 첫 실전 판 안내만 띄우는 중.
var intro_only: bool = false
var step_index: int = -1
## 지금 돌리는 캐릭터 튜토리얼 (규칙 튜토리얼이면 null).
var lesson: CharacterTutorial
## 처음 일어난 순간 설명 (캐릭터 튜토리얼과 이어지는 실전 판).
var guide: CharacterMomentGuide

var _step: TutorialStep
var _steps: Array[TutorialStep] = []
var _advance_pending: bool = false
var _letters: Dictionary[String, int] = {}
var _rng: RandomNumberGenerator
var _caption_mode: SpotlightOverlay.Mode = SpotlightOverlay.Mode.TAP
var _caption_head: String = ""
var _caption_text: String = ""
var _caption_holes: PackedStringArray = PackedStringArray()
## 순간 설명이 떠 있다 (누르면 앞의 설명으로 돌아간다).
var _moment_open: bool = false
var _moment_holes: PackedStringArray = PackedStringArray()
## 첫 사용 질문이 떠 있다.
var _offer: CharacterTutorial
var _runner: PuzzleRunner
var _puzzle_label: String = ""
var _puzzle_sub: String = ""
var _puzzle_holes: PackedStringArray = PackedStringArray()
var _puzzle_caption: String = ""
var _hold_seeds: bool = false
var _banner_left: float = -1.0
var _banner_then: Callable
var _free: bool = false
var _free_hints: bool = false
var _free_filter: Callable
var _idle: float = 0.0
var _hint_level: int = 0
var _grow_queue: Array[Vector2i] = []
var _grow_wait: float = 0.0
var _pending_match: MatchInfo
## 판 위 안내: 연습 판 자리 / 힌트·첫 수 화살표(이동하면 지운다) / 수선 길.
var _guide_marks: Array[BoardMark] = []
var _hint_marks: Array[BoardMark] = []
var _ring_marks: Array[BoardMark] = []
## 족보 동시 진행 안내를 기다린다 (본 기록을 적을 저장).
var _multi_store: TutorialStore


# --- 시작 · 끝 --------------------------------------------------------------------

## 튜토리얼 판의 세션으로 처음부터 시작한다 (다시 시작하면 새 세션으로 다시 부른다).
func begin(p_session: GameSession) -> void:
	_start_steps(p_session, tutorial.steps, null)
	clear_cards()


## 캐릭터 튜토리얼을 처음부터 (튜토리얼 판의 세션, 남은 시간은 흐르지 않는다).
func begin_lesson(p_session: GameSession, p_lesson: CharacterTutorial) -> void:
	_start_steps(p_session, lessons.steps_for(p_lesson, p_session.character), p_lesson)
	guide = CharacterMomentGuide.new(p_lesson, p_session.character.has_recipe())


## 캐릭터 튜토리얼을 마치고 온 실전 판: 남은 순간 설명만 이어서.
func watch_moments(p_session: GameSession, p_guide: CharacterMomentGuide) -> void:
	_connect_session(p_session)
	running = false
	lesson = null
	_reset_tools()
	guide = p_guide


## 처음 쓰는 캐릭터: "튜토리얼 / 바로 시작"을 묻는다 (판은 첫 이동 전이라 멈춰 있다).
func offer_lesson(p_session: GameSession, p_lesson: CharacterTutorial) -> void:
	_connect_session(p_session)
	running = false
	lesson = null
	guide = null
	_reset_tools()
	_offer = p_lesson
	_caption_holes = PackedStringArray(["chr"])
	spotlight.open(SpotlightOverlay.Mode.TAP, p_session.character.display_name, "%s\n%s" % [p_lesson.cap, p_lesson.description],
		holes_for(_caption_holes), lessons.offer_button, false, false, lessons.offer_skip_button)


## 실전 판: 두 족보가 같은 색을 기다리는 순간 "족보 동시 진행"을 한 번 띄운다 (판이 시작된 뒤, 튜토리얼 중이 아닐 때).
func watch_multi_recipes(p_session: GameSession, store: TutorialStore) -> void:
	_connect_session(p_session)
	_multi_store = store if tips != null and not store.has_seen(TutorialStore.SEEN_MULTI_RECIPES) else null


## 설명 한 장 (TAP, 판을 멈춘다). 누르면 닫히고 앞의 조작 설명이 있으면 다시 띄운다. 띄웠으면 true.
func show_notice(head: String, text: String, holes: PackedStringArray) -> bool:
	if _moment_open or _offer != null or (spotlight.is_open() and spotlight.is_blocking()):
		return false
	_moment_open = true
	_moment_holes = holes
	spotlight.open(SpotlightOverlay.Mode.TAP, head, text, holes_for(_moment_holes), "", false)
	return true


## 첫 실전 판 안내 (시간·족보 카드를 밝히는 설명 한 장, 누르면 시작).
func show_intro(p_session: GameSession) -> void:
	_connect_session(p_session)
	running = true
	intro_only = true
	lesson = null
	_reset_tools()
	say(tutorial.real_game_head, tutorial.real_game_text, PackedStringArray(["time", "cards"]), "시작")


## 건너뛰기: 남은 단계 없이 끝낸다.
func skip() -> void:
	if running:
		_complete()


func is_running() -> bool:
	return running


## 지금 캐릭터 튜토리얼을 돌리는 중인지.
func is_lesson() -> bool:
	return running and lesson != null


## 첫 사용 질문이 떠 있는지.
func is_offering() -> bool:
	return _offer != null


## 순간 설명이 떠 있는지.
func is_moment_open() -> bool:
	return _moment_open


## 캐릭터의 튜토리얼 (없으면 null).
func lesson_for(id: StringName) -> CharacterTutorial:
	return lessons.find(id) if lessons != null else null


## 설명·배너·결과 카드·순간 설명·첫 사용 질문이 떠 있어 판(시간·씨앗·능력)을 멈춰야 하는지.
func halts_game() -> bool:
	if _moment_open or _offer != null:
		return true
	return running and (spotlight.is_blocking() or result_panel.visible or _banner_left >= 0.0)


## 이동 입력을 튜토리얼이 받는지 (퍼즐 중이거나 판이 멈췄을 때).
func intercepts_moves() -> bool:
	return halts_game() or (running and _runner != null)


func handle_move(dir: Vector2i) -> void:
	if _runner != null and not halts_game():
		_runner.step(dir)


## 지금 단계 (테스트·스모크용).
func current_step() -> TutorialStep:
	return _step


func runner() -> PuzzleRunner:
	return _runner


func finish_step() -> void:
	_advance_pending = true


func _start_steps(p_session: GameSession, steps: Array[TutorialStep], p_lesson: CharacterTutorial) -> void:
	_connect_session(p_session)
	session.frozen_clocks = [TimedSystem.Clock.TIMER] as Array[TimedSystem.Clock]
	_rng = GameRng.derive(session.base_seed, GameRng.Stream.TUTORIAL)
	running = true
	intro_only = false
	step_index = -1
	_steps = steps
	lesson = p_lesson
	guide = null
	_reset_tools()
	_advance_pending = true


func _complete() -> void:
	running = false
	var was_lesson: bool = lesson != null
	lesson = null
	_reset_tools()
	spotlight.close()
	if session != null:
		session.frozen_clocks = [] as Array[TimedSystem.Clock]
	_step = null
	if was_lesson:
		lesson_finished.emit()
	else:
		finished.emit()


func _start_next() -> void:
	step_index += 1
	if intro_only or step_index >= _steps.size():
		_complete()
		return
	_caption_holes = PackedStringArray()
	_step = _steps[step_index]
	_step.start(self)


func _process(delta: float) -> void:
	if spotlight.is_open():
		spotlight.update_holes(holes_for(_moment_holes if _moment_open else _caption_holes))
	if not running:
		return
	if _advance_pending:
		_advance_pending = false
		_start_next()
		if not running:
			return
	_grow_seeds(delta)
	if _banner_left >= 0.0:
		_banner_left -= delta
		if _banner_left < 0.0:
			_banner_left = -1.0
			_banner_then.call(self)
		return
	if halts_game():
		return
	if _runner != null:
		_runner.advance(delta)
	if _free and _free_hints:
		_idle_hints(delta)
	if _step != null:
		_step.tick(self, delta)


# --- 설명 ------------------------------------------------------------------------

## 설명 한 장 (TAP): 누르면 지금 단계의 on_tap.
func say(head: String, text: String, holes: PackedStringArray, button: String = "", top: bool = false) -> void:
	_remember_caption(SpotlightOverlay.Mode.TAP, head, text, holes)
	spotlight.open(SpotlightOverlay.Mode.TAP, head, text, holes_for(holes), button, true, top)


## 조작 설명 (ACT): 판을 직접 조작한다.
func act(head: String, text: String, holes: PackedStringArray) -> void:
	_remember_caption(SpotlightOverlay.Mode.ACT, head, text, holes)
	spotlight.open(SpotlightOverlay.Mode.ACT, head, text, holes_for(holes))


func set_caption(text: String) -> void:
	_caption_text = text
	if not _moment_open:
		spotlight.set_text(text)


## 단계 배너 (잠깐 판을 멈춘다), 끝나면 then(director).
func banner(title: String, sub: String, then: Callable) -> void:
	_remember_caption(SpotlightOverlay.Mode.ACT, title, sub, PackedStringArray())
	spotlight.open(SpotlightOverlay.Mode.ACT, title, sub, [] as Array[Rect2], "", true)
	_banner_left = banner_time
	_banner_then = then


## 칭찬 한마디 (메시지 줄).
func cheer(text: String) -> void:
	if session != null and not text.is_empty():
		session.announce(text)


## 캐릭터 튜토리얼 활용 연습 제목 ("시계공 · 활용").
func lesson_head() -> String:
	return lessons.lesson_head % session.character.display_name


## 문구의 {A} {B} {C} {A을} {next}를 채운다.
func fill(template: String) -> String:
	var out: String = template
	for key: String in ["A", "B", "C"]:
		var word: String = TutorialDirector.color_name(letter(key))
		out = out.replace("{%s을}" % key, TutorialDirector.with_object_particle(word)).replace("{%s}" % key, word)
	return out.replace("{next}", TutorialDirector.color_name(first_recipe_next()))


static func color_name(color: int) -> String:
	return Board.COLOR_NAMES[color] if color >= 0 and color < Board.COLOR_NAMES.size() else "다른"


## 받침이 있으면 "을", 없으면 "를".
static func with_object_particle(word: String) -> String:
	if word.is_empty():
		return word
	var code: int = word.unicode_at(word.length() - 1) - 0xAC00
	return word + ("을" if code >= 0 and code < 11172 and code % 28 != 0 else "를")


## 스포트라이트가 밝힐 자리 (캔버스 좌표).
func holes_for(names: PackedStringArray) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for target: String in names:
		match target:
			"cards", "chr", "score", "coin", "time", "card:0", "card:1", "card:2":
				rects.append_array(hud.target_rects(target))
			"player":
				rects.append(board_view.cells_rect([session.board.player_pos] as Array[Vector2i]))
			"board":
				var last: Vector2i = Vector2i.ONE * (session.board.size - 1)
				rects.append(board_view.cells_rect([Vector2i.ZERO, last] as Array[Vector2i]))
			"marks":
				for mark: BoardMark in session.board_marks():
					rects.append(board_view.cells_rect([mark.rect.position, mark.rect.end - Vector2i.ONE] as Array[Vector2i]))
			"puzzle":
				if _runner != null:
					rects.append(board_view.cells_rect(_window_cells()))
			"board_coins":
				for pos: Vector2i in session.board.all_positions():
					if session.board.has_coin(pos):
						rects.append(board_view.cells_rect([pos] as Array[Vector2i]))
			"seeds":
				var seeds: Array[Vector2i] = session.board.positions_of_type(Board.CellType.SEED)
				if not seeds.is_empty():
					rects.append(board_view.cells_rect(seeds))
	var shown: Array[Rect2] = []
	for rect: Rect2 in rects:
		if rect.size != Vector2.ZERO:
			shown.append(rect)
	return shown


func _remember_caption(mode: SpotlightOverlay.Mode, head: String, text: String, holes: PackedStringArray) -> void:
	_caption_mode = mode
	_caption_head = head
	_caption_text = text
	_caption_holes = holes


## 순간 설명을 닫고 앞의 설명을 다시 띄운다.
func _close_moment() -> void:
	_moment_open = false
	_moment_holes = PackedStringArray()
	if running and _caption_mode == SpotlightOverlay.Mode.ACT and _banner_left < 0.0:
		spotlight.open(SpotlightOverlay.Mode.ACT, _caption_head, _caption_text, holes_for(_caption_holes))
	else:
		spotlight.close()


# --- 판 · 족보 --------------------------------------------------------------------

func letter(key: String) -> int:
	return _letters.get(key, Board.NO_COLOR)


func random_color() -> int:
	return _rng.randi_range(0, session.get_config().color_count - 1)


## 글자 색을 새로 고른다: A = 지금 판에서 가장 빨리 매치할 수 있는 색(from_plan) 또는 무작위, B · C = 다른 색.
func pick_letters(from_plan: bool) -> void:
	var a: int = random_color()
	if from_plan:
		var plan: MatchPlanner.Plan = MatchPlanner.best(session.board, plan_depth - 1, plan_nodes)
		if plan != null:
			a = plan.color
	_letters = {"A": a}
	var others: Array[int] = _other_colors(a)
	GameRng.shuffle(others, _rng)
	_letters["B"] = others[0] if others.size() > 0 else a
	_letters["C"] = others[1] if others.size() > 1 else _letters["B"]


## 족보 카드를 글자 색으로 깐다 (keep_letters가 아니면 글자를 무작위로 새로 고른다).
func set_letter_cards(specs: Array[PackedStringArray], progress: PackedInt32Array, keep_letters: bool) -> void:
	if not keep_letters:
		pick_letters(false)
	var list: Array[PackedInt32Array] = []
	for spec: PackedStringArray in specs:
		var colors: PackedInt32Array = PackedInt32Array()
		for key: String in spec:
			colors.append(letter(key))
		list.append(colors)
	session.recipes.replace_all(list, progress)
	_emit_recipes()


func clear_cards() -> void:
	session.recipes.replace_all([] as Array[PackedInt32Array])
	_emit_recipes()


## 지금 족보를 모두 한 칸 남게 채운다 (HTML tCardsNear).
func fill_cards_near() -> void:
	var list: Array[PackedInt32Array] = []
	var progress: PackedInt32Array = PackedInt32Array()
	for recipe: RecipeSet.Recipe in session.recipes.recipes:
		list.append(recipe.colors)
		progress.append(maxi(recipe.progress, recipe.length() - 1))
	session.recipes.replace_all(list, progress)
	_emit_recipes()


## 첫 족보를 [A, A, B]로 (A = 지금 판에서 가장 빨리 매치할 수 있는 색), 나머지 족보는 그대로 (쌍둥이 연습).
func set_twin_cards() -> void:
	pick_letters(true)
	var list: Array[PackedInt32Array] = []
	for recipe: RecipeSet.Recipe in session.recipes.recipes:
		list.append(recipe.colors)
	var twin: PackedInt32Array = PackedInt32Array([letter("A"), letter("A"), letter("B")])
	if list.is_empty():
		list.append(twin)
	else:
		list[0] = twin
	session.recipes.replace_all(list)
	_emit_recipes()


## 첫 족보의 다음 색 (카드가 없거나 다 찼으면 NO_COLOR).
func first_recipe_next() -> int:
	if session.recipes.slot_count() == 0 or session.recipes.recipes[0].is_complete():
		return Board.NO_COLOR
	return session.recipes.recipes[0].next_color()


## 모든 족보의 다음 색.
func recipe_nexts() -> Array[int]:
	var nexts: Array[int] = []
	for recipe: RecipeSet.Recipe in session.recipes.recipes:
		if not recipe.is_complete():
			nexts.append(recipe.next_color())
	return nexts


## 실제 판처럼 새로 섞는다 (플레이어 가운데, 시작 자리 매치 없음).
func random_board() -> void:
	var fresh: Board = Board.generate(session.get_config(), _rng)
	for pos: Vector2i in fresh.all_positions():
		if fresh.get_cell_type(pos) != Board.CellType.PLAYER:
			session.board.set_color_block(pos, fresh.get_color(pos))
	session.board.set_player(fresh.player_pos)
	session.notify_board_rearranged()


## 캐릭터 튜토리얼 연습 판: 판 가운데(at_top이면 맨 위 줄) 5×5 창에 A = 같은 색, P = 나, . = 다른 색을 깐다.
## marks의 C = 설 칸, S = 모을 자리, arrow = 첫 수 방향 (0이면 없음).
func lay_practice(rows: PackedStringArray, marks: PackedStringArray, arrow: Vector2i, at_top: bool) -> void:
	var board: Board = session.board
	var origin: Vector2i = Vector2i((board.size - PRACTICE_SIZE) / 2, 0 if at_top else (board.size - PRACTICE_SIZE) / 2)
	var color: int = random_color()
	var others: Array[int] = _other_colors(color)
	var player: Vector2i = board.player_pos
	for y: int in rows.size():
		for x: int in rows[y].length():
			var pos: Vector2i = origin + Vector2i(x, y)
			if rows[y][x] == "P":
				player = pos
			board.set_color_block(pos, color if rows[y][x] == "A" else others[_rng.randi_range(0, others.size() - 1)])
	if board.player_pos != player:
		board.set_color_block(board.player_pos, others[_rng.randi_range(0, others.size() - 1)])
	board.set_player(player)
	session.notify_board_rearranged()
	var guide_marks: Array[BoardMark] = []
	for y: int in marks.size():
		for x: int in marks[y].length():
			match marks[y][x]:
				"C":
					guide_marks.append(BoardMark.at_cell(BoardMark.Kind.GOAL_CENTER, origin + Vector2i(x, y)))
				"S":
					guide_marks.append(BoardMark.at_cell(BoardMark.Kind.GOAL_SLOT, origin + Vector2i(x, y)))
	if arrow != Vector2i.ZERO:
		var mark: BoardMark = BoardMark.at_cell(BoardMark.Kind.ARROW, player + arrow)
		mark.direction = arrow
		guide_marks.append(mark)
	show_guide_marks(guide_marks)


## 내 칸에서 시작하는 size×size 정사각형 테두리 길 (수선사 연습). 0이면 지운다.
func show_ring(size: int) -> void:
	_ring_marks.clear()
	if size > 1:
		_ring_marks.append(BoardMark.path(TutorialDirector.ring_path(session.board.player_pos, size, session.board.size)))
	_emit_marks()


## start를 꼭짓점으로 판 안쪽으로 그리는 size×size 테두리 한 바퀴 (시작 칸으로 돌아온다).
static func ring_path(start: Vector2i, size: int, board_size: int) -> Array[Vector2i]:
	var span: int = size - 1
	var dx: int = 1 if start.x + span < board_size else -1
	var dy: int = 1 if start.y + span < board_size else -1
	var path: Array[Vector2i] = [start]
	for k: int in range(1, span + 1):
		path.append(start + Vector2i(dx * k, 0))
	for k: int in range(1, span + 1):
		path.append(start + Vector2i(dx * span, dy * k))
	for k: int in range(1, span + 1):
		path.append(start + Vector2i(dx * (span - k), dy * span))
	for k: int in range(1, span + 1):
		path.append(start + Vector2i(0, dy * (span - k)))
	return path


## 판 위 안내 표시 (능력의 표시에 덧붙인다).
func show_guide_marks(marks: Array[BoardMark]) -> void:
	_guide_marks = marks
	_emit_marks()


func clear_guide_marks() -> void:
	if _has_tutorial_marks():
		_guide_marks = []
		_hint_marks = []
		_ring_marks.clear()
		_emit_marks()


func _has_tutorial_marks() -> bool:
	return not (_guide_marks.is_empty() and _hint_marks.is_empty() and _ring_marks.is_empty())


func _show_hint_marks(marks: Array[BoardMark]) -> void:
	_hint_marks = marks
	_emit_marks()


func _emit_marks() -> void:
	var marks: Array[BoardMark] = session.board_marks().duplicate()
	marks.append_array(_guide_marks)
	marks.append_array(_hint_marks)
	marks.append_array(_ring_marks)
	board_channel.marks_changed.emit(marks)


func _other_colors(color: int) -> Array[int]:
	var others: Array[int] = []
	for other: int in session.get_config().color_count:
		if other != color:
			others.append(other)
	return others


## 묶어 둔 씨앗을 하나씩 자라게 한다 (다시 자라는 칸 설명).
func grow_held_seeds() -> void:
	_grow_queue = session.board.positions_of_type(Board.CellType.SEED)
	_grow_wait = seed_grow_delay
	_hold_seeds = false
	session.frozen_clocks.erase(TimedSystem.Clock.REFILL)


## 첫 이동을 배울 때 옆 칸 화살표.
func show_move_arrow() -> void:
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var to: Vector2i = session.board.player_pos + dir
		if session.board.is_inside(to):
			var mark: BoardMark = BoardMark.at_cell(BoardMark.Kind.ARROW, to)
			mark.direction = dir
			_show_hint_marks([mark] as Array[BoardMark])
			return


# --- 블럭 모으기 퍼즐 ----------------------------------------------------------------

## 판 가운데 창에 퍼즐을 깔고 시작한다. 풀리면 본게임 매치로 처리하고, 끝나면 지금 단계의 on_puzzle_finished.
## fill_real이면 창 둘레 밖은 실제 판처럼 아무 색 (캐릭터 튜토리얼 발동해 보기).
func start_puzzle(def: PuzzleDef, target: int, hide_goal: bool, quick: bool, coins: int, label: String, sub: String,
		holes: PackedStringArray, hold_seeds: bool, caption: String = "", fill_real: bool = false) -> void:
	var origin: Vector2i = Vector2i.ONE * ((session.board.size - book.window_size) / 2)
	var puzzle: BlockPuzzle = BlockPuzzle.new(session.board, def, target, origin, book, session.get_config().color_count, _rng, fill_real)
	puzzle.hide_goal = hide_goal
	_attach_coins(puzzle, coins)
	_runner = PuzzleRunner.new(board_channel, book)
	_runner.quick = quick
	_runner.solved.connect(_on_puzzle_solved)
	_runner.result_ready.connect(_on_puzzle_result)
	_runner.finished.connect(_on_puzzle_finished)
	_runner.changed.connect(_on_puzzle_changed)
	_puzzle_label = label
	_puzzle_sub = sub
	_puzzle_holes = holes.duplicate()
	_puzzle_holes.append("puzzle")
	_puzzle_caption = caption
	_hold_seeds = hold_seeds
	_end_free_marks()
	_runner.begin(puzzle)
	show_puzzle_caption()


## 퍼즐 조작 설명 (판 안내 문구).
func show_puzzle_caption() -> void:
	if _runner == null:
		return
	act(_puzzle_label, _puzzle_caption if not _puzzle_caption.is_empty() else _runner.tip_text(), _puzzle_holes)


func _attach_coins(puzzle: BlockPuzzle, coins: int) -> void:
	var cells: Array[BoardCell] = puzzle.targets.duplicate()
	GameRng.shuffle(cells, _rng)
	for i: int in mini(coins, cells.size()):
		cells[i].attach_coin(1.0e6)  # 튜토리얼 금화는 사라지지 않는다


func _on_puzzle_solved(_center: Vector2i, _color: int) -> void:
	session.resolve_player_match()
	if _hold_seeds:
		session.frozen_clocks.append(TimedSystem.Clock.REFILL)


func _on_puzzle_result(info: PuzzleRunner.ResultInfo) -> void:
	spotlight.close()
	result_panel.show_result(info, "다음")


func _on_puzzle_finished(stars: int) -> void:
	var finished_runner: PuzzleRunner = _runner
	if finished_runner.puzzle.def.id != "" and not finished_runner.quick:
		PuzzleStore.new().record_board(finished_runner.puzzle.def.id, stars)
	_runner = null
	puzzle_bar.visible = false
	_emit_marks()
	if _step != null:
		_step.on_puzzle_finished(self, stars)


func _on_puzzle_changed() -> void:
	if _runner == null:
		return
	puzzle_bar.show_runner(_runner, _puzzle_label, _puzzle_sub)
	if spotlight.is_open() and spotlight.mode == SpotlightOverlay.Mode.ACT and _banner_left < 0.0 and not _moment_open:
		set_caption(_puzzle_caption if not _puzzle_caption.is_empty() and _runner.tip_override.is_empty() else _runner.tip_text())


## 결과 카드·퍼즐 막대 버튼 (main.tscn에서 연결).
func _on_result_replay() -> void:
	if _runner != null:
		_runner.start_replay()
		show_puzzle_caption()


func _on_result_retry() -> void:
	if _runner != null:
		_runner.retry()
		show_puzzle_caption()


func _on_result_next() -> void:
	if _runner != null:
		_runner.accept()


func _on_bar_undo() -> void:
	if _runner != null:
		_runner.undo()


func _on_bar_reset() -> void:
	if _runner != null:
		_runner.reset()


func _on_bar_hint() -> void:
	if _runner != null:
		_runner.raise_hint()


func _on_spotlight_tapped() -> void:
	if _offer != null:
		var offered: CharacterTutorial = _offer
		_offer = null
		spotlight.close()
		begin_lesson(session, offered)
		return
	if _moment_open:
		_close_moment()
		return
	if not running:
		return
	if intro_only:
		spotlight.close()
		_complete()
		return
	if _step != null:
		_step.on_tap(self)


## 첫 사용 질문의 "바로 시작".
func _on_spotlight_alt() -> void:
	if _offer != null:
		_offer = null
		spotlight.close()


func _on_spotlight_skip() -> void:
	skip()


func _window_cells() -> Array[Vector2i]:
	var window: Rect2i = _runner.puzzle.window
	return [window.position, window.end - Vector2i.ONE] as Array[Vector2i]


# --- 자유 매치 --------------------------------------------------------------------

## 자유 매치 시작 (hints: 가만히 있으면 만들 자리 → 첫 수 화살표, filter: 힌트가 고를 매치).
func begin_free(hints: bool, filter: Callable) -> void:
	_free = true
	_free_hints = hints
	_free_filter = filter
	_idle = 0.0
	_hint_level = 0


func end_free() -> void:
	_free = false
	_end_free_marks()


func _end_free_marks() -> void:
	_hint_level = 0
	if not _hint_marks.is_empty():
		_show_hint_marks([] as Array[BoardMark])


func _idle_hints(delta: float) -> void:
	if _hint_level >= 2:
		return
	_idle += delta
	if _idle < hint_idle:
		return
	_idle = 0.0
	var plan: MatchPlanner.Plan = MatchPlanner.best(session.board, plan_depth, plan_nodes, _free_filter, _canonical())
	if plan == null:
		return
	_hint_level += 1
	var marks: Array[BoardMark] = [BoardMark.at_cell(BoardMark.Kind.GOAL_CENTER, plan.center)]
	for dir: Vector2i in Board.DIRECTIONS:
		marks.append(BoardMark.at_cell(BoardMark.Kind.GOAL_SLOT, plan.center + dir))
	if _hint_level >= 2:
		var arrow: BoardMark = BoardMark.at_cell(BoardMark.Kind.ARROW, session.board.player_pos + plan.path[0])
		arrow.direction = plan.path[0]
		marks.append(arrow)
	_show_hint_marks(marks)


func _canonical() -> Callable:
	return session.ability.canonical_color if session.ability != null else Callable()


func _grow_seeds(delta: float) -> void:
	if _grow_queue.is_empty():
		return
	_grow_wait -= delta
	if _grow_wait > 0.0:
		return
	_grow_wait = seed_grow_gap
	session.refill.mature_cells([_grow_queue.pop_front()] as Array[Vector2i])


# --- 세션 사건 --------------------------------------------------------------------

func _connect_session(p_session: GameSession) -> void:
	if session == p_session:
		return
	_disconnect_session()
	session = p_session
	session.move_started.connect(_on_session_moved)
	session.matched.connect(_on_session_matched)
	session.recipes_updated.connect(_on_session_recipes)
	session.marks_changed.connect(_on_session_marks)
	session.ability_triggered.connect(_on_ability_triggered)
	session.moment.connect(_on_session_moment)
	session.metrics.changed.connect(_on_metric_changed)


func _disconnect_session() -> void:
	if session == null:
		return
	for pair: Array in [[session.move_started, _on_session_moved], [session.matched, _on_session_matched],
			[session.recipes_updated, _on_session_recipes], [session.marks_changed, _on_session_marks],
			[session.ability_triggered, _on_ability_triggered], [session.moment, _on_session_moment],
			[session.metrics.changed, _on_metric_changed]]:
		var sig: Signal = pair[0]
		if sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	session = null


func _on_session_moved(_result: Board.MoveResult) -> void:
	if not running or _runner != null:
		return
	_idle = 0.0
	_end_free_marks()  # 힌트·첫 이동 화살표
	if _step != null:
		_step.on_move(self)


func _on_session_matched(_center: Vector2i, color: int, _cells: Array[Vector2i]) -> void:
	if not running:
		return
	_pending_match = MatchInfo.new()
	_pending_match.color = color
	_pending_match.next_before = first_recipe_next()


## 매치 뒤 족보 진행 결과가 오면 단계에 매치를 알린다 (매치 밖의 카드 바꾸기는 무시).
func _on_session_recipes(_recipes: RecipeSet, outcome: RecipeSet.ClearOutcome) -> void:
	_check_multi_recipes()
	if not running or _pending_match == null:
		return
	var info: MatchInfo = _pending_match
	_pending_match = null
	var advanced: Dictionary[int, bool] = {}
	for slot: int in outcome.advanced_slots:
		advanced[slot] = true
	info.advanced = advanced.size()
	info.completed = outcome.completed_slots.size()
	if _step != null:
		_step.on_match(self, info)
		if info.completed > 0:
			_step.on_event(self, CharacterLessonStep.RECIPE, info.completed)


## 능력 표시가 바뀌면 안내 표시를 다시 덧붙인다.
func _on_session_marks(_marks: Array[BoardMark]) -> void:
	if _has_tutorial_marks():
		_emit_marks()


func _on_ability_triggered(_message: String) -> void:
	_on_event(TutorialMoment.ABILITY, 0)


func _on_session_moment(name: StringName) -> void:
	_on_event(name, 0)


func _on_metric_changed(key: StringName, amount: int) -> void:
	_on_event(key, amount)


## 캐릭터 튜토리얼 사건: 지금 단계에 알리고, 처음 일어난 순간이면 설명을 띄운다.
func _on_event(event: StringName, amount: int) -> void:
	if running and _step != null:
		_step.on_event(self, event, amount)
	if guide == null or _moment_open or _offer != null:
		return
	var moment: TutorialMoment = guide.moment_for(event)
	if moment != null:
		show_notice(lessons.title_for(guide.tutorial, session.character), moment.text, moment.holes)


func _check_multi_recipes() -> void:
	if _multi_store == null or running or not session.is_running():
		return
	var slots: Array[int] = session.recipes.slots_waiting_same_color(_canonical())
	if slots.is_empty():
		return
	var holes: PackedStringArray = PackedStringArray()
	for slot: int in slots:
		holes.append("card:%d" % slot)
	if show_notice(tips.multi_head, tips.multi_text, holes):
		_multi_store.mark_seen(TutorialStore.SEEN_MULTI_RECIPES)
		_multi_store = null


func _emit_recipes() -> void:
	session.recipes_updated.emit(session.recipes, RecipeSet.ClearOutcome.new())


func _reset_tools() -> void:
	_runner = null
	_free = false
	_hint_level = 0
	_banner_left = -1.0
	_grow_queue.clear()
	_hold_seeds = false
	_letters.clear()
	_pending_match = null
	_moment_open = false
	_moment_holes = PackedStringArray()
	_offer = null
	_guide_marks = []
	_hint_marks = []
	_ring_marks.clear()
	if puzzle_bar != null:
		puzzle_bar.visible = false
	if result_panel != null:
		result_panel.visible = false
