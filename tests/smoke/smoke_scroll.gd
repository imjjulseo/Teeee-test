extends "res://tests/smoke/smoke_base.gd"
## 메뉴 화면 스크롤과 일시정지 버튼 스와이프 (E36). 실제 터치 이벤트로 줄·카드·버튼 위에서 끌어 본다.
## 모드: level · characters · shop · puzzle · options · achievements = 그 화면의 내용 위에서 끌면 스크롤되고(캐릭터는 판이 넘어가고) 눌리지 않는다,
## flick = 캐릭터 판을 빠르게 밀면 여러 장 넘어간다,
## tap = 스크롤 안 버튼을 그냥 누르면 눌린다, pause_swipe = 일시정지 버튼 위 스와이프는 이동이고 일시정지가 아니다,
## pause_tap = 일시정지 버튼을 그냥 누르면 일시정지.

const DRAG_FRAMES: int = 12
const DRAG_STEP: float = 40.0
const FLICK_FRAMES: int = 4
const FLICK_STEP: float = 180.0

var _scroll: ScrollContainer
var _target: Control
var _axis: Vector2 = Vector2.UP
var _pos: Vector2
var _before: int = 0
var _frames: int = 0
var _player_before: Vector2i


func _setup() -> void:
	match mode:
		"level":
			ProgressStore.new().set_level(30)
			change_scene_to_file("res://scenes/level_rewards.tscn")
		"characters", "flick":
			change_scene_to_file("res://scenes/character_select.tscn")
		"shop":
			change_scene_to_file("res://scenes/shop.tscn")
		"puzzle":
			change_scene_to_file("res://scenes/puzzle_menu.tscn")
		"options":
			change_scene_to_file("res://scenes/options.tscn")
		"achievements":
			change_scene_to_file("res://scenes/achievements.tscn")
		"tap":
			ProgressStore.new().add_currency(0, 100)
			change_scene_to_file("res://scenes/shop.tscn")
		"pause_swipe", "pause_tap":
			change_scene_to_file("res://scenes/main.tscn")
		_:
			fail("unknown mode " + mode)
			finish()


## 끌어 볼 스크롤과, 터치를 시작할 내용. 화면이 뜬 뒤 한 번 부른다.
func _pick() -> void:
	match mode:
		"level":
			var screen: LevelRewardsScreen = current_scene as LevelRewardsScreen
			_scroll = node("%Scroll")
			_target = _visible_child(screen.get_node("%Rows"))
		"characters", "flick":
			_target = (current_scene as CharacterSelect).carousel().current_page().get_node("%EquipButton")
			_axis = Vector2.LEFT
		"shop":
			_scroll = node("%ShopPage")
			_target = (current_scene as ShopScreen).shop_card_for(&"gardener")
		"puzzle":
			_scroll = node("%Scroll")
			_target = (current_scene as PuzzleMenuScreen).buttons()[0]
			_axis = Vector2.LEFT
		"options":
			_scroll = node("SafeArea/Content/Layout/Page/Box/Scroll")
			_target = node("%QuickOptions/%DpadButton")  # 끌어도 패드로 바뀌면 안 된다
		"achievements":
			_scroll = node("%Scroll")
			_target = (current_scene as AchievementsScreen).common_rows()[1]


func _first_box(scroll: ScrollContainer) -> Node:
	var box: Node = scroll.get_child(0)
	while box.get_child_count() == 1:
		box = box.get_child(0)
	return box


## 스크롤 영역 안에 보이는 줄 하나 (카드·줄·버튼).
func _visible_child(box: Node) -> Control:
	var area: Rect2 = _scroll.get_global_rect()
	for child: Node in box.get_children():
		if child is Control and not (child is GradeHeader) and (child as Control).visible and area.has_point((child as Control).get_global_rect().get_center()):
			return child
	return null


func _finger(to: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	var scale: Vector2 = root.get_final_transform().get_scale()
	event.position = root.get_final_transform() * to
	event.relative = (to - _pos) * scale
	event.velocity = event.relative * 60.0
	Input.parse_input_event(event)
	_pos = to


func _tick() -> void:
	match mode:
		"tap":
			_tick_tap()
		"pause_swipe":
			_tick_pause_swipe()
		"pause_tap":
			_tick_pause_tap()
		_:
			_tick_drag()


func _tick_drag() -> void:
	match step:
		0:
			if current_scene != null and step_time > 0.6:
				if mode == "shop" and (current_scene as ShopScreen).tab != ShopScreen.Tab.SHOP:  # 탭을 먼저 바꾸고 줄 자리가 정해진 뒤 고른다
					(current_scene as ShopScreen).set_tab(ShopScreen.Tab.SHOP)
					step_time = 0.0
					return
				_pick()
				if _target == null:
					fail("nothing to touch")
					finish()
					return
				next_step()
		1:
			if step_time > 0.2:
				_before = _scroll_value()
				_pos = _target.get_global_rect().get_center()
				touch(_pos, true)
				_frames = 0
				next_step()
		2:
			_finger(_pos + _axis * (FLICK_STEP if mode == "flick" else DRAG_STEP))
			_frames += 1
			if _frames >= (FLICK_FRAMES if mode == "flick" else DRAG_FRAMES):
				touch(_pos, false)
				next_step()
		3:
			if step_time > 0.5:
				if mode == "flick":
					expect(_scroll_value() >= _before + 2, "a fast swipe skips pages (%d → %d)" % [_before, _scroll_value()])
				else:
					expect(_scroll_value() != _before, "%s: dragging on content scrolls (%d → %d)" % [mode, _before, _scroll_value()])
				_expect_no_press()
				finish()


func _scroll_value() -> int:
	if _scroll == null:
		return (current_scene as CharacterSelect).carousel().index
	return _scroll.scroll_horizontal if _axis.y == 0.0 else _scroll.scroll_vertical


## 끌었으니 눌린 것이 없어야 한다.
func _expect_no_press() -> void:
	match mode:
		"characters":
			expect(CharacterStore.new().selected_id == &"", "the button on the page did not press")
		"puzzle":
			expect(current_scene.name == "PuzzleMenu", "the board did not open")
		"shop":
			expect(not (node("%CharacterSheet") as Control).visible, "the card did not open")
		"options":
			expect(OptionsStore.new().control_mode == OptionsStore.ControlMode.SWIPE, "the button did not change the option")


func _tick_tap() -> void:
	match step:
		0:
			if in_scene("Shop", 0.4):
				(current_scene as ShopScreen).set_tab(ShopScreen.Tab.SHOP)
				next_step()
		1:
			if step_time > 0.2:
				click_control((current_scene as ShopScreen).shop_card_for(&"gardener"))
				next_step()
		2:
			if step_time > 0.2:
				expect((node("%CharacterSheet") as Control).visible, "a plain tap still presses the row inside the scroll")
				finish()


func _tick_pause_swipe() -> void:
	var button: Control = null if current_scene == null or current_scene.name != "Main" else node("Hud/%PauseButton")
	match step:
		0:
			if playing(0.5):
				_player_before = session().board.player_pos
				_pos = button.get_global_rect().get_center()
				touch(_pos, true)
				next_step()
		1:
			if step_time > 0.05:
				_finger(_pos + Vector2.DOWN * 50.0)  # 33px를 넘지만 아직 버튼 안
				next_step()
		2:
			if step_time > 0.05:
				touch(_pos, false)
				next_step()
		3:
			if step_time > 0.2:
				expect(session().board.player_pos == _player_before + Vector2i.DOWN, "swipe on the pause button moves (%s)" % session().board.player_pos)
				expect(flow().state != S.PAUSED, "and does not pause")
				finish()


func _tick_pause_tap() -> void:
	match step:
		0:
			if playing(0.5):
				auto_resume = false
				click_control(node("Hud/%PauseButton"))
				next_step()
		1:
			if step_time > 0.2:
				expect(flow().state == S.PAUSED, "a plain tap pauses")
				finish()
