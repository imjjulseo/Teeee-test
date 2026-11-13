class_name BoardMarksView
extends Node2D
## 능력의 판 위 표시를 칸 위에 그린다 (마라토너 깃발, 탐험가 구역). 받은 BoardMark를 그대로 그릴 뿐 판정하지 않는다.
## 좌표는 칸 기준 (BoardView의 Cells와 같은 원점).
## 표시 종류에 디자인 이미지(BoardTheme.mark_textures)가 있으면 그 칸 범위에 이미지를 그린다 (화살표는 방향대로 돌림, 길은 늘 선).
## 퍼즐·튜토리얼 안내는 HTML 그대로: 모을 블록은 흰 빛이 맥박처럼(tuthl, 1.2초), 당길 블록은 노란 빛(tpull), 목표 가운데는 노란
## 방사형(tctr), 화살표는 흰 화살표가 깜빡임(tarr, 0.9초). 목표 자리·설 칸(tslot · tdest)은 HTML처럼 그리지 않는다.

## 매 프레임 다시 그리는(움직이는) 표시.
const ANIMATED: Array[BoardMark.Kind] = [BoardMark.Kind.SWIPE, BoardMark.Kind.TARGET, BoardMark.Kind.PULL, BoardMark.Kind.ARROW,
	BoardMark.Kind.FLAG_READY, BoardMark.Kind.WARN, BoardMark.Kind.PATH, BoardMark.Kind.ZONE]
## 능력 표시 연출 (HTML): 준비된 깃발 노란 빛 맥박(wpPulse 1초), 불 번짐 예고 칸 점선이 주황↔빨강으로 번갈아(emberWarn 0.35초),
## 수선사 끈 점선이 흐름(thread 1.2초), 탐험가 구역이 생길 때 작게서 튀어나옴(zoneIn 0.45초). 효과 줄이기면 멈춘 모습.
const ZONE_IN_TIME: float = 0.45
const ZONE_IN_CURVE: Vector4 = Vector4(0.2, 0.9, 0.3, 1.4)

@export var theme_data: BoardTheme

var _marks: Array[BoardMark] = []
var _swipe_time: float = 0.0
## 깜빡이는 표시의 시계 (초).
var _pulse_time: float = 0.0
## 구역이 처음 보인 시각 (rect → _pulse_time). 새 구역만 튀어나온다.
var _zone_born: Dictionary = {}
## 효과 줄이기 (BoardView가 알려 준다).
var reduce_motion: bool = false


func show_marks(marks: Array[BoardMark]) -> void:
	var born: Dictionary = {}
	for mark: BoardMark in marks:
		if mark.kind == BoardMark.Kind.ZONE:
			born[mark.rect] = _zone_born.get(mark.rect, _pulse_time)
	_zone_born = born
	_marks = marks
	_swipe_time = 0.0
	queue_redraw()


## 움직이는 표시가 있으면 매 프레임 다시 그린다.
func _process(delta: float) -> void:
	for mark: BoardMark in _marks:
		if ANIMATED.has(mark.kind):
			_swipe_time = fmod(_swipe_time + delta, theme_data.swipe_period)
			_pulse_time = fmod(_pulse_time + delta, 3600.0)
			queue_redraw()
			return


## 지금 그리는 표시 (테스트/디버그용).
func marks() -> Array[BoardMark]:
	return _marks


func _draw() -> void:
	var step: float = theme_data.cell_size + theme_data.cell_gap
	for mark: BoardMark in _marks:
		var rect: Rect2 = Rect2(Vector2(mark.rect.position) * step,
			Vector2(mark.rect.size) * step - Vector2.ONE * theme_data.cell_gap)
		var art: Texture2D = theme_data.mark_art(mark.kind) if mark.kind != BoardMark.Kind.PATH else null
		if art != null:
			_draw_art(art, rect, mark.direction if mark.kind == BoardMark.Kind.ARROW else Vector2i.RIGHT)
			continue
		match mark.kind:
			BoardMark.Kind.ZONE:
				_draw_zone(mark, rect)
			BoardMark.Kind.FLAG:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_color, false, theme_data.mark_line_width)
			BoardMark.Kind.FLAG_READY:
				var glow: float = 1.0 if reduce_motion else _pulse(1.0, 0.5)  # HTML wpPulse: 빛 .7 → .35 → .7
				_draw_glow(rect, Color(theme_data.mark_flag_ready_color, 0.7 * glow), 0.03, 0.15)
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_ready_color, false, theme_data.mark_line_width * 1.5)
				_draw_pennant(rect, theme_data.mark_flag_ready_color)
			BoardMark.Kind.FLAG_NEXT:
				draw_rect(rect.grow(-theme_data.mark_line_width / 2.0), theme_data.mark_flag_next_color, false, theme_data.mark_line_width)
			BoardMark.Kind.PATH:
				_draw_path(mark, step)
			BoardMark.Kind.WARN:  # HTML emberWarn: 점선 #FFB04A ↔ #FF4A2A, 0.35초 왕복
				var k: float = 0.0 if reduce_motion else 0.5 - 0.5 * cos(_pulse_time / 0.35 * PI)
				var warn: Color = theme_data.mark_warn_color.lerp(theme_data.mark_warn_hot_color, k)
				_draw_soft_fill(rect, Color(warn, 0.15 * k))
				_draw_dashed_rect(rect.grow(-theme_data.mark_line_width), warn)
			BoardMark.Kind.TARGET:  # HTML .tuthl: 밝게 + 흰 빛 (0 0 16px 6px rgba(255,255,255,.45)), 1.2초 맥박
				var k: float = _pulse(theme_data.glow_period, 0.2)
				_draw_soft_fill(rect, theme_data.glow_brighten)
				_draw_glow(rect.grow(-rect.size.x * 0.06), Color(theme_data.target_glow_color, theme_data.target_glow_color.a * k), 0.15, 0.39)
			BoardMark.Kind.PULL:  # HTML .tpull: 노란 빛 (0 0 18px 7px rgba(255,210,63,.6))
				var k: float = _pulse(theme_data.glow_period, 0.2)
				_draw_glow(rect, Color(theme_data.puzzle_pull_color, theme_data.pull_glow_alpha * k), 0.17, 0.44)
			BoardMark.Kind.GOAL_CENTER:  # HTML .tctr: 노란 방사형 (가운데 .35 → 70%에서 0)
				_draw_radial(rect.get_center(), rect.size.x * 0.5, theme_data.puzzle_goal_color)
			BoardMark.Kind.GOAL_SLOT, BoardMark.Kind.GOAL_SLOT_FILLED, BoardMark.Kind.STAND:
				pass  # HTML: display:none
			BoardMark.Kind.ARROW:
				_draw_arrow(rect, mark.direction)
			BoardMark.Kind.SWIPE:
				_draw_swipe(rect, mark.direction, step)


## 이미지를 rect에 맞춰 그린다. 오른쪽을 향한 이미지를 direction 쪽으로 돌린다.
func _draw_art(art: Texture2D, rect: Rect2, direction: Vector2i) -> void:
	draw_set_transform(rect.get_center(), Vector2(direction).angle(), Vector2.ONE)
	draw_texture_rect(art, Rect2(-rect.size / 2.0, rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 끈: 시작 칸 원 + 지나온 칸을 잇는 선 + 칸마다 점.
func _draw_path(mark: BoardMark, step: float) -> void:
	var half: float = theme_data.cell_size / 2.0
	var points: PackedVector2Array = PackedVector2Array()
	for cell: Vector2i in mark.cells:
		points.append(Vector2(cell) * step + Vector2.ONE * half)
	draw_arc(points[0], theme_data.cell_size * theme_data.trail_start_radius, 0.0, TAU, 32, theme_data.trail_color, theme_data.trail_width / 2.0)
	if points.size() > 1:
		draw_polyline(points, theme_data.trail_color, theme_data.trail_width, true)
		_draw_thread(points)
	for point: Vector2 in points:
		draw_circle(point, theme_data.trail_width * 0.6, theme_data.trail_color)


## 끈 위로 흐르는 밝은 점선 (HTML #trail .th: dasharray 7 5, 1.2초에 24만큼 흐름 → 칸 크기 비율).
func _draw_thread(points: PackedVector2Array) -> void:
	var unit: float = theme_data.cell_size / 43.0  # HTML 칸 ≈ 43 CSS px
	var dash: float = 7.0 * unit
	var gap: float = 5.0 * unit
	var shift: float = 0.0 if reduce_motion else fmod(_pulse_time / 1.2, 1.0) * 24.0 * unit
	var color: Color = theme_data.trail_color.lightened(0.6)
	var walked: float = -shift
	for i: int in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		var t: float = 0.0
		while t < length:
			var phase: float = fposmod(walked + t, dash + gap)
			var run: float = minf((dash - phase) if phase < dash else (dash + gap - phase), length - t)
			if phase < dash:
				draw_line(a.lerp(b, t / length), a.lerp(b, (t + run) / length), color, theme_data.trail_width * 0.35, true)
			t += maxf(run, 0.5)
		walked += length


## 탐험가 구역: 생길 때 0.6배·투명에서 튀어나온다 (HTML zoneIn), 바탕은 캐릭터 색 대신 구역 색을 옅게.
func _draw_zone(mark: BoardMark, rect: Rect2) -> void:
	var age: float = _pulse_time - float(_zone_born.get(mark.rect, -100.0))
	var e: float = 1.0 if reduce_motion else KeyframeAnim.bezier(ZONE_IN_CURVE, clampf(age / ZONE_IN_TIME, 0.0, 1.0))
	var grown: Rect2 = rect.grow(-theme_data.mark_line_width / 2.0)
	var scaled: Rect2 = Rect2(grown.get_center() - grown.size * lerpf(0.6, 1.0, e) / 2.0, grown.size * lerpf(0.6, 1.0, e))
	var color: Color = Color(theme_data.mark_zone_color, theme_data.mark_zone_color.a * clampf(e, 0.0, 1.0))
	_draw_soft_fill(scaled, Color(color, 0.16 * color.a))
	_draw_dashed_rect(scaled, color)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var corners: PackedVector2Array = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i: int in corners.size():
		draw_dashed_line(corners[i], corners[(i + 1) % corners.size()], color, theme_data.mark_line_width, theme_data.mark_dash_length)


## 칸 가운데의 흰 화살표 (HTML .tarr: 칸의 52%, 그림자, 0.9초마다 1 → .35 → 1).
func _draw_arrow(rect: Rect2, direction: Vector2i) -> void:
	var dir: Vector2 = Vector2(direction).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var c: Vector2 = rect.get_center()
	var half: float = rect.size.x * 0.52 / 2.0
	# HTML clip-path: polygon(0 30%, 52% 30%, 52% 6%, 100% 50%, 52% 94%, 52% 70%, 0 70%) (오른쪽을 향한 모양)
	var shape: Array[Vector2] = [Vector2(0, 0.3), Vector2(0.52, 0.3), Vector2(0.52, 0.06), Vector2(1, 0.5), Vector2(0.52, 0.94), Vector2(0.52, 0.7), Vector2(0, 0.7)]
	var points: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in shape:
		var local: Vector2 = (p - Vector2(0.5, 0.5)) * half * 2.0
		points.append(c + dir * local.x + side * local.y)
	var k: float = _pulse(theme_data.arrow_period, 0.35)
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		shadow.append(p + Vector2(0, rect.size.x * 0.02))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.5 * k))
	draw_colored_polygon(points, Color(theme_data.puzzle_arrow_color, k))


## 1 → low → 1을 period초마다 (HTML 50% 지점에서 low).
func _pulse(period: float, low: float) -> float:
	return lerpf(1.0, low, 0.5 - 0.5 * cos(_pulse_time / period * TAU))


## rect 둘레로 퍼지는 빛 (CSS box-shadow: spread · blur를 칸 크기 비율로). 바깥으로 갈수록 옅어지는 선을 겹쳐 그린다.
func _draw_glow(rect: Rect2, color: Color, spread: float, blur: float) -> void:
	var cell: float = rect.size.x
	var steps: int = 10
	var reach: float = cell * (spread + blur)
	for i: int in steps:
		var t: float = float(i) / steps
		var grow: float = reach * t
		var fade: float = 1.0 if grow <= cell * spread else pow(1.0 - (grow - cell * spread) / (cell * blur), 2.0)
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.draw_center = false
		box.set_border_width_all(int(ceil(reach / steps)) + 1)
		box.border_color = Color(color, color.a * fade / steps * 3.0)
		box.set_corner_radius_all(int(cell * 0.3 + grow))
		draw_style_box(box, rect.grow(grow))


## 블록을 밝게 (HTML filter: brightness(1.15)) — 둥근 흰 막을 얇게 덮는다.
func _draw_soft_fill(rect: Rect2, color: Color) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(rect.size.x * 0.2))
	draw_style_box(box, rect)


## 가운데가 진하고 바깥으로 옅어지는 원 (CSS radial-gradient, 70%에서 0).
func _draw_radial(center: Vector2, radius: float, color: Color) -> void:
	var rings: int = 12
	for i: int in rings:
		var t: float = 1.0 - float(i) / rings
		draw_circle(center, radius * 0.7 * t, Color(color, color.a / rings * 1.6))


## 손가락 안내: 0~15% 나타나며 커짐 → 60%까지 옆 칸으로 → 80%부터 작아지며 사라짐 (HTML @keyframes tswipe).
func _draw_swipe(rect: Rect2, direction: Vector2i, step: float) -> void:
	var t: float = _swipe_time / theme_data.swipe_period
	var travel: float = clampf((t - 0.15) / 0.45, 0.0, 1.0)
	travel = travel * travel * (3.0 - 2.0 * travel)  # ease-in-out
	var scale: float = lerpf(0.8, 1.0, clampf(t / 0.15, 0.0, 1.0)) if t < 0.6 else lerpf(1.0, 0.8, clampf((t - 0.6) / 0.2, 0.0, 1.0))
	var alpha: float = clampf(t / 0.15, 0.0, 1.0) if t < 0.6 else 1.0 - clampf((t - 0.6) / 0.2, 0.0, 1.0)
	var center: Vector2 = rect.get_center() + Vector2(direction) * step * travel
	var radius: float = rect.size.x * theme_data.swipe_size / 2.0 * scale
	var halo: Color = theme_data.swipe_halo
	var fill: Color = theme_data.swipe_color
	draw_circle(center, radius + rect.size.x * 0.06, Color(halo, halo.a * alpha))
	draw_circle(center, radius, Color(fill, fill.a * alpha))


## 칸 왼쪽 위의 작은 깃발 (준비된 깃발).
func _draw_pennant(rect: Rect2, color: Color) -> void:
	var s: float = rect.size.x * 0.35
	var base: Vector2 = rect.position + Vector2.ONE * rect.size.x * 0.12
	draw_colored_polygon(PackedVector2Array([base, base + Vector2(s, s * 0.35), base + Vector2(0, s * 0.7)]), color)
