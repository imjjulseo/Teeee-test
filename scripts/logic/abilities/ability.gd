class_name Ability
extends Resource
## 캐릭터 능력의 기반 클래스 (기획서 5.2장). 능력 하나 = 하위 클래스 하나. 순수 로직.
## - 캐릭터 .tres에 하위 클래스 리소스로 들어가며, 능력별 수치는 하위 클래스의 @export로 둔다.
## - GameSession은 판마다 duplicate()한 인스턴스를 쓴다 → 실행 중 상태(남은 시간, 대기 횟수, 스택)는
##   export하지 않은 멤버에 두어 원본 리소스와 다른 판에 남지 않게 한다.
## - 세션은 아래 훅만 부른다. 새 능력은 필요한 훅만 오버라이드한 하위 클래스를 추가하면 된다.
##   능력이 세션에 거는 일은 세션의 공개 API로만 한다 (board, recipes, refill, add_bonus_score, cells_changed 등).
##
## 훅 (부르는 때)
##   recipe_lengths   판을 만들 때 족보 슬롯 길이를 바꾼다 (장인).
##   setup            판을 만든 직후 한 번 (판 끝 연결, 첫 현상금 색, 첫 구역).
##   match_rule       매치 판정 규칙 (벽 타는 자). null = 기본 규칙.
##   locks_input      true인 동안 이동 입력을 무시한다 (연쇄 폭파 중).
##   canonical_color  매치·족보·캐릭터 족보가 색을 비교하기 전에 바꾼다 (색약: 두 색을 같은 색으로).
##   intercept_move   이동 입력을 능력이 가로채면 true (사진 계획, 레이서 방향 전환, 마탄 사격, 파키 반복 입력 무시).
##                    능력이 실제로 움직일 때는 session.perform_move(판정 포함) / shift_player(판정 없음).
##   on_hold / on_release   방향 입력을 누르고 있기 시작 / 뗌 (파키 돌진). on_long_press: 화면을 꾹 누름 (방화광 소화).
##   refill_colors    씨앗에 심을 색을 바꾼다 (방화광: 빨강은 불이라 리필되지 않음).
##   pass_through_wall 벽에 막힌 이동을 능력이 대신 처리하면 true (거울: 판을 뒤집으며 통과). 이동으로 세고 매치를 판정한다.
##   condition_frozen true인 동안 캐릭터 족보가 진행되지 않는다 (피의 시간, 수선사 끈).
##   on_move          이동이 받아들여진 직후, 매치 판정 전 (깃발, 지나온 길).
##   after_move       이동의 매치 판정이 끝난 뒤 (matched = 이 이동으로 매치했는지) (떠돌이·묘수꾼 수 세기).
##   trigger          캐릭터 족보 완성 (발동형). 메시지 줄에 띄울 결과 문구를 돌려준다.
##   modify_match_time 매치로 얻는 시간을 보정한다 (벽 ×0.5, 현상금 +2).
##   on_match         매치 1회 직후, 족보 진행 전 (피버 스택, 구역 안 매치).
##   override_clear   매치의 족보 진행을 대신한다 (와일드, 쌍둥이, 탐험가).
##   modify_outcome   족보 진행 결과(점수)를 보정한다 (올인, 장인).
##   clock_rate       시계별 배속 (TIMER 0 = 시간 정지, REFILL ×2 = 리필 가속).
##   advance / time_to_next_event   실제 플레이 시간 진행과 다음 능력 사건 시각 (지속 효과 종료 등).
##   on_game_end      판이 결과로 끝날 때 한 번 (피버 정산).
## 표시
##   status_text      캐릭터 카드 둘째 줄 (남은 초·스택·남은 횟수). 비어 있으면 능력 이름.
##   effect_remaining 배경 효과가 켜진 남은 시간 (없으면 음수, 끝없이 켜져 있으면 INF).
##   effect_block_color / effect_blink_window   배경 효과를 칠할 블록 색 ID (NO_COLOR = 캐릭터 색) / 깜빡이기 시작하는 남은 초 (음수 = 테마 기본).
##   board_marks      판 위 표시 (깃발, 구역). 바뀌면 session.notify_marks_changed()를 부른다.
##   display_style    블록·족보를 칠하는 방식 (색 합치기, 흑백). 바뀌면 session.notify_display_changed()를 부른다.
## 캐릭터 튜토리얼 (8.8장)
##   prefers_hint     활용 연습의 힌트가 고를 매치 (정원사·시계공·화가·현상금·탐험가). 지표는 session.metrics, 효과의 한 순간은
##                    session.notify_moment(MOMENT_*)로 남기면 튜토리얼이 목표·처음 보는 순간으로 쓴다.


## 판을 만들 때 족보 슬롯 길이 (기본은 설정값 그대로).
func recipe_lengths(lengths: PackedInt32Array) -> PackedInt32Array:
	return lengths


## 판을 만든 직후 한 번 (첫 이동 전).
func setup(_session: GameSession) -> void:
	pass


## 매치 판정 규칙. null이면 기본 규칙(MatchRule).
func match_rule() -> MatchRule:
	return null


## true인 동안 이동 입력을 무시한다 (조작 잠금 연출).
func locks_input() -> bool:
	return false


## 이동 입력(dir)을 가로챘으면 true (세션은 보통 이동을 하지 않는다).
func intercept_move(_session: GameSession, _dir: Vector2i) -> bool:
	return false


## 방향 입력을 누르고 있기 시작했다 (그 입력의 이동은 바로 뒤에 따로 온다).
func on_hold(_session: GameSession, _dir: Vector2i) -> void:
	pass


## 누르고 있던 방향 입력을 뗐다.
func on_release(_session: GameSession) -> void:
	pass


## 화면을 움직이지 않고 꾹 눌렀다.
func on_long_press(_session: GameSession) -> void:
	pass


## 씨앗에 심을 색 (cleared = 깬 색). 기본은 그대로.
func refill_colors(colors: Array[int], _cleared: int, _rng: RandomNumberGenerator) -> Array[int]:
	return colors


## 벽에 막힌 이동을 대신 처리했으면 true (판을 바꾼 뒤 session.notify_board_rearranged()).
func pass_through_wall(_session: GameSession, _result: Board.MoveResult) -> bool:
	return false


## true인 동안 캐릭터 족보가 진행되지 않는다.
func condition_frozen() -> bool:
	return false


## 비교에 쓰는 색. 기본은 그대로.
func canonical_color(color: int) -> int:
	return color


## 이동이 받아들여진 직후, 매치 판정 전.
func on_move(_session: GameSession, _result: Board.MoveResult) -> void:
	pass


## 이동의 매치 판정이 끝난 뒤. matched = 이 이동으로 매치했는지.
func after_move(_session: GameSession, _matched: bool) -> void:
	pass


## 매치로 얻는 시간(초)을 보정한다. found는 이번 매치 (색, 깨지는 칸).
func modify_match_time(_session: GameSession, seconds: float, _found: MatchRule.Found) -> float:
	return seconds


## 발동형: 캐릭터 족보를 완성했을 때. 반환값은 메시지 줄 문구 (예: "정지: 4초").
func trigger(_session: GameSession) -> String:
	return ""


## 매치 1회 직후 (시간·씨앗 처리 뒤, 족보 진행 전).
func on_match(_session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	pass


## 매치 1회의 족보 처리를 대신한다. null을 반환하면 기본 규칙(색에 맞는 족보 진행)을 쓴다.
func override_clear(_session: GameSession, _color: int) -> RecipeSet.ClearOutcome:
	return null


## 족보 처리 결과(점수)를 보정한다.
func modify_outcome(_session: GameSession, _outcome: RecipeSet.ClearOutcome) -> void:
	pass


## 시계별 배속. 1 = 보통, 0 = 멈춤. 값이 바뀌는 순간은 time_to_next_event로 알려야 한다 (프레임 분할과 무관하게).
func clock_rate(_clock: TimedSystem.Clock) -> float:
	return 1.0


## RUNNING 중 실제 플레이 시간 delta만큼 진행한다 (일시정지·첫 이동 전 제외).
func advance(_session: GameSession, _delta: float) -> void:
	pass


## 다음 능력 사건(지속 효과 종료 등)까지 남은 실제 시간(초). 없으면 INF.
## 세션은 한 프레임을 이 시각에서 끊어 사건 순서대로 처리한다.
func time_to_next_event() -> float:
	return INF


## 판이 결과로 끝날 때 한 번 (부활 확인 뒤). 남은 효과를 정산한다.
func on_game_end(_session: GameSession) -> void:
	pass


## 캐릭터 카드 둘째 줄 상태. 비어 있으면 표시하지 않는다 (카드는 능력 이름을 보여 준다).
func status_text() -> String:
	return ""


## 배경 효과가 켜진 남은 시간(초). 꺼져 있으면 음수, 끝없이 켜져 있으면 INF.
func effect_remaining() -> float:
	return -1.0


## 배경 효과를 블록 색으로 칠할 때 그 색 ID (현상금). Board.NO_COLOR면 캐릭터 색.
func effect_block_color() -> int:
	return Board.NO_COLOR


## 배경 효과가 깜빡이기 시작하는 남은 시간(초). 음수면 테마 기본값 (5.2장: 3초).
func effect_blink_window() -> float:
	return -1.0


## 판 위 표시 (깃발·구역).
func board_marks() -> Array[BoardMark]:
	return []


## 블록·족보 표시 방식. null이면 보통.
func display_style() -> DisplayStyle:
	return null


## 캐릭터 튜토리얼 활용 연습에서 힌트가 이 매치(color, 매치할 자리 center)를 골라도 되는지. goal = 그 연습의 목표 값.
func prefers_hint(_session: GameSession, _color: int, _center: Vector2i, _goal: int) -> bool:
	return true


## 이 색이 지금 캐릭터 족보의 다음 칸인지 (능력의 색 비교 포함).
static func needs_for_condition(session: GameSession, color: int) -> bool:
	var recipe: RecipeSet.Recipe = session.ability_recipe
	return recipe != null and not recipe.is_complete() and session.ability.canonical_color(recipe.next_color()) == color


## 초를 HUD 표기로 (소수 1자리 반올림, 정수면 소수점 없음: 4 / 3.7). 음수는 0.
static func format_seconds(seconds: float) -> String:
	return format_number(maxf(seconds, 0.0))


## 수치를 문구 표기로 (소수 1자리 반올림, 정수면 소수점 없음: 배율 2 / 1.5).
static func format_number(value: float) -> String:
	return ("%.1f" % snappedf(value, 0.1)).trim_suffix(".0")
