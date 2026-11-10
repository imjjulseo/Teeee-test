class_name MainMenu
extends Control
## 메인 화면 (기획서 8.1장, E38). 위 줄(TopBar), 경험치 2배 칸(표시만), 로고, BEST 최고점, 시작 칸, 아래 줄(BottomNav).
## 아래 줄 가운데 캐릭터 블럭을 위로 밀면 블럭이 시작 칸으로 올라가 게임이 시작된다. 누르면 캐릭터 화면 (BottomNav).
## 메뉴 버튼은 튜토리얼 흐름(TutorialFlow)에 따라 열린다. 첫 뽑기 유도 단계에서는 밀어도 상점으로 간다 (shop_requested).
## 씬 전환은 main_menu.tscn에서 signal → SceneNavigator로 연결한다.

signal start_game_requested
signal shop_requested

@export var roster: CharacterRoster
## 판을 이만큼 하기 전까지 스와이프 안내를 보인다.
@export var hint_games: int = 3
## 블럭이 시작 칸으로 올라가는 시간, 안내가 깜빡이는 주기.
@export var start_fly_time: float = 0.2
@export var hint_period: float = 1.2
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var flow: TutorialFlow
var unlocks: MenuUnlocks = MenuUnlocks.new()
var _starting: bool = false
var _reduce_motion: bool = false

@onready var _top_bar: TopBar = %TopBar
@onready var _nav: BottomNav = %BottomNav
@onready var _best_label: Label = %BestLabel
@onready var _ghost: CharacterBlockView = %GhostBlock
@onready var _hint: Control = %SwipeHint


func _ready() -> void:
	flow = TutorialFlow.current(save_path)
	unlocks = flow.unlocks()
	_reduce_motion = OptionsStore.new(save_path).reduce_motion
	_top_bar.setup(save_path)
	_nav.setup(save_path)
	_best_label.text = str(BestScoreStore.new(save_path).best)
	_show_ghost()
	_show_hint()


## 지금 메뉴 버튼이 눌릴 수 있는지 (테스트/디버그용).
func is_entry_enabled(entry: MenuUnlocks.Entry) -> bool:
	return unlocks.is_open(entry)


## 빛나는 버튼 (없으면 -1).
func highlighted_entry() -> int:
	return flow.highlighted_entry()


## 스와이프 안내가 보이는지 (테스트/디버그용).
func shows_swipe_hint() -> bool:
	return _hint.visible


func _show_ghost() -> void:
	var collection: CharacterCollection = CharacterCollection.new(roster, ProgressStore.new(save_path), CharacterStore.new(save_path))
	_ghost.show_character(collection.equipped_character())


func _show_hint() -> void:
	var games: int = AchievementStore.new(save_path).stat("games")
	_hint.visible = games < hint_games and not flow.start_goes_to_shop()
	if _hint.visible and is_inside_tree() and not _reduce_motion:
		var tween: Tween = _hint.create_tween().set_loops()
		tween.tween_property(_hint, "modulate:a", 0.35, hint_period / 2.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_hint, "modulate:a", 1.0, hint_period / 2.0).set_trans(Tween.TRANS_SINE)


## 블럭을 위로 밀었다 (main_menu.tscn에서 BottomNav.start_swiped에 연결).
func _on_start_swiped() -> void:
	if _starting:
		return
	_starting = true
	if flow.start_goes_to_shop() or _reduce_motion or not is_inside_tree():
		_leave()
		return
	var block: Control = _nav.block()
	var tween: Tween = create_tween()
	tween.tween_property(block, "global_position", _ghost.global_position, start_fly_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_leave)


func _leave() -> void:
	if flow.start_goes_to_shop():
		shop_requested.emit()
	else:
		start_game_requested.emit()
