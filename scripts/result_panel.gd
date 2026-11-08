class_name ResultPanel
extends CanvasLayer
## 결과 화면 (RESULT 상태, 기획서 5장): 최종 점수, 최고 기록 표시, 최고점, 이번 판 코인과 보유 재화,
## 경험치 바(Lv · 다음 보드 단계), 레벨업 보상 목록(레벨 보상, 선택권, 보드 업그레이드), 다시 하기, 메뉴.
## 이번 판에 달성한 업적은 목록 끝에 붙는다. 버튼은 retry_requested / main_menu_requested로만 알린다.
## 처음 결과를 보면 경험치 바를 스포트라이트로 한 번 설명한다 (8.8장 처음 볼 때 안내, 체험 판 제외).

signal retry_requested
signal main_menu_requested

## 보상 목록 한 줄 (데이터로 개수가 정해지는 반복 노드).
@export var reward_row_scene: PackedScene
@export var tips: FirstViewTips
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var _guides: GuideQueue

@onready var _score_label: Label = %FinalScoreLabel
@onready var _best_label: Label = %BestScoreLabel
@onready var _new_best_label: Label = %NewBestLabel
@onready var _coin_label: Label = %CoinLabel
@onready var _wallet_label: Label = %WalletLabel
@onready var _level_label: Label = %LevelLabel
@onready var _exp_fill: ColorRect = %ExpFill
@onready var _rewards_list: VBoxContainer = %RewardsList
@onready var _title_label: Label = %Title
@onready var _menu_button: Button = %MainMenuButton
@onready var _exp_bar: ColorRect = %ExpBar
@onready var _spotlight: SpotlightOverlay = %Spotlight


func _ready() -> void:
	visible = false


## 체험 판 결과: 보상·기록이 없으므로 최고점·코인·재화·경험치·보상 목록을 숨기고, 메뉴 버튼은 캐릭터 화면으로 (8.5장).
func _on_trial_result_ready(character_name: String) -> void:
	_title_label.text = "%s 체험 끝" % character_name
	_new_best_label.visible = false
	for node: CanvasItem in [_best_label, _coin_label, _wallet_label, _level_label, _exp_bar, _rewards_list]:
		node.visible = false
	_menu_button.text = "캐릭터"


## 튜토리얼 흐름: 첫 실전 판 뒤에는 다시 하기를 숨겨 메뉴로 이끈다.
func _on_result_guided(menu_only: bool) -> void:
	(%RetryButton as Button).visible = not menu_only


## 체험 판 결과로 보이고 있는지 (테스트/디버그용).
func is_trial_result() -> bool:
	return not _coin_label.visible


func _on_result_ready(score: int, best: int, is_new_best: bool, _picked_coins: int) -> void:
	_score_label.text = str(score)
	_best_label.text = "최고점 %d" % best
	_new_best_label.visible = is_new_best


## 판 끝 정산: 이번 판 코인, 보유 재화, 경험치 바, 보상 목록.
func _on_rewards_ready(rewards: RunRewards.Result, coins_total: int, diamonds_total: int) -> void:
	_coin_label.text = "● +%d" % rewards.coins
	_wallet_label.text = "보유 ● %d · ◆ %d" % [coins_total, diamonds_total]
	var next: String = " · 다음 %s" % rewards.next_stage_description if not rewards.next_stage_description.is_empty() else ""
	_level_label.text = "Lv %d%s" % [rewards.level_after, next]
	_exp_fill.anchor_right = clampf(float(rewards.exp_after) / maxi(rewards.exp_needed, 1), 0.0, 1.0)
	_show_rewards(ResultPanel.reward_lines(rewards))
	_guide_experience()


## 처음 결과: 경험치 바 안내 (HTML lvTip).
func _guide_experience() -> void:
	if tips == null:
		return
	_guides = GuideQueue.new(_spotlight, TutorialStore.new(save_path))
	var bar: Control = _exp_bar
	if _guides.add(TutorialStore.SEEN_EXPERIENCE, tips.experience_head, tips.experience_text,
			func() -> Array[Rect2]: return [bar.get_global_rect()] as Array[Rect2]):
		_guides.start(self)


## 처음 볼 때 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guides != null and _guides.is_open()


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()


## 보상 목록 줄 [이름, 내용]: 레벨마다 레벨 보상(+ 선택권), 보드가 바뀌었으면 보드 업그레이드.
static func reward_lines(rewards: RunRewards.Result) -> Array[PackedStringArray]:
	var lines: Array[PackedStringArray] = []
	for up: RunRewards.LevelUp in rewards.level_ups:
		lines.append(PackedStringArray(["레벨 %d" % up.level, "● %d  ◆ %d" % [up.coins, up.diamonds]]))
		if up.ticket_grade >= 0:
			lines.append(PackedStringArray(["선택권", "%s 1장" % CharacterData.GRADE_NAMES[up.ticket_grade]]))
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
