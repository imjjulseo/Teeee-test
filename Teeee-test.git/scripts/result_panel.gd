class_name ResultPanel
extends CanvasLayer
## 결과 화면 (RESULT 상태, 기획서 5장, E38): 최종 점수(0부터 차오름), 최고 기록 표시, 전체 · 캐릭터 최고점, 경험치 바(Lv · 다음 보드 단계), 보유 코인, 다시 하기, 메뉴.
## 얻은 코인·경험치는 숫자로 따로 보이지 않고, 보유 코인과 레벨 바에 더해지는 연출로 보여 준다. 레벨이 오르면 "레벨 업" 표시만 (보상은 레벨 보상 화면, E36).
## 목록에는 보드 업그레이드와 이번 판에 달성한 업적이 나온다. 효과 줄이기면 연출 없이 바로 최종값. 버튼은 retry_requested / main_menu_requested로만 알린다.
## 처음 결과를 보면 경험치 바를 스포트라이트로 한 번 설명한다 (8.8장 처음 볼 때 안내, 체험 판 제외).

signal retry_requested
signal main_menu_requested

## 보상 목록 한 줄 (데이터로 개수가 정해지는 반복 노드).
@export var reward_row_scene: PackedScene
@export var tips: FirstViewTips
## 코인·경험치가 더해지는 연출 시간.
@export var theme_data: BoardTheme
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var _guides: GuideQueue
var _pending_character_best: String = ""
var _rewards: RunRewards.Result
var _coins_before: int = 0
var _coins_after: int = 0
var _score_tween: Tween
var _coin_tween: Tween
var _exp_tween: Tween
## 처음 결과의 경험치 안내를 닫은 뒤에 연출을 시작한다.
var _tally_waiting: bool = false

@onready var _score_label: Label = %FinalScoreLabel
@onready var _best_label: Label = %BestScoreLabel
@onready var _character_best_label: Label = %CharacterBestLabel
@onready var _new_best_label: Label = %NewBestLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _level_label: Label = %LevelLabel
@onready var _level_up_label: Label = %LevelUpLabel
@onready var _exp_fill: ColorRect = %ExpFill
@onready var _rewards_list: VBoxContainer = %RewardsList
@onready var _title_label: Label = %Title
@onready var _menu_button: Button = %MainMenuButton
@onready var _exp_bar: ColorRect = %ExpBar
@onready var _spotlight: SpotlightOverlay = %Spotlight


func _ready() -> void:
	visible = false


## 튜토리얼 흐름: 첫 실전 판 뒤에는 다시 하기를 숨겨 메뉴로 이끈다.
func _on_result_guided(menu_only: bool) -> void:
	(%RetryButton as Button).visible = not menu_only


func _on_result_ready(score: int, best: int, is_new_best: bool, _picked_coins: int) -> void:
	_best_label.text = "전체 최고점\n%d" % best
	_new_best_label.visible = is_new_best
	_character_best_label.visible = false
	_play_score(score)


## 이 판 캐릭터의 최고점 (result_ready 바로 앞에 온다).
func _on_character_best_ready(character_name: String, best: int) -> void:
	_pending_character_best = "%s 최고점\n%d" % [character_name, best]


## 점수가 0부터 차오른다 (효과 줄이기면 바로).
func _play_score(score: int) -> void:
	if _score_tween != null:
		_score_tween.kill()
	_character_best_label.text = _pending_character_best
	_character_best_label.visible = not _pending_character_best.is_empty()
	if not is_inside_tree() or theme_data == null or OptionsStore.new(save_path).reduce_motion:
		_score_label.text = str(score)
		return
	_score_label.text = "0"
	_score_tween = create_tween()
	_score_tween.tween_method(func(value: float) -> void: _score_label.text = str(roundi(value)),
		0.0, float(score), theme_data.result_score_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 판 끝 정산: 정산 전 값을 보이고 (안내가 있으면 닫은 뒤) 보유 코인·경험치 바가 차오른다.
func _on_rewards_ready(rewards: RunRewards.Result, coins_before: int, coins_after: int) -> void:
	_stop_tally()
	_rewards = rewards
	_coins_before = coins_before
	_coins_after = coins_after
	_show_coins(coins_before)
	_level_label.text = "Lv %d" % rewards.level_before
	_level_up_label.visible = false
	_set_exp_fill(rewards.bar_steps[0].from)
	_show_rewards(ResultPanel.reward_lines(rewards))
	_tally_waiting = _guide_experience()
	if not _tally_waiting:
		_play_tally()


func _show_coins(coins: int) -> void:
	_coin_label.text = "보유 코인 ● %d" % coins


func _set_exp_fill(ratio: float) -> void:
	_exp_fill.anchor_right = ratio


func _stop_tally() -> void:
	for tween: Tween in [_coin_tween, _exp_tween]:
		if tween != null:
			tween.kill()
	_coin_tween = null
	_exp_tween = null


func _play_tally() -> void:
	if not is_inside_tree() or theme_data == null or OptionsStore.new(save_path).reduce_motion:
		_finish_tally()
		return
	_coin_tween = create_tween()
	_coin_tween.tween_method(func(value: float) -> void: _show_coins(roundi(value)),
		float(_coins_before), float(_coins_after), theme_data.result_coin_time)
	_exp_tween = create_tween()
	for step: RunRewards.BarStep in _rewards.bar_steps:
		_exp_tween.tween_method(_set_exp_fill, step.from, step.to, theme_data.result_exp_time * (step.to - step.from))
		if step.to >= 1.0:
			_exp_tween.tween_callback(_on_bar_filled.bind(step.level + 1))
	_exp_tween.tween_callback(_finish_exp)


## 바가 가득 찼다: 레벨이 오른다.
func _on_bar_filled(level: int) -> void:
	_level_label.text = "Lv %d" % level
	_set_exp_fill(0.0)
	if not _level_up_label.visible:
		_level_up_label.visible = true
		_pop_row.call_deferred(_level_up_label, 0.0)


func _finish_exp() -> void:
	var next: String = " / 다음 %s" % _rewards.next_stage_description if not _rewards.next_stage_description.is_empty() else ""
	_level_label.text = "Lv %d%s" % [_rewards.level_after, next]
	_level_up_label.visible = not _rewards.level_ups.is_empty()
	_set_exp_fill(_rewards.bar_steps.back().to)


## 연출 없이 최종값.
func _finish_tally() -> void:
	_stop_tally()
	_show_coins(_coins_after)
	_finish_exp()


## 처음 결과: 경험치 바 안내 (HTML lvTip). 안내를 띄우면 true.
func _guide_experience() -> bool:
	if tips == null:
		return false
	_guides = GuideQueue.new(_spotlight, TutorialStore.new(save_path))
	var bar: Control = _exp_bar
	if not _guides.add(TutorialStore.SEEN_EXPERIENCE, tips.experience_head, tips.experience_text,
			func() -> Array[Rect2]: return [bar.get_global_rect()] as Array[Rect2]):
		return false
	if not is_inside_tree():
		return false
	_guides.start(self)
	return true


## 처음 볼 때 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guides != null and _guides.is_open()


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()
	if _tally_waiting and (_guides == null or not _guides.is_open()):
		_tally_waiting = false
		_play_tally()


## 목록 줄 [이름, 내용]: 보드가 바뀌었으면 보드 업그레이드. 레벨 보상은 레벨 보상 화면에서 받으므로 나오지 않는다 (E36).
static func reward_lines(rewards: RunRewards.Result) -> Array[PackedStringArray]:
	var lines: Array[PackedStringArray] = []
	if rewards.board_upgraded():
		lines.append(PackedStringArray(["보드 업그레이드", rewards.upgraded_description]))
	return lines


## 이번 판에 달성한 업적을 보상 목록 끝에 붙인다 (rewards_ready 다음에 온다).
func _on_achievements_ready(lines: Array[PackedStringArray]) -> void:
	_add_rows(lines)


## 지금 보이는 보상 목록 (테스트/디버그용).
func shown_rewards() -> Array[PackedStringArray]:
	var lines: Array[PackedStringArray] = []
	for row: Node in _rewards_list.get_children():
		if not row.is_queued_for_deletion():
			lines.append((row as RewardRow).texts())
	return lines


func _show_rewards(lines: Array[PackedStringArray]) -> void:
	for row: Node in _rewards_list.get_children():
		_rewards_list.remove_child(row)
		row.queue_free()
	_add_rows(lines)


func _add_rows(lines: Array[PackedStringArray]) -> void:
	if reward_row_scene == null:
		return
	var reduce: bool = OptionsStore.new().reduce_motion
	for i: int in lines.size():
		var line: PackedStringArray = lines[i]
		var row: RewardRow = reward_row_scene.instantiate() as RewardRow
		_rewards_list.add_child(row)
		row.show_reward(line[0], line[1])
		if not reduce and row.is_inside_tree():
			_pop_row.call_deferred(row, i * 0.08)


## 보상 줄이 작게서 튀어나온다 (HTML mslIn 0.5초 cubic-bezier(.2,.9,.3,1.5): 0.2배·투명 → 원래), 줄마다 조금씩 늦게.
func _pop_row(row: Control, delay: float) -> void:
	if not is_instance_valid(row):
		return
	row.pivot_offset = row.size / 2.0
	KeyframeAnim.play(row, row, 0.5, [
		[0.0, {"scale": Vector2.ONE * 0.2, "modulate:a": 0.0}],
		[1.0, {"scale": Vector2.ONE, "modulate:a": 1.0}],
	], Vector4(0.2, 0.9, 0.3, 1.5), delay)


func _on_state_changed(state: GameFlow.GameState) -> void:
	var was_visible: bool = visible
	visible = state == GameFlow.GameState.RESULT
	if visible and not was_visible:
		OverlayIn.play(get_node_or_null("Center") as Control)  # 카드가 커지며 나타남 (HTML ovgIn)


func _on_retry_button_pressed() -> void:
	retry_requested.emit()


func _on_main_menu_button_pressed() -> void:
	main_menu_requested.emit()
