extends "res://tests/framework/test_case.gd"
## KeyframeAnim: CSS cubic-bezier 곡선과 @keyframes 보간 (HTML 연출 이식, E32).


func test_bezier_matches_css_reference_points() -> void:
	assert_near(KeyframeAnim.bezier(KeyframeAnim.LINEAR, 0.3), 0.3, 1e-4)
	assert_near(KeyframeAnim.bezier(KeyframeAnim.EASE, 0.5), 0.8024, 2e-3, "CSS ease at 50%")
	assert_near(KeyframeAnim.bezier(KeyframeAnim.EASE_IN, 0.5), 0.3153, 2e-3, "CSS ease-in at 50%")
	assert_near(KeyframeAnim.bezier(KeyframeAnim.EASE_OUT, 0.5), 0.6847, 2e-3, "CSS ease-out at 50%")
	assert_eq(KeyframeAnim.bezier(KeyframeAnim.EASE, 0.0), 0.0)
	assert_eq(KeyframeAnim.bezier(KeyframeAnim.EASE, 1.0), 1.0)
	assert_true(KeyframeAnim.bezier(Vector4(0.2, 0.9, 0.3, 1.4), 0.6) > 1.0, "overshooting curve goes past 1")


func test_curve_applies_per_keyframe_segment() -> void:
	var frames: Array = [[0.0, {"x": 0.0}], [0.5, {"x": 10.0}], [1.0, {"x": 0.0}]]
	assert_near(KeyframeAnim.sample(frames, 0.25, KeyframeAnim.EASE_OUT)["x"], 10.0 * KeyframeAnim.bezier(KeyframeAnim.EASE_OUT, 0.5), 1e-3)
	assert_near(KeyframeAnim.sample(frames, 0.5, KeyframeAnim.EASE_OUT)["x"], 10.0, 1e-4, "keyframe value at its time")
	assert_near(KeyframeAnim.sample(frames, 1.0, KeyframeAnim.EASE_OUT)["x"], 0.0, 1e-4)


func test_property_missing_in_a_middle_frame_spans_its_neighbours() -> void:
	# CSS: opacity를 30%에 적지 않으면 0% → 100%가 한 구간.
	var frames: Array = [[0.0, {"a": 1.0, "s": 1.0}], [0.3, {"s": 2.0}], [1.0, {"a": 0.0, "s": 0.0}]]
	assert_near(KeyframeAnim.sample(frames, 0.5, KeyframeAnim.LINEAR)["a"], 0.5, 1e-4)
	assert_near(KeyframeAnim.sample(frames, 0.3, KeyframeAnim.LINEAR)["s"], 2.0, 1e-4)


func test_whole_curve_for_web_animations() -> void:
	var node: Node2D = Node2D.new()
	var frames: Array = [[0.0, {"position:x": 0.0}], [0.5, {"position:x": 6.0}], [1.0, {"position:x": 0.0}]]
	KeyframeAnim.apply(node, frames, 0.25, KeyframeAnim.EASE_OUT, true)
	var eased: float = KeyframeAnim.bezier(KeyframeAnim.EASE_OUT, 0.25)  # 전체 곡선 뒤 구간은 직선
	assert_near(node.position.x, 6.0 * eased / 0.5, 1e-3)
	node.free()
