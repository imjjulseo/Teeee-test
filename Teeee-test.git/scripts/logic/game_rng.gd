class_name GameRng
extends RefCounted
## 게임 전체에서 쓰는 seed 기반 RNG.
## - create(): 판의 기준 seed를 정하고 로그로 남긴다 (0이면 랜덤).
## - derive(): 기준 seed 하나에서 기능별 RNG를 따로 만든다. 한 기능이 난수를 더 뽑거나 덜 뽑아도
##   다른 기능의 결과가 바뀌지 않아, 같은 seed로 비교하는 밸런스 테스트가 버전이 바뀌어도 유지된다.

## 기능별 RNG. 값은 기준 seed에 더하는 고정 오프셋 번호다 (순서·값을 바꾸면 같은 seed의 결과가 바뀐다).
## 새 기능은 끝에 새 번호로 추가한다.
enum Stream {
	BOARD = 1,  ## 시작 판 배치, 시작 매치 형태 제거
	REFILL = 2,  ## 씨앗 색과 심는 순서
	RECIPES = 3,  ## 족보 색 (시작, 완성 후 교체, 피버)
	ABILITY = 4,  ## 캐릭터 능력 (연금술사 변성 등)
	COINS = 5,  ## 금화가 붙는지 (4.4장)
	TUTORIAL = 6,  ## 튜토리얼 퍼즐·카드 색 (8.8장)
}

## 스트림 간 seed 간격 (큰 소수).
const STREAM_STRIDE: int = 1_000_003


## initial_seed가 0이면 랜덤 seed, 아니면 고정 seed로 기준 RNG를 만든다. 실제 seed를 로그로 남긴다.
static func create(initial_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if initial_seed == 0:
		rng.randomize()
		rng.seed = rng.seed  # state를 seed 기준으로 초기화해 로그의 seed로 재현 가능하게 한다.
	else:
		rng.seed = initial_seed
	print("[GameRng] seed = %d" % rng.seed)
	return rng


## 기준 seed에서 기능별 RNG를 만든다. 같은 (base_seed, stream)이면 항상 같은 난수열.
static func derive(base_seed: int, stream: Stream) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = base_seed + int(stream) * STREAM_STRIDE
	return rng


## Fisher-Yates 균등 셔플 (제자리).
static func shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp


## [0, 1) 균등 난수가 chance보다 작으면 true (chance 0이면 항상 false, 1이면 항상 true).
static func roll(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() < chance
