class_name AchievementsScreen
extends Control
## 업적 화면 (기획서 8.1 · 8.6 · 8.7장): 공통 업적 카드(지금 단계, 진행, 보상) + 히든 업적(조건 숨김).
## 열 때 공통 업적을 다시 본다 (뽑기·상점으로 모은 캐릭터 등 판 밖의 변화). 캐릭터 업적은 캐릭터 상세 시트에 있다.
## 처음 열면 업적 → 히든 업적 순서로 스포트라이트 안내 (8.8장 처음 볼 때 안내). 업적을 본 기록은 튜토리얼 흐름(모두 열림)에도 쓴다.

@export var achievements: AchievementBook
@export var row_scene: PackedScene
## 처음 볼 때 안내 문구 (비어 있으면 안내 없이 본 것으로만 적는다).
@export var tips: FirstViewTips
@export var spotlight: SpotlightOverlay
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var tracker: AchievementTracker
var _common_rows: Array[AchievementRow] = []
var _hidden_rows: Array[AchievementRow] = []
var _guides: GuideQueue

@onready var _common_box: VBoxContainer = %CommonList
@onready var _hidden_box: VBoxContainer = %HiddenList
@onready var _wallet_label: WalletView = %WalletLabel
@onready var _scroll: ScrollContainer = %Scroll
@onready var _hidden_title: Control = %HiddenTitle


func _ready() -> void:
	achievements = AchievementBook.ensure_valid(achievements)
	var progress: ProgressStore = ProgressStore.new(save_path)
	tracker = AchievementTracker.new(achievements, AchievementStore.new(save_path), progress)
	var best: int = BestScoreStore.new(save_path).best
	tracker.check_common(best)
	for item: CommonAchievement in achievements.common:
		var row: AchievementRow = row_scene.instantiate() as AchievementRow
		_common_box.add_child(row)
		row.show_status(tracker.common_status(item, best))
		_common_rows.append(row)
	for item: HiddenAchievement in achievements.hidden:
		var row: AchievementRow = row_scene.instantiate() as AchievementRow
		_hidden_box.add_child(row)
		row.show_hidden("히든 캐릭터")
		_hidden_rows.append(row)
	_wallet_label.show_amounts(progress.coins, progress.diamonds)
	_queue_guides(TutorialStore.new(save_path))


## 처음 열면: 공통 업적 보상 → 히든 업적 (HTML spotOnce _ach · _ach2). 안내가 없으면 본 것으로만.
func _queue_guides(tutorial: TutorialStore) -> void:
	if tips == null or spotlight == null:
		tutorial.mark_seen(TutorialStore.SEEN_ACHIEVEMENTS)
		return
	_guides = GuideQueue.new(spotlight, tutorial)
	var rows: Array[AchievementRow] = _common_rows
	_guides.add(TutorialStore.SEEN_ACHIEVEMENTS, tips.achievements_head, tips.achievements_text,
		func() -> Array[Rect2]: return AchievementsScreen._rects_of(rows.slice(0, 3)))
	var hidden: Array[AchievementRow] = _hidden_rows
	var scroll: ScrollContainer = _scroll
	_guides.add(TutorialStore.SEEN_HIDDEN_ACHIEVEMENTS, tips.hidden_head, tips.hidden_text,
		func() -> Array[Rect2]: return AchievementsScreen._rects_of(hidden), true,
		func() -> void: scroll.ensure_control_visible(hidden.back() if not hidden.is_empty() else _hidden_title))
	_guides.start(self)


## 처음 볼 때 안내가 떠 있는지 / 그 키 (테스트/디버그용).
func guide_key() -> String:
	return _guides.current_key() if _guides != null else ""


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()


static func _rects_of(rows: Array[AchievementRow]) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for row: AchievementRow in rows:
		rects.append(row.get_global_rect())
	return rects

func common_rows() -> Array[AchievementRow]:
	return _common_rows


func hidden_rows() -> Array[AchievementRow]:
	return _hidden_rows
