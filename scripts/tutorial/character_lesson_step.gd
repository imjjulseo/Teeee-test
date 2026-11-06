class_name CharacterLessonStep
extends TutorialStep
## 캐릭터 튜토리얼의 활용 연습 한 단계 (기획서 8.8장, HTML CTL): 판을 준비하고 조작 설명(ACT)을 띄운 뒤,
## 목표 사건(goal)이 값 at_least 이상으로 count번 일어나면 다음 단계.
## 사건 = 능력 지표 이름(RunMetrics.changed, 값 = 더한 값/잰 값) · 능력의 순간(GameSession.notify_moment) · RECIPE(족보 완성, 값 = 장 수).
## prime이면 캐릭터 족보를 마지막 한 칸만 남겨 두고, 능력이 발동하면 잠시 뒤 다시 채운다.
## 연습 판(practice_rows): 판 가운데(또는 맨 위) 5×5 창에 A = 같은 색, P = 나, . = 다른 색. practice_marks의 C = 설 칸, S = 모을 자리.

enum Hint {
	NONE,  ## 힌트 없음
	ANY,  ## 아무 매치
	CHARACTER_NEXT,  ## 캐릭터 족보 다음 색
	RECIPE_NEED,  ## 일반 족보의 다음 색
	LETTER_A,  ## 준비한 글자 A 색 (쌍둥이)
	COLOR,  ## hint_color
	ABILITY,  ## 능력이 고른다 (Ability.prefers_hint)
}

## 족보 완성 사건 이름.
const RECIPE: StringName = &"recipe"

@export_multiline var text: String = ""
@export var goal: StringName = RECIPE
@export var at_least: int = 1
@export var count: int = 1
## count가 2 이상일 때 진행 문구 ({done} / {count}).
@export var progress_text: String = ""
@export var hint: Hint = Hint.NONE
@export var hint_color: int = Board.NO_COLOR

@export_group("Setup")
## 실제 판처럼 새로 섞는다.
@export var fresh: bool = false
@export var prime: bool = false
## 족보를 모두 한 칸 남게 채운다.
@export var cards_near: bool = false
## 첫 족보를 [A, A, B]로 (같은 색이 이어진 족보).
@export var twin_cards: bool = false
@export var practice_rows: PackedStringArray = PackedStringArray()
@export var practice_marks: PackedStringArray = PackedStringArray()
## 연습 판 첫 수 화살표 (없으면 0).
@export var practice_arrow: Vector2i = Vector2i.ZERO
## 연습 판을 판 맨 위 줄에 붙여 깐다 (벽 타는 자).
@export var practice_at_top: bool = false
## 발동하면 내 칸에서 시작하는 이 크기 정사각형 테두리 길을 보여 준다 (수선사, 0 = 없음).
@export var ring_size: int = 0
## 시작할 때 능력 효과가 이미 끝났으면 건너뛴다 (피버·마탄·제우스).
@export var skip_when_inactive: bool = false

@export_group("Retry")
## 목표 사건 값이 at_least보다 작으면 retry_text를 보여 준다 ({value} = 그 값).
@export var retry_below: bool = false
## 이 순간에 목표를 못 채웠으면 다시: retry_text, 연습 판을 다시 깔고, retrigger면 능력을 다시 켠다.
@export var retry_moment: StringName = &""
@export var retrigger: bool = false
@export_multiline var retry_text: String = ""

## 능력이 발동한 뒤 캐릭터 족보를 다시 채우기까지(초), 다 채운 뒤 다음 단계까지(초).
const REPRIME_DELAY: float = 0.7
const RETRY_DELAY: float = 0.6
const DONE_PAUSE: float = 0.5

var _done: int = 0
var _wait: float = -1.0
var _reprime_in: float = -1.0
var _retry_in: float = -1.0


func start(director: TutorialDirector) -> void:
	_done = 0
	_wait = -1.0
	_reprime_in = -1.0
	_retry_in = -1.0
	_prepare(director)
	if skip_when_inactive and director.session.ability.effect_remaining() <= 0.0:
		director.finish_step()
		return
	director.act(director.lesson_head(), text, PackedStringArray())
	director.begin_free(hint != Hint.NONE, _hint_filter(director))


func on_event(director: TutorialDirector, event: StringName, amount: int) -> void:
	if _wait >= 0.0:
		return
	if event == TutorialMoment.ABILITY:
		director.show_ring(ring_size)
		if prime:
			_reprime_in = REPRIME_DELAY
	if event == goal:
		if amount >= at_least:
			_count_goal(director)
			return
		if retry_below and not retry_text.is_empty():
			director.cheer(retry_text.replace("{value}", str(amount)))
	if event == retry_moment and retry_moment != &"":
		director.show_ring(0)
		if not retry_text.is_empty():
			director.cheer(retry_text)
		_retry_in = RETRY_DELAY


func tick(director: TutorialDirector, delta: float) -> void:
	if _wait >= 0.0:
		_wait -= delta
		if _wait <= 0.0:
			director.finish_step()
		return
	if _reprime_in >= 0.0:
		_reprime_in -= delta
		if _reprime_in < 0.0:
			director.session.prime_ability_condition()
	if _retry_in >= 0.0:
		_retry_in -= delta
		if _retry_in < 0.0:
			_retry(director)


func validate(_book: PuzzleBook) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if goal == &"":
		errors.append("lesson without goal")
	if not practice_rows.is_empty() and practice_rows.size() != 5:
		errors.append("practice board must have 5 rows")
	if hint == Hint.COLOR and hint_color < 0:
		errors.append("hint COLOR without hint_color")
	return errors


func _prepare(director: TutorialDirector) -> void:
	if not practice_rows.is_empty():
		director.lay_practice(practice_rows, practice_marks, practice_arrow, practice_at_top)
	elif fresh:
		director.random_board()
	if twin_cards:
		director.set_twin_cards()
	elif cards_near:
		director.fill_cards_near()
	if prime:
		director.session.prime_ability_condition()


func _count_goal(director: TutorialDirector) -> void:
	_done += 1
	if _done < count:
		if not progress_text.is_empty():
			director.set_caption(progress_text.replace("{done}", str(_done)).replace("{count}", str(count)))
		return
	director.cheer(director.lessons.cheer)
	director.end_free()
	director.show_ring(0)
	director.clear_guide_marks()
	_wait = DONE_PAUSE


func _retry(director: TutorialDirector) -> void:
	if not practice_rows.is_empty():
		director.lay_practice(practice_rows, practice_marks, practice_arrow, practice_at_top)
	if retrigger:
		director.session.trigger_ability()
	if prime:
		director.session.prime_ability_condition()


## 힌트가 고를 매치 (MatchPlanner.Plan) 조건.
func _hint_filter(director: TutorialDirector) -> Callable:
	var session: GameSession = director.session
	match hint:
		Hint.CHARACTER_NEXT:
			return func(plan: MatchPlanner.Plan) -> bool: return Ability.needs_for_condition(session, plan.color)
		Hint.RECIPE_NEED:
			return func(plan: MatchPlanner.Plan) -> bool: return director.recipe_nexts().has(plan.color)
		Hint.LETTER_A:
			return func(plan: MatchPlanner.Plan) -> bool: return plan.color == director.letter("A")
		Hint.COLOR:
			var color: int = hint_color
			return func(plan: MatchPlanner.Plan) -> bool: return plan.color == color
		Hint.ABILITY:
			var goal_value: int = at_least
			return func(plan: MatchPlanner.Plan) -> bool: return session.ability.prefers_hint(session, plan.color, plan.center, goal_value)
	return Callable()
