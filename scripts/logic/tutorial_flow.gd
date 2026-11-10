class_name TutorialFlow
extends RefCounted
## 튜토리얼 흐름 (기획서 8.8장, HTML menuStage): 튜토리얼 → 첫 실전 판 → 레벨 보상 화면 안내 → 첫 뽑기(고정) →
## 캐릭터 화면 → 그 캐릭터로 시작 → 업적 안내 → 퍼즐 안내(11/06) → 모두 열림. 메뉴 버튼은 이 순서로 열리고(한 번 열리면 계속), 지금 누를 버튼이 빛난다.
## 순수 규칙: 저장 값(TutorialStore)과 결과로 끝난 판 수를 받아 판단만 한다.

enum Stage { START, LEVEL, SHOP, CHARACTERS, PLAY, ACHIEVEMENTS, PUZZLES, ALL }

## 단계별로 열린 메뉴 버튼 수 (MenuUnlocks.ORDER 앞에서부터: 시작 · 레벨 · 상점 · 캐릭터 · 업적 · 퍼즐).
const OPENED: Dictionary[Stage, int] = {
	Stage.START: 1, Stage.LEVEL: 2, Stage.SHOP: 3, Stage.CHARACTERS: 4, Stage.PLAY: 4, Stage.ACHIEVEMENTS: 5, Stage.PUZZLES: 6, Stage.ALL: 6,
}
## 단계별로 빛나는 메뉴 버튼 (없으면 -1).
const HIGHLIGHT: Dictionary[Stage, int] = {
	Stage.START: MenuUnlocks.Entry.START, Stage.LEVEL: MenuUnlocks.Entry.LEVEL, Stage.SHOP: MenuUnlocks.Entry.SHOP,
	Stage.CHARACTERS: MenuUnlocks.Entry.CHARACTERS, Stage.PLAY: MenuUnlocks.Entry.START,
	Stage.ACHIEVEMENTS: MenuUnlocks.Entry.ACHIEVEMENTS, Stage.PUZZLES: MenuUnlocks.Entry.PUZZLES, Stage.ALL: -1,
}

var store: TutorialStore
## 결과로 끝난 판 수 (AchievementStore 누적 통계).
var games_played: int = 0
## 첫 뽑기 전에 해야 하는 실전 판 수.
var games_before_gacha: int = 1


func _init(p_store: TutorialStore, p_games_played: int, p_games_before_gacha: int = 1) -> void:
	store = p_store
	games_played = p_games_played
	games_before_gacha = p_games_before_gacha


## 저장 파일에서 읽은 지금 흐름 (공통 위·아래 줄이 쓴다).
static func current(save_path: String = "") -> TutorialFlow:
	return TutorialFlow.new(TutorialStore.new(save_path), AchievementStore.new(save_path).stat("games"))


func stage() -> Stage:
	if not store.done:
		return Stage.START
	match store.flow:
		TutorialStore.Flow.BEFORE, TutorialStore.Flow.FIRST_GAMES:
			if level_step():
				return Stage.LEVEL
			return Stage.SHOP if gacha_ready() else Stage.START
		TutorialStore.Flow.FIRST_CHARACTER:
			return Stage.PLAY if store.has_seen(TutorialStore.SEEN_CHARACTERS) else Stage.CHARACTERS
	if not store.has_seen(TutorialStore.SEEN_ACHIEVEMENTS):
		return Stage.ACHIEVEMENTS
	return Stage.ALL if store.has_seen(TutorialStore.SEEN_PUZZLES) else Stage.PUZZLES


## 레벨 버튼 안내 단계: 첫 실전 판을 했고 레벨 보상 화면을 아직 안 봤다.
func level_step() -> bool:
	return _first_games_done() and not store.has_seen(TutorialStore.SEEN_LEVEL_SCREEN)


## 첫 뽑기 유도 단계: 레벨 보상 화면까지 봤다.
func gacha_ready() -> bool:
	return _first_games_done() and store.has_seen(TutorialStore.SEEN_LEVEL_SCREEN)


## 이번 뽑기가 튜토리얼 흐름의 첫 뽑기(고정)인지.
func is_first_pull() -> bool:
	return gacha_ready()


## 결과 화면에서 다시 하기 대신 메뉴로 이끈다 (첫 실전 판 뒤).
func guides_to_menu() -> bool:
	return store.done and store.flow == TutorialStore.Flow.FIRST_GAMES and games_played >= games_before_gacha


## 메뉴의 게임 시작 버튼이 상점으로 간다 (첫 뽑기 유도).
func start_goes_to_shop() -> bool:
	return gacha_ready()


func unlocks() -> MenuUnlocks:
	return MenuUnlocks.new(OPENED[stage()])


func highlighted_entry() -> int:
	return HIGHLIGHT[stage()]


func _first_games_done() -> bool:
	return store.done and store.flow == TutorialStore.Flow.FIRST_GAMES and games_played >= games_before_gacha
