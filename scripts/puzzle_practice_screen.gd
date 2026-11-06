class_name PuzzlePracticeScreen
extends Control
## 설정 > 블럭 모으기 (기획서 8.1 · 8.8장): 연습 기록(푼 문제·모은 별·최소 수 성공), 난이도 고르기 + 연습 시작,
## 퍼즐 레벨(단계별 판 목록과 별 — 판은 순서대로 열리고 Lv.2~4는 첫 클리어 코인, PuzzleUnlocks). 풀기는 PuzzleRequest를 적고 play_requested (practice.tscn에서 씬 전환).

signal play_requested

@export var book: PuzzleBook
@export var chip_scene: PackedScene
@export var level_row_scene: PackedScene
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var store: PuzzleStore
var _chips: Array[FilterChip] = []
var _rows: Array[PuzzleLevelRow] = []

@onready var _stats_label: Label = %StatsLabel
@onready var _chips_box: HBoxContainer = %Difficulties
@onready var _description: Label = %DifficultyDescription
@onready var _levels_box: VBoxContainer = %Levels


func _ready() -> void:
	book = PuzzleBook.ensure_valid(book)
	store = PuzzleStore.new(save_path)
	_stats_label.text = "푼 문제 %d · 모은 별 %d · 최소 수 성공 %d" % [store.solved, store.star_total, store.perfect]
	for i: int in book.difficulties.size():
		var chip: FilterChip = chip_scene.instantiate() as FilterChip
		_chips_box.add_child(chip)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.setup(i, book.difficulties[i].name)
		chip.chosen.connect(_on_difficulty_chosen)
		_chips.append(chip)
	var unlocks: PuzzleUnlocks = PuzzleUnlocks.new(book, store)
	for level: PuzzleLevel in book.levels:
		var row: PuzzleLevelRow = level_row_scene.instantiate() as PuzzleLevelRow
		_levels_box.add_child(row)
		row.setup(level, store, unlocks)
		row.board_chosen.connect(_on_board_chosen)
		_rows.append(row)
	_show_difficulty()


func difficulty() -> PuzzleDifficulty:
	return book.find_difficulty(store.difficulty)


func level_rows() -> Array[PuzzleLevelRow]:
	return _rows


func _show_difficulty() -> void:
	var current: PuzzleDifficulty = difficulty()
	for i: int in _chips.size():
		_chips[i].set_selected(book.difficulties[i] == current)
	_description.text = current.description if current != null else ""


func _on_difficulty_chosen(index: int) -> void:
	store.set_difficulty(book.difficulties[index].id)
	_show_difficulty()


## 연습 시작 (practice.tscn에서 연결).
func _on_start_pressed() -> void:
	PuzzleRequest.practice(difficulty().id)
	play_requested.emit()


func _on_board_chosen(id: String) -> void:
	PuzzleRequest.board(id)
	play_requested.emit()
