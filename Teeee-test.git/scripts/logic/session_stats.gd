class_name SessionStats
extends RefCounted
## 한 판의 플레이 통계 (기획서 10.1 지표 + 밸런스 판단용). GameSession이 직접 센다. 순수 로직.

## 점수 시간대 경계(실제 플레이 시간, 초). 0~30 / 30~60 / 60~.
## 매치 1회당 이동 수 구간 경계 (10.1장 핵심 위험 지표): 1~4수 / 5~7수 / 8수 이상. 0수(이동 없이 매치)는 첫 구간.
const MATCH_MOVE_EDGES: Array[int] = [5, 8]
const BUCKET_EDGES: Array[float] = [30.0, 60.0]

## 실제 플레이 시간(초). 첫 이동 전·일시정지 제외, 시계공 정지 중에도 흐른다.
var play_time: float = 0.0
## 승인된 이동 수 (교환·빈칸 이동).
var moves: int = 0
## 벽·잘못된 방향으로 막힌 입력 수.
var blocked_moves: int = 0
var matches: int = 0
## 깨진 블록 수 (매치한 칸 + 능력으로 터진 칸, 업적 "블록 부수기").
var blocks_cleared: int = 0
## 완성한 족보 수 (동시 완성은 각각 센다).
var recipes_completed: int = 0
var ability_triggers: int = 0
## 판 중 가장 컸던 남은 시간 (시간 보너스·정지로 늘어나는지 확인용).
var max_remaining: float = 0.0
## 시간대별 얻은 점수: [0~30초, 30~60초, 60초~].
var score_by_time: PackedInt32Array = PackedInt32Array([0, 0, 0])
## 매치 1회당 이동 수 구간별 매치 수: [1~4, 5~7, 8~] (플레이어 자리의 매치만, 능력이 판 밖에서 깬 것 제외).
var match_moves: PackedInt32Array = PackedInt32Array([0, 0, 0])
## 그 매치들까지 쓴 이동 수 합 (평균 = 합 ÷ 매치 수).
var match_moves_total: int = 0
## 족보 완성으로 얻은 점수 / 족보 밖 점수(피버 정산·박치기·사진 보너스·저주 등, 음수 포함).
var recipe_points: int = 0
var bonus_points: int = 0
## 부활한 횟수.
var revives: int = 0
## 마지막 매치 뒤 이동 수.
var _moves_since_match: int = 0


## gained 점수를 지금 플레이 시간의 시간대에 더한다.
func add_score(gained: int) -> void:
	var bucket: int = 0
	while bucket < BUCKET_EDGES.size() and play_time >= BUCKET_EDGES[bucket]:
		bucket += 1
	score_by_time[bucket] += gained


## 승인된 이동 한 번.
func count_move() -> void:
	moves += 1
	_moves_since_match += 1


## 플레이어 자리의 매치 한 번: 지난 매치 뒤 이동 수를 구간에 넣고 다시 센다.
func record_match_moves() -> void:
	var bucket: int = 0
	while bucket < MATCH_MOVE_EDGES.size() and _moves_since_match >= MATCH_MOVE_EDGES[bucket]:
		bucket += 1
	match_moves[bucket] += 1
	match_moves_total += _moves_since_match
	_moves_since_match = 0


## 이동 수를 잰 매치 수.
func measured_matches() -> int:
	return match_moves[0] + match_moves[1] + match_moves[2]


## 매치 1회당 평균 이동 수 (잰 매치가 없으면 0).
func average_match_moves() -> float:
	var count: int = measured_matches()
	return float(match_moves_total) / count if count > 0 else 0.0