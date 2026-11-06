class_name BoardChannel
extends Node
## 보드 화면(BoardView)용 이벤트 채널. GameController가 판마다 bind()로 세션 이벤트를 연결하고,
## 보드 쪽 View는 이 채널의 signal만 구독한다 (연결은 main.tscn에 명시).

signal board_created(board: Board)
signal character_ready(character: CharacterData)
signal move_started(result: Board.MoveResult)
signal move_blocked(result: Board.MoveResult)
signal matched(center: Vector2i, color: int, cells: Array[Vector2i])
signal cells_refilled(cells: Array[Vector2i])
## 능력(연금술사 "변성")으로 색이 바뀐 칸.
signal cells_changed(cells: Array[Vector2i])
## 금화가 붙거나 사라진 칸.
signal coins_changed(cells: Array[Vector2i])
## 능력의 판 위 표시 (깃발·구역).
signal marks_changed(marks: Array[BoardMark])
## 능력이 블록을 터뜨렸다 (폭파범 연쇄).
signal cells_blasted(cells: Array[Vector2i], color: int)
## 블록 표시 방식 (색약·레트로, null = 보통).
signal display_style_changed(style: DisplayStyle)


## 새 판의 세션 이벤트를 이 채널로 연결하고, 초기 상태(캐릭터 외형 → 보드)를 알린다.
func bind(session: GameSession, character: CharacterData) -> void:
	session.move_started.connect(move_started.emit)
	session.move_blocked.connect(move_blocked.emit)
	session.matched.connect(matched.emit)
	session.cells_refilled.connect(cells_refilled.emit)
	session.cells_changed.connect(cells_changed.emit)
	session.coins_changed.connect(coins_changed.emit)
	session.marks_changed.connect(marks_changed.emit)
	session.cells_blasted.connect(cells_blasted.emit)
	session.display_style_changed.connect(display_style_changed.emit)
	session.board_rearranged.connect(board_created.emit)  # 판을 통째로 바꿨다 (거울): 다시 그린다
	character_ready.emit(character)
	display_style_changed.emit(session.display_style())
	board_created.emit(session.board)
	marks_changed.emit(session.board_marks())
