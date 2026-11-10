class_name GameFlow
extends RefCounted
## 게임 상태 머신 (기획서 6장). 상태는 GameState enum 하나로만 관리한다. 순수 로직.
##
##   WAITING ──(첫 이동)──▶ PLAYING ──(0초)──▶ REVIVE ──accept──▶ PLAYING
##      │                    │  ▲                 │ decline
##      └──pause──▶ PAUSED ◀─┘  └ resume          ▼
##                    │                         RESULT ──retry──▶ WAITING
##                    ├─abandon──▶ ABANDONED     ▲
##                    └─restart──▶ WAITING       └── 0초인데 부활을 제안할 수 없으면 바로 RESULT
##
## - WAITING: 판이 깔리고 첫 이동을 기다림. 시계·리필 정지. 이동하면 PLAYING (E5).
## - PAUSED: WAITING·PLAYING에서 진입, resume하면 원래 상태로. 시계·리필·능력 정지, 입력 불가.
## - REVIVE: 0초 도달 후 부활 확인. 제안 여부는 RevivePolicy가 정한다 (E10).
##   revive_decision_time초 안에 고르지 않으면 끝내기와 같이 RESULT. 앱이 포커스를 잃은 동안은 멈춘다 (E36).
## - RESULT: 들어가기 직전 session.finish()로 능력의 남은 효과를 정산한다 (피버 스택 점수).
## - ABANDONED: 일시정지에서 메뉴로 나감. 결과를 거치지 않으므로 점수·보상이 기록되지 않는다.

enum GameState {
	WAITING,
	PLAYING,
	PAUSED,
	REVIVE,
	RESULT,
	ABANDONED,
}

signal state_changed(state: GameState)
## 새 세션이 만들어짐 (WAITING 진입 직전). 리스너가 세션 signal을 연결할 기회.
signal session_started(session: GameSession)
## 남은 시간이 0이 됐다 (부활 확인·결과 전에 한 번).
signal time_up

var state: GameState = GameState.WAITING
var session: GameSession
## 0초에 부활을 제안할지 정하는 규칙. 기본은 부활 없음.
var revive_policy: RevivePolicy = RevivePolicy.new()

var _config: GameConfig
## 선택한 캐릭터 (null이면 능력 없음). 재시작해도 유지된다.
var _character: CharacterData
## 일시정지 전 상태 (resume하면 돌아간다).
var _paused_from: GameState = GameState.PLAYING
## 부활 확인의 남은 시간(초).
var _revive_left: float = 0.0
## 앱이 포커스를 잃어 부활 확인 시간이 멈췄다.
var _revive_held: bool = false


## 설정이 잘못됐으면 오류를 알리고 기본값으로 진행한다 (GameConfig.ensure_valid, 배포 빌드에서도).
func _init(config: GameConfig, character: CharacterData = null) -> void:
	_config = GameConfig.ensure_valid(config)
	_character = character


## 다음 판부터 쓸 설정 (보드 단계가 바뀌었을 때). 잘못된 설정이면 기본값.
func set_config(config: GameConfig) -> void:
	_config = GameConfig.ensure_valid(config)


## 새 판을 만들어 WAITING부터 시작한다. rng를 주지 않으면 config.initial_seed로 만든다.
func start_new_game(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = GameRng.create(_config.initial_seed)
	_disconnect_session()
	revive_policy.reset()
	session = GameSession.new(_config, rng, null, _character)
	session.started.connect(_on_session_started)
	session.time_up.connect(_on_session_time_up)
	session_started.emit(session)
	_enter(GameState.WAITING)


func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	if state == GameState.PLAYING:
		session.advance(delta)
	elif state == GameState.REVIVE and not _revive_held:
		_revive_left -= delta
		if _revive_left <= 0.0:
			decline_revive()


## 부활 확인의 남은 시간 비율 (1 → 0, 게이지용).
func revive_ratio() -> float:
	return clampf(_revive_left / _config.revive_decision_time, 0.0, 1.0)


## 앱이 포커스를 잃음 / 되찾음: 잃은 동안 부활 확인 시간을 멈춘다.
func hold_revive(held: bool) -> void:
	_revive_held = held


## WAITING·PLAYING일 때만 이동을 전달한다. 전달했으면 true. 첫 이동이면 PLAYING이 된다.
## hand = 움직일 플레이어 (양손잡이: 0 왼손, 1 오른손).
func request_move(dir: Vector2i, hand: int = 0) -> bool:
	if not _accepts_moves():
		return false
	return session.request_move(dir, hand)


## 옆 칸을 탭했다: 플레이어(둘이면 둘 중 하나) 바로 옆 칸이면 그쪽으로 이동한다. 이동을 전달했으면 true.
func request_move_toward(cell: Vector2i) -> bool:
	if not _accepts_moves():
		return false
	for hand: int in session.board.player_count():
		var dir: Vector2i = Board.direction_from(session.board.player_position(hand), cell)
		if dir != Vector2i.ZERO:
			return session.request_move(dir, hand)
	return false


## 방향 입력을 누르고 있기 시작했다 / 뗐다, 화면을 꾹 눌렀다 (능력용: 파키 돌진, 방화광 소화).
func hold_direction(dir: Vector2i, hand: int = 0) -> void:
	if _accepts_moves():
		session.hold_direction(dir, hand)


## 뗀 것은 어느 상태에서든 알린다 (일시정지 중에 손을 떼도 돌진이 이어지지 않게).
func release_hold() -> void:
	if session != null:
		session.release_hold()


func long_press() -> void:
	if _accepts_moves():
		session.long_press()


func pause() -> bool:
	if not _accepts_moves():
		return false
	_paused_from = state
	_enter(GameState.PAUSED)
	return true


func resume() -> bool:
	if state != GameState.PAUSED:
		return false
	_enter(_paused_from)
	return true


func toggle_pause() -> void:
	if state == GameState.PAUSED:
		resume()
	else:
		pause()


## 일시정지 중에만 판을 포기(메뉴로 나가기)할 수 있다. 포기한 판은 점수가 기록되지 않는다.
func abandon() -> bool:
	if state != GameState.PAUSED:
		return false
	_enter(GameState.ABANDONED)
	return true


## 일시정지 중 "다시 시작": 보상 없이 새 판 (E20).
func restart(rng: RandomNumberGenerator = null) -> bool:
	if state != GameState.PAUSED:
		return false
	start_new_game(rng)
	return true


## RESULT에서만 새 판을 시작한다.
func retry(rng: RandomNumberGenerator = null) -> bool:
	if state != GameState.RESULT:
		return false
	start_new_game(rng)
	return true


## 부활 확인에서 부활: 남은 시간 revive_time초로 다시 진행한다.
func accept_revive() -> bool:
	if state != GameState.REVIVE:
		return false
	revive_policy.consume(session)
	session.revive(_config.revive_time)
	_enter(GameState.PLAYING)
	return true


## 부활 확인에서 끝내기: 결과로.
func decline_revive() -> bool:
	if state != GameState.REVIVE:
		return false
	_enter(GameState.RESULT)
	return true


func _accepts_moves() -> bool:
	return state == GameState.WAITING or state == GameState.PLAYING


func _on_session_started() -> void:
	if state == GameState.WAITING:
		_enter(GameState.PLAYING)


func _on_session_time_up() -> void:
	time_up.emit()
	_enter(GameState.REVIVE if revive_policy.can_offer(session) else GameState.RESULT)


## 이전 판의 signal이 새 판 상태를 바꾸지 않도록 연결을 끊는다.
func _disconnect_session() -> void:
	if session == null:
		return
	if session.started.is_connected(_on_session_started):
		session.started.disconnect(_on_session_started)
	if session.time_up.is_connected(_on_session_time_up):
		session.time_up.disconnect(_on_session_time_up)


func _enter(next: GameState) -> void:
	if next == GameState.RESULT:
		session.finish()  # 능력이 남은 효과를 정산한 점수로 결과를 낸다 (피버)
	elif next == GameState.REVIVE:
		_revive_left = _config.revive_decision_time
	state = next
	state_changed.emit(next)
