extends "res://tests/framework/test_case.gd"
## 스크롤 안에서 터치를 멈추는 노드가 없어야 내용 위에서 끌어도 스크롤된다 (E36). 슬라이더만 예외 (끌어서 값을 바꾼다).
## 스크롤 안에 코드로 넣는 반복 줄 씬도 함께 검사한다. 스크롤을 쓰는 화면이 늘면 자동으로 포함된다.

const ROW_SCENES: Array[String] = [
	"achievement_grade_section", "achievement_row", "character_block", "character_chain_group", "filter_chip", "grade_header", "level_reward_row",
	"puzzle_board_button", "recipe_step", "shop_card", "shop_grade_section", "star_row", "ticket_row",
]


func _blockers(node: Node, base: Node, inside: bool, out: PackedStringArray) -> void:
	if inside and node is Control and not (node is ScrollContainer) and not (node is Slider):
		if (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			out.append(String(base.get_path_to(node)))
	for child: Node in node.get_children():
		_blockers(child, base, inside or node is ScrollContainer, out)


func _scene_blockers(path: String, inside: bool) -> PackedStringArray:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var out: PackedStringArray = PackedStringArray()
	_blockers(scene, scene, inside, out)
	scene.free()
	return out


func test_nothing_inside_a_scroll_stops_touches() -> void:
	var dir: DirAccess = DirAccess.open("res://scenes")
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tscn"):
			assert_eq(_scene_blockers("res://scenes/" + name, false), PackedStringArray(), "%s: inside a scroll" % name)


func test_rows_put_into_a_scroll_do_not_stop_touches() -> void:
	for row: String in ROW_SCENES:
		assert_eq(_scene_blockers("res://scenes/%s.tscn" % row, true), PackedStringArray(), row)


func test_tap_survives_small_finger_movement() -> void:
	assert_true(int(ProjectSettings.get_setting("gui/common/default_scroll_deadzone", 0)) > 0, "a little jitter is not a scroll")


func test_pause_button_lets_swipes_through() -> void:
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	assert_eq((hud.get_node("SafeArea/Content/TopRow/PauseButton") as Control).mouse_filter, Control.MOUSE_FILTER_PASS)
	hud.free()
