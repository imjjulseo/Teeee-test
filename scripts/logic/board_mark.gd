class_name BoardMark
extends RefCounted
## 능력이 판 위에 보여 주는 표시 하나 (마라토너 깃발, 탐험가 구역 등). 순수 데이터 — 그리는 법은 View가 정한다.

enum Kind {
	FLAG,  ## 지금 가야 할 깃발 (매치 전)
	FLAG_READY,  ## 지금 가야 할 깃발 (매치를 해서 밟으면 보너스)
	FLAG_NEXT,  ## 그다음 깃발 (흐리게)
	ZONE,  ## 구역 (점선 테두리)
	PATH,  ## 지나온 길 (수선사 끈, 사진사 계획): cells를 차례로 잇는 선, rect는 시작 칸
	WARN,  ## 곧 바뀔 칸 예고 (방화광: 다음에 불이 번질 칸)
	# 블럭 모으기 퍼즐 안내 (8.8장)
	TARGET,  ## 모을 블록 (테두리 강조)
	GOAL_CENTER,  ## 목표 모양의 가운데 (내가 설 칸)
	GOAL_SLOT,  ## 목표 모양의 빈 자리 (점선)
	GOAL_SLOT_FILLED,  ## 목표 모양에 이미 모인 자리
	STAND,  ## 힌트: 먼저 설 칸
	PULL,  ## 힌트: 당길 블록
	ARROW,  ## 힌트: 첫 수 방향 (direction)
}

var kind: Kind
## 표시하는 칸 범위 (칸 하나면 크기 1×1).
var rect: Rect2i
## PATH: 차례로 이을 칸들.
var cells: Array[Vector2i] = []
## ARROW: 가리키는 방향.
var direction: Vector2i = Vector2i.ZERO


func _init(p_kind: Kind, p_rect: Rect2i) -> void:
	kind = p_kind
	rect = p_rect


static func at_cell(p_kind: Kind, cell: Vector2i) -> BoardMark:
	return BoardMark.new(p_kind, Rect2i(cell, Vector2i.ONE))


## path[0]에서 시작해 차례로 잇는 길.
static func path(p_cells: Array[Vector2i]) -> BoardMark:
	var mark: BoardMark = BoardMark.new(Kind.PATH, Rect2i(p_cells[0], Vector2i.ONE))
	mark.cells = p_cells.duplicate()
	return mark
