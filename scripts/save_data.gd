class_name SaveData
extends RefCounted
## 로컬 저장 파일(ConfigFile) 입출력의 유일한 창구. 저장 항목별 클래스(BestScoreStore, CharacterStore,
## OptionsStore)는 이 클래스로 값을 읽고 쓰기만 한다.
## - [meta] version으로 저장 형식 버전을 기록하고, 불러올 때 옛 형식을 _migrate()에서 현재 형식으로 옮긴다.
## - 쓸 때는 항상 파일을 새로 읽은 뒤 바꿔 저장하므로(읽고-수정-쓰기) 다른 항목의 값을 지우지 않는다.
## - 테스트·스모크는 path_override로 사용자 저장 파일과 다른 파일을 쓴다.
##
## 저장 형식 (version 4):
##   [meta]    version = 4
##   [score]   best = int
##   [player]  character = String (캐릭터 id, HTML 프로토타입 id)
##   [options] control_mode = "swipe" | "dpad"
##             master_volume = int 0~100 (없으면 100)
##             reduce_motion = bool (없으면 false)
##   [progress] level = int (1~), exp = int, coins = int, diamonds = int,
##             tickets = Dictionary (등급 → 선택권 장 수), unlocked = PackedStringArray (해금한 캐릭터 id, 기본 캐릭터는 늘 해금)
##   [achievements] [stats] [tutorial] [puzzle] — 각 Store 참고

const DEFAULT_PATH: String = "user://save.cfg"
const CURRENT_VERSION: int = 4
const META_SECTION: String = "meta"
const KEY_VERSION: String = "version"
## version 4 미만 저장에서 남기는 항목 (팀 결정 11/04: 경험치·선택권 규칙이 바뀌어 진행을 초기화한다, 설정만 남김).
const KEPT_ON_RESET: PackedStringArray = [OptionsStore.SECTION]

## 비어 있지 않으면 경로를 주지 않은 모든 SaveData가 이 파일을 쓴다 (테스트·스모크용).
static var path_override: String = ""

var path: String

var _file: ConfigFile = ConfigFile.new()
## 불러온 파일의 원래 버전 (파일이 없거나 버전 기록 전 형식이면 0).
var _loaded_version: int = 0


## p_path가 비어 있으면 path_override → DEFAULT_PATH 순으로 정한다.
func _init(p_path: String = "") -> void:
	path = resolve_path(p_path)
	if _file.load(path) == OK:
		var value: Variant = _file.get_value(META_SECTION, KEY_VERSION, 0)
		_loaded_version = value if typeof(value) == TYPE_INT else 0
	_migrate()


static func resolve_path(p_path: String) -> String:
	if not p_path.is_empty():
		return p_path
	return path_override if not path_override.is_empty() else DEFAULT_PATH


## 불러온 파일의 원래 버전.
func loaded_version() -> int:
	return _loaded_version


func get_value(section: String, key: String, default: Variant) -> Variant:
	return _file.get_value(section, key, default)


func set_value(section: String, key: String, value: Variant) -> void:
	_file.set_value(section, key, value)


## 현재 버전을 기록해 저장한다.
func save() -> Error:
	_file.set_value(META_SECTION, KEY_VERSION, CURRENT_VERSION)
	var err: Error = _file.save(path)
	if err != OK:
		push_warning("SaveData: failed to save %s (error %d)" % [path, err])
	return err


## 진행 초기화 (설정의 "진행 초기화", HTML resetMeta): 설정([options])만 남기고 진행·재화·캐릭터·업적·튜토리얼·퍼즐·최고 점수를
## 지워 저장한다. 다음 실행은 처음 실행과 같다 (튜토리얼부터).
static func reset_progress(p_path: String = "") -> Error:
	var data: SaveData = SaveData.new(p_path)
	for section: String in data._file.get_sections():
		if not KEPT_ON_RESET.has(section):
			data._file.erase_section(section)
	return data.save()


## 한 항목만 바꿔 저장하는 지름길: 파일을 새로 읽고, 값을 바꾸고, 저장한다.
static func write_value(p_path: String, section: String, key: String, value: Variant) -> Error:
	var data: SaveData = SaveData.new(p_path)
	data.set_value(section, key, value)
	return data.save()


## 옛 형식을 현재 형식으로 옮긴다. 형식이 바뀔 때마다 단계를 추가한다.
## 옮긴 내용은 메모리에만 있고 다음 저장 때 파일에 기록된다.
func _migrate() -> void:
	# version 3 이하 (0 = 버전 기록 전): 진행·재화·캐릭터·업적·튜토리얼·퍼즐·최고 점수를 지우고 설정만 남긴다 (E26).
	# 옛 버전의 캐릭터 id 이름 바꾸기(v1 → 2)와 [progress] 추가(v2 → 3)는 이 초기화에 포함된다.
	if _loaded_version < 4:
		for section: String in _file.get_sections():
			if not KEPT_ON_RESET.has(section):
				_file.erase_section(section)
