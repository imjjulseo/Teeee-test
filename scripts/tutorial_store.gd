class_name TutorialStore
extends RefCounted
## 튜토리얼 진행 (기획서 8.8 · 8.9장): 규칙 튜토리얼을 끝냈는지, 튜토리얼 흐름 단계, 본 안내, 튜토리얼을 기다리는 캐릭터.
## 저장 파일 입출력은 SaveData가 한다 ([tutorial]). 저장에 이 칸이 없는데 진행 기록(레벨·판 수·최고 점수)이 있으면
## 튜토리얼을 끝낸 것으로 본다 (6단계 결정: 기존 저장 파일).

const SECTION: String = "tutorial"
const KEY_DONE: String = "done"
const KEY_FLOW: String = "flow"
const KEY_SEEN: String = "seen"
const KEY_WANT: String = "want_character"

## 흐름 단계 (HTML gt): 0 튜토리얼 전 → 1 튜토리얼 끝(첫 실전 판·레벨 보상·첫 뽑기) → 2 첫 캐릭터 받음 → 3 그 캐릭터로 시작함.
enum Flow { BEFORE, FIRST_GAMES, FIRST_CHARACTER, DONE }

## 본 안내 이름.
const SEEN_LEVEL_SCREEN: String = "level_screen"
const SEEN_CHARACTERS: String = "characters"
const SEEN_ACHIEVEMENTS: String = "achievements"
const SEEN_GACHA_GIFT: String = "gacha_gift"
const SEEN_REAL_GAME: String = "real_game"
## 처음 쓰는 캐릭터 질문(6c)을 모두 본 것으로 (기존 저장·개발용 튜토리얼 끝냄). 캐릭터별은 "character:<id>".
const SEEN_ALL_CHARACTERS: String = "all_characters"
## 처음 볼 때 안내 (6d, FirstViewTips): 족보 동시 진행, 첫 결과의 경험치, 히든 업적. 업적·캐릭터 화면은 SEEN_ACHIEVEMENTS · SEEN_CHARACTERS.
const SEEN_MULTI_RECIPES: String = "multi_recipes"
const SEEN_EXPERIENCE: String = "experience"
const SEEN_HIDDEN_ACHIEVEMENTS: String = "hidden_achievements"
const ALL_SEEN: PackedStringArray = [SEEN_LEVEL_SCREEN, SEEN_CHARACTERS, SEEN_ACHIEVEMENTS, SEEN_GACHA_GIFT, SEEN_REAL_GAME, SEEN_ALL_CHARACTERS,
	SEEN_MULTI_RECIPES, SEEN_EXPERIENCE, SEEN_HIDDEN_ACHIEVEMENTS]

var path: String
var done: bool = false
var flow: Flow = Flow.BEFORE
var seen: Dictionary[String, bool] = {}
## 첫 뽑기로 받아 튜토리얼을 기다리는 캐릭터 (6c).
var want_character: StringName = &""


## p_path가 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
func _init(p_path: String = "") -> void:
	path = SaveData.resolve_path(p_path)
	var data: SaveData = SaveData.new(path)
	var saved_done: Variant = data.get_value(SECTION, KEY_DONE, "")
	if typeof(saved_done) != TYPE_BOOL:  # 이 칸이 없는 저장 (튜토리얼 이전 판)
		if TutorialStore._has_progress(data):
			_mark_finished()
		return
	done = saved_done == true
	var saved_flow: Variant = data.get_value(SECTION, KEY_FLOW, 0)
	flow = clampi(saved_flow, Flow.BEFORE, Flow.DONE) as Flow if typeof(saved_flow) == TYPE_INT else Flow.BEFORE
	var saved_seen: Variant = data.get_value(SECTION, KEY_SEEN, PackedStringArray())
	if saved_seen is PackedStringArray or saved_seen is Array:
		for key: Variant in saved_seen:
			if typeof(key) == TYPE_STRING:
				seen[key] = true
	var saved_want: Variant = data.get_value(SECTION, KEY_WANT, "")
	if typeof(saved_want) == TYPE_STRING or typeof(saved_want) == TYPE_STRING_NAME:
		want_character = StringName(saved_want)


func has_seen(key: String) -> bool:
	return seen.has(key)


func mark_seen(key: String) -> void:
	if not seen.has(key):
		seen[key] = true
		save()


## 이 캐릭터를 써 본 적이 있는지 (처음이면 "튜토리얼 / 바로 시작"을 묻는다).
func has_seen_character(id: StringName) -> bool:
	return has_seen(SEEN_ALL_CHARACTERS) or has_seen(TutorialStore.character_key(id))


func mark_character_seen(id: StringName) -> void:
	mark_seen(TutorialStore.character_key(id))


static func character_key(id: StringName) -> String:
	return "character:%s" % id


## 규칙 튜토리얼을 끝냈다 (흐름은 첫 실전 판부터).
func complete_rule_tutorial() -> void:
	done = true
	flow = maxi(flow, Flow.FIRST_GAMES) as Flow
	save()


## 첫 뽑기로 첫 캐릭터를 받았다.
func got_first_character(id: StringName) -> void:
	flow = maxi(flow, Flow.FIRST_CHARACTER) as Flow
	want_character = id
	save()


## 첫 캐릭터로 판을 시작했다 (그 캐릭터면 그 판이 캐릭터 튜토리얼, GameController).
func started_with_character() -> void:
	if flow == Flow.FIRST_CHARACTER:
		flow = Flow.DONE
		want_character = &""
		save()


## 튜토리얼과 흐름을 모두 끝낸 상태로 (기존 저장, 개발용).
func finish_all() -> void:
	_mark_finished()
	save()


## 처음부터 (개발용).
func restart_all() -> void:
	done = false
	flow = Flow.BEFORE
	seen.clear()
	want_character = &""
	save()


func save() -> void:
	var data: SaveData = SaveData.new(path)
	data.set_value(SECTION, KEY_DONE, done)
	data.set_value(SECTION, KEY_FLOW, int(flow))
	data.set_value(SECTION, KEY_SEEN, PackedStringArray(seen.keys()))
	data.set_value(SECTION, KEY_WANT, String(want_character))
	data.save()


func _mark_finished() -> void:
	done = true
	flow = Flow.DONE
	for key: String in ALL_SEEN:
		seen[key] = true
	want_character = &""


static func _has_progress(data: SaveData) -> bool:
	var level: Variant = data.get_value(ProgressStore.SECTION, ProgressStore.KEY_LEVEL, 1)
	var games: Variant = data.get_value(AchievementStore.STATS_SECTION, "games", 0)
	var best: Variant = data.get_value(BestScoreStore.SECTION, BestScoreStore.KEY_BEST, 0)
	return (typeof(level) == TYPE_INT and level > 1) or (typeof(games) == TYPE_INT and games > 0) or (typeof(best) == TYPE_INT and best > 0)
