class_name MainMenu
extends Control
## 메인 메뉴 (기획서 8.1장). 위: 레벨 버튼(Lv · 경험치 바 → 레벨 보상), 지갑(코인·다이아).
## 가운데: 게임 시작 + 보드 단계 안내, 현재 캐릭터 버튼. 아래: 상점 · 캐릭터 · 업적 · 설정.
## 버튼은 튜토리얼 흐름(TutorialFlow)에 따라 차례로 열리고, 지금 누를 버튼이 빛난다. 첫 뽑기 유도 단계에서는
## 게임 시작이 상점으로 간다 (shop_requested). 씬 전환은 main_menu.tscn에서 signal → SceneNavigator로 연결한다.

signal start_game_requested
signal shop_requested

@export var roster: CharacterRoster
@export var progression: ProgressionConfig
## 빛나는 버튼의 색과 한 번 깜빡이는 시간(초).
@export var glow_color: Color = Color(1.35, 1.2, 0.75)
@export var glow_period: float = 0.9
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var flow: TutorialFlow
var unlocks: MenuUnlocks = MenuUnlocks.new()

@onready var _level_label: Label = %LevelLabel
@onready var _exp_fill: ColorRect = %ExpFill
@onready var _wallet_label: WalletView = %WalletLabel
@onready var _stage_label: Label = %StageLabel
@onready var _character_button: Button = %CharacterButton
@onready var _buttons: Dictionary[MenuUnlocks.Entry, Button] = {
	MenuUnlocks.Entry.START: %StartButton,
	MenuUnlocks.Entry.LEVEL: %LevelButton,
	MenuUnlocks.Entry.SHOP: %ShopButton,
	MenuUnlocks.Entry.CHARACTERS: %CharactersButton,
	MenuUnlocks.Entry.ACHIEVEMENTS: %AchievementsButton,
	MenuUnlocks.Entry.OPTIONS: %OptionsButton,
}


func _ready() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	var progress: ProgressStore = ProgressStore.new(save_path)
	var collection: CharacterCollection = CharacterCollection.new(roster, progress, CharacterStore.new(save_path))
	flow = TutorialFlow.new(TutorialStore.new(save_path), AchievementStore.new(save_path).stat("games"))
	unlocks = flow.unlocks()
	_show_level(progress)
	_wallet_label.show_amounts(progress.coins, progress.diamonds)
	_stage_label.text = "첫 캐릭터 뽑기" if flow.start_goes_to_shop() \
		else MainMenu.stage_hint(progression, progress.level, BestScoreStore.new(save_path).best)
	_character_button.text = "캐릭터 · %s" % collection.equipped_character().display_name
	_apply_unlocks()
	_glow(flow.highlighted_entry())


## 게임 시작 버튼 아래 안내: 다음 보드 단계가 있으면 "Lv N에 …", 본 게임 보드면 최고점.
static func stage_hint(config: ProgressionConfig, level: int, best: int) -> String:
	var next: String = config.next_stage_description(level)
	return "Lv %d에 %s" % [level + 1, next] if not next.is_empty() else "최고점 %d" % best


## 지금 메뉴 버튼이 눌릴 수 있는지 (테스트/디버그용).
func is_entry_enabled(entry: MenuUnlocks.Entry) -> bool:
	return not _buttons[entry].disabled


## 빛나는 버튼 (없으면 -1).
func highlighted_entry() -> int:
	return flow.highlighted_entry()


## 게임 시작 (main_menu.tscn에서 연결): 첫 뽑기 유도 단계면 상점으로.
func _on_start_pressed() -> void:
	if flow.start_goes_to_shop():
		shop_requested.emit()
	else:
		start_game_requested.emit()


func _show_level(progress: ProgressStore) -> void:
	_level_label.text = "Lv %d" % progress.level
	_exp_fill.anchor_right = clampf(float(progress.experience) / maxi(progression.exp_to_next(progress.level), 1), 0.0, 1.0)


func _apply_unlocks() -> void:
	for entry: MenuUnlocks.Entry in _buttons:
		_buttons[entry].disabled = not unlocks.is_open(entry)
	_character_button.disabled = not unlocks.is_open(MenuUnlocks.Entry.CHARACTERS)


func _glow(entry: int) -> void:
	if entry < 0 or not _buttons.has(entry as MenuUnlocks.Entry) or not is_inside_tree():
		return
	var button: Button = _buttons[entry as MenuUnlocks.Entry]
	var tween: Tween = create_tween().set_loops()
	tween.tween_property(button, "modulate", glow_color, glow_period / 2.0)
	tween.tween_property(button, "modulate", Color.WHITE, glow_period / 2.0)
