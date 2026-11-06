class_name DebugPanel
extends VBoxContainer
## 설정 화면의 디버그 (기획서 8.1장, 개발 빌드만): 재화 지급, 레벨 올리기, 캐릭터 전부 해금.
## 배포 빌드에서는 숨긴다. 진행 저장은 ProgressStore로만 한다.

## 전부 해금할 캐릭터 목록.
@export var roster: CharacterRoster
## 한 번에 주는 코인·다이아.
@export var grant_coins: int = 1000
@export var grant_diamonds: int = 100

@onready var _status_label: Label = %DebugStatusLabel


func _ready() -> void:
	visible = OS.is_debug_build()
	_refresh()


func _on_grant_button_pressed() -> void:
	ProgressStore.new().add_currency(grant_coins, grant_diamonds)
	_refresh()


func _on_level_button_pressed() -> void:
	var store: ProgressStore = ProgressStore.new()
	store.set_level(store.level + 1)
	_refresh()


func _on_unlock_all_button_pressed() -> void:
	if roster == null:
		return
	var store: ProgressStore = ProgressStore.new()
	for character: CharacterData in roster.characters:
		store.unlock(character.id)
	_refresh()


## 튜토리얼을 처음부터 (다음 게임 시작이 규칙 튜토리얼).
func _on_tutorial_restart_pressed() -> void:
	TutorialStore.new().restart_all()
	_refresh()


## 튜토리얼과 흐름을 모두 끝낸 상태로.
func _on_tutorial_finish_pressed() -> void:
	TutorialStore.new().finish_all()
	_refresh()


## 흐름 단계로 바로: 첫 뽑기 직전 (튜토리얼 끝 · 실전 판 1번 · 레벨 보상 화면 봄).
func _on_tutorial_gacha_pressed() -> void:
	var tutorial: TutorialStore = TutorialStore.new()
	tutorial.restart_all()
	tutorial.complete_rule_tutorial()
	tutorial.mark_seen(TutorialStore.SEEN_REAL_GAME)
	tutorial.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	_ensure_games_played(1)
	_refresh()


## 흐름 단계로 바로: 첫 캐릭터(첫 뽑기 후보의 첫 캐릭터)를 받음.
func _on_tutorial_character_pressed() -> void:
	if roster == null:
		return
	_on_tutorial_gacha_pressed()
	var id: StringName = &"gardener"
	ProgressStore.new().unlock(id)
	CharacterStore.new().select(id)
	var tutorial: TutorialStore = TutorialStore.new()
	tutorial.mark_seen(TutorialStore.SEEN_GACHA_GIFT)
	tutorial.got_first_character(id)
	_refresh()


func _ensure_games_played(count: int) -> void:
	var achievements: AchievementStore = AchievementStore.new()
	if achievements.stat("games") < count:
		achievements.add_stat("games", count - achievements.stat("games"))
		achievements.save()


## 지금 진행 상태 문구 (테스트/디버그용).
func status_text() -> String:
	return _status_label.text


func _refresh() -> void:
	var store: ProgressStore = ProgressStore.new()
	var tutorial: TutorialStore = TutorialStore.new()
	_status_label.text = "Lv %d · ● %d · ◆ %d · 해금 %d\n튜토리얼 %s · 흐름 %d" % [store.level, store.coins, store.diamonds,
		store.unlocked.size(), "끝" if tutorial.done else "전", tutorial.flow]
