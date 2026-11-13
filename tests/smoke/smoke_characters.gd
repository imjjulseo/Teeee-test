extends "res://tests/smoke/smoke_base.gd"
## 캐릭터 선택과 능력 (기획서 5.2장). 모드:
<<<<<<< HEAD
## - select : 메인 → 블록 → 캐릭터 정보, 등급순 32명, 능력명·족보·설명, 히든은 가림, 화살표, 다시 누르면 메인
=======
## - select : 메인 → 블럭 → 캐릭터 정보, 등급순 32명, 능력명·족보·설명, 히든은 가림, 화살표, 다시 누르면 메인
>>>>>>> Choi
## - basic / gardener / clock / gambler / fever / joker : 해당 캐릭터로 게임, 실제 매치로 능력 발동
##   → 배너("이름!"), 메시지 줄 결과 문구, 캐릭터 카드 둘째 줄 상태, 배경 효과, 그리고 능력별 후속 확인

var _snap: Variant
var _points: int = 0


func _setup() -> void:
	config.game_duration = 1000.0
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.SWIPE)
	if mode == "select":
		CharacterStore.new().select(&"basic")
		change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		ProgressStore.new().unlock(StringName(mode))  # 해금한 캐릭터만 장착된다
		CharacterStore.new().select(StringName(mode))
		change_scene_to_file("res://scenes/main.tscn")


func _tick() -> void:
	if mode == "select":
		_tick_select()
	elif mode == "basic":
		_tick_basic()
	elif PASSIVE_MODES.has(mode):
		_tick_passive()
	else:
		_tick_ability()


## 상시형 캐릭터: 카드(족보 없이 상태), 판 위 표시·배경 효과, 실제 이동으로 능력 확인.
const PASSIVE_MODES: PackedStringArray = ["twins", "artisan", "wall", "marathon", "bounty", "navigator", "explorer", "wanderer", "mirror", "arson", "racer", "pachy", "ambi"]


func _tick_passive() -> void:
	match step:
		0:
			if playing():
				var card: RecipeView = node("Hud/%AbilityView")
				expect(card.visible, "character card shown")
				expect((card as RecipeView).shown_step_count() == 0, "passive card has no recipe steps")
				expect(_card() == session().ability.status_text(), "card shows the status (%s)" % _card())
				expect(_recipes_fit(), "cards fit on screen")
				_check_passive_start()
				shot(mode)
				next_step()
		1:
			_check_passive_followup()


func _marks() -> Array[BoardMark]:
	return (node("BoardView/Marks") as BoardMarksView).marks()


func _check_passive_start() -> void:
	match mode:
		"artisan":
			expect(not (node("Hud/%Recipe2") as Control).visible, "only two recipe cards")
			expect((node("Hud/%Recipe0") as RecipeView).shown_step_count() == 3, "3-step recipe")
		"marathon":
			expect(_marks().size() == 2 and _marks()[0].rect.position == Vector2i(0, 0), "flag at the top-left + next flag drawn")
		"explorer":
			expect(_marks().size() == 1 and _marks()[0].kind == BoardMark.Kind.ZONE, "zone drawn")
		"bounty":
			_snap = (session().ability as BountyAbility).bounty_color
		"arson":
			expect(session().board.count_color_blocks(1) == 1, "one fire to start")
		"ambi":
			expect(session().board.count_type(Board.CellType.PLAYER) == 2, "two players")
			expect(_views_show_board(), "both players drawn")


func _check_passive_followup() -> void:
	match mode:
		"ambi":
			# 실제 키: 방향키 = 오른손, WASD = 왼손
			var board: Board = session().board
			if _snap == null:
				_snap = [board.player_position(0), board.player_position(1)]
				press_key(KEY_UP)
				press_key(KEY_S)
			elif step_time > 0.3:
				expect(board.player_position(1) == (_snap[1] as Vector2i) + Vector2i.UP, "arrow key moved the right player")
				expect(board.player_position(0) == (_snap[0] as Vector2i) + Vector2i.DOWN, "WASD moved the left player")
				shot("ambi")
				finish()
		"racer":
			if _snap == null:
				_snap = session().board.player_pos
				press_key(KEY_UP)  # 방향만 바꾼다
				expect(session().board.player_pos == _snap, "input only steers")
			elif step_time > 0.45:
				expect(session().board.player_pos.y <= int((_snap as Vector2i).y) - 2, "kept running up by itself (%s)" % session().board.player_pos)
				finish()
		"pachy":
			# 실제 스와이프: 오른쪽으로 밀고 손가락을 떼지 않으면 돌진
			if _snap == null:
				_snap = session().board.player_pos
				touch(Vector2(300, 1725), true)
			elif _snap is Vector2i and step_time > 0.05 and step_time < 0.2:
				drag(Vector2(360, 1725))
				_snap = [_snap]
			elif _snap is Array and step_time > 0.8:
				var pachy: PachyAbility = session().ability as PachyAbility
				var start: Vector2i = _snap[0]
				expect(session().board.player_pos.x >= start.x + 2 or pachy.headbutts > 0, "held swipe dashed (%s from %s)" % [session().board.player_pos, start])
				touch(Vector2(360, 1725), false)
				_snap = "released"
				step_time = 0.0
			elif _snap is String and step_time > 0.4:
				expect(not (session().ability as PachyAbility).dashing, "lifting the finger stops the dash")
				finish()
		"arson":
			if _snap == null:
				_snap = "started"
				flow().request_move(Vector2i.UP)
			elif step_time > 3.2:
				expect(not _marks().is_empty() and _marks()[0].kind == BoardMark.Kind.WARN, "spread warning drawn")
				shot("arson_warn")
				finish()
		"bounty":
			# 첫 이동으로 시계가 흐르면 배경이 현상금 색이 된다.
			if _snap is int:
				flow().request_move(Vector2i.UP)
				_snap = "moved"
			elif step_time > 0.5:
				var color: Color = (node("BoardView") as BoardView).theme_data.color_for((session().ability as BountyAbility).bounty_color)
				expect(_effect().is_effect_on() and _effect().effect_color().is_equal_approx(color), "background in the bounty color")
				shot("bounty_playing")
				finish()
		"mirror":
			var mirror: MirrorAbility = session().ability as MirrorAbility
			if _snap == null:
				for _i: int in session().board.player_pos.x + 1:  # 왼쪽 벽까지 간 뒤 한 번 더 → 거울세계
					flow().request_move(Vector2i.LEFT)
				_snap = "passed"
			elif step_time > 0.4:
				expect(mirror.in_mirror, "mirror world")
				expect(session().board.player_pos.x == session().board.size - 1, "player on the right edge")
				expect(_views_show_board(), "board redrawn after the flip")
				expect(_card() == "거울세계", "card status (%s)" % _card())
				var recipe: RecipeSet.Recipe = session().recipes.recipes[2]
				var first: Panel = node("Hud/%Recipe2").get_node("%Steps").get_child(0)
				var first_color: Color = (first.get_theme_stylebox("panel") as StyleBoxFlat).bg_color
				var last: Color = _theme().color_for(recipe.colors[recipe.length() - 1])
				expect(Color(first_color.r, first_color.g, first_color.b).is_equal_approx(Color(last.r, last.g, last.b)), "recipe card shown reversed")
				expect(_effect().is_effect_on(), "mirror background")
				shot("mirror_world")
				finish()
		"navigator":
			if _snap == null:
				var board: Board = session().board
				for _i: int in board.player_pos.x + 1:  # 왼쪽 벽까지 간 뒤 한 번 더 → 반대편
					flow().request_move(Vector2i.LEFT)
				_snap = board.player_pos
			elif step_time > 0.5:
				var board: Board = session().board
				expect(session().stats.blocked_moves == 0, "never blocked by the wall")
				expect(int(_snap.x) == board.size - 1, "came out on the right edge (%s)" % _snap)
				var view: BoardView = node("BoardView")
				var player_view: CellView = view.get("_views")[board.player_pos]
				var step_px: float = view.theme_data.cell_size + view.theme_data.cell_gap
				expect(player_view.position.is_equal_approx(Vector2(board.player_pos) * step_px), "player drawn on its cell after wrapping")
				finish()
		"wall":
			if _snap == null:
				_prepare_wall_match(2)
				_snap = session().match_count
				flow().request_move(Vector2i.LEFT)
			elif step_time > 0.4:
				expect(session().match_count == int(_snap) + 1, "3-cell match against the wall")
				expect(session().board.count_type(Board.CellType.SEED) == 3, "three seeds")
				shot("wall_match")
				finish()
		_:
			finish()


## 플레이어를 왼쪽 벽 바로 옆으로 옮기고, 벽 칸으로 들어가면 위·아래·오른쪽이 color가 되게 칠한다.
func _prepare_wall_match(color: int) -> void:
	var board: Board = session().board
	while board.player_pos.x > 1:
		board.try_move(Vector2i.LEFT)  # 판만 옮긴다 (스모크 준비용, 매치·통계 없음)
	var y: int = board.player_pos.y
	for pos: Vector2i in [Vector2i(0, y - 1), Vector2i(0, y + 1), Vector2i(0, y)]:
		board.set_color_block(pos, color)
	for pos: Vector2i in [Vector2i(1, y - 1), Vector2i(1, y + 1)]:  # 우연한 4칸 매치가 아니게
		board.set_color_block(pos, (color + 1) % 4)
	redraw_board()


## 메인 → 캐릭터 화면. 장착·체험은 smoke_menu sheet, 끌어서 넘기기는 smoke_scroll characters · flick.
func _tick_select() -> void:
	var select: CharacterSelect = current_scene as CharacterSelect
	match step:
		0:
			if in_scene("MainMenu"):
				expect((node("%BottomNav") as BottomNav).block().shown_letter() == "기", "the block shows the equipped character")
				click_control(node("%BottomNav/%BlockGesture"))
				next_step()
		1:
			if in_scene("CharacterSelect", 0.7):
				var page: CharacterInfo = select.carousel().current_page()
				expect(select.shown_character().id == &"basic", "starts on the equipped character")
				expect(page.shown_actions() == PackedStringArray(["장착 중"]), "basic: equipped, no tutorial (%s)" % [page.shown_actions()])
				expect((page.block() as Control).modulate.a == 1.0, "block rise finished")
				shot("select_start")
				select.show_character(&"gardener")
				next_step()
		2:
			if step_time > 0.2:
				var page: CharacterInfo = select.carousel().current_page()
				expect(page.character.id == &"gardener", "gardener page")
<<<<<<< HEAD
				expect(page.shown_actions() == PackedStringArray(["미보유", "튜토리얼 / 체험"]), "unowned (%s)" % [page.shown_actions()])
=======
				expect(page.shown_actions() == PackedStringArray(["미보유", "튜토리얼 및 체험"]), "unowned (%s)" % [page.shown_actions()])
>>>>>>> Choi
				expect((page.get_node("%EffectLabel") as Label).text == page.character.detail_effect, "effect detail shown")
				expect((page.get_node("%AbilityName") as Label).text == "촉진" and (page.get_node("%AbilityKind") as Label).text == "족보형", "ability name and kind")
				var condition: RecipeView = page.get_node("%SheetCondition")
				expect(condition.visible and condition.shown_step_count() == 2 and not (condition.get_node("%PointsLabel") as Control).visible, "the recipe card, without the ability name")
				expect(page.get_global_rect().end.y <= (node("%BottomNav") as Control).get_global_rect().position.y + 0.5, "page above the nav")
				shot("select_sheet")
				select.show_character(&"wall")
				next_step()
		3:
			if step_time > 0.2:
				var page: CharacterInfo = select.carousel().current_page()
				expect((page.get_node("%AbilityKind") as Label).text == "상시형" and not (page.get_node("%SheetCondition") as Control).visible, "passive: no recipe")
				select.show_character(&"racer")
				next_step()
		4:
			if step_time > 0.2:
				var page: CharacterInfo = select.carousel().current_page()
				expect((page.get_node("%SheetNameLabel") as Label).text == "???" and (page.get_node("%HiddenNote") as Control).visible, "hidden stays veiled")
<<<<<<< HEAD
				expect(not (page.get_node("%AbilityBox") as Control).visible and not (page.get_node("%EffectLabel") as Control).visible and not (page.get_node("%LessonButton") as Control).visible, "no ability, no trial")
=======
				expect(not (page.get_node("%EffectBox") as Control).visible and not (page.get_node("%LessonButton") as Control).visible, "no ability, no trial")
>>>>>>> Choi
				shot("select_hidden")
				for character: CharacterData in select.collection.sorted():
					select.show_character(character.id)  # 32명 모두 그려진다
				expect(select.shown_character() == select.collection.sorted().back(), "32 pages")
				click_control(node("%BottomNav/%BlockGesture"))
				next_step()
		5:
			if in_scene("MainMenu"):
				finish()

func _tick_basic() -> void:
	if step == 0 and playing():
		expect(not (node("Hud/%AbilityView") as Control).visible, "no character card")
		expect((node("Hud/%Recipe0") as RecipeView).step_size() == (node("Hud/%Recipe0") as RecipeView).theme_data.recipe_step_size, "normal step size")
		expect(not (node("EffectBackground") as EffectBackground).is_effect_on(), "no background effect")
		shot("basic")
		finish()


## 캐릭터 족보를 마지막 1칸만 남기고, 그 색으로 실제 매치를 일으킨다.
func _trigger_by_match() -> void:
	var colors: PackedInt32Array = session().character.condition_colors
	session().ability_recipe.progress = colors.size() - 1
	controller.hud_channel.ability_updated.emit(session().ability_recipe, session().character)
	prepare_match_above(colors[colors.size() - 1])
	flow().request_move(Vector2i.UP)


func _hud() -> Hud:
	return node("Hud") as Hud


## 캐릭터 카드 둘째 줄.
func _card() -> String:
	return (node("Hud/%AbilityView") as RecipeView).caption_text()


func _effect() -> EffectBackground:
	return node("EffectBackground") as EffectBackground


func _effect_on_in_character_color() -> bool:
	return _effect().is_effect_on() and _effect().effect_color().is_equal_approx(session().character.accent_color)


func _tick_ability() -> void:
	match step:
		0:
			if playing():
				expect((node("Hud/%CharacterRow") as Control).visible, "character row shown")
				expect((node("Hud/%CharacterRow") as Control).get_global_rect().end.y <= (node("BoardView") as BoardView).cells_rect([Vector2i.ZERO] as Array[Vector2i]).position.y, "character row above the board")
				expect(_recipes_fit(), "cards and character row fit on screen")
				expect(_card() == session().character.ability_name, "card shows the ability name before triggering")
				if mode == "gardener":
					session().board.set_seed(Vector2i(0, 0), 3, 1.0, 1.0)
				_trigger_by_match()
				next_step()
		1:
			if step_time > 0.2:
				_check_triggered()
				shot(mode)
				next_step()
		2:
			_check_followup()
		3:
			_check_fever_end()


func _check_triggered() -> void:
	var character: CharacterData = session().character
	expect(session().stats.ability_triggers == 1, "triggered by the real match")
	expect(_hud().banner_title() == character.ability_name + "!", "banner %s! (%s)" % [character.ability_name, _hud().banner_title()])
	expect(not _hud().message_text().is_empty(), "message line shows the result (%s)" % _hud().message_text())
	match mode:
		"gardener":
			expect(session().board.count_type(Board.CellType.SEED) == 0, "all seeds grown")
			expect(_hud().message_text() == "촉진: 씨앗 전부 성장", "gardener message")
			expect(_card() == "촉진", "no status for an instant ability")
		"clock":
			expect(session().is_clock_stopped(), "time stop")
			expect(_card().ends_with("초"), "card shows remaining stop (%s)" % _card())
			expect(_effect_on_in_character_color(), "background effect in the character color")
			_snap = session().remaining_time()
		"gambler":
			expect(_card() == "×2", "card shows the charge (%s)" % _card())
			expect(not _effect().is_effect_on(), "waiting effect has no background")
		"fever":
			expect(_card().ends_with("0스택"), "card shows time and stacks (%s)" % _card())
			expect(_effect_on_in_character_color(), "background effect in the character color")
		"joker":
			expect(_card() == "와일드 2", "card shows wild charges (%s)" % _card())
		"bomber":
			expect(_card() == "폭발 1", "card shows the bomb (%s)" % _card())
		"poseidon":
			expect(_views_show_board(), "board view shows the sunk colors")
		"colorblind":
			var colorblind: ColorblindAbility = session().ability as ColorblindAbility
			expect(_board_view().display_style() != null, "board uses the merged palette")
			expect(_views_show_board(), "merged color drawn as the base color")
			expect(_recipe_fill(colorblind.merged_color).is_equal_approx(_theme().color_for(colorblind.base_color)), "recipe cards merge too")
		"retro":
			expect(_board_view().display_style() != null and _board_view().display_style().monochrome, "board is monochrome")
			expect(_views_show_board(), "blocks drawn in gray")
		"architect":
			# 어느 족보가 늘어날지는 판마다 다르다 (가장 많이 진행된 족보) → 카드 칸 수 합이 1 늘었는지 본다.
			var expected: int = 0
			for recipe: RecipeSet.Recipe in session().recipes.recipes:
				expected += recipe.length()
			expect(_recipe_steps_total() == expected and expected == 2 + 3 + 4 + 1, "one recipe card got one more step (%d)" % _recipe_steps_total())
			expect(_recipes_fit(), "cards still fit")
		"runner":
			expect(session().is_clock_stopped(), "time stopped")
			expect(_card().ends_with("초"), "card shows moves and seconds (%s)" % _card())
		"vampire":
			expect(_board_view().display_style() != null, "blood palette on the board")
			expect(_views_show_board(), "every block drawn red")
			expect(_effect_on_in_character_color(), "red background")
		"seer":
			expect(_seeds_revealed(), "seeds show their next color")
		"sewer":
<<<<<<< HEAD
			expect(_card().begins_with("12칸 / ") and _card().ends_with("초"), "card shows rope and time (%s)" % _card())
=======
			expect(_card().begins_with("12칸 · ") and _card().ends_with("초"), "card shows rope and time (%s)" % _card())
>>>>>>> Choi
			expect(_marks().size() == 1 and _marks()[0].kind == BoardMark.Kind.PATH, "rope drawn")
		"zeus":
			expect(session().is_input_locked(), "no input during the strikes")
			expect(session().is_clock_stopped(), "time stopped")
<<<<<<< HEAD
			expect(_card().begins_with("낙뢰 "), "card shows strikes left (%s)" % _card())
=======
			expect(_card().begins_with("⚡"), "card shows strikes left (%s)" % _card())
>>>>>>> Choi
		"photo":
			expect((session().ability as PhotoAbility).planning, "photo taken")
			expect(_marks().size() == 1 and _marks()[0].kind == BoardMark.Kind.PATH, "plan path drawn")
		"madan":
<<<<<<< HEAD
			expect(_card().begins_with("6발 / "), "card shows bullets (%s)" % _card())
=======
			expect(_card().begins_with("6발 · "), "card shows bullets (%s)" % _card())
>>>>>>> Choi
			expect(session().is_clock_stopped(), "time stopped")


## 예지안: 씨앗 칸이 자랄 색(흐리게)으로 칠해져 있다.
func _seeds_revealed() -> bool:
	var board: Board = session().board
	var views: Dictionary = _board_view().get("_views")
	var seeds: int = 0
	for pos: Vector2i in views:
		if board.get_cell_type(pos) != Board.CellType.SEED:
			continue
		seeds += 1
		var fill: Color = ((views[pos] as CellView).get_node("Fill") as ColorRect).color
		var next: Color = _theme().color_for(board.get_color(pos))
		if not Color(fill.r, fill.g, fill.b).is_equal_approx(Color(next.r, next.g, next.b)):
			return false
	return seeds > 0


## 수선사 끈이 돌 3×3 고리와 그 둘레를 매치가 생기지 않는 무늬(노랑·파랑·초록, (x+y) mod 3)로 칠하고,
## 고리 안쪽 칸은 빨강 블록으로 둔다 (무작위 판에서 걷는 도중 매치가 나 안쪽이 씨앗이 되지 않게).
func _paint_loop_area() -> void:
	var board: Board = session().board
	var start: Vector2i = board.player_pos
	var palette: Array[int] = [0, 2, 3]
	for y: int in range(start.y - 1, start.y + 4):
		for x: int in range(start.x - 1, start.x + 4):
			var pos: Vector2i = Vector2i(x, y)
			if board.is_inside(pos) and pos != start:
				board.set_color_block(pos, palette[(x + y) % 3])
	board.set_color_block(start + Vector2i(1, 1), 1)
	redraw_board()


## 일반 족보 카드 3장의 칸 수 합.
func _recipe_steps_total() -> int:
	var total: int = 0
	for path: String in ["Hud/%Recipe0", "Hud/%Recipe1", "Hud/%Recipe2"]:
		total += (node(path) as RecipeView).shown_step_count()
	return total


func _board_view() -> BoardView:
	return node("BoardView") as BoardView


func _theme() -> BoardTheme:
	return _board_view().theme_data


## 모든 블록 칸이 논리 판의 색을 (능력의 표시 방식을 적용해) 그리고 있다.
func _views_show_board() -> bool:
	var board: Board = session().board
	var views: Dictionary = _board_view().get("_views")
	for pos: Vector2i in views:
		if board.get_cell_type(pos) != Board.CellType.COLOR_BLOCK:
			continue
		var fill: Color = ((views[pos] as CellView).get_node("Fill") as ColorRect).color
		if not fill.is_equal_approx(_theme().display_color(board.get_color(pos), _board_view().display_style())):
			return false
	return true


## 족보 카드에서 color 칸이 칠해진 색 (족보 0을 그 색 한 칸짜리처럼 보이게 바꿔 확인).
func _recipe_fill(color: int) -> Color:
	session().recipes.set_recipe_colors(0, PackedInt32Array([color, color]))
	controller.hud_channel.recipes_updated.emit(session().recipes, RecipeSet.ClearOutcome.new())
	var step: Panel = node("Hud/%Recipe0").get_node("%Steps").get_child(0)
	return (step.get_theme_stylebox("panel") as StyleBoxFlat).bg_color


func _check_followup() -> void:
	match mode:
		"clock":
			if step_time > 1.0:
				expect(session().remaining_time() == float(_snap), "remaining frozen during stop")
				finish()
		"gambler":
			if step_time < 0.01:
				return
			if _snap == null:
				_points = prime_recipe(0, 1)
				_snap = session().score
				prepare_match_below(1)
				flow().request_move(Vector2i.DOWN)
				step_time = 0.02
			elif step_time > 0.5:
				expect(session().score - int(_snap) == _points * 2, "next completion x2 (+%d)" % (session().score - int(_snap)))
				expect(_card() == "올인", "charge used → card shows the name again (%s)" % _card())
				finish()
		"fever":
			var fever: FeverAbility = session().ability as FeverAbility
			if _snap == null:
				_snap = session().score
				prepare_match_below(2)
				flow().request_move(Vector2i.DOWN)  # 피버 중 매치 → 스택 1
				expect(fever.stacks == 1, "a match during fever adds a stack")
			elif not fever.is_active():
				expect(_hud().banner_title() == "피버 1스택!", "payout banner (%s)" % _hud().banner_title())
				expect(session().score >= int(_snap) + 50, "payout 50 added (+%d)" % (session().score - int(_snap)))
				expect(_card() == "피버", "card back to the name (%s)" % _card())
				next_step()
			elif step_time > 12.0:
				fail("fever did not end")
				finish()
		"joker":
			if step_time < 0.01:
				return
			if _snap == null:
				session().recipes.set_recipe_colors(0, PackedInt32Array([0, 0]))
				session().recipes.set_recipe_colors(1, PackedInt32Array([1, 1, 1]))
				session().recipes.set_recipe_colors(2, PackedInt32Array([2, 2, 2, 2]))
				_snap = session().match_count
				prepare_match_below(3)
				flow().request_move(Vector2i.DOWN)
				step_time = 0.02
			elif step_time > 0.5:
				var progress: Array[int] = []
				for r: RecipeSet.Recipe in session().recipes.recipes:
					progress.append(r.progress)
				expect(session().match_count == int(_snap) + 1, "second match")
				expect(progress == ([1, 1, 1] as Array[int]), "wild advanced all (%s)" % [progress])
				expect(_card() == "와일드", "one wild left (%s)" % _card())
				finish()
		"zeus":
			var zeus: ZeusAbility = session().ability as ZeusAbility
			if _snap == null:
				_snap = zeus.strikes_left
			elif step_time > 1.3:
				expect(zeus.strikes_left < int(_snap), "lightning strikes the recipes (%d → %d)" % [int(_snap), zeus.strikes_left])
				shot("zeus_strikes")
				finish()
		"photo":
			# 실제 키로 계획 → 사진이 깨지면 계획대로 움직인다
			var photo: PhotoAbility = session().ability as PhotoAbility
			if _snap == null:
				_snap = session().board.player_pos
				press_key(KEY_LEFT)
				press_key(KEY_LEFT)
			elif _snap is Vector2i and step_time > 0.3:
				expect(photo.plan.size() == 2 and session().board.player_pos == _snap, "keys only plan (%d)" % photo.plan.size())
				shot("photo_plan")
				_snap = [_snap]
			elif _snap is Array and not photo.planning and not photo.replaying:
				var start: Vector2i = _snap[0]
				expect(session().board.player_pos == start + Vector2i(-2, 0), "replayed the plan (%s)" % session().board.player_pos)
				finish()
			elif step_time > 9.0:
				fail("photo did not replay")
				finish()
		"madan":
			var madan: MadanAbility = session().ability as MadanAbility
			if _snap == null:
				_snap = session().board.player_pos
				press_key(KEY_DOWN)
			elif step_time > 0.3:
				expect(madan.shots_used == 1, "a real key fired one shot")
				expect(session().board.player_pos == (_snap as Vector2i) + Vector2i.DOWN, "moved into the shot cell")
<<<<<<< HEAD
				expect(_card().begins_with("5발 / "), "card counts bullets (%s)" % _card())
=======
				expect(_card().begins_with("5발 · "), "card counts bullets (%s)" % _card())
>>>>>>> Choi
				shot("madan_shot")
				finish()
		"sewer":
			var sewer: SewerAbility = session().ability as SewerAbility
			if _snap == null:
				_snap = "looping"
				_paint_loop_area()
				for dir: Vector2i in [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.DOWN, Vector2i.LEFT, Vector2i.LEFT, Vector2i.UP, Vector2i.UP]:
					flow().request_move(dir)
			elif step_time > 0.3:
				expect(not sewer.armed, "loop closed")
				expect(sewer.closes == 1, "inside block pulled (%s)" % _hud().message_text())
				expect(_marks().is_empty(), "rope cleared")
				shot("sewer_closed")
				finish()
		"bomber":
			var bomber: BomberAbility = session().ability as BomberAbility
			if _snap == null:
				prepare_match_below(1)
				var tail: Vector2i = session().board.player_pos + Vector2i.DOWN * 3  # 십자 아래로 이어진 빨강 한 칸
				session().board.set_color_block(tail, 1)
				redraw_board()
				flow().request_move(Vector2i.DOWN)
				expect(session().is_input_locked(), "input locked while chaining")
				_snap = session().remaining_time()
			elif not bomber.is_chaining():
				expect(bomber.blasted >= 1, "chain blasted %d block(s)" % bomber.blasted)
				expect(not session().is_input_locked(), "input back after the chain")
				shot("bomber_chain")
				finish()
			elif step_time > 3.0:
				fail("chain did not end")
				finish()
		_:
			finish()


## 피버가 끝난 뒤: 배경 효과가 꺼진다.
func _check_fever_end() -> void:
	if step_time > 0.2:
		expect(not _effect().is_effect_on(), "background effect off after fever")
		shot("fever_end")
		finish()


func _recipes_fit() -> bool:
	var width: float = root.get_visible_rect().size.x
	for path: String in ["Hud/%Recipe0", "Hud/%Recipe1", "Hud/%Recipe2", "Hud/%CharacterRow"]:
		var rect: Rect2 = (node(path) as Control).get_global_rect()
		if (node(path) as Control).visible and (rect.position.x < 0.0 or rect.end.x > width):
			return false
	return true
