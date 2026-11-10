class_name BoardStage
extends Resource
## 보드 단계 하나 (기획서 8.2장): 계정 레벨에 따라 바뀌는 판 규칙. 판을 만들 때 GameConfig 사본에 덮어쓴다.

@export var color_count: int = 4
@export var recipe_lengths: PackedInt32Array = PackedInt32Array([2, 3, 4])
## 리필 총시간: 판 시작 → refill_ramp_time초 뒤 (GameConfig의 같은 이름 값을 대신한다).
@export var refill_total_start: float = 8.0
@export var refill_total_end: float = 2.0
@export var game_duration: float = 60.0
## 결과 화면 "다음 단계" 안내 문구 (예: "4색 · 4칸 족보").
@export var description: String = ""


## base 설정의 사본에 이 단계의 규칙을 덮어쓴 설정.
func apply_to(base: GameConfig) -> GameConfig:
	var config: GameConfig = base.duplicate() as GameConfig
	config.color_count = color_count
	config.recipe_lengths = recipe_lengths.duplicate()
	config.refill_total_start = refill_total_start
	config.refill_total_end = refill_total_end
	config.game_duration = game_duration
	return config
