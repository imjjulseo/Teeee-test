class_name CoinSystem
extends TimedSystem
## 금화 (기획서 4.4장, E9). 리필 시계를 따른다.
## - 블록이 다 자라는 순간 coin_chance 확률로 금화가 붙는다 (판 위 coin_max개 미만일 때만). 금화는 블록과 함께 움직인다.
## - coin_life초가 지나면 사라진다.
## - 금화 블록이 매치로 깨지면 줍는다. 직전 금화로부터 coin_chain_gap초 안이면 연속: coin_value × 1, × 2, × 3 …

## 금화가 붙거나 사라진 칸.
signal coins_changed(cells: Array[Vector2i])
## 매치로 금화를 주웠다. amount는 이번에 얻은 코인, chain은 마지막 금화의 연속 횟수.
signal coins_collected(amount: int, chain: int)

## 금화가 새로 붙는지. 튜토리얼 판 등에서 끈다.
var enabled: bool = true
## 이번 판에 주운 코인 합.
var collected: int = 0
## 지금 연속 횟수 (마지막으로 주운 금화 기준).
var chain: int = 0

var _board: Board
var _config: GameConfig
var _rng: RandomNumberGenerator
## 리필 시계 기준 현재 시각과 마지막으로 금화를 주운 시각 (연속 판정용).
var _now: float = 0.0
var _last_pickup: float = -INF


func _init(board: Board, config: GameConfig, rng: RandomNumberGenerator) -> void:
	_board = board
	_config = config
	_rng = rng


func clock() -> TimedSystem.Clock:
	return TimedSystem.Clock.REFILL


## 다 자란 칸마다 금화가 붙을지 정한다.
func on_cells_matured(cells: Array[Vector2i]) -> void:
	if not enabled:
		return
	var attached: Array[Vector2i] = []
	for pos: Vector2i in cells:
		if _board.coin_count() >= _config.coin_max:
			break
		if GameRng.roll(_rng, _config.coin_chance):
			_board.get_cell(pos).attach_coin(_config.coin_life)
			attached.append(pos)
	if not attached.is_empty():
		coins_changed.emit(attached)


## 금화 연속을 처음부터 (튜토리얼 금화 퍼즐, HTML coinChain = 0).
func reset_chain() -> void:
	chain = 0
	_last_pickup = -INF


## 매치로 깨지는 cells의 금화를 줍는다. 얻은 코인을 반환한다 (없으면 0).
func collect(cells: Array[Vector2i]) -> int:
	var gained: int = 0
	for pos: Vector2i in cells:
		var cell: BoardCell = _board.get_cell(pos)
		if not cell.has_coin():
			continue
		chain = chain + 1 if _now - _last_pickup <= _config.coin_chain_gap else 1
		_last_pickup = _now
		gained += _config.coin_value * chain
		cell.remove_coin()
	if gained > 0:
		collected += gained
		coins_collected.emit(gained, chain)
	return gained


func time_to_next_event() -> float:
	var soonest: float = INF
	for pos: Vector2i in _coin_positions():
		soonest = minf(soonest, maxf(_board.get_cell(pos).coin_remaining, 0.0))
	return soonest


func advance(dt: float) -> void:
	_now += dt
	var expired: Array[Vector2i] = []
	for pos: Vector2i in _coin_positions():
		var cell: BoardCell = _board.get_cell(pos)
		cell.coin_remaining -= dt
		if cell.coin_remaining <= TimedSystem.EPSILON:
			cell.remove_coin()
			expired.append(pos)
	if not expired.is_empty():
		coins_changed.emit(expired)


func _coin_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for pos: Vector2i in _board.all_positions():
		if _board.has_coin(pos):
			result.append(pos)
	return result
