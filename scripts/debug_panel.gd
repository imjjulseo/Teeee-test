class_name DebugPanel
extends VBoxContainer
## 설정 화면 맨 위의 디버그 (기획서 8.1장): "디버그" 버튼을 누르면 펼쳐진다 (개발 빌드는 펼친 채로 시작).
## 버튼에는 배포 빌드 이름(application/config/version, 배포 워크플로가 날짜와 커밋으로 적는다)이 함께 보인다.
## 재화 지급, 레벨 올리기, 캐릭터 전부 해금, 튜토리얼 단계 이동, 튜토리얼 건너뛰고 메뉴 모두 열기,
## 메뉴에서 바로 갈 수 없는 화면 열기(인트로, 규칙 튜토리얼, 짧은 판 = 결과·부활 화면, 레벨 보상).
## 테스트 기간이라 배포 빌드(웹)에도 보인다. 출시 전에 show_in_release를 끈다. 진행 저장은 각 Store로만 한다.

## 진행(재화, 레벨, 해금, 튜토리얼)을 바꿨다: 화면이 위·아래 줄을 다시 그린다.
signal progress_changed
## 게임 씬으로 간다 (PlayRequest를 적어 둔 뒤).
signal game_requested

## 배포 빌드에도 보인다 (테스트 기간). 출시 전에 끈다.
@export var show_in_release: bool = true
## "짧은 판"의 제한시간(초): 결과·부활 화면을 빨리 본다.
@export var short_game_seconds: float = 5.0

## 전부 해금할 캐릭터 목록.
@export var roster: CharacterRoster
## 한 번에 주는 코인·다이아.
@export var grant_coins: int = 1000
@export var grant_diamonds: int = 100

@onready var _status_label: Label = %DebugStatusLabel
@onready var _toggle: Button = %DebugToggle


func _ready() -> void:
	visible = OS.is_debug_build() or show_in_release
	_toggle.set_pressed_no_signal(OS.is_debug_build())
	_toggle.text = toggle_text()
	_show_body(_toggle.button_pressed)
	_refresh()


## 펼침 버튼 글: 배포할 때 적어 넣은 빌드 이름이 있으면 함께 보인다 (기기에 옛 판이 남아 있는지 확인용).
static func toggle_text() -> String:
	var build: String = str(ProjectSettings.get_setting("application/config/version", ""))
	return "디버그" if build.is_empty() else "디버그 (빌드 %s)" % build


## 펼쳐져 있는지 (테스트/디버그용).
func is_open() -> bool:
	return _toggle.button_pressed


func _on_toggle_pressed() -> void:
	_show_body(_toggle.button_pressed)


## 규칙 튜토리얼을 다시 본다 (기록·보상 없음).
func _on_rule_tutorial_pressed() -> void:
	PlayRequest.replay_tutorial = true
	game_requested.emit()


## 제한시간이 짧은 판: 금방 결과 화면, 다이아가 있으면 부활 화면.
func _on_short_game_pressed() -> void:
	PlayRequest.game_seconds = short_game_seconds
	game_requested.emit()


func _show_body(on: bool) -> void:
	for child: Node in get_children():
		if child is Control and child != _toggle:
			(child as Control).visible = on


func _on_grant_button_pressed() -> void:
	ProgressStore.new().add_currency(grant_coins, grant_diamonds)
	_changed()


func _on_level_button_pressed() -> void:
	var store: ProgressStore = ProgressStore.new()
	store.set_level(store.level + 1)
	_changed()


func _on_unlock_all_button_pressed() -> void:
	if roster == null:
		return
	var store: ProgressStore = ProgressStore.new()
	for character: CharacterData in roster.characters:
		store.unlock(character.id)
	_changed()


## 튜토리얼을 처음부터 (다음 게임 시작이 규칙 튜토리얼).
func _on_tutorial_restart_pressed() -> void:
	TutorialStore.new().restart_all()
	_changed()


## 튜토리얼과 흐름을 모두 끝낸 상태로.
func _on_tutorial_finish_pressed() -> void:
	TutorialStore.new().finish_all()
	_changed()


## 흐름 단계로 바로: 첫 뽑기 직전 (튜토리얼 끝 · 실전 판 1번 · 레벨 보상 화면 봄).
func _on_tutorial_gacha_pressed() -> void:
	var tutorial: TutorialStore = TutorialStore.new()
	tutorial.restart_all()
	tutorial.complete_rule_tutorial()
	tutorial.mark_seen(TutorialStore.SEEN_REAL_GAME)
	tutorial.mark_seen(TutorialStore.SEEN_LEVEL_SCREEN)
	_ensure_games_played(1)
	_changed()


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
	_changed()


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


## 진행을 바꾼 뒤: 상태 문구를 고치고 화면에 알린다.
func _changed() -> void:
	_refresh()
	progress_changed.emit()
