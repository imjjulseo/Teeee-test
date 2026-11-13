extends "res://tests/smoke/smoke_base.gd"
## 6c 캐릭터 튜토리얼 (기획서 8.8장). 모드:
## - first : 첫 뽑기로 받은 시계공으로 시작 → 캐릭터 튜토리얼 판(시간 안 흐름) → 소개·캐릭터 족보 설명 클릭 → 발동해 보기 퍼즐(실제 방향키)
##           → 발동 순간 설명 → 정지 중 매치(활용) → 준비 끝 "시작" → 같은 캐릭터 실전 판 (보상 있는 판, 순간 설명 이어짐)
## - wall  : 튜토리얼 / 체험 요청(체험)으로 벽 타는 자 → 연습 판에서 실제 위 키로 벽 매치 → 벽 매치 순간 설명 → 한 번 더 → 캐릭터 화면으로
## - offer : 처음 쓰는 축제꾼 → "튜토리얼 / 바로 시작" 질문 → 바로 시작 실제 클릭 → 그냥 판, 처음 사용 기록
## - accept: 같은 질문에서 튜토리얼 실제 클릭 → 캐릭터 튜토리얼
## - redo  : 캐릭터 화면 → 가진 시계공 → 튜토리얼 / 체험 실제 클릭 → 체험 튜토리얼 판 → 건너뛰기 → 캐릭터 화면

const KEYS: Dictionary[Vector2i, Key] = {Vector2i.UP: KEY_UP, Vector2i.DOWN: KEY_DOWN, Vector2i.LEFT: KEY_LEFT, Vector2i.RIGHT: KEY_RIGHT}

var _path: Array[Vector2i] = []
var _cooldown: float = 0.0
var _lesson_session: GameSession
var _shots: Dictionary[String, bool] = {}
var _moments: int = 0


func _setup() -> void:
	var character: StringName = &"clock"
	match mode:
		"wall":
			character = &"wall"
		"offer", "accept":
			character = &"fever"
	ProgressStore.new().unlock(character)
	CharacterStore.new().select(character)
	var store: TutorialStore = TutorialStore.new()
	match mode:
		"first":
			store.restart_all()
			store.complete_rule_tutorial()
			store.mark_seen(TutorialStore.SEEN_REAL_GAME)
			store.got_first_character(&"clock")
		"offer", "accept":
			store.restart_all()
			store.complete_rule_tutorial()
			store.mark_seen(TutorialStore.SEEN_REAL_GAME)
		"wall":
			TrialRequest.character_id = &"wall"
	if mode == "redo":
		change_scene_to_file("res://scenes/character_select.tscn")
	else:
		change_scene_to_file("res://scenes/main.tscn")


func _director() -> TutorialDirector:
	return node("Tutorial") as TutorialDirector


func _spot() -> SpotlightOverlay:
	return node("SpotlightOverlay") as SpotlightOverlay


func _tick() -> void:
	match mode:
		"first", "wall":
			_tick_lesson()
		"offer", "accept":
			_tick_offer()
		"redo":
			_tick_redo()


# --- first · wall: 튜토리얼 끝까지 ----------------------------------------------------

func _tick_lesson() -> void:
	match step:
		0:
			if playing(0.5):
				expect(controller.is_lesson(), "character tutorial game")
				expect(session().character.id == StringName(mode if mode == "wall" else "clock"), "with that character")
				expect(session().frozen_clocks.has(TimedSystem.Clock.TIMER), "time does not flow")
				expect(TutorialStore.new().has_seen_character(session().character.id), "first use recorded")
				if mode == "first":
					expect(TutorialStore.new().flow == TutorialStore.Flow.DONE, "flow done (played with the first character)")
					expect(not controller.is_trial(), "not a trial")
				else:
					expect(controller.is_trial(), "tutorial again = trial game")
				expect(_spot().caption_head().ends_with(_director().lesson.cap), "intro card (%s)" % _spot().caption_head())
				shot("%s_intro" % mode)
				_lesson_session = session()
				next_step()
		1:
			if not is_instance_valid(controller):  # 체험은 튜토리얼이 끝나면 연 화면으로 돌아간다 (E38)
				if mode == "wall" and current_scene != null and current_scene.name == "CharacterSelect":
					expect(smoke_log_rows().is_empty(), "no playtest row")
					finish()
				return
			if not controller.is_lesson():
				next_step()
				return
			_cooldown -= 1.0 / 60.0
			if _cooldown <= 0.0:
				_drive()
		2:
			if step_time > 0.5:
				_check_real_game()
				finish()


func _drive() -> void:
	var director: TutorialDirector = _director()
	if _spot().is_blocking():
		if director.is_moment_open():
			_moments += 1
			_shot_once("%s_moment_%d" % [mode, _moments])
		else:
			_shot_once("%s_say_%d" % [mode, director.step_index])
		var button: Button = _spot().get_node("%CaptionButton")
		click_control(button if button.visible else _spot().get_node("%Caption"))
		_cooldown = 0.3
		return
	var runner: PuzzleRunner = director.runner()
	if runner != null:
		if runner.is_playing():
			if _path.is_empty():
				_path = runner.puzzle.solution.path.duplicate()
				_shot_once("%s_trigger_puzzle" % mode)
			press_key(KEYS[_path.pop_front()])
			_cooldown = 0.08
		return
	var lesson_step: CharacterLessonStep = director.current_step() as CharacterLessonStep
	if lesson_step == null:
		return
	_shot_once("%s_lesson_%d" % [mode, director.step_index])
	if mode == "wall" and not lesson_step.practice_rows.is_empty():
		press_key(KEY_UP)  # 연습 판: 벽으로 올라가면 3칸 매치
	elif mode == "wall":
		_make_wall_match()
	else:
		var board: Board = session().board
		board.teleport_player(board.center())
		prepare_match_above(0)
		flow().request_move(Vector2i.UP)
	_cooldown = 0.6


## 맨 위 줄 가운데에 3칸 십자를 칠하고 실제로 위로 움직여 벽 매치.
func _make_wall_match() -> void:
	var board: Board = session().board
	var top: Vector2i = Vector2i(board.size / 2, 0)
	board.teleport_player(top + Vector2i.DOWN)
	_paint([top, top + Vector2i.LEFT, top + Vector2i.RIGHT] as Array[Vector2i], 1)
	press_key(KEY_UP)


func _check_real_game() -> void:
	expect(not controller.is_lesson() and session() != _lesson_session, "real game after the tutorial")
	expect(flow().state == S.WAITING, "waits for the first move")
	expect(session().character.id == _lesson_session.character.id, "same character")
	expect(session().frozen_clocks.is_empty(), "time flows in the real game")
	expect(_director().guide != null, "moment explanations carry over")
	expect(_moments >= 1, "a first-time moment was explained (%d)" % _moments)
	if mode == "first":
		expect(not controller.is_trial(), "real game with rewards")
		expect(_director().guide.done, "clock: trigger moment was the only one")
	else:
		expect(controller.is_trial(), "tutorial again → trial game")
	shot("%s_real_game" % mode)


# --- offer · accept -------------------------------------------------------------

func _tick_offer() -> void:
	match step:
		0:
			if playing(0.5):
				expect(_director().is_offering(), "first use of the fever → asks")
				expect(_spot().button_texts() == PackedStringArray(["바로 시작", "튜토리얼"]), "two buttons (%s)" % ", ".join(_spot().button_texts()))
				expect(_director().halts_game(), "the question holds the game")
				expect(TutorialStore.new().has_seen_character(&"fever"), "asked once")
				shot("offer")
				click_control(_spot().get_node("%AltButton" if mode == "offer" else "%CaptionButton"))
				next_step()
		1:
			if step_time > 0.4:
				if mode == "offer":
					expect(not _director().is_offering() and not controller.is_lesson() and not _spot().is_open(), "start right away")
					flow().request_move(Vector2i.UP)
					expect(flow().state == S.PLAYING, "plays normally")
				else:
					expect(controller.is_lesson(), "tutorial chosen → character tutorial")
					expect(_spot().is_open() and _spot().caption_head() == "축제꾼 / 피버", "intro (%s)" % _spot().caption_head())
				finish()


# --- redo -----------------------------------------------------------------------

func _tick_redo() -> void:
	match step:
		0:
			if in_scene("CharacterSelect", 0.6):
				var select: CharacterSelect = current_scene as CharacterSelect
				select.show_character(&"clock")
				next_step()
		1:
			if step_time > 0.3:
				var page: CharacterInfo = (current_scene as CharacterSelect).carousel().current_page()
				expect(page.shown_actions().has("튜토리얼 / 체험"), "owned character → tutorial and trial (%s)" % ", ".join(page.shown_actions()))
				shot("redo_sheet")
				click_control(page.get_node("%LessonButton"))
				next_step()
		2:
			if playing(0.5):
				expect(controller.is_trial() and controller.is_lesson(), "trial game that is the tutorial")
				click_control(_spot().get_node("%SkipButton"))
				controller = null
				next_step()
		3:
			if in_scene("CharacterSelect", 0.3):
				finish()

func _shot_once(shot_name: String) -> void:
	if not _shots.has(shot_name):
		_shots[shot_name] = true
		shot(shot_name)
