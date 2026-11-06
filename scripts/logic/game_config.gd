class_name GameConfig
extends Resource
## 게임 규칙 밸런스 값 (기획서 10장). 로직은 이 리소스를 주입받아 사용한다.

@export_group("Board")
## 보드 한 변의 칸 수. 홀수이고 3 이상이어야 한다 (B19, E2).
@export var board_size: int = 9
## 색 종류 수. 블록 수가 나누어떨어지지 않으면 앞 색부터 1개씩 더 많다 (2.1장).
@export var color_count: int = 4
## 시작 판에서 플레이어 주변 매치 형태를 없애기 위해 블록 색을 맞바꾸는 최대 횟수 (E3).
@export var initial_match_fix_attempts: int = 50

@export_group("Time")
## 제한시간(초). 첫 이동에 시작한다 (E5).
@export var game_duration: float = 60.0
## n번째 매치에 얻는 시간 = max(clear_time_min, clear_time_start − clear_time_decay × (n − 1)) (5장).
@export var clear_time_start: float = 2.5
@export var clear_time_decay: float = 0.08
@export var clear_time_min: float = 0.8
## 한 프레임에 게임에 반영하는 최대 시간(초). 로딩·GC 등으로 프레임이 길게 멈춰도 그 이상은 흘려보내지 않는다 (E19).
@export var max_frame_delta: float = 0.1
## 남은 시간이 이 값 미만이면 HUD 시간을 경고 표시한다 (5장).
@export var warning_time_threshold: float = 5.0
## 부활하면 남은 시간이 이 값이 된다 (E10).
@export var revive_time: float = 10.0

@export_group("Refill")
## 씨앗이 블록이 되기까지 총시간(초): 판 경과 0초에 start, refill_ramp_time초에 end, 그 사이 선형 (4.3장, E6).
@export var refill_total_start: float = 8.0
@export var refill_total_end: float = 2.0
@export var refill_ramp_time: float = 90.0
## 총시간을 대기 : 자람 = refill_wait_weight : refill_grow_weight로 나눈다.
@export var refill_wait_weight: float = 3.0
@export var refill_grow_weight: float = 5.0

@export_group("Recipe")
## 족보 슬롯별 길이 (5.1장). 슬롯 수 = 배열 길이.
@export var recipe_lengths: PackedInt32Array = PackedInt32Array([2, 3, 4])
## 족보 점수 = recipe_base_score × L(L−1)/2 × (1 + recipe_repeat_bonus × 반복 수) (E7).
@export var recipe_base_score: int = 100
@export var recipe_repeat_bonus: float = 0.25
## 족보의 첫 색은 판에 이 개수 이상 있어야 한다 (씨앗은 자랄 색으로 센다).
@export var recipe_first_color_min: int = 4
## 족보 색을 다시 뽑는 최대 횟수 (첫 색 조건·중복 금지를 못 맞추면 마지막 결과를 쓴다).
@export var recipe_generation_attempts: int = 40

@export_group("Coins")
## 블록이 다 자랄 때 금화가 붙을 확률 0~1 (4.4장, E9).
@export_range(0.0, 1.0) var coin_chance: float = 0.1
## 금화 수명(리필 시계 초).
@export var coin_life: float = 15.0
## 판 위 금화 최대 수.
@export var coin_max: int = 3
## 금화 1개 기본 값. 연속으로 주우면 ×1, ×2, ×3 …
@export var coin_value: int = 10
## 직전 금화로부터 이 시간(리필 시계 초) 안에 주우면 연속.
@export var coin_chain_gap: float = 4.0

@export_group("Animation")
## 이동 애니메이션 시간(초). 순수 시각 효과 — 판정은 이동 즉시 (E4).
@export var move_animation_time: float = 0.09
## 매치 제거 연출 시간(초). 순수 시각 효과.
@export var clear_animation_time: float = 0.18

@export_group("Input")
## 손가락이 이 거리(px, 기준 해상도)를 넘게 움직이는 순간 1칸 이동한다. 한 번 닿을 때 1칸 (3.2장, E8).
@export var swipe_threshold: float = 22.0
## 패드 버튼을 누르고 있으면 이 시간(초) 뒤부터 반복 이동한다.
@export var pad_repeat_delay: float = 0.17
## 패드 반복 이동 간격(초).
@export var pad_repeat_interval: float = 0.06
## 꾹 누르기: 화면을 움직이지 않고 이만큼(초) 누르고 있으면 (방화광 소화). 손가락이 이 거리(px)보다 움직이면 취소.
@export var long_press_time: float = 0.5
@export var long_press_slop: float = 12.0

@export_group("Debug")
## 0이면 매 판 랜덤 seed, 0이 아니면 고정 seed.
@export var initial_seed: int = 0
## 개발 빌드에서 판마다 user://playtest_log.csv에 플레이 기록을 남긴다 (배포 빌드에서는 항상 끔).
@export var playtest_logging: bool = true


## 설정 오류 목록을 반환한다. 비어 있으면 유효하다.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if board_size < 3:
		errors.append("board_size must be >= 3 (got %d)" % board_size)
	if board_size % 2 == 0:
		errors.append("board_size must be odd (got %d)" % board_size)
	if color_count < 1:
		errors.append("color_count must be >= 1 (got %d)" % color_count)
	if initial_match_fix_attempts < 0:
		errors.append("initial_match_fix_attempts must be >= 0")
	if game_duration <= 0.0:
		errors.append("game_duration must be > 0")
	if clear_time_start < 0.0 or clear_time_decay < 0.0 or clear_time_min < 0.0:
		errors.append("clear times must be >= 0")
	if max_frame_delta <= 0.0:
		errors.append("max_frame_delta must be > 0")
	if revive_time <= 0.0:
		errors.append("revive_time must be > 0")
	if refill_total_start <= 0.0 or refill_total_end <= 0.0:
		errors.append("refill totals must be > 0")
	if refill_ramp_time < 0.0:
		errors.append("refill_ramp_time must be >= 0")
	if refill_wait_weight < 0.0 or refill_grow_weight < 0.0 or refill_wait_weight + refill_grow_weight <= 0.0:
		errors.append("refill weights must be >= 0 with a positive sum")
	if recipe_lengths.is_empty():
		errors.append("recipe_lengths must not be empty")
	for length: int in recipe_lengths:
		if length < 1:
			errors.append("recipe_lengths entries must be >= 1")
			break
	if recipe_base_score < 0 or recipe_repeat_bonus < 0.0:
		errors.append("recipe scores must be >= 0")
	if recipe_generation_attempts < 1:
		errors.append("recipe_generation_attempts must be >= 1")
	if coin_life <= 0.0 or coin_max < 0 or coin_value < 0 or coin_chain_gap < 0.0:
		errors.append("coin settings out of range")
	if move_animation_time < 0.0 or clear_animation_time < 0.0:
		errors.append("animation times must be >= 0")
	if swipe_threshold <= 0.0:
		errors.append("swipe_threshold must be > 0")
	if pad_repeat_delay < 0.0 or pad_repeat_interval <= 0.0:
		errors.append("pad repeat times out of range")
	return errors


## 설정이 유효하면 그대로, 아니면 오류를 알리고(push_error) 기본값 설정을 반환한다.
## assert와 달리 배포 빌드에서도 동작한다. 게임은 멈추지 않고 기본 규칙으로 진행된다.
static func ensure_valid(config: GameConfig) -> GameConfig:
	if config == null:
		push_error("GameConfig: config is null, using defaults")
		return GameConfig.new()
	var errors: PackedStringArray = config.validate()
	if errors.is_empty():
		return config
	push_error("GameConfig: invalid settings, using defaults instead: %s" % ", ".join(errors))
	return GameConfig.new()


## 실제 경과 시간을 한 프레임 최대 반영 시간으로 자른다 (음수는 0).
func clamp_frame_delta(raw_delta: float) -> float:
	return clampf(raw_delta, 0.0, max_frame_delta)


## n번째(1부터) 매치에 얻는 시간 (5장).
func clear_time_for(match_number: int) -> float:
	return maxf(clear_time_min, clear_time_start - clear_time_decay * (match_number - 1))


## 판 경과 시간 elapsed에 심는 씨앗의 리필 총시간 (4.3장).
func refill_total_at(elapsed: float) -> float:
	var ramp: float = 1.0 if refill_ramp_time <= 0.0 else minf(1.0, elapsed / refill_ramp_time)
	return refill_total_start - (refill_total_start - refill_total_end) * ramp


## 리필 총시간 중 대기 비율 0~1.
func refill_wait_share() -> float:
	return refill_wait_weight / (refill_wait_weight + refill_grow_weight)
