extends "res://tests/framework/test_case.gd"
## 안전 영역(노치/펀치홀) → 뷰포트 여백 변환 (SafeArea.insets_from, 순수 함수).


func test_full_screen_without_notch_has_no_insets() -> void:
	var insets: Vector4 = SafeArea.insets_from(Rect2(0, 0, 1080, 2340), Vector2.ZERO, Vector2(1080, 2340), Vector2(720, 1560))
	assert_eq(insets, Vector4.ZERO)


func test_top_notch_and_bottom_gesture_bar_scale_to_viewport() -> void:
	# 1080x2340 화면, 위 노치 90px, 아래 제스처 바 48px. 뷰포트는 720x1560 (배율 2/3).
	var insets: Vector4 = SafeArea.insets_from(Rect2(0, 90, 1080, 2340 - 90 - 48), Vector2.ZERO, Vector2(1080, 2340), Vector2(720, 1560))
	assert_near(insets.x, 0.0)
	assert_near(insets.y, 60.0, 1e-4)
	assert_near(insets.z, 0.0)
	assert_near(insets.w, 32.0, 1e-4)


func test_side_cutout_in_landscape_like_layout() -> void:
	var insets: Vector4 = SafeArea.insets_from(Rect2(100, 0, 1800, 1000), Vector2.ZERO, Vector2(2000, 1000), Vector2(2000, 1000))
	assert_eq(insets, Vector4(100, 0, 100, 0))


func test_window_offset_is_respected() -> void:
	# 창이 화면 (200, 100)에 있고, 안전 영역이 창을 완전히 덮으면 여백 없음.
	var insets: Vector4 = SafeArea.insets_from(Rect2(0, 0, 1920, 1040), Vector2(200, 100), Vector2(405, 720), Vector2(720, 1280))
	assert_eq(insets, Vector4.ZERO)


func test_invalid_input_gives_no_insets() -> void:
	assert_eq(SafeArea.insets_from(Rect2(), Vector2.ZERO, Vector2(1080, 2340), Vector2(720, 1560)), Vector4.ZERO)
	assert_eq(SafeArea.insets_from(Rect2(0, 0, 10, 10), Vector2.ZERO, Vector2.ZERO, Vector2(720, 1280)), Vector4.ZERO)
