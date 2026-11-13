class_name TopBar
extends PanelContainer
## 메뉴 화면 공통 위 줄 (기획서 8.1장, E38): 레벨 버튼(Lv · 경험치 바 · 받을 보상 표시), 지갑(코인 · 다이아).
## 레벨 버튼을 누르면 레벨 화면으로 가고, 뒤로가기는 지금 화면으로 돌아온다. 다이아는 BM이 정해지면 구매창으로 간다 (diamond_requested, 지금은 연결 없음).
## 주인 화면이 _ready에서 setup을 부르고, 재화가 바뀌면 refresh를 부른다.

signal diamond_requested

@export var progression: ProgressionConfig

var _save_path: String = ""


func setup(save_path: String = "") -> void:
	_save_path = save_path
	refresh()


## 저장 파일의 지금 값으로 다시 보인다.
func refresh() -> void:
	progression = ProgressionConfig.ensure_valid(progression)
	var progress: ProgressStore = ProgressStore.new(_save_path)
	(%LevelLabel as Label).text = "Lv %d" % progress.level
	(%ExpFill as Control).anchor_right = clampf(float(progress.experience) / maxi(progression.exp_to_next(progress.level), 1), 0.0, 1.0)
	(%WalletLabel as WalletView).show_amounts(progress.coins, progress.diamonds)
	var open: bool = TutorialFlow.current(_save_path).unlocks().is_open(MenuUnlocks.Entry.LEVEL)
	level_button().disabled = not open
	(%ClaimMark as Control).visible = open and not progress.claimable_levels().is_empty()


func level_button() -> Button:
	return %LevelButton as Button


func _on_level_button_pressed() -> void:
	var host: Node = owner
	LevelRewardsScreen.return_scene = host.scene_file_path if host != null else ""
	(%LevelNavigator as SceneNavigator).go()


func _on_diamond_button_pressed() -> void:
	diamond_requested.emit()
