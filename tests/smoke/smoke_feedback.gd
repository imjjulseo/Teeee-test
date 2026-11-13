extends "res://tests/smoke/smoke_base.gd"
## 피드백: 실제 입력 경로 스와이프 → 매치 → 족보 완성 "+점수" 팝업, 효과음 요청 순서, 모든 칸 문양,
## 씨앗 칸은 자랄 색을 숨기고 대기 뒤 중앙에서 차오름, 일시정지 버튼 실제 클릭은 이동이 아님,
## 일시정지 → 설정에서 조작을 패드로 바꾸면 계속한 판에 바로 패드가 나옴 (E40). 모드: run / audio

var _sfx: Array[StringName] = []
var _growth_before: float = 0.0
var _points: int = 0
var _start: Vector2i = Vector2i.ZERO


func _setup() -> void:
	config.game_duration = 1000.0
	CharacterStore.new().select(&"basic")
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.SWIPE)
	change_scene_to_file("res://scenes/main.tscn")


func _tick() -> void:
	if mode == "audio":
		_tick_audio()
		return
	match step:
		0:
			if playing():
				(node("SfxPlayer") as SfxPlayer).requested.connect(func(id: StringName) -> void: _sfx.append(id))
				prepare_match_above(1)
				_points = prime_recipe(0, 1)
				_start = session().board.player_pos
				touch(Vector2(540, 1500), true)
				next_step()
		1:
			drag(Vector2(555, 1320))  # 위로 180px → 손을 떼기 전에 UP
			touch(Vector2(555, 1320), false)
			next_step()
		2:
			if step_time > 0.3:
				expect(session().board.player_pos == _start + Vector2i.UP, "swipe up moved player")
				expect(session().score == _points, "recipe completed via swipe")
				expect(_floating_texts().has("+%d" % _points), "+%d flies to the score (%s)" % [_points, _floating_texts()])
				expect(_sfx == ([SfxPlayer.SWAP, SfxPlayer.MATCH, SfxPlayer.RECIPE_COMPLETE] as Array[StringName]), "sfx order %s" % [_sfx])
				expect(_glyphs_match(), "every glyph matches its color")
				expect(_seeds_hidden(), "seed cells hide their next color")
				_growth_before = _max_growth()
				shot("match")
				next_step()
		3:
			if step_time > 4.0:  # 대기 3초 뒤 자라기 시작 (리필 총 8초 = 대기 3 + 자람 5)
				expect(_growth_before < 0.001, "no growth while waiting (%.3f)" % _growth_before)  # Control 배율은 0이 아니라 최소 1e-5로 잘린다
				expect(_max_growth() > 0.1, "growth fills over time")
				auto_resume = false
				click_control(node("Hud/%PauseButton"))
				next_step()
		4:
			if step_time > 0.4:
				expect(flow().state == S.PAUSED, "pause button click → PAUSED")
				expect(session().board.player_pos == _start + Vector2i.UP, "button click did not move")
				click_control(node("PauseOverlay/%OptionsButton"))
				next_step()
		5:
			if step_time > 0.3:
				expect((node("PauseOverlay") as PauseOverlay).is_options_open(), "settings open inside the pause screen")
				expect((node("PauseOverlay/%QuickOptions/%SwipeButton") as Button).button_pressed, "shows the saved control mode")
				shot("pause_options")
				click_control(node("PauseOverlay/%QuickOptions/%DpadButton"))
				next_step()
		6:
			if step_time > 0.3:
				expect(OptionsStore.new().control_mode == OptionsStore.ControlMode.DPAD, "pad saved")
				expect(flow().state == S.PAUSED, "still paused while changing settings")
				click_control(node("PauseOverlay/%BackButton"))
				next_step()
		7:
			if step_time > 0.3:
				expect(not (node("PauseOverlay") as PauseOverlay).is_options_open(), "back to the pause buttons")
				click_control(node("PauseOverlay/Center/ResumeButton"))
				next_step()
		8:
			if step_time > 0.4:
				expect(flow().state == S.PLAYING, "resumed")
				expect((node("VirtualDpad") as VirtualDpad).visible, "pad shows in the same game")
				expect((node("InputRouter") as InputRouter).control_mode == OptionsStore.ControlMode.DPAD, "input follows the new mode")
				shot("pad_after_pause")
				finish()


func _floating_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in node("Hud/%Floats").get_children():
		if child is FloatingText:
			texts.append((child as FloatingText).text)
	return texts


func _views() -> Dictionary:
	return (node("BoardView") as BoardView).get("_views")


func _glyphs_match() -> bool:
	var board: Board = session().board
	var theme_data: BoardTheme = (node("BoardView") as BoardView).theme_data
	for pos: Vector2i in _views():
		var expected: GlyphView.Shape = GlyphView.Shape.NONE
		if board.get_cell_type(pos) == Board.CellType.COLOR_BLOCK:
			expected = theme_data.glyph_for(board.get_color(pos))
		if (_views()[pos] as CellView).glyph_shape() != expected:
			return false
	return true


func _seeds_hidden() -> bool:
	var board: Board = session().board
	var theme_data: BoardTheme = (node("BoardView") as BoardView).theme_data
	var count: int = 0
	for pos: Vector2i in _views():
		if board.get_cell_type(pos) != Board.CellType.SEED:
			continue
		count += 1
		var cell: CellView = _views()[pos]
		if not (cell.get_node("Fill") as ColorRect).color.is_equal_approx(theme_data.seed_base_color) or cell.glyph_shape() != GlyphView.Shape.NONE:
			return false
	return count == 4


func _max_growth() -> float:
	var best: float = 0.0
	for pos: Vector2i in _views():
		if session().board.get_cell_type(pos) == Board.CellType.SEED:
			best = maxf(best, (_views()[pos] as CellView).growth_progress())
	return best


## 모드 audio: 같은 프레임의 매치음 + 족보 완성음이 둘 다 재생되는지 (예전 단일 플레이어면 하나가 끊김).
func _tick_audio() -> void:
	match step:
		0:
			if playing():
				var sfx: SfxPlayer = node("SfxPlayer")
				sfx.sounds = {SfxPlayer.MATCH: _tone(660.0), SfxPlayer.RECIPE_COMPLETE: _tone(990.0)}
				prepare_match_above(1)
				_points = prime_recipe(0, 1)
				flow().request_move(Vector2i.UP)
				next_step()
		1:
			if session().score == _points:
				var sfx: SfxPlayer = node("SfxPlayer")
				expect(sfx.is_playing(SfxPlayer.MATCH), "match sound playing")
				expect(sfx.is_playing(SfxPlayer.RECIPE_COMPLETE), "recipe sound playing at the same time")
				expect(sfx.get_player(SfxPlayer.MATCH).bus == &"SFX", "routed to SFX bus")
				var sfx_bus: int = AudioServer.get_bus_index(&"SFX")
				expect(sfx_bus > 0 and AudioServer.get_bus_send(sfx_bus) == &"Master", "SFX bus → Master")
				finish()


func _tone(hz: float) -> AudioStreamWAV:
	var rate: int = 22050
	var samples: int = int(rate * 0.6)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	for i: int in samples:
		data.encode_s16(i * 2, int(sin(TAU * hz * i / rate) * 6000.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream