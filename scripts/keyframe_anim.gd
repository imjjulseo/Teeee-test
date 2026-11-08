class_name KeyframeAnim
extends RefCounted
## HTML의 CSS @keyframes · Web Animations 연출을 Godot Tween으로 그대로 옮기는 도구 (E32).
## - 키프레임 = [시점(0~1), {속성: 값}]. 모든 키프레임이 같은 속성들을 적는다 (CSS처럼 빈 칸을 이웃 값으로 채우지 않는다).
## - 곡선은 CSS cubic-bezier 네 수(Vector4). CSS @keyframes처럼 **키프레임 구간마다** 곡선을 따로 적용한다.
##   HTML이 element.animate(…, {easing})로 만든 연출(Web Animations)은 곡선이 **전체 시간**에 걸리고 구간 사이는 직선이다 → whole.
## - 시작 전 지연(delay) 동안에도 첫 키프레임 값을 보여 준다 (CSS fill: backwards). 끝나면 마지막 키프레임 값.
## - 속성 이름은 Object.set_indexed 경로 ("scale", "modulate", "position:y").
## View 전용. 로직은 이 연출을 기다리지 않는다 (E4).

## CSS 기본 곡선 이름 (cubic-bezier 제어점 x1, y1, x2, y2).
const EASE: Vector4 = Vector4(0.25, 0.1, 0.25, 1.0)
const EASE_IN: Vector4 = Vector4(0.42, 0.0, 1.0, 1.0)
const EASE_OUT: Vector4 = Vector4(0.0, 0.0, 0.58, 1.0)
const EASE_IN_OUT: Vector4 = Vector4(0.42, 0.0, 0.58, 1.0)
const LINEAR: Vector4 = Vector4(0.0, 0.0, 1.0, 1.0)


## target의 속성을 frames대로 duration초 동안 바꾼다. owner가 사라지면 Tween도 멈춘다. 만든 Tween을 돌려준다.
## frames: [[0.0, {"scale": Vector2.ONE}], [1.0, {"scale": Vector2(2, 2)}]]
static func play(owner: Node, target: Object, duration: float, frames: Array, curve: Vector4 = EASE,
		delay: float = 0.0, whole: bool = false) -> Tween:
	apply(target, frames, 0.0, curve, whole)
	var tween: Tween = owner.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void: apply(target, frames, t, curve, whole), 0.0, 1.0, maxf(duration, 0.001))
	return tween


## t(0~1)마다 step(곡선을 건 진행도 0~1)을 부르는 Tween (값을 직접 계산하는 연출: CSS filter 보간 등).
static func run(owner: Node, duration: float, step: Callable, curve: Vector4 = EASE, delay: float = 0.0) -> Tween:
	step.call(0.0)
	var tween: Tween = owner.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(func(t: float) -> void: step.call(bezier(curve, t)), 0.0, 1.0, maxf(duration, 0.001))
	return tween


## 시점 t(0~1)의 값을 target에 적용한다. whole이면 곡선을 전체 시간에 걸고 구간 사이는 직선.
static func apply(target: Object, frames: Array, t: float, curve: Vector4, whole: bool = false) -> void:
	if target == null or frames.is_empty():
		return
	var values: Dictionary = sample(frames, bezier(curve, t), LINEAR) if whole else sample(frames, t, curve)
	for path: String in values:
		target.set_indexed(NodePath(path), values[path])


## 시점 t(0~1)의 속성 값들. 테스트·미리 계산용.
## CSS처럼 속성마다 그 속성을 적은 키프레임끼리 보간한다 (적지 않은 키프레임은 건너뛴다. 첫·끝 키프레임에는 모든 속성을 적는다).
static func sample(frames: Array, t: float, curve: Vector4) -> Dictionary:
	var out: Dictionary = {}
	for path: String in (frames[0] as Array)[1]:
		out[path] = _sample_property(frames, path, t, curve)
	return out


static func _sample_property(frames: Array, path: String, t: float, curve: Vector4) -> Variant:
	var prev: Array = frames[0]
	for i: int in range(1, frames.size()):
		var frame: Array = frames[i]
		var values: Dictionary = frame[1]
		if not values.has(path):
			continue
		var from_t: float = prev[0]
		var to_t: float = frame[0]
		if t <= to_t or i == frames.size() - 1:
			var span: float = to_t - from_t
			var local: float = 1.0 if span <= 0.0 else clampf((t - from_t) / span, 0.0, 1.0)
			return lerp((prev[1] as Dictionary)[path], values[path], bezier(curve, local))
		prev = frame
	return (prev[1] as Dictionary)[path]


## CSS cubic-bezier(x1, y1, x2, y2)의 진행도 x(0~1)에서의 값 y.
static func bezier(curve: Vector4, x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	if curve == LINEAR:
		return x
	# x(s) = x를 푸는 매개변수 s: 뉴턴법 몇 번, 안 되면 이분법.
	var s: float = x
	for _i: int in 8:
		var err: float = _axis(curve.x, curve.z, s) - x
		if absf(err) < 1e-5:
			return _axis(curve.y, curve.w, s)
		var slope: float = _slope(curve.x, curve.z, s)
		if absf(slope) < 1e-6:
			break
		s -= err / slope
	var low: float = 0.0
	var high: float = 1.0
	s = x
	for _i: int in 30:
		var value: float = _axis(curve.x, curve.z, s)
		if absf(value - x) < 1e-5:
			break
		if value < x:
			low = s
		else:
			high = s
		s = (low + high) / 2.0
	return _axis(curve.y, curve.w, s)


## 제어점 p1, p2(시작 0, 끝 1)인 3차 베지어의 매개변수 s에서의 값.
static func _axis(p1: float, p2: float, s: float) -> float:
	var inv: float = 1.0 - s
	return 3.0 * inv * inv * s * p1 + 3.0 * inv * s * s * p2 + s * s * s


static func _slope(p1: float, p2: float, s: float) -> float:
	var inv: float = 1.0 - s
	return 3.0 * inv * inv * p1 + 6.0 * inv * s * (p2 - p1) + 3.0 * s * s * (1.0 - p2)
