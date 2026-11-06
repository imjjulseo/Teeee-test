class_name RunMetrics
extends RefCounted
## 한 판의 업적 지표 (기획서 8.6 · 8.7장, 별첨 B). 이름(StringName) → 정수.
## 능력은 자기 지표를 add(누적) / record_max(한 번에 가장 큰 값)로 남기고, 판이 끝나면 AchievementTracker가
## 업적 목표와 비교한다. 업적 데이터(achievements.tres)가 같은 이름을 쓴다. 판 공통 지표(점수·매치·족보)는
## 판이 끝날 때 SessionStats에서 채운다 (fill_from_session).
## 이동 습관 지표(히든 업적)도 여기서 센다: 좌우 이동 수, 같은 방향으로 이어 간 칸 수와 그 뒤 매치.
## 능력이 남길 때마다 changed를 보낸다 (캐릭터 튜토리얼이 목표·처음 보는 순간으로 쓴다, 8.8장).

## add / record_max 한 번: amount = 더한 값 또는 이번에 잰 값 (record_max는 최댓값이 바뀌지 않아도 보낸다).
signal changed(key: StringName, amount: int)

const SCORE: StringName = &"score"
const MATCHES: StringName = &"matches"
const RECIPES: StringName = &"recipes"
## 히든 업적 지표 (8.7장, 진행만 기록): 왼쪽·오른쪽 이동 수 중 작은 쪽, 초당 이동 수 × 100, 직선 이동 뒤 매치 수.
const BOTH_SIDES_MOVES: StringName = &"hidden_both_sides_moves"
const MOVES_PER_SECOND_X100: StringName = &"hidden_moves_per_second_x100"
const STRAIGHT_MATCHES: StringName = &"hidden_straight_matches"

## "직선 이동 뒤 매치"로 치는 같은 방향 연속 칸 수 (8.7장 파키케팔로사우르스 조건 초안).
## 값은 AchievementBook.straight_run (판 시작 때 GameController가 넣는다).
var straight_run: int = 5

var _values: Dictionary[StringName, int] = {}
var _left_moves: int = 0
var _right_moves: int = 0
var _run_dir: Vector2i = Vector2i.ZERO
var _run_length: int = 0


func value(key: StringName) -> int:
	return _values.get(key, 0)


func add(key: StringName, amount: int = 1) -> void:
	_values[key] = value(key) + amount
	changed.emit(key, amount)


## 지금까지 가장 큰 값만 남긴다 ("한 번에 N").
func record_max(key: StringName, amount: int) -> void:
	_values[key] = maxi(value(key), amount)
	changed.emit(key, amount)


## 받아들여진 이동 한 번 (세션이 부른다).
func on_move(dir: Vector2i) -> void:
	if dir == Vector2i.LEFT:
		_left_moves += 1
	elif dir == Vector2i.RIGHT:
		_right_moves += 1
	_run_length = _run_length + 1 if dir == _run_dir else 1
	_run_dir = dir
	_values[BOTH_SIDES_MOVES] = mini(_left_moves, _right_moves)


## 이동으로 매치했다 (세션이 부른다). 같은 방향으로 straight_run칸 이상 이어 온 이동이면 직선 매치.
func on_move_match() -> void:
	if _run_length >= straight_run:
		add(STRAIGHT_MATCHES)


## 판이 끝날 때 판 공통 지표를 채운다.
func fill_from_session(session: GameSession) -> void:
	_values[SCORE] = session.score
	_values[MATCHES] = session.stats.matches
	_values[RECIPES] = session.stats.recipes_completed
	if session.stats.play_time > 0.0:
		_values[MOVES_PER_SECOND_X100] = int(100.0 * session.stats.moves / session.stats.play_time)
