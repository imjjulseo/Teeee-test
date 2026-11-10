class_name MadanAbility
extends Ability
## 마탄 "장전": 씨앗이 전부 즉시 자라고, 시간·리필이 멈추며 shots발이 장전된다 (time_limit초 제한, 판 경과).
## 장전 중 이동 = 들어가는 칸의 블록을 쏜다: 그 칸에 들어가고, 떠난 칸에는 씨앗. 다 자란 블록이면 그 색으로 족보를 진행하고
## (탄으로 완성한 족보 × shot_multiplier), 캐릭터 족보는 진행하지 않는다. 매치 판정은 하지 않는다.
## shots발을 다 쏘면 devil_delay초 뒤, time_limit초가 지나면 바로 7번째 탄의 저주 — 장전할 때 예고된 하나:
## 시간 −time_penalty초(최소 0.5초) / 점수 −score_penalty / 이번 장전에 생긴 씨앗이 regen_delay초 동안 자라지 않음.

enum Curse { TIME, SCORE, REGEN }

@export var shots: int = 6
@export var time_limit: float = 18.0
@export var devil_delay: float = 0.65
@export var shot_multiplier: float = 1.25
@export var time_penalty: float = 8.0
@export var time_floor: float = 0.5
@export var score_penalty: int = 1000
@export var regen_delay: float = 30.0

## 업적 지표: 한 번 장전에 모두 명중한 횟수, 한 번 장전으로 완성한 족보 수(가장 큰 값), 쏴서 깬 블록 누적.
const METRIC_ALL_HIT: StringName = &"madan_all_hit"
const METRIC_LOAD_RECIPES: StringName = &"madan_load_recipes"
const METRIC_SHOT_BLOCKS: StringName = &"madan_shot_blocks"
## 장전이 끝나 7번째 탄이 나간다 (저주 직전).
const MOMENT_END: StringName = &"madan_end"

var _window: EffectWindowMetrics = EffectWindowMetrics.new(&"", METRIC_LOAD_RECIPES)

var armed: bool = false
var shots_used: int = 0
## 명중(다 자란 블록)한 탄 수.
var hits: int = 0
var curse: Curse = Curse.TIME
var time_left: float = 0.0

## 6발을 다 써서 저주를 기다리는 중.
var _firing: bool = false
var _devil_in: float = 0.0
## 이번 장전에 생긴 씨앗 (칸째로 움직이므로 칸 객체를 기억한다).
var _planted: Array[BoardCell] = []
## 탄으로 족보를 진행하는 중 (점수 배율).
var _shooting: bool = false


func trigger(session: GameSession) -> String:
	armed = true
	shots_used = 0
	hits = 0
	curse = session.get_rng().randi_range(0, Curse.size() - 1) as Curse
	time_left = time_limit
	_firing = false
	_planted.clear()
	_window.begin()
	session.refill.mature_all()
	return "장전: %d발 · 7번째 탄 %s" % [shots, curse_name()]


func intercept_move(session: GameSession, dir: Vector2i) -> bool:
	if not armed:
		return false
	var board: Board = session.board
	var target: Vector2i = board.step_from(board.player_pos, dir)
	if _firing or shots_used >= shots or not board.is_inside(target) or board.get_cell_type(target) == Board.CellType.PLAYER:
		session.move_blocked.emit(Board.MoveResult.new(Board.MoveOutcome.BLOCKED_BY_WALL, board.player_pos, target))
		return true
	shots_used += 1
	var hit_color: int = board.get_color(target) if board.get_cell_type(target) == Board.CellType.COLOR_BLOCK else Board.NO_COLOR
	session.blast_cell(target, true)  # 쏜 칸은 씨앗이 되고, 들어가면 그 씨앗이 떠난 칸으로 간다
	var result: Board.MoveResult = session.shift_player(dir)
	if result.is_accepted():
		_planted.append(board.get_cell(result.from))
	if hit_color != Board.NO_COLOR:
		hits += 1
		session.metrics.add(METRIC_SHOT_BLOCKS)
		if hits == shots:
			session.metrics.add(METRIC_ALL_HIT)
		_shooting = true
		session.apply_clear_to_recipes(hit_color)
		_shooting = false
	if shots_used >= shots:
		_firing = true
		_devil_in = devil_delay
	return true


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if _shooting:
		outcome.scale_completed(shot_multiplier)
		_window.on_outcome(session.metrics, outcome)


func clock_rate(clock: TimedSystem.Clock) -> float:
	return 0.0 if armed and (clock == TimedSystem.Clock.TIMER or clock == TimedSystem.Clock.REFILL) else 1.0


func advance(session: GameSession, delta: float) -> void:
	if not armed:
		return
	if _firing:
		_devil_in -= delta
		if _devil_in <= TimedSystem.EPSILON:
			_devil(session)
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		shots_used = shots
		_devil(session)


func time_to_next_event() -> float:
	if not armed:
		return INF
	return maxf(_devil_in if _firing else time_left, 0.0)


func status_text() -> String:
	if not armed:
		return ""
	return "%d발 · %s초 · %s" % [shots - shots_used, Ability.format_seconds(time_left), curse_name()]


func effect_remaining() -> float:
	return maxf(time_left, 0.0) if armed else -1.0


## 예고된 저주 문구 (예: "시간 −8초").
func curse_name() -> String:
	match curse:
		Curse.TIME:
			return "시간 −%s초" % Ability.format_number(time_penalty)
		Curse.SCORE:
			return "점수 −%d" % score_penalty
	return "재생 %s초" % Ability.format_number(regen_delay)


func _devil(session: GameSession) -> void:
	session.notify_moment(MOMENT_END)
	armed = false
	_firing = false
	match curse:
		Curse.TIME:
			session.take_time(time_penalty, time_floor)
		Curse.SCORE:
			session.add_bonus_score(-mini(session.score, score_penalty), "7번째 탄")
		Curse.REGEN:
			for cell: BoardCell in _planted:
				cell.delay_growth(regen_delay)
	_planted.clear()
	session.announce("7번째 탄: %s" % curse_name())
