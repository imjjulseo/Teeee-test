class_name LevelRewardsScreen
extends Control
## 레벨 보상 화면 (기획서 8.1장): 아래가 Lv1, 위로 갈수록 높은 레벨. 레벨마다 보상 목록, 다음 레벨 줄에 경험치 바.
## 처음 열면 지금 레벨 줄이 보이도록 스크롤한다. 보상 문구는 ProgressionConfig.rewards_for_level.

@export var progression: ProgressionConfig
## 레벨 한 줄 (데이터로 개수가 정해지는 반복 노드).
@export var row_scene: PackedScene
## 튜토리얼 흐름의 레벨 보상 안내 (첫 실전 판 뒤 한 번).
@export var spotlight: SpotlightOverlay
@export var guide_head: String = "레벨 보상"
@export var guide_text: String = "레벨마다 코인과 다이아 보상을 받을 수 있어요"
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var _rows: Array[LevelRewardRow] = []
var _guiding: bool = false

@onready var _rows_box: VBoxContainer = %Rows
@onready var _scroll: ScrollContainer = %Scroll
@onready var _summary_label: Label = %SummaryLabel


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	var progress: ProgressStore = ProgressStore.new(save_path)
	var needed: int = progression.exp_to_next(progress.level)
	_summary_label.text = "Lv %d · 다음 레벨까지 %d / %d" % [progress.level, progress.experience, needed]
	var ratio: float = float(progress.experience) / maxi(needed, 1)
	for level: int in range(progression.levels_to_show(progress.level), 0, -1):
		var row: LevelRewardRow = row_scene.instantiate() as LevelRewardRow
		_rows_box.add_child(row)
		row.show_level(level, progression.rewards_for_level(level), LevelRewardRow.state_for(level, progress.level), ratio)
		_rows.append(row)
	var tutorial: TutorialStore = TutorialStore.new(save_path)
	_guiding = TutorialFlow.new(tutorial, AchievementStore.new(save_path).stat("games")).level_step()
	if _guiding:
		tutorial.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	_scroll_to_current.call_deferred()


## 레벨 보상 안내가 떠 있는지 (테스트/디버그용).
func is_guiding() -> bool:
	return _guiding and spotlight != null and spotlight.is_open()


func _show_guide() -> void:
	if not _guiding or spotlight == null:
		return
	var next: LevelRewardRow = null
	for row: LevelRewardRow in _rows:
		if row.state == LevelRewardRow.State.NEXT:
			next = row
	var holes: Array[Rect2] = []
	if next != null:
		holes.append(next.get_global_rect())
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
