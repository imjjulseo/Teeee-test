class_name PlaytestSummary
extends RefCounted
## 플레이 기록 요약 (기획서 10.1장): playtest_log.csv 내용을 읽어 결과까지 간 판만 묶어 본다.
## - 전체·캐릭터별: 판 수, 점수 평균·중앙값·상위 10%, 분당 득점, 판 길이, 최대 남은 시간, 능력 발동, 금화,
##   시간대별 득점, **매치 1회당 이동 수 분포**(1~4 / 5~7 / 8수 이상, 핵심 위험 지표)와 평균
## - 계정 레벨 구간별 점수 (초심자·숙련자 격차)
## 열은 헤더 이름으로 찾는다 — 열이 없는 옛 기록은 그 값을 비운다. 표시는 lines() (tools/playtest_summary.gd가 출력).

## 계정 레벨 구간 시작값 (Lv1~20 초보자 · Lv21~, 팀 결정 11/04).
const LEVEL_BANDS: Array[int] = [1, 21]

## 한 묶음의 요약.
class Group:
	var name: String = ""
	var games: int = 0
	var score_mean: float = 0.0
	var score_median: float = 0.0
	var score_top10: float = 0.0
	var points_per_minute: float = 0.0
	var seconds: float = 0.0
	var max_remaining: float = 0.0
	var ability_triggers: float = 0.0
	var coins: float = 0.0
	var score_by_time: PackedFloat32Array = PackedFloat32Array([0, 0, 0])
	## 매치 1회당 이동 수 구간 비율(%) [1~4, 5~7, 8~]과 잰 매치 수, 평균 이동 수. 잰 매치가 없으면 match_count 0.
	var match_share: PackedFloat32Array = PackedFloat32Array([0, 0, 0])
	var match_count: int = 0
	var match_moves_avg: float = 0.0

var overall: Group
var by_character: Array[Group] = []
var by_level: Array[Group] = []
## 버린 판 (결과까지 가지 않은 판) 수.
var abandoned: int = 0


## CSV 글 전체로 요약을 만든다.
static func from_csv(text: String) -> PlaytestSummary:
	var summary: PlaytestSummary = PlaytestSummary.new()
	var rows: Array[Dictionary] = PlaytestSummary.parse(text)
	var results: Array[Dictionary] = []
	for row: Dictionary in rows:
		if row.get("end", "") == PlaytestLog.END_RESULT:
			results.append(row)
		else:
			summary.abandoned += 1
	summary.overall = PlaytestSummary._group("전체", results)
	var characters: Dictionary[String, Array] = {}
	for row: Dictionary in results:
		var id: String = row.get("character", "none")
		if not characters.has(id):
			characters[id] = []
		characters[id].append(row)
	var ids: Array = characters.keys()
	ids.sort()
	for id: String in ids:
		var list: Array[Dictionary] = []
		list.assign(characters[id])
		summary.by_character.append(PlaytestSummary._group(id, list))
	for band: int in LEVEL_BANDS.size():
		var low: int = LEVEL_BANDS[band]
		var high: int = LEVEL_BANDS[band + 1] - 1 if band + 1 < LEVEL_BANDS.size() else 1 << 30
		var list: Array[Dictionary] = []
		for row: Dictionary in results:
			var level: int = int(row.get("account_level", "0"))
			if level >= low and level <= high:
				list.append(row)
		var label: String = "Lv%d~%d" % [low, high] if high < 1 << 30 else "Lv%d~" % low
		summary.by_level.append(PlaytestSummary._group(label, list))
	return summary


## 헤더가 있는 CSV → 행마다 {열 이름: 값}. 빈 줄은 건너뛴다.
static func parse(text: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var lines: PackedStringArray = text.replace("\r", "").split("\n", false)
	if lines.is_empty():
		return rows
	var header: PackedStringArray = lines[0].split(",")
	for i: int in range(1, lines.size()):
		var values: PackedStringArray = lines[i].split(",")
		var row: Dictionary = {}
		for k: int in mini(header.size(), values.size()):
			row[header[k]] = values[k]
		rows.append(row)
	return rows


## 읽기 좋은 표 (한 줄씩).
func lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	out.append("결과까지 간 판 %d · 나간 판 %d" % [overall.games, abandoned])
	out.append("")
	out.append("매치당 이동 수 (핵심 위험 지표: 1~4수에만 몰리면 순발력 게임, 8수 이상 꼬리가 살아 있으면 계획 게임)")
	for group: Group in [overall] + by_character:
		out.append("  " + PlaytestSummary._match_line(group))
	out.append("")
	out.append("점수")
	for group: Group in [overall] + by_character:
		out.append("  " + PlaytestSummary._score_line(group))
	out.append("")
	out.append("계정 레벨별 (초심자·숙련자 격차)")
	for group: Group in by_level:
		out.append("  " + PlaytestSummary._score_line(group))
	return out


static func _group(name: String, rows: Array[Dictionary]) -> Group:
	var group: Group = Group.new()
	group.name = name
	group.games = rows.size()
	if rows.is_empty():
		return group
	var scores: Array[float] = []
	var minutes: float = 0.0
	var buckets: PackedFloat32Array = PackedFloat32Array([0, 0, 0])
	var move_total: float = 0.0
	for row: Dictionary in rows:
		var score: float = float(row.get("score", "0"))
		var seconds: float = float(row.get("play_seconds", "0"))
		scores.append(score)
		minutes += seconds / 60.0
		group.seconds += seconds
		group.max_remaining += float(row.get("max_remaining", "0"))
		group.ability_triggers += float(row.get("ability_triggers", "0"))
		group.coins += float(row.get("coins", "0"))
		for k: int in 3:
			group.score_by_time[k] += float(row.get(["score_0_30", "score_30_60", "score_60_plus"][k], "0"))
		var counts: Array[float] = [float(row.get("match_moves_1_4", "0")), float(row.get("match_moves_5_7", "0")), float(row.get("match_moves_8_plus", "0"))]
		for k: int in 3:
			buckets[k] += counts[k]
		move_total += float(row.get("match_moves_avg", "0")) * (counts[0] + counts[1] + counts[2])
	var n: float = rows.size()
	scores.sort()
	var total: float = 0.0
	for score: float in scores:
		total += score
	group.score_mean = total / n
	group.score_median = PlaytestSummary._percentile(scores, 0.5)
	group.score_top10 = PlaytestSummary._percentile(scores, 0.9)
	group.points_per_minute = total / minutes if minutes > 0.0 else 0.0
	group.seconds /= n
	group.max_remaining /= n
	group.ability_triggers /= n
	group.coins /= n
	for k: int in 3:
		group.score_by_time[k] /= n
	group.match_count = int(buckets[0] + buckets[1] + buckets[2])
	if group.match_count > 0:
		for k: int in 3:
			group.match_share[k] = 100.0 * buckets[k] / group.match_count
		group.match_moves_avg = move_total / group.match_count
	return group


## 정렬된 값의 p 분위 (가까운 순위, 0~1).
static func _percentile(sorted: Array[float], p: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)]


static func _match_line(group: Group) -> String:
	if group.match_count == 0:
		return "%s: 기록 없음" % group.name
	return "%s: 1~4수 %.0f%% · 5~7수 %.0f%% · 8수+ %.0f%% (매치 %d, 평균 %.1f수)" % [group.name,
		group.match_share[0], group.match_share[1], group.match_share[2], group.match_count, group.match_moves_avg]


static func _score_line(group: Group) -> String:
	if group.games == 0:
		return "%s: 판 없음" % group.name
	return "%s: %d판 · 평균 %.0f · 중앙값 %.0f · 상위10%% %.0f · 분당 %.0f · %.0f초 · 최대 남은 %.1f초 · 발동 %.1f · 금화 %.1f · 시간대 %.0f/%.0f/%.0f" % [
		group.name, group.games, group.score_mean, group.score_median, group.score_top10, group.points_per_minute,
		group.seconds, group.max_remaining, group.ability_triggers, group.coins,
		group.score_by_time[0], group.score_by_time[1], group.score_by_time[2]]
