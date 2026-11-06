extends "res://tests/smoke/smoke_base.gd"
## 설정과 조작 방법 (기획서 3.2, 8.1장). 모드: dpad | swipe
## 메뉴 → OPTIONS 실제 클릭 → 한 페이지 설정(스와이프 기본) → (dpad) 패드 실제 클릭 저장 / (swipe) 효과 줄이기 실제 클릭 저장
## → 마스터 볼륨 슬라이더 실제 클릭(저장·Master 버스 반영), 손 떼는 신호 없는 변경은 뒤로 갈 때 저장
## → 게임: 저장된 볼륨 유지
##   dpad  = 패드 판 아래 가운데, 실제 클릭 1칸, 누르고 있으면 반복, 스와이프 무시
##   swipe = 패드 숨김, 손을 떼기 전에 1칸(22px), 옆 칸 탭 1칸, 효과 줄이기가 게임에 전달됨

const Mode = OptionsStore.ControlMode

var _player_before: Vector2i = Vector2i.ZERO
var _moves_before: int = 0


func _setup() -> void:
	config.game_duration = 1000.0
	OptionsStore.new().set_control_mode(Mode.SWIPE)
	change_scene_to_file("res://scenes/main_menu.tscn")


func _master_db() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(OptionsStore.MASTER_BUS))


func _tick() -> void:
	if step <= 5:
		_tick_options()
	elif mode == "dpad":
		_tick_dpad()
	else:
		_tick_swipe()


func _tick_options() -> void:
	match step:
		0:
			if in_scene("MainMenu"):
				var options: Button = node("%OptionsButton")
				expect(options.get_global_rect().position.y > (node("%CharacterButton") as Control).get_global_rect().end.y, "설정 below the character button")
				click_control(options)
				next_step()
		1:
			if in_scene("OptionsMenu"):
				expect((node("%SwipeButton") as Button).button_pressed, "swipe selected by default")
				expect(not (node("%ReduceMotionToggle") as CheckButton).button_pressed, "reduce motion off by default")
				click_control(node("%DpadButton") if mode == "dpad" else node("%ReduceMotionToggle"))
				next_step()
		2:
			if step_time > 0.3:
				var expected: OptionsStore.ControlMode = Mode.DPAD if mode == "dpad" else Mode.SWIPE
				expect(OptionsStore.new().control_mode == expected, "saved control mode = " + mode)
				expect(OptionsStore.new().reduce_motion == (mode == "swipe"), "reduce motion click saved")
				shot("options_" + mode)
				var slider: HSlider = node("%MasterVolumeSlider")
				expect(slider.is_visible_in_tree() and slider.value == 100.0, "master volume 100 by default")
				click_control(slider)  # 가운데를 실제 클릭 → 약 50
				next_step()
		3:
			if step_time > 0.3:
				var saved: int = OptionsStore.new().master_volume
				expect(saved > 35 and saved < 65, "click on the slider middle saved about 50 (%d)" % saved)
				expect((node("%MasterVolumeLabel") as Label).text == str(saved), "label shows the value")
				expect(is_equal_approx(_master_db(), OptionsStore.volume_to_db(saved)), "Master bus follows the slider")
				(node("%MasterVolumeSlider") as HSlider).value = 30  # 손을 떼는 신호 없이 바뀜 (마우스 휠 등)
				(node("SafeArea/Content/Layout/BackButton") as Button).pressed.emit()
				next_step()
		4:
			if in_scene("MainMenu", 0.2):
				expect(OptionsStore.new().master_volume == 30, "unsaved change saved when leaving options")
				(node("%StartButton") as Button).pressed.emit()
				next_step()
		5:
			if playing():
				expect(is_equal_approx(_master_db(), OptionsStore.volume_to_db(30)), "game scene keeps the saved volume")
				var board_view: BoardView = node("BoardView")
				expect(board_view.is_reduce_motion() == (mode == "swipe"), "reduce motion reaches the board")
				_remember()
				next_step()


func _tick_dpad() -> void:
	var pad: CanvasLayer = node("VirtualDpad")
	match step:
		6:
			expect(pad.visible, "pad shown")
			var rect: Rect2 = (pad.get_node("SafeArea/Content/Pad") as Control).get_global_rect()
			var board_view: BoardView = node("BoardView")
			var board_bottom: float = board_view.global_position.y + board_view.board_extent() * board_view.scale.y / 2.0
			expect(rect.position.y >= board_bottom, "pad under the board")
			expect(absf(rect.get_center().x - root.get_visible_rect().size.x / 2.0) < 1.0, "pad centered")
			click_control(pad.get_node("SafeArea/Content/Pad/Up"))
			next_step()
		7:
			if step_time > 0.4:
				expect(session().board.player_pos - _player_before == Vector2i.UP, "pad click moved up by 1")
				shot("game_dpad")
				_remember()
				press_control(pad.get_node("SafeArea/Content/Pad/Left"))  # 누르고 있기
				next_step()
		8:
			if step_time > 0.4:
				release_mouse()
				var moved: int = session().stats.moves + session().stats.blocked_moves - _moves_before
				expect(moved >= 4, "holding the pad repeats (0.17 s, then every 0.06 s): %d moves in 0.4 s" % moved)
				_remember()
				next_step()
		9:
			if step_time > 0.3:
				expect(session().stats.moves + session().stats.blocked_moves == _moves_before, "released → repeat stops (+%d, held %s)" % [session().stats.moves + session().stats.blocked_moves - _moves_before, (node("VirtualDpad") as VirtualDpad).held_direction()])
				_remember()
				touch(Vector2(360, 600), true)  # 패드 모드에서 스와이프 시도
				next_step()
		10:
			if step_time > 0.05 and step_time < 0.1:
				drag(Vector2(360, 400))
				touch(Vector2(360, 400), false)
			if step_time > 0.4:
				expect(session().board.player_pos == _player_before, "swipe ignored in pad mode")
				finish()


func _tick_swipe() -> void:
	match step:
		6:
			expect(not (node("VirtualDpad") as CanvasLayer).visible, "pad hidden in swipe mode")
			touch(Vector2(360, 1100), true)
			next_step()
		7:
			if step_time > 0.05 and step_time < 0.1:
				drag(Vector2(360, 1070))  # 30px: 22px를 넘는 순간 이동
			if step_time > 0.3:
				expect(session().board.player_pos - _player_before == Vector2i.UP, "moved up by 1 before lifting the finger")
				touch(Vector2(360, 900), false)
				next_step()
		8:
			if step_time > 0.3:
				expect(session().board.player_pos - _player_before == Vector2i.UP, "still only 1 cell for that touch")
				shot("game_swipe")
				_remember()
				var center: Vector2 = _right_cell_center()
				expect((node("BoardView") as BoardView).cell_at(center) == _player_before + Vector2i.RIGHT, "cell_at maps the screen to the board")
				touch(center, true)
				next_step()
		9:
			if step_time > 0.05 and step_time < 0.1:
				touch(_right_cell_center(), false)
			if step_time > 0.3:
				expect(session().board.player_pos - _player_before == Vector2i.RIGHT, "tapping the right cell moved there")
				finish()


## 플레이어 오른쪽 칸 가운데의 화면(뷰포트) 위치.
func _right_cell_center() -> Vector2:
	var board_view: BoardView = node("BoardView")
	var cell_px: float = board_view.theme_data.cell_size + board_view.theme_data.cell_gap
	var target: Vector2i = _player_before + Vector2i.RIGHT
	return board_view.get_node("Cells").get_global_transform() \
		* (Vector2(target) * cell_px + Vector2.ONE * board_view.theme_data.cell_size / 2.0)


func _remember() -> void:
	_player_before = session().board.player_pos
	_moves_before = session().stats.moves + session().stats.blocked_moves
