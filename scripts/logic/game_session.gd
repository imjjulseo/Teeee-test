class_name GameSession
extends RefCounted
## 한 판의 순수 게임 로직 (기획서 3~5장). Node 없이 request_move와 advance(delta)로만 진행된다.
## 세션은 순서를 조율하고, 세부 규칙은 구성 요소가 맡는다:
##   Board(판·이동·매치 판정) / TimeKeeper(남은 시간) / RefillSystem(씨앗) / CoinSystem(금화) / RecipeSet(족보) / Ability(캐릭터)
## - 시작: 첫 이동(벽에 막힌 입력 포함)에 시계가 흐르기 시작한다 (E5).
## - 이동: 입력 즉시 교환하고 바로 매치를 판정한다. 애니메이션은 View의 표현일 뿐이다 (E4).
## - 매치: 금화 줍기 → 매치 시간 획득 → 씨앗 심기 → 족보·캐릭터 족보 진행.
## - 시간: 등록된 TimedSystem과 능력의 다음 사건 시각에서 프레임을 끊어 처리한다 (프레임레이트 무관).
## - 종료: 남은 시간이 0이 되는 순간 TIMED_OUT → time_up. 부활하면 다시 RUNNING (GameFlow가 결정).
## - 캐릭터 능력: 캐릭터 족보를 완성하면 발동하고 진행이 0으로 돌아간다. 효과 중에도 족보는 진행·재발동한다 (E11).
##   능력별 동작은 Ability 하위 클래스에 있고 세션은 공통 훅만 부른다 (훅 목록은 Ability 참고).
## - 끝: 판이 결과로 끝나면 GameFlow가 finish()를 불러 능력이 남은 효과를 정산한다 (피버).

## 첫 이동으로 시계가 흐르기 시작했다.
signal started
signal move_started(result: Board.MoveResult)
signal move_blocked(result: Board.MoveResult)
## 매치 성공. cells는 씨앗이 심어진 4칸.
signal matched(center: Vector2i, color: int, cells: Array[Vector2i])
## 매치로 얻은 시간(초).
signal time_gained(seconds: float)
## 씨앗이 다 자라 색 블록이 된 칸들.
signal cells_refilled(cells: Array[Vector2i])
## 금화가 붙거나 사라진 칸.
signal coins_changed(cells: Array[Vector2i])
## 매치로 금화를 주웠다 (amount = 이번에 얻은 코인, chain = 연속 횟수).
signal coins_collected(amount: int, chain: int)
## 남은 시간이 0이 됐다. 이후 이동은 거절된다 (부활하면 다시 받는다).
signal time_up
## 매치로 족보가 진행되었을 때. outcome에 진행/완성 슬롯과 획득 점수가 담긴다.
signal recipes_updated(recipes: RecipeSet, outcome: RecipeSet.ClearOutcome)
signal score_changed(score: int)
## 능력 조건 진행이 바뀌었을 때 (발동 후 초기화 포함).
signal ability_updated(recipe: RecipeSet.Recipe)
## 능력 발동. message는 결과 문구 (예: "정지: 4초").
signal ability_triggered(message: String)
## 족보 밖에서 얻은 점수 (피버 정산 등). label은 연출 문구 (예: "피버 7스택!").
signal bonus_scored(points: int, label: String)
## 능력으로 색이 바뀐 칸. 바뀐 뒤 매치 판정은 하지 않는다.
signal cells_changed(cells: Array[Vector2i])
## 능력의 판 위 표시(깃발·구역)가 바뀌었다.
signal marks_changed(marks: Array[BoardMark])
## 능력이 메시지 줄에 알릴 문구 (발동 외의 사건: 현상금 색 변경 등).
signal ability_announced(text: String)
## 능력이 블록을 하나씩 터뜨렸다 (폭파범 연쇄). cells는 씨앗이 된 칸, color는 터진 블록의 색.
signal cells_blasted(cells: Array[Vector2i], color: int)
## 블록·족보 표시 방식이 바뀌었다 (null = 보통).
signal display_style_changed(style: DisplayStyle)
## 능력이 판 배치를 통째로 바꿨다 (거울 뒤집기). View는 판을 다시 그린다.
signal board_rearranged(board: Board)
## 능력 효과의 한 순간 (피버 끝, 수선 실패 등 — 지표로 세지 않는 사건). 캐릭터 튜토리얼이 처음 보는 순간을 설명한다.
signal moment(name: StringName)

## advance 한 번에 처리할 사건 수 상한 (무한 반복 방지).
const MAX_EVENTS_PER_ADVANCE: int = 10000

enum Phase {
	WAITING,  ## 첫 이동 전. 시계·리필 정지
	RUNNING,
	TIMED_OUT,  ## 0초 도달. 부활하면 RUNNING
}

var board: Board
var recipes: RecipeSet
var refill: RefillSystem
var coins: CoinSystem
var phase: Phase = Phase.WAITING
var score: int = 0
var match_count: int = 0
## 판 경과 시간(초). 첫 이동부터, 일시정지 제외. 시간 정지 능력과 무관하게 흐른다 (리필 총시간 기준).
var elapsed: float = 0.0
var character: CharacterData
## 캐릭터 족보 진행 (발동형이 아니면 null).
var ability_recipe: RecipeSet.Recipe
## 이번 판의 능력 인스턴스 (캐릭터 리소스의 능력을 복제한 것, 능력 없으면 null). 실행 중 상태를 가진다.
## 발동형·상시형 모두 있다.
var ability: Ability
## 판의 기준 seed (플레이 기록·재현용).
var base_seed: int = 0
## 플레이 통계 (기획서 10.1). 플레이 기록에 쓴다.
var stats: SessionStats = SessionStats.new()
## 업적 지표 (능력이 남기고, 판이 끝나면 AchievementTracker가 평가한다).
var metrics: RunMetrics = RunMetrics.new()
## 멈춘 시계 (튜토리얼: 남은 시간이 줄지 않음, 설명 중 씨앗이 자라지 않음). 능력 배속보다 앞선다.
var frozen_clocks: Array[TimedSystem.Clock] = []

var _config: GameConfig
var _time: TimeKeeper
## 능력 전용 seed RNG.
var _ability_rng: RandomNumberGenerator
## 시간에 따라 사건을 일으키는 구성 요소 (공통 시간표).
var _timed_systems: Array[TimedSystem] = []
## finish()가 이미 불렸는지 (정산은 한 번만).
var _finished: bool = false
## 매치 판정 규칙 (능력이 바꿀 수 있다).
var _match_rule: MatchRule


## rng는 판의 기준 seed로만 쓴다 (rng.seed에서 보드·리필·족보·능력·금화 RNG를 따로 만든다).
## p_board를 주지 않으면 config와 보드용 RNG로 새 보드를 생성한다. p_character를 주지 않으면 능력 없음.
## 설정이 잘못됐으면 오류를 알리고 기본값으로 진행한다 (GameConfig.ensure_valid, 배포 빌드에서도).
func _init(p_config: GameConfig, rng: RandomNumberGenerator, p_board: Board = null, p_character: CharacterData = null) -> void:
	_config = GameConfig.ensure_valid(p_config)
	base_seed = rng.seed
	_ability_rng = GameRng.derive(base_seed, GameRng.Stream.ABILITY)
	character = p_character
	if character != null and character.has_ability():
		ability = character.ability.duplicate() as Ability
	if character != null and character.has_recipe():
		ability_recipe = RecipeSet.Recipe.new(character.condition_colors.duplicate(), 0)
	board = p_board if p_board != null else Board.generate(_config, GameRng.derive(base_seed, GameRng.Stream.BOARD))
	_time = TimeKeeper.new(_config.game_duration)
	var color_count: int = _config.color_count
	var counted_board: Board = board  # 람다가 세션(self)을 캡처하지 않게 지역 변수로 (순환 참조 방지)
	var lengths: PackedInt32Array = ability.recipe_lengths(_config.recipe_lengths) if ability != null else _config.recipe_lengths
	recipes = RecipeSet.from_config(_config, GameRng.derive(base_seed, GameRng.Stream.RECIPES),
		func() -> PackedInt32Array: return counted_board.color_counts(color_count), lengths)
	var custom_rule: MatchRule = ability.match_rule() if ability != null else null
	_match_rule = custom_rule if custom_rule != null else MatchRule.new()
	_match_rule.canonical = _canonical()
	refill = RefillSystem.new(board, _config, GameRng.derive(base_seed, GameRng.Stream.REFILL))
	if ability != null:
		refill.color_filter = ability.refill_colors
	coins = CoinSystem.new(board, _config, GameRng.derive(base_seed, GameRng.Stream.COINS))
	_timed_systems = [refill, coins]
	# 세션 signal로 전달한다. 메서드로 연결해야 세션 ↔ 구성 요소 순환 참조가 생기지 않는다.
	refill.cells_matured.connect(_on_cells_matured)
	coins.coins_changed.connect(_on_coins_changed)
	coins.coins_collected.connect(_on_coins_collected)
	stats.max_remaining = remaining_time()
	if ability != null:
		ability.setup(self)


## 이동 요청 (플레이어 입력). 0초가 지났으면 거절하고 false. 첫 이동이면 시계를 시작한다.
## 이동은 즉시 반영되고 매치도 바로 판정한다 (E4). 벽에 막혀도 요청은 처리된 것으로 true.
## 조작 잠금 연출(연쇄 폭파 등) 중이면 무시하고 false. hand = 움직일 플레이어 (양손잡이, 그 밖에는 무시).
## 능력이 입력을 가로챌 수 있다 (사진 계획, 레이서 방향 전환, 마탄 사격).
func request_move(dir: Vector2i, hand: int = 0) -> bool:
	if phase == Phase.TIMED_OUT or is_input_locked():
		return false
	start()
	board.select_player(hand)
	if ability != null and ability.intercept_move(self, dir):
		return true
	return perform_move(dir)


## 실제로 한 칸 움직이고 매치를 판정한다 (능력의 자동 이동: 레이서 질주, 파키 돌진, 사진 실행). 입력 잠금·가로채기를 거치지 않는다.
func perform_move(dir: Vector2i) -> bool:
	if phase == Phase.TIMED_OUT:
		return false
	var result: Board.MoveResult = board.try_move(dir)
	if not result.is_accepted():
		if not _passes_through_wall(result):
			stats.blocked_moves += 1
			move_blocked.emit(result)
			return true
	else:
		move_started.emit(result)
		metrics.on_move(dir)
		if ability != null:
			ability.on_move(self, result)
	stats.count_move()
	var matched_now: bool = _resolve_match()
	if matched_now:
		metrics.on_move_match()
	if ability != null:
		ability.after_move(self, matched_now)
	return true


## 매치 판정 없이 플레이어를 한 칸 옮긴다 (마탄: 쏜 칸으로 들어감). 이동 수로 센다. 결과를 돌려준다.
func shift_player(dir: Vector2i) -> Board.MoveResult:
	var result: Board.MoveResult = board.try_move(dir)
	if result.is_accepted():
		stats.count_move()
		move_started.emit(result)
	else:
		move_blocked.emit(result)
	return result


## 방향 입력을 누르고 있기 시작했다 / 뗐다 / 화면을 꾹 눌렀다 (능력에 전달: 파키 돌진, 방화광 소화).
func hold_direction(dir: Vector2i, hand: int = 0) -> void:
	if phase == Phase.TIMED_OUT or ability == null:
		return
	board.select_player(hand)
	ability.on_hold(self, dir)


func release_hold() -> void:
	if ability != null:
		ability.on_release(self)


func long_press() -> void:
	if phase == Phase.TIMED_OUT or is_input_locked() or ability == null:
		return
	start()
	ability.on_long_press(self)


## 남은 시간을 seconds만큼 줄인다 (마탄 저주). minimum 밑으로는 내려가지 않는다.
func take_time(seconds: float, minimum: float) -> void:
	_time.set_remaining(maxf(minimum, remaining_time() - seconds))


## 벽에 막힌 이동을 능력이 대신 처리했는지 (거울: 벽을 통과하며 판을 뒤집음).
func _passes_through_wall(result: Board.MoveResult) -> bool:
	return result.outcome == Board.MoveOutcome.BLOCKED_BY_WALL and ability != null and ability.pass_through_wall(self, result)


## 능력이 판 배치를 통째로 바꿨을 때 부른다 (거울 뒤집기). View는 판을 다시 그린다.
func notify_board_rearranged() -> void:
	board_rearranged.emit(board)


## 매치 밖의 매치 1회로 시간을 준다 (예지안 모양, 수선사 폐곡선): 매치 수를 세고 그 차례의 매치 시간. 얻은 시간.
func award_match_time() -> float:
	match_count += 1
	stats.matches += 1
	var gained: float = _config.clear_time_for(match_count)
	_time.add(gained)
	stats.max_remaining = maxf(stats.max_remaining, remaining_time())
	time_gained.emit(gained)
	return gained


## 능력의 조작 잠금 연출 중인지 (입력을 받지 않는다).
func is_input_locked() -> bool:
	return ability != null and ability.locks_input()


## 플레이어를 to 칸과 맞바꾸고 그 자리의 매치를 판정한다 (떠돌이 순간이동). 이동 수로 세지 않는다. 매치했으면 true.
func teleport_player(to: Vector2i) -> bool:
	var result: Board.MoveResult = board.teleport_player(to)
	if not result.is_accepted():
		return false
	move_started.emit(result)
	return _resolve_match()


## pos의 다 자란 블록 하나를 터뜨린다 (폭파범 연쇄, 수선사): 금화 줍기 → 씨앗 심기. 시간·족보는 능력이 정한다.
## include_seeds면 씨앗도 (자랄 색으로) 깬다 (예지안). 그 밖의 칸이면 false.
func blast_cell(pos: Vector2i, include_seeds: bool = false) -> bool:
	var type: Board.CellType = board.get_cell_type(pos)
	if type != Board.CellType.COLOR_BLOCK and not (include_seeds and type == Board.CellType.SEED):
		return false
	var color: int = board.get_color(pos)
	var cells: Array[Vector2i] = [pos]
	coins.collect(cells)
	refill.plant(cells, color, elapsed)
	stats.blocks_cleared += 1
	cells_blasted.emit(cells, color)
	return true


## 족보 진행 결과를 점수에 반영한다 (능력 보정 → HUD 알림 → 점수). 능력이 매치 밖에서 족보를 진행할 때도 쓴다.
func apply_recipe_outcome(outcome: RecipeSet.ClearOutcome) -> void:
	if ability != null:
		ability.modify_outcome(self, outcome)
	recipes_updated.emit(recipes, outcome)
	stats.recipes_completed += outcome.completed_slots.size()
	if outcome.points != 0:
		score += outcome.points
		stats.add_score(outcome.points)
		stats.recipe_points += outcome.points
		score_changed.emit(score)


## 블록·족보 표시 방식 (능력이 없거나 보통이면 null).
func display_style() -> DisplayStyle:
	return ability.display_style() if ability != null else null


## 능력이 표시 방식을 바꿨을 때 부른다.
func notify_display_changed() -> void:
	display_style_changed.emit(display_style())


## 첫 이동 전이면 시계를 시작한다 (이동 외에 판을 건드리는 조작 — 꾹 누르기 능력 등 — 도 시계를 시작한다).
func start() -> void:
	if phase != Phase.WAITING:
		return
	phase = Phase.RUNNING
	started.emit()


func is_waiting() -> bool:
	return phase == Phase.WAITING


func is_running() -> bool:
	return phase == Phase.RUNNING


## 남은 게임 시간(초). 0 미만으로 내려가지 않는다.
func remaining_time() -> float:
	return _time.remaining


## 남은 시간을 seconds로 맞춘다 (튜토리얼 시간 설명: HTML timeLeft = 제한시간 × 0.6).
func set_remaining_time(seconds: float) -> void:
	_time.set_remaining(seconds)


## 0초에서 부활: 남은 시간을 seconds로 하고 다시 진행한다. TIMED_OUT이 아니면 false.
func revive(seconds: float) -> bool:
	if phase != Phase.TIMED_OUT:
		return false
	_time.set_remaining(seconds)
	phase = Phase.RUNNING
	stats.revives += 1
	return true


## 이 판에 적용 중인 설정 (잘못된 설정이 들어왔으면 대체된 기본값).
func get_config() -> GameConfig:
	return _config


## 능력 전용 seed RNG.
func get_rng() -> RandomNumberGenerator:
	return _ability_rng


## 능력이 남은 시간을 멈추고 있는지 (HUD 표시용).
func is_clock_stopped() -> bool:
	return _clock_rate(TimedSystem.Clock.TIMER) <= 0.0


## 판이 결과로 끝났다 (GameFlow가 RESULT에 들어갈 때 한 번). 능력이 남은 효과를 정산한다.
func finish() -> void:
	if _finished:
		return
	_finished = true
	if ability != null:
		ability.on_game_end(self)


## 매치 밖에서 얻는 시간 (능력용: 깃발 등). HUD에 "+N"으로 떠오른다.
func add_time(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_time.add(seconds)
	stats.max_remaining = maxf(stats.max_remaining, remaining_time())
	time_gained.emit(seconds)


## 능력이 메시지 줄에 문구를 띄운다.
func announce(text: String) -> void:
	ability_announced.emit(text)


## 능력의 판 위 표시 (능력이 없으면 비어 있음).
func board_marks() -> Array[BoardMark]:
	return ability.board_marks() if ability != null else ([] as Array[BoardMark])


## 능력이 판 위 표시를 바꿨을 때 부른다.
func notify_marks_changed() -> void:
	marks_changed.emit(board_marks())


## 족보 밖에서 얻는 점수 (능력용). label은 연출 문구.
func add_bonus_score(points: int, label: String) -> void:
	if points == 0:
		return
	score += points
	stats.add_score(points)
	stats.bonus_points += points
	bonus_scored.emit(points, label)
	score_changed.emit(score)


## 판에서 주운 코인.
func collected_coins() -> int:
	return coins.collected


## 실제 시간 delta만큼 진행한다 (RUNNING일 때만). 한 프레임 안에 여러 사건(씨앗 단계, 금화 수명, 0초 도달,
## 능력 타이머)이 있으면 **다음 사건 시각까지만 진행하고 그 사건을 처리하기를 반복**한다.
## 그래서 프레임을 어떻게 나누든 사건이 일어나는 순서와 결과가 같다 (프레임레이트 무관).
func advance(delta: float) -> void:
	var left: float = delta
	var guard: int = 0
	while left > 0.0 and phase == Phase.RUNNING and guard < MAX_EVENTS_PER_ADVANCE:
		var step: float = minf(left, _time_to_next_event())
		_step(step)
		left -= step
		guard += 1


## 매치 1회(color)를 족보·점수에 반영한다. 능력이 족보 처리를 대신하거나(와일드) 점수를 보정(올인)할 수 있다.
## 매치 판정 후 세션이 부르며, 디버그·테스트에서 매치 없이 족보만 진행할 때도 쓴다.
func apply_clear_to_recipes(color: int) -> void:
	var outcome: RecipeSet.ClearOutcome = ability.override_clear(self, color) if ability != null else null
	if outcome == null:
		outcome = recipes.apply_clear(color, _canonical())
	apply_recipe_outcome(outcome)


## 매치 1회(color)로 캐릭터 능력 발동 조건을 진행한다. 완성하면 능력이 발동하고 진행이 0으로 돌아간다.
## 매치 판정 후 세션이 부르며, 디버그·테스트에서 능력만 진행할 때도 쓴다.
func advance_ability_condition(color: int) -> void:
	if ability_recipe == null or ability.condition_frozen() or ability.canonical_color(ability_recipe.next_color()) != color:
		return
	ability_recipe.progress += 1
	if ability_recipe.is_complete():
		ability_recipe.progress = 0
		_trigger_ability()
	ability_updated.emit(ability_recipe)


## 판을 바깥에서 움직인 뒤(튜토리얼 블록 모으기 퍼즐) 지금 플레이어 자리의 매치를 본게임 규칙대로 처리한다
## (금화·시간·씨앗·족보·캐릭터 족보). 매치했으면 true. 이동 수로 세지 않는다.
func resolve_player_match() -> bool:
	start()
	return _resolve_match()


## 플레이어 위치의 매치를 판정하고 처리한다 (기획서 4.2장). 매치했으면 true.
func _resolve_match() -> bool:
	var center: Vector2i = board.player_pos
	var found: MatchRule.Found = _match_rule.find(board, center)
	if found == null:
		return false
	var color: int = found.color
	var cells: Array[Vector2i] = found.cells
	coins.collect(cells)
	match_count += 1
	stats.matches += 1
	stats.blocks_cleared += cells.size()
	stats.record_match_moves()
	var gained: float = _config.clear_time_for(match_count)
	if ability != null:
		gained = ability.modify_match_time(self, gained, found)
	_time.add(gained)
	refill.plant(cells, color, elapsed)
	stats.max_remaining = maxf(stats.max_remaining, remaining_time())
	matched.emit(center, color, cells)
	if gained > 0.0:
		time_gained.emit(gained)
	if ability != null:
		ability.on_match(self, color, cells)
	apply_clear_to_recipes(color)
	advance_ability_condition(color)
	return true


## 색 비교용 변환 (능력이 두 색을 같은 색으로 볼 때). 능력이 없으면 비어 있다.
func _canonical() -> Callable:
	return ability.canonical_color if ability != null else Callable()


## 다음 사건까지 남은 실제 시간(초).
func _time_to_next_event() -> float:
	var timer_rate: float = _clock_rate(TimedSystem.Clock.TIMER)
	var next: float = _time.time_to_zero() / timer_rate if timer_rate > 0.0 else INF
	for system: TimedSystem in _timed_systems:
		var rate: float = _clock_rate(system.clock())
		if rate > 0.0:
			next = minf(next, system.time_to_next_event() / rate)
	if ability != null:
		next = minf(next, ability.time_to_next_event())
	return maxf(next, 0.0)


## 사건이 없는 구간 dt만큼 모든 것을 진행하고, 끝 시각에 도달한 사건을 처리한다.
## 배속은 구간 시작 때 정한다 (구간 끝의 능력 사건이 배속을 바꾸더라도 이 구간에는 적용되지 않는다).
func _step(dt: float) -> void:
	var timer_rate: float = _clock_rate(TimedSystem.Clock.TIMER)
	var rates: Array[float] = []
	for system: TimedSystem in _timed_systems:
		rates.append(_clock_rate(system.clock()))
	stats.play_time += dt
	elapsed += dt
	_time.consume(dt * timer_rate)
	for i: int in _timed_systems.size():
		_timed_systems[i].advance(dt * rates[i])
	if ability != null:
		ability.advance(self, dt)
	if _time.is_out():
		phase = Phase.TIMED_OUT
		time_up.emit()


## 시계별 배속. 능력이 바꿀 수 있다 (시간 정지, 리필 가속 등).
func _clock_rate(clock: TimedSystem.Clock) -> float:
	if frozen_clocks.has(clock):
		return 0.0
	return ability.clock_rate(clock) if ability != null else 1.0


## 능력 효과의 한 순간을 알린다 (능력이 부른다, 이름은 능력의 MOMENT_* 상수).
func notify_moment(name: StringName) -> void:
	moment.emit(name)


## 캐릭터 족보를 마지막 한 칸만 남긴다 (캐릭터 튜토리얼의 발동 연습). 조건이 멈춰 있으면(수선사 끈) 그대로.
func prime_ability_condition() -> void:
	if ability_recipe == null or ability.condition_frozen():
		return
	ability_recipe.progress = ability_recipe.length() - 1
	ability_updated.emit(ability_recipe)


## 족보 없이 능력을 바로 발동한다 (캐릭터 튜토리얼 연습 판을 다시 할 때).
func trigger_ability() -> void:
	if ability != null:
		_trigger_ability()


func _trigger_ability() -> void:
	stats.ability_triggers += 1
	var message: String = ability.trigger(self)
	ability_triggered.emit(message)


func _on_cells_matured(cells: Array[Vector2i]) -> void:
	coins.on_cells_matured(cells)
	cells_refilled.emit(cells)


func _on_coins_changed(cells: Array[Vector2i]) -> void:
	coins_changed.emit(cells)


func _on_coins_collected(amount: int, chain: int) -> void:
	coins_collected.emit(amount, chain)
