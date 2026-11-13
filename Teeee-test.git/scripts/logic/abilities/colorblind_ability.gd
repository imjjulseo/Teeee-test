class_name ColorblindAbility
extends Ability
## 색약 "뒤섞임": duration초(실제 플레이 시간) 동안 무작위 두 색을 같은 색으로 친다 — 두 번째 색(merged_color)이
## 첫 번째 색(base_color)으로 보이고(문양은 그대로) 매치·족보·캐릭터 족보 모두 같은 색으로 본다.
## 색은 능력 RNG로 고른다. 효과 중 재발동하면 남은 시간에 더한다 (같은 두 색 유지).

@export var duration: float = 10.0

## 업적 지표: 섞인 두 색으로 한 매치 수, 색약 한 번의 매치·완성 수 (가장 큰 값).
const METRIC_MIXED_MATCHES: StringName = &"colorblind_mixed_matches"
const METRIC_EFFECT_MATCHES: StringName = &"colorblind_matches"
const METRIC_EFFECT_RECIPES: StringName = &"colorblind_recipes"

var time_left: float = 0.0
var _window: EffectWindowMetrics = EffectWindowMetrics.new(METRIC_EFFECT_MATCHES, METRIC_EFFECT_RECIPES)
## 기준 색 (합쳐진 색이 이 색이 된다). 꺼져 있으면 NO_COLOR.
var base_color: int = Board.NO_COLOR
## 기준 색으로 보이는 색.
var merged_color: int = Board.NO_COLOR

var _color_count: int = 4


func setup(session: GameSession) -> void:
	_color_count = session.get_config().color_count


func trigger(session: GameSession) -> String:
	if not is_active() and _color_count > 1:
		var rng: RandomNumberGenerator = session.get_rng()
		base_color = rng.randi_range(0, _color_count - 1)
		merged_color = (base_color + 1 + rng.randi_range(0, _color_count - 2)) % _color_count
		_window.begin()
	time_left += duration
	session.notify_display_changed()
	return "색약: %s초 동안 두 색이 같은 색" % Ability.format_seconds(duration)


func canonical_color(color: int) -> int:
	return base_color if is_active() and color == merged_color else color


## 시간은 바꾸지 않고, 씨앗이 되기 전의 실제 색으로 "섞인 두 색 매치"인지만 본다.
func modify_match_time(session: GameSession, seconds: float, found: MatchRule.Found) -> float:
	if is_active() and _has_both_colors(session.board, found.cells):
		session.metrics.add(METRIC_MIXED_MATCHES)
	return seconds


func on_match(session: GameSession, _color: int, _cells: Array[Vector2i]) -> void:
	if is_active():
		_window.on_match(session.metrics)


func modify_outcome(session: GameSession, outcome: RecipeSet.ClearOutcome) -> void:
	if is_active():
		_window.on_outcome(session.metrics, outcome)


func _has_both_colors(board: Board, cells: Array[Vector2i]) -> bool:
	var has_base: bool = false
	var has_merged: bool = false
	for pos: Vector2i in cells:
		has_base = has_base or board.get_color(pos) == base_color
		has_merged = has_merged or board.get_color(pos) == merged_color
	return has_base and has_merged


func advance(session: GameSession, delta: float) -> void:
	if not is_active():
		return
	time_left -= delta
	if time_left <= TimedSystem.EPSILON:
		time_left = 0.0
		base_color = Board.NO_COLOR
		merged_color = Board.NO_COLOR
		session.notify_display_changed()


func time_to_next_event() -> float:
	return time_left if is_active() else INF


func is_active() -> bool:
	return time_left > 0.0 and merged_color != Board.NO_COLOR


func display_style() -> DisplayStyle:
	if not is_active():
		return null
	var style: DisplayStyle = DisplayStyle.new()
	style.color_alias[merged_color] = base_color
	return style


func status_text() -> String:
	return "%s초" % Ability.format_seconds(time_left) if is_active() else ""


func effect_remaining() -> float:
	return time_left if is_active() else -1.0
