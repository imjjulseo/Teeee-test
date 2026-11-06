extends "res://tests/smoke/smoke_base.gd"
## 화면 비율·안전 영역별 배치. 창 크기는 --resolution으로 준다. 모드: plain | notch (가상 노치 위 90 / 아래 40)
## 조작은 가상 방향키(가장 빡빡한 배치)로 확인한다.
## 예: godot --path . --resolution 360x780 -s tests/smoke/smoke_layout.gd -- notch

const NOTCH: Vector4 = Vector4(0, 90, 0, 40)


func _setup() -> void:
	if mode == "notch":
		SafeArea.debug_insets = NOTCH
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.DPAD)
	change_scene_to_file("res://scenes/main.tscn")


func _tick() -> void:
	match step:
		0:
			if in_scene("Main", 0.8):
				_check_game()
				var vp: Vector2 = root.get_visible_rect().size
				shot("%dx%d_%s" % [vp.x, vp.y, mode])
				controller = null
				change_scene_to_file("res://scenes/character_select.tscn")
				next_step()
		1:
			if in_scene("CharacterSelect", 0.4):
				_inside_safe("SafeArea/Content/Layout/Header", "character title and wallet")
				_inside_safe("SafeArea/Content/Layout/Scroll", "character cards")
				_inside_safe("SafeArea/Content/Layout/BackButton", "character back")
				change_scene_to_file("res://scenes/options.tscn")
				next_step()
		2:
			if in_scene("OptionsMenu", 0.4):
				_inside_safe("SafeArea/Content/Layout/Title", "options title")
				_inside_safe("SafeArea/Content/Layout/BackButton", "options back")
				change_scene_to_file("res://scenes/main_menu.tscn")
				next_step()
		3:
			if in_scene("MainMenu", 0.4):
				_inside_safe("SafeArea/Content/TopBar", "menu level and wallet")
				_inside_safe("SafeArea/Content/BottomBar", "menu bottom buttons")
				var center: Rect2 = (node("SafeArea/Content/Center") as Control).get_global_rect()
				expect(center.position.y >= (node("SafeArea/Content/TopBar") as Control).get_global_rect().end.y, "menu center below the top bar")
				expect(center.end.y <= (node("SafeArea/Content/BottomBar") as Control).get_global_rect().position.y, "menu center above the bottom bar")
				change_scene_to_file("res://scenes/level_rewards.tscn")
				next_step()
		4:
			if in_scene("LevelRewards", 0.4):
				_inside_safe("SafeArea/Content/Layout/Title", "level rewards title")
				_inside_safe("SafeArea/Content/Layout/BackButton", "level rewards back")
				finish()


func _safe_rect() -> Rect2:
	var vp: Rect2 = root.get_visible_rect()
	var i: Vector4 = SafeArea.debug_insets
	return Rect2(vp.position + Vector2(i.x, i.y), vp.size - Vector2(i.x + i.z, i.y + i.w))


func _inside_safe(path: String, what: String) -> void:
	var r: Rect2 = (node(path) as Control).get_global_rect()
	expect(_safe_rect().grow(0.5).encloses(r), "%s inside safe area" % what)


func _check_game() -> void:
	var vp: Vector2 = root.get_visible_rect().size
	var board: BoardView = node("BoardView")
	var half: float = board.board_extent() * board.scale.x / 2.0
	var board_rect: Rect2 = Rect2(board.global_position - Vector2.ONE * half, Vector2.ONE * half * 2.0)
	var recipes: Rect2 = (node("Hud/SafeArea/Content/Recipes") as Control).get_global_rect()
	var pad: Rect2 = (node("VirtualDpad/SafeArea/Content/Pad") as Control).get_global_rect()
	var area: Rect2 = (node("LayoutLayer/GameLayout/SafeArea/Column/BoardArea") as Control).get_global_rect()
	print("  viewport %s board %s scale %.2f" % [vp, board_rect, board.scale.x])
	expect(board.scale.x > 0.5, "board visible (scale %.2f)" % board.scale.x)
	expect(absf(board.global_position.x - vp.x / 2.0) < 1.0, "board centered")
	expect(area.grow(0.5).encloses(board_rect), "board inside BoardArea")
	expect(board_rect.position.y >= recipes.end.y, "board below recipes")
	expect(board_rect.end.y <= pad.position.y, "board above d-pad")
	expect(absf(pad.get_center().x - vp.x / 2.0) < 1.0, "d-pad centered")
	_inside_safe("Hud/SafeArea/Content/TopRow/PauseButton", "pause button")
	_inside_safe("Hud/SafeArea/Content/TopRow", "score/coins/time")
	_inside_safe("Hud/SafeArea/Content/TimeBar", "time bar")
	_inside_safe("Hud/SafeArea/Content/MessageLabel", "message line")
	var message: Rect2 = (node("Hud/SafeArea/Content/MessageLabel") as Control).get_global_rect()
	expect(message.position.y >= pad.end.y, "message line below the d-pad")
	_inside_safe("Hud/SafeArea/Content/Recipes", "recipes")
	_inside_safe("VirtualDpad/SafeArea/Content/Pad", "d-pad")
