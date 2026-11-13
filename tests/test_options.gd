extends "res://tests/framework/test_case.gd"
## 옵션: 조작 방법(스와이프 / 가상 방향키) 저장, 입력 라우팅, 가상 방향키.
## 입력 라우팅은 main.tscn의 실제 연결(FlowChannel → InputRouter·VirtualDpad, VirtualDpad → InputRouter)을
## 그대로 이어 붙여, 원래 signal(조작 방법 알림, 방향키 버튼 누름)을 보내서 확인한다.

const TEST_SAVE: String = "user://test_options_save.cfg"
const Mode = OptionsStore.ControlMode
const SceneWiring = preload("res://tests/framework/scene_wiring.gd")
const DPAD_BUTTONS: Dictionary = {
	"Up": Vector2i.UP, "Down": Vector2i.DOWN, "Left": Vector2i.LEFT, "Right": Vector2i.RIGHT,
}


func _clean() -> void:
	if FileAccess.file_exists(TEST_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))


## main.tscn처럼 연결된 입력 부분: { router, pad, flow }. 게임 시작 시처럼 조작 방법을 알린다.
func _rig(mode: OptionsStore.ControlMode) -> Dictionary:
	var router: InputRouter = InputRouter.new()
	router.config = make_config()
	var pad: VirtualDpad = (load("res://scenes/virtual_dpad.tscn") as PackedScene).instantiate() as VirtualDpad
	var flow: FlowChannel = FlowChannel.new()
	var wired: int = SceneWiring.connect_like("res://scenes/main.tscn", {
		"InputRouter": router, "VirtualDpad": pad, "GameController/FlowChannel": flow,
	})
	assert_eq(wired, 5, "control_mode → router, control_mode → pad, pad → router (press, hold, release)")
	flow.control_mode_ready.emit(mode)
	return {"router": router, "pad": pad, "flow": flow}


func _free(rig: Dictionary) -> void:
	for key: String in rig:
		(rig[key] as Node).free()


func _press_dpad(rig: Dictionary, button: String) -> void:
	((rig["pad"] as Node).get_node("SafeArea/Content/Pad/" + button) as Button).button_down.emit()


func _touch(pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = pos
	event.pressed = pressed
	return event


func _drag(pos: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.position = pos
	return event


func _key(physical: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = true
	return event


## actions를 실행하는 동안 발생한 move_requested 목록.
func _frame(router: InputRouter, actions: Callable) -> Array[Vector2i]:
	var got: Array[Vector2i] = []
	var record: Callable = func(dir: Vector2i, _hand: int) -> void: got.append(dir)
	router.move_requested.connect(record)
	actions.call()
	router.move_requested.disconnect(record)
	return got


func _swipe_right(router: InputRouter) -> void:
	router.handle_input(_touch(Vector2(100, 600), true))
	router.handle_input(_drag(Vector2(300, 600)))
	router.handle_input(_touch(Vector2(300, 600), false))


# --- 저장 -------------------------------------------------------------------

func test_default_is_swipe_and_selection_persists() -> void:
	_clean()
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.SWIPE)
	OptionsStore.new(TEST_SAVE).set_control_mode(Mode.DPAD)
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.DPAD, "reloaded from disk")
	OptionsStore.new(TEST_SAVE).set_control_mode(Mode.SWIPE)
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.SWIPE)
	_clean()


func test_options_keep_other_save_keys() -> void:
	_clean()
	BestScoreStore.new(TEST_SAVE).submit(700)
	CharacterStore.new(TEST_SAVE).select(&"joker")
	OptionsStore.new(TEST_SAVE).set_control_mode(Mode.DPAD)
	assert_eq(BestScoreStore.new(TEST_SAVE).best, 700)
	assert_eq(CharacterStore.new(TEST_SAVE).selected_id, &"joker")
	BestScoreStore.new(TEST_SAVE).submit(900)
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.DPAD, "kept after other saves")
	_clean()


func test_invalid_saved_value_falls_back_to_swipe() -> void:
	_clean()
	var file: ConfigFile = ConfigFile.new()
	file.set_value("options", "control_mode", "telepathy")
	file.save(TEST_SAVE)
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.SWIPE)
	_clean()


# --- 입력 라우팅 (main.tscn 연결 그대로) ------------------------------------------

func test_swipe_mode_accepts_swipe_and_ignores_dpad() -> void:
	var rig: Dictionary = _rig(Mode.SWIPE)
	var router: InputRouter = rig["router"]
	assert_eq(_frame(router, _swipe_right.bind(router)), [Vector2i.RIGHT] as Array[Vector2i], "swipe works")
	assert_eq(_frame(router, _press_dpad.bind(rig, "Up")).size(), 0, "virtual pad ignored in swipe mode")
	assert_false((rig["pad"] as CanvasLayer).visible, "pad hidden")
	_free(rig)


func test_dpad_mode_accepts_dpad_and_ignores_swipe() -> void:
	var rig: Dictionary = _rig(Mode.DPAD)
	var router: InputRouter = rig["router"]
	assert_true((rig["pad"] as CanvasLayer).visible, "pad shown")
	assert_eq(_frame(router, _swipe_right.bind(router)).size(), 0, "swipe ignored in dpad mode")
	for button: String in DPAD_BUTTONS:
		assert_eq(_frame(router, _press_dpad.bind(rig, button)), [DPAD_BUTTONS[button]] as Array[Vector2i], "pad %s" % button)
	_free(rig)


func test_keyboard_works_in_both_modes() -> void:
	for mode: OptionsStore.ControlMode in [Mode.SWIPE, Mode.DPAD]:
		var rig: Dictionary = _rig(mode)
		var router: InputRouter = rig["router"]
		var got: Array[Vector2i] = _frame(router, func() -> void: router.handle_input(_key(KEY_W)))
		assert_eq(got, [Vector2i.UP] as Array[Vector2i], "mode %d" % mode)
		_free(rig)


func test_dpad_sends_every_press_in_order() -> void:
	var rig: Dictionary = _rig(Mode.DPAD)
	var got: Array[Vector2i] = _frame(rig["router"], func() -> void:
		_press_dpad(rig, "Up")
		_press_dpad(rig, "Left"))
	assert_eq(got, [Vector2i.UP, Vector2i.LEFT] as Array[Vector2i], "nothing is merged (E4)")
	_free(rig)


func test_dpad_tracks_the_held_button_until_release() -> void:
	var rig: Dictionary = _rig(Mode.DPAD)
	var pad: VirtualDpad = rig["pad"]
	_press_dpad(rig, "Right")
	assert_eq(pad.held_direction(), Vector2i.RIGHT, "held → repeats (timing checked in the smoke test)")
	(pad.get_node("SafeArea/Content/Pad/Right") as Button).button_up.emit()
	assert_eq(pad.held_direction(), Vector2i.ZERO, "released → stops")
	_free(rig)


func test_switching_mode_resets_swipe_tracking() -> void:
	var rig: Dictionary = _rig(Mode.SWIPE)
	var router: InputRouter = rig["router"]
	router.handle_input(_touch(Vector2(100, 600), true))  # 손가락을 댄 채로
	(rig["flow"] as FlowChannel).control_mode_ready.emit(Mode.SWIPE)  # 새 판 시작 알림
	var got: Array[Vector2i] = _frame(router, func() -> void: router.handle_input(_drag(Vector2(300, 600))))
	assert_eq(got.size(), 0, "stale touch from before the mode notice is not a swipe")
	_free(rig)


# --- 가상 방향키 --------------------------------------------------------------

func test_virtual_dpad_buttons_emit_on_press_and_do_not_take_focus() -> void:
	var pad: VirtualDpad = (load("res://scenes/virtual_dpad.tscn") as PackedScene).instantiate() as VirtualDpad
	var got: Array[Vector2i] = []
	pad.direction_pressed.connect(func(dir: Vector2i) -> void: got.append(dir))
	for button: String in DPAD_BUTTONS:
		(pad.get_node("SafeArea/Content/Pad/" + button) as Button).button_down.emit()
	assert_eq(got, [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT] as Array[Vector2i])
	for button: String in DPAD_BUTTONS:
		assert_eq((pad.get_node("SafeArea/Content/Pad/" + button) as Button).focus_mode, Control.FOCUS_NONE, "%s must not steal arrow keys" % button)
	pad.free()


# --- 마스터 볼륨 ----------------------------------------------------------------

func after_each() -> void:
	OptionsStore.apply_master_volume(OptionsStore.MAX_VOLUME)  # Master 버스는 전역 상태 → 원래대로
	_clean()


func _master_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master"))


func _master_muted() -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))


## 옵션 화면을 연다 (_ready에서 저장값을 읽는다). 러너는 트리가 돌기 전에 실행되므로 _ready는 notification()으로.
## (화면을 나갈 때 저장하는 _exit_tree는 트리 밖 Control에 보내면 엔진이 죽으므로 스모크 smoke_input에서 확인한다.)
func _open_options() -> OptionsMenu:
	var menu: OptionsMenu = (load("res://scenes/options.tscn") as PackedScene).instantiate() as OptionsMenu
	menu.save_path = TEST_SAVE
	menu.notification(Node.NOTIFICATION_READY)
<<<<<<< HEAD
	(menu.get_node("%QuickOptions") as QuickOptions).notification(Node.NOTIFICATION_READY)  # 설정 부품은 자기 _ready에서 값을 읽는다
=======
>>>>>>> Choi
	return menu


func _slider(menu: OptionsMenu) -> HSlider:
<<<<<<< HEAD
	return menu.get_node("%QuickOptions/%MasterVolumeSlider")
=======
	return menu.get_node("%MasterVolumeSlider")
>>>>>>> Choi


## 사용자가 슬라이더를 value로 옮긴 것처럼: 값 + value_changed (Range는 트리 밖에서 signal을 보내지 않는다).
func _drag_to(menu: OptionsMenu, value: float) -> void:
	var slider: HSlider = _slider(menu)
	slider.set_value_no_signal(value)
	slider.value_changed.emit(slider.value)


func test_master_volume_defaults_to_100_and_persists() -> void:
	_clean()
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 100)
	var store: OptionsStore = OptionsStore.new(TEST_SAVE)
	store.set_master_volume(35)
	store.save_master_volume()
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 35, "reloaded from disk")
	assert_eq(OptionsStore.new(TEST_SAVE).control_mode, Mode.SWIPE, "other option untouched")


func test_master_volume_is_clamped_and_bad_saved_values_are_ignored() -> void:
	_clean()
	var store: OptionsStore = OptionsStore.new(TEST_SAVE)
	store.set_master_volume(-5)
	assert_eq(store.master_volume, 0)
	store.set_master_volume(150)
	assert_eq(store.master_volume, 100)
	for bad: Variant in ["loud", 250, -3]:
		var file: ConfigFile = ConfigFile.new()
		file.set_value("options", "master_volume", bad)
		file.save(TEST_SAVE)
		var expected: int = 100 if typeof(bad) == TYPE_STRING else clampi(bad, 0, 100)
		assert_eq(OptionsStore.new(TEST_SAVE).master_volume, expected, "saved %s" % str(bad))


func test_master_volume_drives_the_master_bus() -> void:
	OptionsStore.apply_master_volume(100)
	assert_near(_master_db(), 0.0, 1e-4, "100 = 0 dB")
	assert_false(_master_muted())
	OptionsStore.apply_master_volume(50)
	assert_near(_master_db(), linear_to_db(0.25), 1e-4, "50 → volume² curve (about -12 dB)")
	OptionsStore.apply_master_volume(0)
	assert_true(_master_muted(), "0 = muted")
	OptionsStore.apply_master_volume(1)
	assert_false(_master_muted(), "unmuted again above 0")
	assert_true(OptionsStore.volume_to_db(1) < OptionsStore.volume_to_db(2), "louder as the value grows")


func test_sfx_and_bgm_buses_follow_master() -> void:
	for bus_name: StringName in [&"SFX", &"BGM"]:
		var bus: int = AudioServer.get_bus_index(bus_name)
		assert_true(bus >= 0, "%s bus exists" % bus_name)
		assert_eq(AudioServer.get_bus_send(bus), &"Master", "%s → Master" % bus_name)


func test_options_screen_slider_applies_immediately_and_saves_on_release() -> void:
	_clean()
	var menu: OptionsMenu = _open_options()
	var slider: HSlider = _slider(menu)
<<<<<<< HEAD
	var label: Label = menu.get_node("%QuickOptions/%MasterVolumeLabel")
=======
	var label: Label = menu.get_node("%MasterVolumeLabel")
>>>>>>> Choi
	assert_eq(slider.min_value, 0.0)
	assert_eq(slider.max_value, 100.0)
	assert_eq(slider.value, 100.0, "shows the default")
	_drag_to(menu, 40)  # 끄는 중
	assert_eq(label.text, "40")
	assert_eq(menu.master_volume(), 40)
	assert_near(_master_db(), OptionsStore.volume_to_db(40), 1e-4, "sound follows while dragging")
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 100, "not saved while dragging")
	slider.drag_ended.emit(true)
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 40, "saved on release")
	menu.free()


func test_options_screen_mutes_at_zero_and_shows_saved_value_next_time() -> void:
	_clean()
	var menu: OptionsMenu = _open_options()
	_drag_to(menu, 0)
	_slider(menu).drag_ended.emit(true)
	assert_true(_master_muted(), "0 = muted")
	menu.free()
	OptionsStore.apply_master_volume(100)
	var reopened: OptionsMenu = _open_options()
	assert_eq(_slider(reopened).value, 0.0, "slider shows the saved value")
<<<<<<< HEAD
	assert_eq((reopened.get_node("%QuickOptions/%MasterVolumeLabel") as Label).text, "0")
=======
	assert_eq((reopened.get_node("%MasterVolumeLabel") as Label).text, "0")
>>>>>>> Choi
	reopened.free()


func test_audio_options_loader_applies_saved_volume_when_a_scene_opens() -> void:
	_clean()
	var store: OptionsStore = OptionsStore.new(TEST_SAVE)
	store.set_master_volume(20)
	store.save_master_volume()
	var loader: AudioOptionsLoader = AudioOptionsLoader.new()
	loader.save_path = TEST_SAVE
	loader.notification(Node.NOTIFICATION_READY)
	assert_near(_master_db(), OptionsStore.volume_to_db(20), 1e-4)
	loader.free()
	for scene: String in ["res://scenes/intro.tscn", "res://scenes/main_menu.tscn", "res://scenes/main.tscn"]:
		var state: SceneState = (load(scene) as PackedScene).get_state()
		var found: bool = false
		for i: int in state.get_node_count():
			found = found or state.get_node_name(i) == &"AudioOptionsLoader"
		assert_true(found, "%s has an AudioOptionsLoader" % scene)

# --- 효과 줄이기 ----------------------------------------------------------------

func test_reduce_motion_defaults_off_and_persists() -> void:
	_clean()
	assert_false(OptionsStore.new(TEST_SAVE).reduce_motion)
	OptionsStore.new(TEST_SAVE).set_reduce_motion(true)
	assert_true(OptionsStore.new(TEST_SAVE).reduce_motion, "reloaded from disk")
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 100, "other options untouched")


func test_options_screen_toggle_saves_reduce_motion() -> void:
	_clean()
	var menu: OptionsMenu = _open_options()
<<<<<<< HEAD
	var toggle: CheckButton = menu.get_node("%QuickOptions/%ReduceMotionToggle")
=======
	var toggle: CheckButton = menu.get_node("%ReduceMotionToggle")
>>>>>>> Choi
	assert_false(toggle.button_pressed)
	toggle.toggled.emit(true)
	assert_true(OptionsStore.new(TEST_SAVE).reduce_motion)
	assert_true(menu.reduce_motion())
	menu.free()
	var reopened: OptionsMenu = _open_options()
<<<<<<< HEAD
	assert_true((reopened.get_node("%QuickOptions/%ReduceMotionToggle") as CheckButton).button_pressed, "shows the saved value")
=======
	assert_true((reopened.get_node("%ReduceMotionToggle") as CheckButton).button_pressed, "shows the saved value")
>>>>>>> Choi
	reopened.free()

# 설정 화면의 실제 클릭(조작 방법·볼륨)은 실제 창 스모크 테스트(smoke_input)로 확인한다.
# --- 진행 초기화 ------------------------------------------------------------------

func _detach_reset(menu: OptionsMenu) -> Array[int]:
	for connection: Dictionary in menu.progress_reset.get_connections():
		menu.progress_reset.disconnect(connection["callable"])
	var count: Array[int] = [0]
	menu.progress_reset.connect(func() -> void: count[0] += 1)
	return count


func test_reset_progress_keeps_only_options() -> void:
	_clean()
	OptionsStore.new(TEST_SAVE).set_reduce_motion(true)
	SaveData.write_value(TEST_SAVE, "progress", "level", 7)
	SaveData.write_value(TEST_SAVE, "tutorial", "done", true)
	assert_eq(SaveData.reset_progress(TEST_SAVE), OK)
	var data: SaveData = SaveData.new(TEST_SAVE)
	assert_eq(data.get_value("progress", "level", 1), 1, "progress erased")
	assert_eq(data.get_value("tutorial", "done", false), false, "tutorial erased")
	assert_true(OptionsStore.new(TEST_SAVE).reduce_motion, "options kept")
	_clean()


func test_reset_button_needs_a_second_press_in_time() -> void:
	_clean()
	SaveData.write_value(TEST_SAVE, "progress", "level", 7)
	var menu: OptionsMenu = _open_options()
	var count: Array[int] = _detach_reset(menu)
	var button: Button = menu.get_node("%ResetButton")
	button.pressed.emit()
	assert_true(menu.is_reset_armed(), "first press only arms")
	assert_eq(button.text, OptionsMenu.RESET_CONFIRM_TEXT)
	assert_eq(SaveData.new(TEST_SAVE).get_value("progress", "level", 1), 7, "nothing erased yet")
	menu.tick(menu.reset_confirm_time + 0.1)
	assert_false(menu.is_reset_armed(), "times out")
	assert_eq(button.text, OptionsMenu.RESET_TEXT)
	button.pressed.emit()
	menu.tick(1.0)
	button.pressed.emit()
	assert_eq(count[0], 1, "second press in time resets and leaves")
	assert_eq(SaveData.new(TEST_SAVE).get_value("progress", "level", 1), 1, "progress erased")
	menu.free()
	_clean()
<<<<<<< HEAD


# --- 일시정지 화면의 설정 (E40) -------------------------------------------------------

func _open_quick() -> QuickOptions:
	var quick: QuickOptions = (load("res://scenes/quick_options.tscn") as PackedScene).instantiate() as QuickOptions
	quick.save_path = TEST_SAVE
	quick.notification(Node.NOTIFICATION_READY)
	return quick


func test_quick_options_save_and_announce_changes() -> void:
	_clean()
	var quick: QuickOptions = _open_quick()
	var modes: Array[int] = []
	var motions: Array[bool] = []
	quick.control_mode_changed.connect(func(mode: OptionsStore.ControlMode) -> void: modes.append(mode))
	quick.reduce_motion_changed.connect(func(enabled: bool) -> void: motions.append(enabled))
	(quick.get_node("%DpadButton") as Button).pressed.emit()
	(quick.get_node("%DpadButton") as Button).pressed.emit()
	(quick.get_node("%ReduceMotionToggle") as CheckButton).toggled.emit(true)
	assert_eq(modes, [Mode.DPAD] as Array[int], "announced once (the second press changes nothing)")
	assert_eq(motions, [true] as Array[bool])
	assert_true((quick.get_node("%DpadButton") as Button).button_pressed)
	assert_false((quick.get_node("%SwipeButton") as Button).button_pressed)
	var saved: OptionsStore = OptionsStore.new(TEST_SAVE)
	assert_eq([saved.control_mode, saved.reduce_motion], [Mode.DPAD, true], "saved right away")
	quick.free()
	_clean()


func test_quick_options_volume_saves_when_closed() -> void:
	_clean()
	var quick: QuickOptions = _open_quick()
	var slider: HSlider = quick.get_node("%MasterVolumeSlider")
	slider.set_value_no_signal(40)
	slider.value_changed.emit(40.0)
	assert_eq((quick.get_node("%MasterVolumeLabel") as Label).text, "40")
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 100, "not saved while dragging")
	quick.save_pending()
	assert_eq(OptionsStore.new(TEST_SAVE).master_volume, 40)
	quick.free()
	OptionsStore.new(TEST_SAVE).set_master_volume(100)
	OptionsStore.new(TEST_SAVE).apply_audio()
	_clean()


func test_pause_overlay_opens_settings_and_forwards_changes() -> void:
	_clean()
	SaveData.path_override = TEST_SAVE
	var overlay: PauseOverlay = (load("res://scenes/pause_overlay.tscn") as PackedScene).instantiate() as PauseOverlay
	overlay.propagate_notification(Node.NOTIFICATION_READY)
	var modes: Array[int] = []
	overlay.control_mode_changed.connect(func(mode: OptionsStore.ControlMode) -> void: modes.append(mode))
	assert_false(overlay.is_options_open())
	(overlay.get_node("%OptionsButton") as Button).pressed.emit()
	assert_true(overlay.is_options_open(), "settings replace the pause buttons")
	(overlay.get_node("%QuickOptions/%DpadButton") as Button).pressed.emit()
	assert_eq(modes, [Mode.DPAD] as Array[int], "the change leaves the overlay as a signal")
	(overlay.get_node("%BackButton") as Button).pressed.emit()
	assert_false(overlay.is_options_open())
	overlay.free()
	SaveData.path_override = ""
	_clean()


func test_tutorial_replay_button_requests_the_rule_tutorial() -> void:
	_clean()
	var menu: OptionsMenu = _open_options()
	var asked: Array[bool] = []
	for connection: Dictionary in menu.tutorial_replay_requested.get_connections():  # 씬 전환은 트리 안에서만 (스모크)
		menu.tutorial_replay_requested.disconnect(connection["callable"])
	menu.tutorial_replay_requested.connect(func() -> void: asked.append(true))
	(menu.get_node("%TutorialButton") as Button).pressed.emit()
	assert_eq(asked, [true] as Array[bool], "goes to the game scene")
	assert_true(PlayRequest.take_replay_tutorial(), "the game scene opens as the rule tutorial")
	menu.free()
	_clean()


func test_debug_panel_skips_the_tutorial_and_asks_for_special_games() -> void:
	_clean()
	SaveData.path_override = TEST_SAVE
	TutorialStore.new().restart_all()
	var panel: DebugPanel = (load("res://scenes/debug_panel.tscn") as PackedScene).instantiate() as DebugPanel
	panel.notification(Node.NOTIFICATION_READY)
	var games: Array[bool] = []
	for connection: Dictionary in panel.game_requested.get_connections():  # 씬 전환은 트리 안에서만 (스모크)
		panel.game_requested.disconnect(connection["callable"])
	panel.game_requested.connect(func() -> void: games.append(true))
	assert_true(panel.visible, "shown in release builds too while testing")
	(panel.get_node("%UnlockMenusButton") as Button).pressed.emit()
	var tutorial: TutorialStore = TutorialStore.new()
	assert_true(tutorial.done and tutorial.flow == TutorialStore.Flow.DONE, "tutorial and flow finished")
	var unlocks: MenuUnlocks = TutorialFlow.current().unlocks()
	for entry: int in MenuUnlocks.Entry.values():
		assert_true(unlocks.is_open(entry), "entry %d open" % entry)
	(panel.get_node("%ShortGameButton") as Button).pressed.emit()
	assert_near(PlayRequest.take_game_seconds(), panel.short_game_seconds, 1e-9)
	(panel.get_node("%RuleTutorialButton") as Button).pressed.emit()
	assert_true(PlayRequest.take_replay_tutorial())
	assert_eq(games.size(), 2)
	panel.free()
	SaveData.path_override = ""
	_clean()
=======
>>>>>>> Choi
