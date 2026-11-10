class_name LevelRewardsScreen
extends Control
## 레벨 화면 (기획서 8.1장, E38): 아래가 Lv1인 세로 탑. 왼쪽 위 뒤로가기(레벨 버튼을 누른 화면으로), 아래 레벨 · 다음 레벨까지 · 경험치 막대.
## 선택권이 있는 레벨은 큰 칸, 레벨 사이 기둥이 경험치만큼 찬다. 처음 열면 지금 레벨이 보이도록 스크롤한다. 보상 문구는 ProgressionConfig.rewards_for_level.
## 오른 레벨의 보상 칸을 눌러서 받는다 (E36, ProgressStore.claim_level_reward).

## 뒤로가기가 돌아갈 화면 (위 줄이 적는다, 비면 메인).
static var return_scene: String = ""

@export var progression: ProgressionConfig
## 레벨 한 줄 (데이터로 개수가 정해지는 반복 노드).
@export var row_scene: PackedScene
## 튜토리얼 흐름의 레벨 보상 안내 (첫 실전 판 뒤 한 번).
@export var spotlight: SpotlightOverlay
@export var guide_head: String = "레벨 보상"
@export var guide_text: String = "레벨이 오르면 여기서 보상을 눌러 받아요"
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var _rows: Array[LevelRewardRow] = []
var _guiding: bool = false
var _progress: ProgressStore

@onready var _rows_box: VBoxContainer = %Rows
@onready var _scroll: ScrollContainer = %Scroll
@onready var _summary_label: Label = %SummaryLabel
@onready var _next_label: Label = %NextLabel
@onready var _exp_fill: Control = %ExpFill


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	_progress = ProgressStore.new(save_path)
	var needed: int = progression.exp_to_next(_progress.level)
	_summary_label.text = "레벨 %d" % _progress.level
	_next_label.text = "다음 레벨까지 %d" % maxi(needed - _progress.experience, 0)
	var ratio: float = float(_progress.experience) / maxi(needed, 1)
	_exp_fill.anchor_right = clampf(ratio, 0.0, 1.0)
	if not LevelRewardsScreen.return_scene.is_empty():
		(%BackNavigator as SceneNavigator).target_scene = LevelRewardsScreen.return_scene
	for level: int in range(progression.levels_to_show(_progress.level), 0, -1):
		var row: LevelRewardRow = row_scene.instantiate() as LevelRewardRow
		_rows_box.add_child(row)
		row.show_level(level, progression.rewards_for_level(level), LevelRewardRow.state_for(level, _progress.level),
			LevelRewardsScreen.stem_ratio(level, _progress.level, ratio), _progress.is_reward_claimable(level), progression.ticket_levels.has(level))
		row.claim_requested.connect(_on_claim_requested)
		_rows.append(row)
	var tutorial: TutorialStore = TutorialStore.new(save_path)
	_guiding = TutorialFlow.new(tutorial, AchievementStore.new(save_path).stat("games")).level_step()
	if _guiding:
		tutorial.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	_scroll_to_current.call_deferred()


## 레벨 보상 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guiding and spotlight != null and spotlight.is_open()


## 줄의 "받기".
func _on_claim_requested(level: int) -> void:
	if not _progress.claim_level_reward(progression.level_up_for(level)):
		return
	for row: LevelRewardRow in _rows:
		if row.level == level:
			row.show_claim(false)


## level 아래로 이어지는 기둥이 찬 비율: 지금 레벨 이하 = 가득, 다음 레벨 = 지금 경험치 비율, 그 위 = 0.
static func stem_ratio(level: int, current: int, exp_ratio: float) -> float:
	if level <= current:
		return 1.0
	return exp_ratio if level == current + 1 else 0.0


## 안내가 밝힐 줄: 받을 보상이 있으면 그 줄, 없으면 다음 레벨 줄.
func _guide_row() -> LevelRewardRow:
	var next: LevelRewardRow = null
	for row: LevelRewardRow in _rows:
		if row.is_claimable():
			return row
		if row.state == LevelRewardRow.State.NEXT:
			next = row
	return next


func _show_guide() -> void:
	if not _guiding or spotlight == null:
		return
	var target: LevelRewardRow = _guide_row()
	var holes: Array[Rect2] = []
	if target != null:
		holes.append(target.get_global_rect())
	spotlight.open(SpotlightOverlay.Mode.TAP, guide_head, guide_text, holes, "", false, true)


func _on_spotlight_tapped() -> void:
	_guiding = false
	spotlight.close()


## 지금 레벨 줄 (없으면 null).
func current_row() -> LevelRewardRow:
	for row: LevelRewardRow in _rows:
		if row.state == LevelRewardRow.State.CURRENT:
			return row
	return null


## 위에서부터 보이는 줄 (테스트/디버그용).
func rows() -> Array[LevelRewardRow]:
	return _rows


func _scroll_to_current() -> void:
	var row: LevelRewardRow = current_row()
	if row == null or not is_inside_tree():
		return
	await get_tree().process_frame  # 줄 크기가 정해진 뒤
	if is_instance_valid(row):
		_scroll.ensure_control_visible(row)
		await get_tree().process_frame
		_show_guide()
