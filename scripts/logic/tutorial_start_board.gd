class_name TutorialStartBoard
extends RefCounted
## 규칙 튜토리얼 시작 판 (HTML tutStartBoard, 고정 시드): seed부터 하나씩 올려 가며 HTML과 같은 순서로 섞은 판 중
## 가운데에서 한 수 매치가 없고, 어느 쪽으로 한 번 움직여도 그다음 한 수 매치가 있는 판을 고른다.
## 찾은 판의 난수(HtmlRng)는 그 뒤 튜토리얼에서 이어 쓴다 (HTML도 같은 RNG를 계속 쓴다).

## 한 번에 찾아볼 seed 개수 (HTML과 같음).
const SEARCH: int = 400000
const PLAYER: int = -1
## HTML DIRS 순서: 위 · 아래 · 왼쪽 · 오른쪽 (행, 열).
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

## 칸 색 (행 우선, 플레이어 칸은 PLAYER).
var colors: PackedInt32Array = PackedInt32Array()
var size: int = 0
## 판을 만든 seed (조건을 만족한 첫 seed).
var seed_used: int = 0
## 판을 만든 뒤의 난수 (튜토리얼이 이어 쓴다).
var rng: HtmlRng


## 조건에 맞는 판을 찾는다. 못 찾으면 null (HTML은 이때 무작위 판).
static func find(start_seed: int, board_size: int, color_count: int) -> TutorialStartBoard:
	var n: int = board_size
	var mid: int = (n - 1) / 2
	var center: int = mid * n + mid
	for seed_value: int in range(start_seed, start_seed + SEARCH):
		var rng: HtmlRng = HtmlRng.new(seed_value)
		var pool: Array = []
		for i: int in n * n - 1:
			pool.append(i % color_count)
		rng.shuffle(pool)
		var grid: PackedInt32Array = PackedInt32Array()
		var k: int = 0
		for i: int in n * n:
			if i == center:
				grid.append(PLAYER)
			else:
				grid.append(pool[k])
				k += 1
		if TutorialStartBoard._is_match(grid, n, center) or TutorialStartBoard._one_move_match(grid, n, center):
			continue
		if not TutorialStartBoard._every_move_leaves_one(grid, n, center):
			continue
		var found: TutorialStartBoard = TutorialStartBoard.new()
		found.colors = grid
		found.size = n
		found.seed_used = seed_value
		found.rng = rng
		return found
	return null


## 판에 깐다 (플레이어 가운데).
func apply_to(board: Board) -> void:
	for y: int in size:
		for x: int in size:
			var value: int = colors[y * size + x]
			if value != PLAYER:
				board.set_color_block(Vector2i(x, y), value)
	var mid: int = (size - 1) / 2
	board.set_player(Vector2i(mid, mid))


## 행마다 글자로 (P = 플레이어, 숫자 = 색) — 테스트·디버그용.
func rows() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for y: int in size:
		var line: String = ""
		for x: int in size:
			var value: int = colors[y * size + x]
			line += "P" if value == PLAYER else str(value)
		out.append(line)
	return out


static func _is_match(grid: PackedInt32Array, n: int, p: int) -> bool:
	var r: int = p / n
	var c: int = p % n
	var color: int = -2
	for dir: Vector2i in DIRS:
		var rr: int = r + dir.y
		var cc: int = c + dir.x
		if rr < 0 or cc < 0 or rr >= n or cc >= n:
			return false
		var value: int = grid[rr * n + cc]
		if color == -2:
			color = value
		elif value != color:
			return false
	return true


## p에서 dir 쪽으로 한 칸 (블록이 p로 오고 플레이어가 그 칸으로). 판 밖이면 빈 배열.
static func _moved(grid: PackedInt32Array, n: int, p: int, dir: Vector2i) -> Array:
	var r: int = p / n + dir.y
	var c: int = p % n + dir.x
	if r < 0 or c < 0 or r >= n or c >= n:
		return []
	var q: int = r * n + c
	var next: PackedInt32Array = grid.duplicate()
	next[p] = next[q]
	next[q] = PLAYER
	return [next, q]


static func _one_move_match(grid: PackedInt32Array, n: int, p: int) -> bool:
	for dir: Vector2i in DIRS:
		var moved: Array = TutorialStartBoard._moved(grid, n, p, dir)
		if not moved.is_empty() and TutorialStartBoard._is_match(moved[0], n, moved[1]):
			return true
	return false


static func _every_move_leaves_one(grid: PackedInt32Array, n: int, p: int) -> bool:
	for dir: Vector2i in DIRS:
		var moved: Array = TutorialStartBoard._moved(grid, n, p, dir)
		if moved.is_empty() or not TutorialStartBoard._one_move_match(moved[0], n, moved[1]):
			return false
	return true
