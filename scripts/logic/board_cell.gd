class_name BoardCell
extends RefCounted
## 보드 한 칸의 상태 (기획서 2.2). Board가 소유하고, 교환할 때는 칸 객체째로 자리를 바꾼다
## → 씨앗 진행·금화처럼 칸에 붙은 상태가 블록과 함께 움직인다. 순수 데이터 + 상태 전환 메서드.

## 씨앗의 단계 (4.3장): 대기(작은 점) → 자람(중앙에서 커짐) → 다 자란 블록.
enum SeedStage {
	WAITING,
	GROWING,
}

## 금화가 없는 칸의 coin_remaining 값.
const NO_COIN: float = -1.0

var type: Board.CellType = Board.CellType.EMPTY
## COLOR_BLOCK이면 블록 색, SEED면 자랄 색(다음 색), 그 밖엔 Board.NO_COLOR.
var color: int = Board.NO_COLOR
var seed_stage: SeedStage = SeedStage.WAITING
## 현재 단계가 끝날 때까지 남은 시간(리필 시계 초).
var seed_remaining: float = 0.0
## 현재 단계의 전체 시간 (진행도 계산용).
var seed_stage_duration: float = 0.0
## 대기가 끝난 뒤 자라는 데 걸릴 시간 (심을 때 정한다).
var seed_grow_duration: float = 0.0
## 금화가 사라질 때까지 남은 시간(리필 시계 초). 금화가 없으면 NO_COIN.
var coin_remaining: float = NO_COIN


func is_block() -> bool:
	return type == Board.CellType.COLOR_BLOCK


func is_seed() -> bool:
	return type == Board.CellType.SEED


func has_coin() -> bool:
	return coin_remaining >= 0.0


func make_player() -> void:
	_reset(Board.CellType.PLAYER, Board.NO_COLOR)


func make_block(p_color: int) -> void:
	_reset(Board.CellType.COLOR_BLOCK, p_color)


func make_empty() -> void:
	_reset(Board.CellType.EMPTY, Board.NO_COLOR)


## 씨앗을 심는다: wait초 대기 후 grow초 동안 자라 next_color 블록이 된다.
func make_seed(next_color: int, wait: float, grow: float) -> void:
	_reset(Board.CellType.SEED, next_color)
	seed_stage = SeedStage.WAITING
	seed_stage_duration = maxf(wait, 0.0)
	seed_remaining = seed_stage_duration
	seed_grow_duration = maxf(grow, 0.0)


## 대기를 끝내고 자라기 시작한다. carry는 이미 지나간 시간(초) — 프레임 경계와 무관하게 끝나는 시각을 맞춘다.
func start_growing(carry: float = 0.0) -> void:
	seed_stage = SeedStage.GROWING
	seed_stage_duration = seed_grow_duration
	seed_remaining = seed_grow_duration - carry


## 씨앗을 처음(대기)부터 다시 seconds초 기다리게 한다 (마탄 저주 "재생 30초"). 자라는 시간은 그대로.
func delay_growth(seconds: float) -> void:
	if not is_seed():
		return
	seed_stage = SeedStage.WAITING
	seed_stage_duration = seconds
	seed_remaining = seconds


## 씨앗이 다 자라 블록이 된다 (색은 심을 때 정한 다음 색).
func mature() -> void:
	make_block(color)


## 씨앗의 자람 진행도 0~1. 대기 중이거나 씨앗이 아니면 0.
func grow_progress() -> float:
	if not is_seed() or seed_stage != SeedStage.GROWING or seed_stage_duration <= 0.0:
		return 0.0
	return clampf(1.0 - seed_remaining / seed_stage_duration, 0.0, 1.0)


func attach_coin(life: float) -> void:
	coin_remaining = life


func remove_coin() -> void:
	coin_remaining = NO_COIN


func _reset(p_type: Board.CellType, p_color: int) -> void:
	type = p_type
	color = p_color
	seed_stage = SeedStage.WAITING
	seed_remaining = 0.0
	seed_stage_duration = 0.0
	seed_grow_duration = 0.0
	coin_remaining = NO_COIN
