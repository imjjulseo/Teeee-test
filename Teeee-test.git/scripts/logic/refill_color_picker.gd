class_name RefillColorPicker
extends RefCounted
## 씨앗 색 정하기 — 분산 규칙 (기획서 4.2장, E6). 순수 함수.
## 1) 깬 색이 아닌 색들을 무작위 순서로 하나씩 먼저 쓴다.
## 2) 칸이 남으면 깬 색을 하나 쓴다.
## 3) 그래도 남으면 판에서 가장 부족한 색(목표 개수 − 현재 개수가 가장 큰 색, 깬 색 제외, 동률은 무작위).
## 4칸 매치면 네 색이 하나씩 들어간다.


## cleared_color를 count칸 깼을 때 심을 색 목록 (count개). counts는 판의 색별 개수(씨앗 포함), target은 색별 목표 개수.
static func pick(cleared_color: int, count: int, color_count: int, counts: PackedInt32Array, target: float,
		rng: RandomNumberGenerator) -> Array[int]:
	var picked: Array[int] = []
	var others: Array[int] = []
	for color: int in color_count:
		if color != cleared_color:
			others.append(color)
	GameRng.shuffle(others, rng)
	for color: int in others:
		if picked.size() < count:
			picked.append(color)
	if picked.size() < count:
		picked.append(cleared_color)
	var projected: PackedInt32Array = counts.duplicate()
	for color: int in picked:
		projected[color] += 1
	while picked.size() < count:
		var color: int = most_lacking(projected, cleared_color, target, rng)
		projected[color] += 1
		picked.append(color)
	return picked


## 목표보다 가장 많이 모자란 색. exclude는 색이 2개 이상일 때만 제외한다. 동률이면 무작위.
static func most_lacking(counts: PackedInt32Array, exclude: int, target: float, rng: RandomNumberGenerator) -> int:
	var best: Array[int] = []
	var best_lack: float = -INF
	for color: int in counts.size():
		if color == exclude and counts.size() > 1:
			continue
		var lack: float = target - counts[color]
		if lack > best_lack:
			best_lack = lack
			best = [color]
		elif lack == best_lack:
			best.append(color)
	return best[rng.randi_range(0, best.size() - 1)]
