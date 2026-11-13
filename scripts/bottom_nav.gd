class_name BottomNav
extends Control
<<<<<<< HEAD
## 메뉴 화면 공통 아래 줄 (기획서 8.1장, E38): 상점 · 업적 · [캐릭터 블록] · 퍼즐 · 설정.
## 지금 화면의 버튼은 튀어나와 있고, 다시 누르면 메인으로 간다. 버튼은 튜토리얼 흐름(TutorialFlow)에 따라 잠기고, 지금 누를 버튼이 빛난다.
## 가운데 블록을 누르면 캐릭터 화면, 메인에서는 위로 밀면 start_swiped (메인이 게임을 시작한다).
=======
## 메뉴 화면 공통 아래 줄 (기획서 8.1장, E38): 상점 · 업적 · [캐릭터 블럭] · 퍼즐 · 설정.
## 지금 화면의 버튼은 튀어나와 있고, 다시 누르면 메인으로 간다. 버튼은 튜토리얼 흐름(TutorialFlow)에 따라 잠기고, 지금 누를 버튼이 빛난다.
## 가운데 블럭을 누르면 캐릭터 화면, 메인에서는 위로 밀면 start_swiped (메인이 게임을 시작한다).
>>>>>>> Choi
## 받을 수 있는 업적 보상이 있으면 업적 버튼에 빨간 점. 주인 화면이 _ready에서 setup을 부르고, 상태가 바뀌면 refresh를 부른다.

signal start_swiped

## 이 화면 (START = 메인).
@export var current: MenuUnlocks.Entry = MenuUnlocks.Entry.START
@export var roster: CharacterRoster
@export var achievements: AchievementBook
## 튀어나온 버튼의 배율과 튀어나오는 시간.
@export var active_scale: float = 1.2
@export var pop_time: float = 0.14
## 레벨 버튼을 빛낼 때 쓰는 위 줄 (없으면 빛내지 않는다).
@export var top_bar: TopBar

var _save_path: String = ""
var _popped: bool = false


func setup(save_path: String = "") -> void:
	_save_path = save_path
	refresh()


<<<<<<< HEAD
## 저장 파일의 지금 값으로 잠금 · 빨간 점 · 블록 · 빛남을 다시 보인다.
=======
## 저장 파일의 지금 값으로 잠금 · 빨간 점 · 블럭 · 빛남을 다시 보인다.
>>>>>>> Choi
func refresh() -> void:
	var flow: TutorialFlow = TutorialFlow.current(_save_path)
	var unlocks: MenuUnlocks = flow.unlocks()
	for entry: MenuUnlocks.Entry in _buttons():
		var button: Button = _buttons()[entry]
		button.disabled = not unlocks.is_open(entry)
		button.theme_type_variation = &"NavButtonActive" if entry == current else &"NavButton"
	_show_block(unlocks)
	(%AchievementsDot as Control).visible = unlocks.is_open(MenuUnlocks.Entry.ACHIEVEMENTS) and _has_claimable_achievement()
	_glow(flow.highlighted_entry())
	_pop_current()


<<<<<<< HEAD
## 가운데 블록 (올라오는 연출·메인의 시작 연출이 위치를 본다).
=======
## 가운데 블럭 (올라오는 연출·메인의 시작 연출이 위치를 본다).
>>>>>>> Choi
func block() -> CharacterBlockView:
	return %Block as CharacterBlockView


## 받을 업적 보상 표시가 보이는지 (테스트/디버그용).
func shows_achievement_dot() -> bool:
	return (%AchievementsDot as Control).visible


func _buttons() -> Dictionary[MenuUnlocks.Entry, Button]:
	return {
		MenuUnlocks.Entry.SHOP: %ShopButton as Button,
		MenuUnlocks.Entry.ACHIEVEMENTS: %AchievementsButton as Button,
		MenuUnlocks.Entry.PUZZLES: %PuzzlesButton as Button,
		MenuUnlocks.Entry.OPTIONS: %OptionsButton as Button,
	}


func _show_block(unlocks: MenuUnlocks) -> void:
	var gesture: BlockGesture = %BlockGesture as BlockGesture
	gesture.tap_enabled = unlocks.is_open(MenuUnlocks.Entry.CHARACTERS)
	gesture.swipe_enabled = current == MenuUnlocks.Entry.START and unlocks.is_open(MenuUnlocks.Entry.START)
	if roster != null:
		var collection: CharacterCollection = CharacterCollection.new(roster, ProgressStore.new(_save_path), CharacterStore.new(_save_path))
		block().show_character(collection.equipped_character())


func _has_claimable_achievement() -> bool:
	if achievements == null:
		return false
	var tracker: AchievementTracker = AchievementTracker.new(achievements, AchievementStore.new(_save_path), ProgressStore.new(_save_path))
	tracker.check_common(BestScoreStore.new(_save_path).best)  # 뽑기·상점으로 모은 캐릭터 등 판 밖의 변화
	return tracker.has_claimable()


## 지금 누를 버튼 (이 화면 버튼은 빼고, 시작은 메인에서만). 레벨은 위 줄.
func _glow(entry: int) -> void:
	var glow: GlowRing = %Glow as GlowRing
	if entry == current:
		glow.follow(block() if current == MenuUnlocks.Entry.START else null)
	elif entry == MenuUnlocks.Entry.LEVEL:
		glow.follow(top_bar.level_button() if top_bar != null else null)
	elif entry == MenuUnlocks.Entry.CHARACTERS:
		glow.follow(block())
	elif _buttons().has(entry as MenuUnlocks.Entry):
		glow.follow(_buttons()[entry as MenuUnlocks.Entry])
	else:
		glow.follow(null)


## 지금 화면 버튼이 튀어나온다 (처음 한 번, 효과 줄이기면 바로).
func _pop_current() -> void:
	var button: Button = _buttons().get(current, null)
	if button == null or _popped:
		return
	_popped = true
<<<<<<< HEAD
	button.z_index = 1  # 커진 버튼이 옆 버튼 위에 그려지게
=======
>>>>>>> Choi
	button.pivot_offset = Vector2(button.size.x / 2.0, button.size.y)
	var target: Vector2 = Vector2.ONE * active_scale
	if not is_inside_tree() or OptionsStore.new(_save_path).reduce_motion:
		button.scale = target
		return
	await get_tree().process_frame  # 크기가 정해진 뒤
	if not is_instance_valid(button):
		return
	button.pivot_offset = Vector2(button.size.x / 2.0, button.size.y)
	create_tween().tween_property(button, "scale", target, pop_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 버튼: 이 화면이면 메인으로, 아니면 그 화면으로.
func _open(entry: MenuUnlocks.Entry, navigator: SceneNavigator) -> void:
	if entry == current:
		(%MenuNavigator as SceneNavigator).go()
	else:
		navigator.go()


func _on_shop_button_pressed() -> void:
	_open(MenuUnlocks.Entry.SHOP, %ShopNavigator as SceneNavigator)


func _on_achievements_button_pressed() -> void:
	_open(MenuUnlocks.Entry.ACHIEVEMENTS, %AchievementsNavigator as SceneNavigator)


func _on_puzzles_button_pressed() -> void:
	_open(MenuUnlocks.Entry.PUZZLES, %PuzzlesNavigator as SceneNavigator)


func _on_options_button_pressed() -> void:
	_open(MenuUnlocks.Entry.OPTIONS, %OptionsNavigator as SceneNavigator)


func _on_block_tapped() -> void:
	_open(MenuUnlocks.Entry.CHARACTERS, %CharacterNavigator as SceneNavigator)


func _on_block_swiped_up() -> void:
	start_swiped.emit()
