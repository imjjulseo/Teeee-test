class_name PuzzleMenuScreen
extends Control
## 메뉴 > 퍼즐 (기획서 8.1 · 8.8장, 팀 결정 11/06): 블럭 모으기 판 목록(단계 구분 없이 1번부터, PuzzleMenu).
## 판마다 미리보기 + 푼 판은 별, 안 푼 판은 첫 클리어 코인. 모든 판이 열려 있다. 풀기는 PuzzleRequest를 적고 play_requested
## (puzzle_menu.tscn에서 씬 전환). 처음 열면 스포트라이트로 한 번 안내한다 (HTML spotOnce _pz, 튜토리얼 흐름의 마지막 단계).

signal play_requested

@export var book: PuzzleBook
@export var board_button_scene: PackedScene
## 처음 볼 때 안내 문구 (비어 있으면 안내 없이 본 것으로만 적는다).
@export var tips: FirstViewTips
@export var spotlight: SpotlightOverlay
## 저장 파일. 비어 있으면 SaveData 기본 경로 (테스트·스모크는 SaveData.path_override).
@export var save_path: String = ""

var store: PuzzleStore
var menu: PuzzleMenu
var _buttons: Array[PuzzleBoardButton] = []
var _guides: GuideQueue

@onready var _grid: GridContainer = %Boards
@onready var _wallet_label: WalletView = %WalletLabel


func _ready() -> void:
	book = PuzzleBook.ensure_valid(book)
	store = PuzzleStore.new(save_path)
	menu = PuzzleMenu.new(book, store)
	var boards: Array[PuzzleDef] = menu.boards()
	for i: int in boards.size():
		var button: PuzzleBoardButton = board_button_scene.instantiate() as PuzzleBoardButton
		_grid.add_child(button)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.setup(boards[i], i + 1, store.stars_of(boards[i].id), menu.pending_reward(boards[i].id))
		button.chosen.connect(_on_board_chosen)
		_buttons.append(button)
	var progress: ProgressStore = ProgressStore.new(save_path)
	_wallet_label.show_amounts(progress.coins, progress.diamonds)
	_queue_guides(TutorialStore.new(save_path))


func buttons() -> Array[PuzzleBoardButton]:
	return _buttons


## 처음 볼 때 안내가 떠 있는지 / 그 키 (테스트/디버그용).
func guide_key() -> String:
	return _guides.current_key() if _guides != null else ""


func _queue_guides(tutorial: TutorialStore) -> void:
	if tips == null or spotlight == null:
		tutorial.mark_seen(TutorialStore.SEEN_PUZZLES)
		return
	_guides = GuideQueue.new(spotlight, tutorial)
	var grid: Control = _grid
	_guides.add(TutorialStore.SEEN_PUZZLES, tips.puzzles_head, tips.puzzles_text,
		func() -> Array[Rect2]: return [grid.get_global_rect()] as Array[Rect2])
	_guides.start(self)


func _on_spotlight_tapped() -> void:
	if _guides != null:
		_guides.next()


func _on_board_chosen(id: String) -> void:
	PuzzleRequest.board(id)
	play_requested.emit()
