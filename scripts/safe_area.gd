class_name SafeArea
extends MarginContainer
## 노치·펀치홀·둥근 모서리를 피하는 여백 컨테이너. 화면 전체(앵커 full rect)에 두고,
## 자식 Control(보통 "Content" 하나)을 안전 영역 안에 배치한다.
## - 모바일: DisplayServer.get_display_safe_area()를 뷰포트 좌표로 바꿔 여백으로 쓴다.
## - 데스크톱: 안전 영역 개념이 없으므로 여백 0 (창이 작업 표시줄에 걸쳐도 무시).
## - 테스트/미리보기: SafeArea.debug_insets로 가상의 노치 여백을 모든 SafeArea에 강제할 수 있다.
## 터치/스와이프를 가로채지 않도록 마우스 필터는 IGNORE.

## (left, top, right, bottom) 뷰포트 px. ZERO가 아니면 실제 기기 값 대신 이 값을 쓴다.
static var debug_insets: Vector4 = Vector4.ZERO

## 안전 영역 여백에 항상 더하는 여백(px).
@export var extra_margin: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


## 화면(스크린) 좌표의 안전 영역을 뷰포트 좌표 여백(left, top, right, bottom)으로 바꾼다. 순수 함수.
static func insets_from(safe_area: Rect2, window_position: Vector2, window_size: Vector2, viewport_size: Vector2) -> Vector4:
	if window_size.x <= 0.0 or window_size.y <= 0.0 or safe_area.size == Vector2.ZERO:
		return Vector4.ZERO
	var window_rect: Rect2 = Rect2(Vector2.ZERO, window_size)
	var local: Rect2 = Rect2(safe_area.position - window_position, safe_area.size).intersection(window_rect)
	if local.size == Vector2.ZERO:
		return Vector4.ZERO
	var to_view: Vector2 = viewport_size / window_size
	return Vector4(
		local.position.x * to_view.x,
		local.position.y * to_view.y,
		(window_size.x - local.end.x) * to_view.x,
		(window_size.y - local.end.y) * to_view.y,
	)


## 현재 적용할 여백.
func current_insets() -> Vector4:
	if debug_insets != Vector4.ZERO:
		return debug_insets
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	return insets_from(
		Rect2(DisplayServer.get_display_safe_area()),
		Vector2(DisplayServer.window_get_position()),
		Vector2(DisplayServer.window_get_size()),
		get_viewport().get_visible_rect().size,
	)


func _update_margins() -> void:
	var insets: Vector4 = current_insets()
	add_theme_constant_override("margin_left", int(ceilf(insets.x)) + extra_margin)
	add_theme_constant_override("margin_top", int(ceilf(insets.y)) + extra_margin)
	add_theme_constant_override("margin_right", int(ceilf(insets.z)) + extra_margin)
	add_theme_constant_override("margin_bottom", int(ceilf(insets.w)) + extra_margin)
