class_name GameController
extends Node
## 순수 로직 GameFlow(상태 머신)를 소유하고 단조 시계(Time.get_ticks_usec) 기준 누적 시간으로 진행시킨다.
## 입력/버튼은 main.tscn의 연결로 받고, 결과는 View 종류별 채널로 알린다 (View는 상태를 바꾸지 않는다):
##   BoardChannel → 보드 화면 / HudChannel → HUD / FlowChannel → 흐름(오버레이·입력·방향키·씬 전환)
## 채널은 main.tscn에서 이 노드의 자식이며, 각 View는 자기 채널만 구독한다.

@export var config: GameConfig
## 진행·재화 수치 (경험치, 레벨업 보상, 보드 단계, 부활 비용).
@export var progression: ProgressionConfig
## 업적 목록·보상 (판이 결과로 끝날 때 평가한다).
@export var achievements: AchievementBook
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""
## 선택 가능한 캐릭터 목록. 저장된 선택(CharacterStore)으로 캐릭터를 고른다.
@export var roster: CharacterRoster
@export var board_channel: BoardChannel
@export var hud_channel: HudChannel
@export var flow_channel: FlowChannel
## 규칙 튜토리얼·첫 실전 판 안내 (비어 있으면 튜토리얼 없이).
@export var tutorial_director: TutorialDirector

var _flow: GameFlow
var _best_store: BestScoreStore
var _progress: ProgressStore
var _character: CharacterData
## 체험 한 판 (캐릭터 화면에서): 보상·경험치·최고 기록·플레이 기록·부활 없음. 나가면 캐릭터 화면으로.
var _trial: bool = false
## 규칙 튜토리얼 판 (튜토리얼을 아직 안 끝냈다): 남은 시간이 흐르지 않고 보상·기록·업적 없음. 끝나면 실전 판으로.
var _tutorial: bool = false
## 규칙 튜토리얼 다시 보기 (PlayRequest.replay_tutorial): 기록·업적 없이 끝나면 메뉴로.
var _replay: bool = false
## 디버그: 이 씬의 판 제한시간 (PlayRequest.game_seconds, 0 = 평소대로).
var _debug_seconds: float = 0.0
## 이번 판 시작 때 첫 실전 판 안내를 띄운다.
var _show_intro: bool = false
## 다음 판 시작 때 캐릭터 튜토리얼을 연다 (첫 뽑기 캐릭터 · 튜토리얼 다시 하기 · 튜토리얼 판 다시 시작).
var _lesson_pending: bool = false
## 다음 판 시작 때 처음 쓰는 캐릭터에게 튜토리얼을 할지 묻는다.
var _offer_pending: bool = false
## 캐릭터 튜토리얼을 마치고 온 실전 판: 남은 순간 설명을 이어 간다.
var _carry_guide: CharacterMomentGuide
var _tutorial_store: TutorialStore
var _last_ticks_usec: int = 0
## 이번 판을 시작할 때의 계정 레벨 (플레이 기록: 보상을 받기 전 레벨).
var _run_level: int = 1


func _ready() -> void:
	# 씬 연결 누락은 알리고 게임을 시작하지 않는다 (assert와 달리 배포 빌드에서도 동작, 알 수 없는 오류로 죽지 않음).
	var missing: PackedStringArray = missing_channels()
	if not missing.is_empty():
		push_error("GameController: channels not assigned in the scene: %s. The game will not start." % ", ".join(missing))
		set_process(false)
		return
	config = GameConfig.ensure_valid(config)
	progression = ProgressionConfig.ensure_valid(progression)
	achievements = AchievementBook.ensure_valid(achievements)
	_best_store = BestScoreStore.new(save_path)
	_progress = ProgressStore.new(save_path)
	var trial_id: StringName = TrialRequest.take()
	_replay = PlayRequest.take_replay_tutorial()
	_debug_seconds = PlayRequest.take_game_seconds()
	if roster != null:
		_trial = trial_id != &""
		# 체험 판은 해금과 무관하게 그 캐릭터, 아니면 장착한 캐릭터 (해금하지 않았으면 기본 캐릭터)
		_character = roster.find(trial_id) if _trial else \
			CharacterCollection.new(roster, _progress, CharacterStore.new(save_path)).equipped_character()
	_setup_tutorial()
	_setup_lesson(_trial)  # 체험 판 = 캐릭터 튜토리얼 (E38)
	_flow = GameFlow.new(_stage_config(), _character)
	# 체험 판은 부활 없음 (8.4장)
	_flow.revive_policy = RevivePolicy.new() if _trial or _tutorial else DiamondRevivePolicy.new(_progress, progression.revive_diamonds)
	_flow.session_started.connect(_on_session_started)
	_flow.state_changed.connect(_on_flow_state_changed)
	_flow.time_up.connect(flow_channel.time_up.emit)
	_start.call_deferred()


## 튜토리얼을 아직 안 끝냈으면 이 판은 규칙 튜토리얼 (기본 캐릭터, 튜토리얼 판 규칙). 첫 캐릭터로 시작하면 흐름을 넘긴다.
func _setup_tutorial() -> void:
	_tutorial_store = TutorialStore.new(save_path)
	if _trial or tutorial_director == null:
		return
	_tutorial = _replay or not _tutorial_store.done
	if _tutorial:
		_character = roster.default_character() if roster != null else null
		return
	_show_intro = not _tutorial_store.has_seen(TutorialStore.SEEN_REAL_GAME)


## 캐릭터 튜토리얼 (8.8장): 첫 뽑기로 받은 캐릭터로 처음 시작하거나 "튜토리얼 다시 하기"면 바로, 처음 쓰는 캐릭터면 묻는다.
## 첫 캐릭터 판은 흐름을 넘긴다 (TutorialStore.started_with_character).
func _setup_lesson(wants_lesson: bool) -> void:
	if tutorial_director == null or _tutorial or _character == null:
		return
	var first_character: bool = _tutorial_store.flow == TutorialStore.Flow.FIRST_CHARACTER and _tutorial_store.want_character == _character.id
	if not _trial:
		_tutorial_store.started_with_character()
	if tutorial_director.lesson_for(_character.id) == null:
		return
	_lesson_pending = wants_lesson or (first_character and not _trial)
	_offer_pending = not _lesson_pending and not _tutorial_store.has_seen_character(_character.id)
	if _lesson_pending:
		_show_intro = false


## 캐릭터 튜토리얼 판인지 (보상·기록 없음).
func _in_lesson() -> bool:
	return tutorial_director != null and tutorial_director.is_lesson()


## 캐릭터 튜토리얼이 끝났다: 실전 판이면 같은 캐릭터로 새 판 (남은 순간 설명은 이어서), 체험이면 연 화면으로 (체험 = 튜토리얼, E38).
func _on_lesson_finished() -> void:
	if not is_running():
		return
	if _trial:
		_leave_trial()
		return
	_carry_guide = tutorial_director.guide
	_flow.set_config(_stage_config())
	_flow.start_new_game()


## 이 판이 캐릭터 튜토리얼인지 (테스트/디버그용).
func is_lesson() -> bool:
	return _in_lesson()


## 이 판이 규칙 튜토리얼인지 (테스트/디버그용).
func is_tutorial() -> bool:
	return _tutorial


## 튜토리얼 진행이 판을 멈추고 있는지 (설명·결과 카드).
func _tutorial_halts() -> bool:
	return tutorial_director != null and tutorial_director.halts_game()


func _tutorial_takes_moves() -> bool:
	return tutorial_director != null and tutorial_director.intercepts_moves()


## 규칙 튜토리얼이 끝났다 (끝까지 또는 건너뛰기): 기록하고 실전 판으로. 첫 실전 판 안내가 끝난 것은 무시.
func _on_tutorial_finished() -> void:
	if not _tutorial:
		return
	if _replay:  # 다시 보기 (설정): 기록·업적 없이 메뉴로
		flow_channel.quit_to_menu.emit()
		return
	_tutorial_store.complete_rule_tutorial()
	AchievementTracker.new(achievements, AchievementStore.new(save_path), _progress).complete_tutorial()
	flow_channel.tutorial_finished.emit()


## 씬에서 지정되지 않은 채널 이름 목록 (비어 있으면 정상).
func missing_channels() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	if board_channel == null:
		missing.append("board_channel")
	if hud_channel == null:
		missing.append("hud_channel")
	if flow_channel == null:
		missing.append("flow_channel")
	return missing


## 게임을 시작했는지 (채널 누락 등으로 시작하지 못했으면 false).
func is_running() -> bool:
	return _flow != null


func _process(_delta: float) -> void:
	if _flow == null or _flow.session == null:
		return
	var now: int = Time.get_ticks_usec()
	# 프레임이 길게 멈춰도(로딩·GC) 한 번에 흘려보내는 시간은 max_frame_delta까지만.
	var delta: float = config.clamp_frame_delta((now - _last_ticks_usec) / 1_000_000.0)
	_last_ticks_usec = now
	if not _tutorial_halts():  # 튜토리얼 설명 중에는 판이 멈춘다
		_flow.advance(delta)
	if _flow.state == GameFlow.GameState.REVIVE:
		flow_channel.revive_countdown.emit(_flow.revive_ratio())
	hud_channel.publish_frame(_flow.session)


## 창/앱이 포커스를 잃으면 자동 일시정지, Android 뒤로 가기는 일시정지 토글 (B14).
func _notification(what: int) -> void:
	if _flow == null:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			_flow.pause()
			_flow.hold_revive(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			_flow.hold_revive(false)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_flow.toggle_pause()


func _on_move_requested(dir: Vector2i, hand: int) -> void:
	if not is_running():
		return
	if _tutorial_takes_moves():
		tutorial_director.handle_move(dir)
	else:
		_flow.request_move(dir, hand)


func _on_hold_started(dir: Vector2i, hand: int) -> void:
	if is_running():
		_flow.hold_direction(dir, hand)


func _on_hold_released() -> void:
	if is_running():
		_flow.release_hold()


func _on_long_pressed() -> void:
	if is_running():
		_flow.long_press()


## 보드가 탭을 칸으로 바꿔 알린다 (스와이프 모드의 옆 칸 탭).
func _on_cell_tapped(cell: Vector2i) -> void:
	if not is_running():
		return
	if _tutorial_takes_moves():
		var dir: Vector2i = Board.direction_from(_flow.session.board.player_pos, cell)
		if dir != Vector2i.ZERO:
			tutorial_director.handle_move(dir)
	else:
		_flow.request_move_toward(cell)


## 일시정지의 다시 시작: 보상 없이 새 판. 튜토리얼 판(체험 포함)은 튜토리얼을 처음부터.
func _on_restart_requested() -> void:
	if not is_running():
		return
	_lesson_pending = _in_lesson()  # 튜토리얼 판의 다시 시작은 튜토리얼을 처음부터
	_flow.set_config(_stage_config())
	_flow.restart()


## 결과 화면의 메뉴.
func _on_result_menu_requested() -> void:
	if is_running():
		flow_channel.quit_to_menu.emit()


## 체험 판을 마치고 체험을 연 화면으로 (캐릭터 화면 / 상점).
func _leave_trial() -> void:
	if TrialRequest.back_to_shop:
		flow_channel.back_to_shop.emit()
	else:
		flow_channel.back_to_characters.emit()


## 체험 판인지 (테스트/디버그용).
func is_trial() -> bool:
	return _trial


## 부활 확인 창의 부활 / 끝내기.
func _on_revive_accepted() -> void:
	if is_running():
		_flow.accept_revive()


func _on_revive_declined() -> void:
	if is_running():
		_flow.decline_revive()


## 지금 계정 레벨의 보드 단계를 적용한 판 설정.
func _stage_config() -> GameConfig:
	if _tutorial:
		return tutorial_director.tutorial.apply_to(config)
	var stage: BoardStage = progression.stage_for_level(_progress.level)
	var staged: GameConfig = stage.apply_to(config) if stage != null else config
	if _debug_seconds <= 0.0:
		return staged
	var short: GameConfig = staged.duplicate() as GameConfig  # 디버그: 짧은 판 (PlayRequest.game_seconds)
	short.game_duration = _debug_seconds
	return short


func _on_pause_requested() -> void:
	if is_running():
		_flow.toggle_pause()


## 일시정지 화면에서 조작 방법을 바꿨다 (E40): 지금 판에 바로 반영. 규칙 튜토리얼은 스와이프 그대로 (저장은 됨).
func _on_control_mode_changed(mode: OptionsStore.ControlMode) -> void:
	flow_channel.control_mode_ready.emit(OptionsStore.ControlMode.SWIPE if _tutorial else mode)


## 일시정지 화면에서 효과 줄이기를 바꿨다 (E40).
func _on_reduce_motion_changed(enabled: bool) -> void:
	flow_channel.reduce_motion_ready.emit(enabled)


func _on_resume_requested() -> void:
	if is_running():
		_flow.resume()


func _on_retry_requested() -> void:
	if is_running():
		_flow.set_config(_stage_config())  # 레벨이 올랐으면 새 보드 단계로
		_flow.retry()


## 일시정지 화면의 MAIN MENU: 판을 포기(ABANDONED)하고 메뉴로. RESULT를 거치지 않으므로 최고 점수에 반영되지 않는다.
func _on_quit_to_menu_requested() -> void:
	if is_running() and _flow.abandon():
		if _trial:
			_leave_trial()
		else:
			flow_channel.quit_to_menu.emit()


## 모든 노드의 _ready 이후 첫 판을 시작해, 연결된 View/HUD가 초기 signal을 받게 한다.
func _start() -> void:
	var options: OptionsStore = OptionsStore.new(save_path)
	# 규칙 튜토리얼은 스와이프로 가르친다 (키보드는 그대로)
	flow_channel.control_mode_ready.emit(OptionsStore.ControlMode.SWIPE if _tutorial else options.control_mode)
	flow_channel.reduce_motion_ready.emit(options.reduce_motion)
	_last_ticks_usec = Time.get_ticks_usec()
	_flow.start_new_game()


func _on_flow_state_changed(state: GameFlow.GameState) -> void:
	match state:
		GameFlow.GameState.REVIVE:
			flow_channel.revive_offered.emit(_flow.session.score, progression.revive_diamonds, _progress.diamonds, config.revive_time)
		GameFlow.GameState.RESULT when _trial or _in_lesson():
			# 체험 판·캐릭터 튜토리얼 판은 남은 시간이 흐르지 않아 결과에 오지 않는다. 혹시 오면 보상·기록 없이 연 화면으로.
			if _trial:
				_leave_trial()
			else:
				flow_channel.quit_to_menu.emit()
		GameFlow.GameState.RESULT:
			var score: int = _flow.session.score
			var is_new_best: bool = _best_store.submit(score)
			if _character != null:
				_best_store.submit_character(_character.id, score)
				flow_channel.character_best_ready.emit(_character.display_name, _best_store.best_of(_character.id))
			var rewards: RunRewards.Result = RunRewards.compute(score, _flow.session.collected_coins(),
				_progress.level, _progress.experience, progression)
			var coins_before: int = _progress.coins
			_progress.apply_rewards(rewards)
			var tracker: AchievementTracker = AchievementTracker.new(achievements, AchievementStore.new(save_path), _progress)
			var completions: Array[AchievementTracker.Completion] = tracker.record_game(_flow.session, _best_store.best)
			_log_playtest(PlaytestLog.END_RESULT)
			flow_channel.result_ready.emit(score, _best_store.best, is_new_best, _flow.session.collected_coins())
			flow_channel.rewards_ready.emit(rewards, coins_before, _progress.coins)
			flow_channel.achievements_ready.emit(GameController.achievement_lines(completions))
			var flow: TutorialFlow = TutorialFlow.new(TutorialStore.new(save_path), tracker.store.stat("games"))
			flow_channel.result_guided.emit(flow.guides_to_menu())
		GameFlow.GameState.ABANDONED when not _trial and not _tutorial and not _in_lesson():
			_log_playtest(PlaytestLog.END_ABANDONED)
	flow_channel.state_changed.emit(state)


## 판이 끝날 때 플레이 기록 한 줄 (개발 빌드 + 설정이 켜져 있을 때만). 최고 점수와 달리 포기한 판도 남긴다.
func _log_playtest(end: String) -> void:
	if not PlaytestLog.is_enabled(config):
		return
	var character_id: StringName = _character.id if _character != null else &""
	var context: PlaytestLog.Context = PlaytestLog.Context.new()
	context.account_level = _run_level
	context.board_stage = progression.stage_number(_run_level)
	context.control = OptionsStore.ControlMode.find_key(OptionsStore.new(save_path).control_mode).to_lower()
	PlaytestLog.append(PlaytestLog.row_for(_flow.session, character_id, end, "", context))


## 결과 화면 보상 목록 줄 [이름, 보상]: ["업적 블록 부수기 I", "업적에서 받기"], 히든 업적은 ["업적 돌머리", "히든 캐릭터"].
static func achievement_lines(completions: Array[AchievementTracker.Completion]) -> Array[PackedStringArray]:
	var lines: Array[PackedStringArray] = []
	for completion: AchievementTracker.Completion in completions:
		lines.append(PackedStringArray(["업적 %s" % completion.name, "업적에서 받기" if completion.needs_claim else completion.reward]))
	return lines


func _on_session_started(session: GameSession) -> void:
	session.metrics.straight_run = achievements.straight_run
	_run_level = _progress.level
	board_channel.bind(session, _character)
	hud_channel.bind(session, _character)
	if _tutorial:
		tutorial_director.begin(session)
	elif _lesson_pending:
		_lesson_pending = false
		_tutorial_store.mark_character_seen(_character.id)
		tutorial_director.begin_lesson(session, tutorial_director.lesson_for(_character.id))
	elif _carry_guide != null:
		tutorial_director.watch_moments(session, _carry_guide)
		_carry_guide = null
	elif _offer_pending:
		_offer_pending = false
		if not _trial:
			_tutorial_store.mark_character_seen(_character.id)
		tutorial_director.offer_lesson(session, tutorial_director.lesson_for(_character.id))
	elif _show_intro:
		_show_intro = false
		_tutorial_store.mark_seen(TutorialStore.SEEN_REAL_GAME)
		tutorial_director.show_intro(session)
	if tutorial_director != null and not _trial and not _tutorial:  # 처음 볼 때 안내: 족보 동시 진행 (6d)
		tutorial_director.watch_multi_recipes(session, _tutorial_store)
