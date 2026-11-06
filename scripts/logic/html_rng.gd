class_name HtmlRng
extends RefCounted
## HTML 프로토타입의 난수(mulberry32)를 그대로 옮긴 것 (튜토리얼 고정 시드, HTML tutStartBoard).
## 같은 seed면 HTML과 같은 수열이 나온다: next_float = RNG(), rnd(k) = (RNG()*k)|0, shuffle = HTML shuffle(Fisher-Yates, 뒤에서부터).
## JS의 32비트 정수 연산(|0, >>>, Math.imul)을 64비트 int로 흉내 낸다.

const MASK32: int = 0xFFFFFFFF

var _state: int = 0


func _init(seed_value: int) -> void:
	_state = HtmlRng._i32(seed_value)


## [0, 1) 실수 (HTML mulberry 한 번).
func next_float() -> float:
	_state = HtmlRng._i32(_state + 0x6D2B79F5)
	var a: int = _state
	var t: int = HtmlRng._imul(a ^ HtmlRng._ushr(a, 15), 1 | a)
	t = HtmlRng._i32(HtmlRng._i32(t + HtmlRng._imul(t ^ HtmlRng._ushr(t, 7), 61 | t)) ^ t)
	return float(HtmlRng._u32(t ^ HtmlRng._ushr(t, 14))) / 4294967296.0


## 0 이상 k 미만 정수 (HTML rnd).
func rnd(k: int) -> int:
	return int(floor(next_float() * k))


## 배열을 제자리에서 섞는다 (HTML shuffle과 같은 순서로 난수를 쓴다).
func shuffle(values: Array) -> Array:
	for i: int in range(values.size() - 1, 0, -1):
		var j: int = rnd(i + 1)
		var tmp: Variant = values[i]
		values[i] = values[j]
		values[j] = tmp
	return values


static func _u32(x: int) -> int:
	return x & MASK32


static func _i32(x: int) -> int:
	return ((x & MASK32) ^ 0x80000000) - 0x80000000


## JS >>> (부호 없는 오른쪽 시프트).
static func _ushr(x: int, bits: int) -> int:
	return HtmlRng._u32(x) >> bits


## JS Math.imul (32비트 곱의 아래 32비트, 부호 있음). 64비트 넘침을 피하려고 16비트씩 나눠 곱한다.
static func _imul(a: int, b: int) -> int:
	var ua: int = HtmlRng._u32(a)
	var ub: int = HtmlRng._u32(b)
	var low: int = (ua & 0xFFFF) * ub
	var high: int = (((ua >> 16) * ub) & 0xFFFF) << 16
	return HtmlRng._i32(low + high)
