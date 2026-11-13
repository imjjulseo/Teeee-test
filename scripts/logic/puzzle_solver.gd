class_name PuzzleSolver
extends RefCounted
<<<<<<< HEAD
## 블록 모으기 최소 수 풀이기 (HTML 팀원 코드, 너비 우선 탐색). 나(빈칸)와 모을 색 블록 4개의 위치만 본다:
=======
## 블럭 모으기 최소 수 풀이기 (HTML 팀원 코드, 너비 우선 탐색). 나(빈칸)와 모을 색 블록 4개의 위치만 본다:
>>>>>>> Choi
## 내가 움직이면 들어간 칸의 블록이 내가 있던 칸으로 온다. 내가 들어간 칸의 상·하·좌·우가 모을 블록 4개면 풀림
## (그 칸이 판 가장자리면 안 됨). 다른 블록은 구별하지 않는다.
## 탐색은 region 안에서만 한다 (GDScript 속도 — 퍼즐 창 둘레 한 칸이면 충분하다).

## 풀이 결과: 최소 수, 방향들, 풀리는 순간 내가 서는 칸(모양의 가운데).
class Solution:
	var depth: int = 0
	var path: Array[Vector2i] = []
	var center: Vector2i = Vector2i.ZERO


## player에서 targets(4칸)를 모으는 가장 짧은 길. max_depth수 안에 없거나 노드가 max_nodes를 넘으면 null.
## prefer가 region 안이면 같은 깊이의 풀이 중 그 칸을 가운데로 하는 것을 고른다.
static func solve(region: Rect2i, board_size: int, player: Vector2i, targets: Array[Vector2i], max_depth: int,
		max_nodes: int, prefer: Vector2i = Vector2i(-1, -1)) -> Solution:
	if targets.size() != 4 or not region.has_point(player):
		return null
	var w: int = region.size.x
	var n: int = w * region.size.y
	var p0: int = _index(player, region)
	var t: PackedInt32Array = PackedInt32Array()
	for cell: Vector2i in targets:
		if not region.has_point(cell):
			return null
		t.append(_index(cell, region))
	t.sort()
	var dirs: Array[Vector2i] = Board.DIRECTIONS
	var ps: PackedInt32Array = PackedInt32Array([p0])
	var ts: PackedInt32Array = t.duplicate()  # 상태마다 4개씩
	var parent: PackedInt32Array = PackedInt32Array([-1])
	var via: PackedInt32Array = PackedInt32Array([-1])
	var seen: Dictionary[int, bool] = {_key(p0, t, n): true}
	var front: PackedInt32Array = PackedInt32Array([0])
	for depth: int in range(1, max_depth + 1):
		var next: PackedInt32Array = PackedInt32Array()
		var hit_state: int = -1
		var hit_dir: int = -1
		var hit_cell: int = -1
		for state: int in front:
			var p: int = ps[state]
			var px: int = p % w
			var py: int = p / w
			for k: int in 4:
				var qx: int = px + dirs[k].x
				var qy: int = py + dirs[k].y
				if qx < 0 or qy < 0 or qx >= w or qy >= region.size.y:
					continue
				var q: int = qy * w + qx
				var moved: PackedInt32Array = ts.slice(state * 4, state * 4 + 4)
				var j: int = moved.find(q)
				if j >= 0:
					moved[j] = p
				if _is_match_at(q, moved, w, region, board_size):
					if hit_state < 0 or (prefer != Vector2i(-1, -1) and _position(q, region) == prefer and _position(hit_cell, region) != prefer):
						hit_state = state
						hit_dir = k
						hit_cell = q
					continue
				moved.sort()
				var key: int = _key(q, moved, n)
				if seen.has(key):
					continue
				seen[key] = true
				ps.append(q)
				ts.append_array(moved)
				parent.append(state)
				via.append(k)
				next.append(ps.size() - 1)
		if hit_state >= 0:
			var solution: Solution = Solution.new()
			solution.depth = depth
			solution.center = _position(hit_cell, region)
			var path: Array[Vector2i] = [dirs[hit_dir]]
			var x: int = hit_state
			while parent[x] >= 0:
				path.append(dirs[via[x]])
				x = parent[x]
			path.reverse()
			solution.path = path
			return solution
		if ps.size() > max_nodes or next.is_empty():
			return null
		front = next
	return null


static func _is_match_at(q: int, cells: PackedInt32Array, w: int, region: Rect2i, board_size: int) -> bool:
	var center: Vector2i = _position(q, region)
	if center.x < 1 or center.y < 1 or center.x > board_size - 2 or center.y > board_size - 2:
		return false
	for dir: Vector2i in Board.DIRECTIONS:
		var cell: Vector2i = center + dir
		if not region.has_point(cell) or not cells.has(_index(cell, region)):
			return false
	return true


static func _key(p: int, sorted_targets: PackedInt32Array, n: int) -> int:
	return p + n * (sorted_targets[0] + n * (sorted_targets[1] + n * (sorted_targets[2] + n * sorted_targets[3])))


static func _index(cell: Vector2i, region: Rect2i) -> int:
	return (cell.y - region.position.y) * region.size.x + (cell.x - region.position.x)


static func _position(index: int, region: Rect2i) -> Vector2i:
	return region.position + Vector2i(index % region.size.x, index / region.size.x)
