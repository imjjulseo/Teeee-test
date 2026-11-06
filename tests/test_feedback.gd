extends "res://tests/framework/test_case.gd"
## 7장 피드백: 게임 이벤트 → 효과음 ID, 색별 문양(7.3).
## 효과음은 main.tscn의 실제 연결(채널·HUD → SfxPlayer)을 그대로 이어 붙이고 채널 signal을 보내서 확인한다.

const SceneWiring = preload("res://tests/framework/scene_wiring.gd")


## { sfx, board, hud_channel, flow, hud, ids }
func _rig() -> Dictionary:
	var sfx: SfxPlayer = (load("res://scenes/sfx_player.tscn") as PackedScene).instantiate() as SfxPlayer
	var board: BoardChannel = BoardChannel.new()
	var hud_channel: HudChannel = HudChannel.new()
	var flow: FlowChannel = FlowChannel.new()
	var hud: Hud = Hud.new()  # warning_tick signal만 쓴다 (씬 트리 불필요)
	var wired: int = SceneWiring.connect_like("res://scenes/main.tscn", {
		"SfxPlayer": sfx, "GameController/BoardChannel": board, "GameController/HudChannel": hud_channel,
		"GameController/FlowChannel": flow, "Hud": hud,
	}, PackedStringArray(["SfxPlayer"]))  # SfxPlayer가 받는 연결만 (Hud는 보내는 쪽으로만 씀)
	assert_true(wired >= 8, "sfx listens to board/hud/flow channels and hud (%d connections)" % wired)
	var ids: Array[StringName] = []
	sfx.requested.connect(func(id: StringName) -> void: ids.append(id))
	return {"sfx": sfx, "board": board, "hud_channel": hud_channel, "flow": flow, "hud": hud, "ids": ids}


func _free(rig: Dictionary) -> void:
	for key: String in ["sfx", "board", "hud_channel", "flow", "hud"]:
		(rig[key] as Node).free()


func _move_result(outcome: Board.MoveOutcome, displaced: Board.CellType) -> Board.MoveResult:
	var result: Board.MoveResult = Board.MoveResult.new(outcome, Vector2i(1, 1), Vector2i(1, 0))
	result.displaced_type = displaced
	return result


func test_sfx_cues_for_game_events() -> void:
	var rig: Dictionary = _rig()
	var board: BoardChannel = rig["board"]
	var flow: FlowChannel = rig["flow"]
	board.move_started.emit(_move_result(Board.MoveOutcome.SWAPPED, Board.CellType.COLOR_BLOCK))
	board.move_started.emit(_move_result(Board.MoveOutcome.MOVED, Board.CellType.EMPTY))
	board.move_blocked.emit(_move_result(Board.MoveOutcome.BLOCKED_BY_WALL, Board.CellType.EMPTY))
	board.matched.emit(Vector2i(2, 2), 1, [] as Array[Vector2i])
	board.cells_refilled.emit([Vector2i(1, 1)] as Array[Vector2i])
	(rig["hud"] as Hud).warning_tick.emit()
	(rig["hud_channel"] as HudChannel).ability_triggered.emit(null, "")
	flow.state_changed.emit(GameFlow.GameState.PLAYING)  # 효과음 없음
	flow.time_up.emit()
	assert_eq(rig["ids"], [SfxPlayer.SWAP, SfxPlayer.MOVE, SfxPlayer.WALL, SfxPlayer.MATCH, SfxPlayer.REFILL,
		SfxPlayer.TICK, SfxPlayer.ABILITY, SfxPlayer.TIME_UP] as Array[StringName])
	_free(rig)


func test_recipe_complete_cue_only_on_completion() -> void:
	var rig: Dictionary = _rig()
	var hud_channel: HudChannel = rig["hud_channel"]
	var recipes: RecipeSet = RecipeSet.from_config(make_config(), RandomNumberGenerator.new(),
		func() -> PackedInt32Array: return PackedInt32Array([20, 20, 20, 20]))
	var progressed: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	progressed.advanced_slots.append(0)
	hud_channel.recipes_updated.emit(recipes, progressed)
	assert_eq((rig["ids"] as Array).size(), 0, "progress alone has no cue")
	var completed: RecipeSet.ClearOutcome = RecipeSet.ClearOutcome.new()
	completed.completed_slots.append(1)
	completed.points = 600
	hud_channel.recipes_updated.emit(recipes, completed)
	assert_eq(rig["ids"], [SfxPlayer.RECIPE_COMPLETE] as Array[StringName])
	_free(rig)


func test_missing_sound_is_silent_placeholder() -> void:
	var sfx: SfxPlayer = (load("res://scenes/sfx_player.tscn") as PackedScene).instantiate() as SfxPlayer
	assert_true(sfx.sounds.is_empty(), "no audio assets yet (B17)")
	sfx.play(SfxPlayer.MATCH)  # 음원이 없으면 오류 없이 넘어간다
	assert_false(sfx.is_playing(SfxPlayer.MATCH))
	sfx.free()


func test_each_color_has_a_distinct_glyph() -> void:
	var theme_data: BoardTheme = load("res://resources/board_theme.tres") as BoardTheme
	var shapes: Array[int] = []
	for color: int in 4:
		var shape: GlyphView.Shape = theme_data.glyph_for(color)
		assert_ne(shape, GlyphView.Shape.NONE, "color %d has a glyph" % color)
		assert_false(shapes.has(shape), "color %d glyph is unique" % color)
		shapes.append(shape)
	assert_eq(theme_data.glyph_for(Board.NO_COLOR), GlyphView.Shape.NONE)
