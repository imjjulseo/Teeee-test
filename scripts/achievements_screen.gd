class_name AchievementsScreen
extends Control
## 업적 화면 (기획서 8.1 · 8.6 · 8.7장). 탭 두 개 (E36):
## - 일반: 공통 업적 카드(지금 단계, 진행, 보상 미리보기, 받기) + 히든 업적(조건 숨김).
## - 캐릭터: 등급 칩을 누르면 그 등급 구역으로 스크롤. 구역 안에 업적이 있는 캐릭터의 3단계 (미보유 포함), 일반 · 히든 구역은 "준비 중" (E38). 처음 누를 때 만든다.
## 달성한 업적의 보상은 [받기]로 받는다 (AchievementTracker.claim, E38).
## 열 때 공통 업적을 다시 본다 (뽑기·상점으로 모은 캐릭터 등 판 밖의 변화).
## 처음 열면 업적 → 히든 업적 순서로 스포트라이트 안내 (8.8장 처음 볼 때 안내). 업적을 본 기록은 튜토리얼 흐름(모두 열림)에도 쓴다.

enum Tab { COMMON, CHARACTER }

@export var achievements: AchievementBook
@export var row_scene: PackedScene
## 캐릭터 탭의 캐릭터 하나 (데이터로 개수가 정해지는 반복 노드).
@export var group_scene: PackedScene
@export var roster: CharacterRoster
## 캐릭터 탭의 등급 색.
@export var theme_data: BoardTheme
## 처음 볼 때 안내 문구 (비어 있으면 안내 없이 본 것으로만 적는다).
@export var tips: FirstViewTips
@export var spotlight: SpotlightOverlay
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var tracker: AchievementTracker
var tab: Tab = Tab.COMMON
var _common_rows: Array[AchievementRow] = []
var _hidden_rows: Array[AchievementRow] = []
var _groups: Array[CharacterChainGroup] = []
var _groups_built: bool = false
var _guides: GuideQueue
var _progress: ProgressStore

@onready var _common_box: VBoxContainer = %CommonList
@onready var _hidden_box: VBoxContainer = %HiddenList
@onready var _top_bar: TopBar = %TopBar
@onready var _nav: BottomNav = %BottomNav
@onready var _scroll: ScrollContainer = %Scroll
@onready var _hidden_title: Control = %HiddenTitle
@onready var _common_tab: Button = %CommonTab
@onready var _character_tab: Button = %CharacterTab
@onready var _character_scroll: ScrollContainer = %CharacterScroll
@onready var _character_list: VBoxContainer = %CharacterList
@onready var _character_page: Control = %CharacterPage
@onready var _chips: HBoxContainer = %Chips


func _ready() -> void:
	achievements = AchievementBook.ensure_valid(achievements)
	_progress = ProgressStore.new(save_path)
	tracker = AchievementTracker.new(achievements, AchievementStore.new(save_path), _progress)
	var best: int = BestScoreStore.new(save_path).best
	tracker.check_common(best)
	for item: CommonAchievement in achievements.common:
		var row: AchievementRow = row_scene.instantiate() as AchievementRow
		_common_box.add_child(row)
		row.show_status(tracker.common_status(item, best))
		row.claim_requested.connect(_on_claim_requested)
		_common_rows.append(row)
	for item: HiddenAchievement in achievements.hidden:
		var row: AchievementRow = row_scene.instantiate() as AchievementRow
		_hidden_box.add_child(row)
		if tracker.is_hidden_done(item):
			row.show_hidden_done(item, achievements.hidden_reward)
		else:
			row.show_hidden(achievements.hidden_reward)
		_hidden_rows.append(row)
	_top_bar.setup(save_path)
	_nav.setup(save_path)
	set_tab(Tab.COMMON)
	_queue_guides(TutorialStore.new(save_path))


func set_tab(p_tab: Tab) -> void:
	tab = p_tab
	if tab == Tab.CHARACTER:
		_build_groups()
	_scroll.visible = tab == Tab.COMMON
	_character_page.visible = tab == Tab.CHARACTER
	_common_tab.set_pressed_no_signal(tab == Tab.COMMON)
	_character_tab.set_pressed_no_signal(tab == Tab.CHARACTER)


## 캐릭터 탭에 보이는 캐릭터: 업적이 있고 히든 등급이 아닌 캐릭터 (미보유 포함, 받은 순서 유지).
static func chain_characters(sorted: Array[CharacterData], book: AchievementBook) -> Array[CharacterData]:
	var list: Array[CharacterData] = []
	for character: CharacterData in sorted:
		if character.grade != CharacterData.Grade.HIDDEN and book.chain_for(character.id) != null:
			list.append(character)
	return list


func _build_groups() -> void:
	if _groups_built or roster == null or group_scene == null:
		return
	_groups_built = true
	var sorted: Array[CharacterData] = CharacterCollection.new(roster, _progress, CharacterStore.new(save_path)).sorted()
	for character: CharacterData in AchievementsScreen.chain_characters(sorted, achievements):
		var group: CharacterChainGroup = group_scene.instantiate() as CharacterChainGroup
		_section_of(character.grade).add_group(group)
		group.show_chain(character, theme_data.grade_color(character.grade), _progress.is_unlocked(character.id), tracker.chain_status(character.id))
		group.claim_requested.connect(_on_claim_requested)
		_groups.append(group)
	for node: Node in _character_list.get_children():
		var section: AchievementGradeSection = node as AchievementGradeSection
		section.show_title(theme_data.grade_color(section.grade))
		section.show_preparing_if_empty()
	_select_chip(CharacterData.Grade.BASIC)


## 등급 칩: 그 등급 구역으로 스크롤한다 (achievements.tscn에서 연결).
func jump_to_grade(grade: int) -> void:
	_select_chip(grade)
	_character_scroll.scroll_vertical = int(_section_of(grade).position.y)


## 그 등급 구역.
func section_for(grade: int) -> AchievementGradeSection:
	return _section_of(grade)


func _section_of(grade: int) -> AchievementGradeSection:
	for node: Node in _character_list.get_children():
		if (node as AchievementGradeSection).grade == grade:
			return node as AchievementGradeSection
	return null


func _select_chip(grade: int) -> void:
	for node: Node in _chips.get_children():
		var chip: FilterChip = node as FilterChip
		chip.show_label("일반" if chip.grade == CharacterData.Grade.BASIC else CharacterData.GRADE_NAMES[chip.grade])
		chip.set_selected(chip.grade == grade)


## 줄의 [받기].
func _on_claim_requested(status: AchievementTracker.TierStatus) -> void:
	if not tracker.claim(status):
		return
	_refresh_rows()
	_top_bar.refresh()
	_nav.refresh()


func _refresh_rows() -> void:
	var best: int = BestScoreStore.new(save_path).best
	for i: int in _common_rows.size():
		_common_rows[i].show_status(tracker.common_status(achievements.common[i], best))
	for group: CharacterChainGroup in _groups:
		group.refresh(tracker.chain_status(group.character.id))


func _on_common_tab_pressed() -> void:
	set_tab(Tab.COMMON)


func _on_character_tab_pressed() -> void:
	set_tab(Tab.CHARACTER)


## 캐릭터 탭의 캐릭터들 (테스트/디버그용).
func character_groups() -> Array[CharacterChainGroup]:
	return _groups


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
