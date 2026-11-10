extends "res://tests/framework/test_case.gd"
## View 종류별 이벤트 채널: main.tscn 연결 구조와 bind() 동작.

const CHANNELS: Dictionary = {
	"GameController/BoardChannel": ["BoardView", "SfxPlayer"],
	"GameController/HudChannel": ["Hud", "SfxPlayer", "EffectBackground"],
	"GameController/FlowChannel": ["InputRouter", "BoardView", "Hud", "VirtualDpad", "LayoutLayer/GameLayout/SafeArea/Column/DpadSpace", "PauseOverlay", "ResultPanel", "RevivePanel", "SfxPlayer", "MenuNavigator", "CharacterNavigator", "ShopNavigator", "TutorialNavigator", "EffectBackground"],
}


func _connections() -> Array[Dictionary]:
	var state: SceneState = (load("res://scenes/main.tscn") as PackedScene).get_state()
	var result: Array[Dictionary] = []
	for i: int in state.get_connection_count():
		result.append({
			"source": String(state.get_connection_source(i)),
			"signal": String(state.get_connection_signal(i)),
			"target": String(state.get_connection_target(i)),
		})
	return result


func test_no_view_listens_to_game_controller_directly() -> void:
	for c: Dictionary in _connections():
		assert_ne(c["source"], "GameController", "%s → %s must go through a channel" % [c["signal"], c["target"]])


func test_each_channel_only_feeds_its_views() -> void:
	for c: Dictionary in _connections():
		if CHANNELS.has(c["source"]):
			assert_true((CHANNELS[c["source"]] as Array).has(c["target"]),
				"%s.%s → %s is outside the channel's views" % [c["source"], c["signal"], c["target"]])


func test_every_channel_signal_is_connected() -> void:
	var connected: Dictionary = {}
	for c: Dictionary in _connections():
		connected["%s.%s" % [c["source"], c["signal"]]] = true
	var scripts: Dictionary = {
		"GameController/BoardChannel": BoardChannel, "GameController/HudChannel": HudChannel,
		"GameController/FlowChannel": FlowChannel,
	}
	for path: String in scripts:
		for info: Dictionary in (scripts[path] as Script).get_script_signal_list():
			assert_true(connected.has("%s.%s" % [path, info["name"]]), "%s.%s has no listener" % [path, info["name"]])


func _rng() -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	return rng


func test_board_channel_bind_relays_session_events() -> void:
	var channel: BoardChannel = BoardChannel.new()
	var got: Array[String] = []
	channel.character_ready.connect(func(_c: CharacterData) -> void: got.append("character"))
	channel.board_created.connect(func(_b: Board) -> void: got.append("board"))
	channel.move_started.connect(func(_r: Board.MoveResult) -> void: got.append("move"))
	var session: GameSession = GameSession.new(make_config(), _rng())
	channel.bind(session, null)
	assert_eq(got, ["character", "board"] as Array[String], "initial state: look before board")
	session.request_move(Vector2i.UP)
	assert_eq(got.back(), "move")
	channel.free()


func test_hud_channel_publishes_only_when_displayed_values_change() -> void:
	var channel: HudChannel = HudChannel.new()
	var times: Array[float] = []
	var statuses: Array[String] = []
	var effects: Array[float] = []
	channel.time_updated.connect(func(remaining: float, _fraction: float, _stopped: bool) -> void: times.append(remaining))
	channel.ability_status.connect(func(text: String) -> void: statuses.append(text))
	channel.effect_updated.connect(func(_accent: Color, _block: int, remaining: float, _window: float) -> void: effects.append(remaining))
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var clock: CharacterData = roster.find(&"clock")
	var session: GameSession = GameSession.new(make_config(), _rng(), null, clock)
	channel.bind(session, clock)
	session.request_move(Vector2i.UP)  # 첫 이동으로 시계 시작
	times.clear()
	statuses.clear()
	effects.clear()
	for _i: int in 480:  # 240fps로 2초
		session.advance(1.0 / 240.0)
		channel.publish_frame(session)
	assert_true(times.size() >= 15 and times.size() <= 30, "~10 time updates/s instead of 480 (%d)" % times.size())
	assert_eq("%.1f" % times.back(), "%.1f" % session.remaining_time(), "last shown time equals what the HUD would show now")
	assert_eq(statuses.size(), 0, "no ability status change → nothing sent")
	assert_eq(effects.size(), 0, "no effect change → nothing sent")
	for color: int in [2, 3, 2]:
		session.advance_ability_condition(color)  # 시계공 정지 발동
	for _i: int in 240:  # 1초
		session.advance(1.0 / 240.0)
		channel.publish_frame(session)
	assert_true(statuses.size() >= 8 and statuses.size() <= 12, "stop countdown ~10 updates/s (%d)" % statuses.size())
	assert_eq(statuses.back(), "3초", "card status shows remaining stop")
	assert_true(effects.size() >= 90 and effects.size() <= 105, "background effect follows the countdown (%d)" % effects.size())
	assert_near(effects.back(), 3.0, 0.01)
	session.advance(3.5)
	channel.publish_frame(session)
	assert_eq(statuses.back(), "", "stop ended → card shows the ability name again")
	assert_true(effects.back() < 0.0, "effect off")
	channel.free()


func test_hud_channel_bind_sends_initial_state_and_frames() -> void:
	var channel: HudChannel = HudChannel.new()
	var got: Dictionary = {}
	channel.recipes_updated.connect(func(_r: RecipeSet, _o: RecipeSet.ClearOutcome) -> void: got["recipes"] = true)
	channel.score_changed.connect(func(s: int) -> void: got["score"] = s)
	channel.ability_updated.connect(func(r: RecipeSet.Recipe, _c: CharacterData) -> void: got["ability_recipe"] = r)
	channel.coins_updated.connect(func(total: int, _amount: int, _chain: int) -> void: got["coins"] = total)
	channel.time_updated.connect(func(remaining: float, fraction: float, stopped: bool) -> void:
		got["fraction"] = fraction
		got["time"] = remaining
		got["stopped"] = stopped)
	channel.ability_status.connect(func(text: String) -> void: got["status"] = text)
	channel.effect_updated.connect(func(_accent: Color, _block: int, remaining: float, _window: float) -> void: got["effect"] = remaining)
	var session: GameSession = GameSession.new(make_config(), _rng())
	channel.bind(session, null)
	assert_true(got.has("recipes"))
	assert_eq(got["score"], 0)
	assert_eq(got["ability_recipe"], null, "no ability for null character")
	assert_near(got["time"], 60.0)
	assert_near(got["fraction"], 1.0, 1e-9, "full time bar")
	assert_eq(got["coins"], 0)
	assert_eq(got["stopped"], false)
	assert_eq(got["status"], "")
	assert_true(float(got["effect"]) < 0.0, "no background effect")
	channel.free()


func test_hud_channel_relays_ability_trigger_and_bonus_score() -> void:
	var channel: HudChannel = HudChannel.new()
	var roster: CharacterRoster = load("res://resources/character_roster.tres")
	var fever: CharacterData = roster.find(&"fever")
	var session: GameSession = GameSession.new(make_config(), _rng(), null, fever)
	var got: Array = []
	channel.ability_triggered.connect(func(c: CharacterData, message: String) -> void: got.append([c, message]))
	channel.bonus_scored.connect(func(points: int, label: String) -> void: got.append([points, label]))
	channel.effect_updated.connect(func(color: Color, _block: int, remaining: float, _window: float) -> void:
		if remaining >= 0.0:
			got.append(color))
	channel.bind(session, fever)
	session.start()
	for color: int in fever.condition_colors:
		session.advance_ability_condition(color)
	channel.publish_frame(session)
	session.add_bonus_score(750, "피버 5스택!")
	assert_eq(got, [[fever, "피버 10초"], fever.accent_color, [750, "피버 5스택!"]])
	channel.free()

func test_hud_channel_relays_time_gained_and_coins() -> void:
	var channel: HudChannel = HudChannel.new()
	var board: Board = Board.new(5)
	for pos: Vector2i in board.all_positions():
		board.set_color_block(pos, 0)
	for pos: Vector2i in [Vector2i(2, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(3, 2)]:
		board.set_color_block(pos, 1)
	board.set_player(Vector2i(2, 3))
	board.get_cell(Vector2i(2, 1)).attach_coin(15.0)
	var config: GameConfig = make_config()
	config.board_size = 5
	var session: GameSession = GameSession.new(config, _rng(), board)
	var gained: Array[float] = []
	var coins: Array = []
	channel.time_gained.connect(func(seconds: float) -> void: gained.append(seconds))
	channel.coins_updated.connect(func(total: int, amount: int, chain: int) -> void: coins.append([total, amount, chain]))
	channel.bind(session, null)
	session.request_move(Vector2i.UP)  # 매치 + 금화 1개
	assert_eq(gained, [2.5] as Array[float])
	assert_eq(coins, [[0, 0, 0], [10, 10, 1]], "initial total, then the pickup")
	channel.free()
