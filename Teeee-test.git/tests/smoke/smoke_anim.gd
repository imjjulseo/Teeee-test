extends "res://tests/smoke/smoke_base.gd"
## 판 연출 (E32, HTML 판 기본 손맛): 같은 장면을 tools/html_anim_capture.js와 같은 시각(ms)에 찍어 나란히 비교한다
## (tools/anim_compare.py). 시간을 느리게(Engine.time_scale) 돌려 연출 시각을 정확히 맞춘다.
## 모드:
## - match: 위 칸 십자 매치 + 족보 완성(+점수가 점수로 날아감, 카드 깨짐 → 새 카드) + 다른 족보 칸 채움 + 금화 "+10"이 코인으로.
##   깨진 블록 그림자·파편·판 흔들림·날아가는 글자가 생기고, 날아가는 동안은 점수·코인이 오르지 않다가 닿으면 오른다.
## - pop: 블록 번쩍임 (modulate가 1보다 밝게 시작해 원래로).
## - stamp: 퍼즐 깔기 — 내 칸에서 가까운 칸부터 튀어나옴 (먼 칸은 아직 작고 투명).
## - wall: 벽 튕김.
## - reduce: 효과 줄이기면 match 장면에서 그림자·파편·떠오르는 글자·카드 연출이 없고 점수·코인이 바로 오른다.
## 스크린샷은 user://smoke_shots/smoke_anim_<모드>_<ms>.png.

const FRAMES: PackedInt32Array = [0, 30, 60, 90, 120, 160, 200, 260, 320, 400, 500, 650, 800]
## 연출 시간을 이 배로 느리게 (한 프레임 ≈ 1.3ms).
const SLOW: float = 0.08

var _anim_t: float = -1.0
## 연출 시작 실제 시각 (µs). 연출 시각 = 실제로 흐른 시간 × SLOW (Tween은 Engine.time_scale로 느려진다).
var _start_usec: int = 0
var _frame: int = 0
var _points: int = 0
var _checked: Dictionary = {}


func _setup() -> void:
	CharacterStore.new().select(&"basic")
	OptionsStore.new().set_control_mode(OptionsStore.ControlMode.SWIPE)
	OptionsStore.new().set_reduce_motion(mode == "reduce")
	TutorialStore.new().finish_all()
	change_scene_to_file("res://scenes/main.tscn")


func _tick() -> void:
	match step:
		0:
			if playing(1.0):
				_prepare()
				next_step()
		1:
			if step_time > 0.6:  # 카드 등장·번쩍임이 끝나게
				Engine.time_scale = SLOW
				_trigger()
				_start_usec = Time.get_ticks_usec()
				next_step()
		2:
			_anim_t = (Time.get_ticks_usec() - _start_usec) / 1000.0 * SLOW
			while _frame < FRAMES.size() and _anim_t >= FRAMES[_frame]:
				_check(FRAMES[_frame])
				shot("%s_%03d" % [mode, FRAMES[_frame]])
				_frame += 1
			if _frame >= FRAMES.size():
				Engine.time_scale = 1.0
				_final_checks()
				finish()


func _board_view() -> BoardView:
	return node("BoardView") as BoardView


func _prepare() -> void:
	# 판 시계·리필을 멈춘다 (느린 시간 동안 씨앗이 자라거나 시간이 끝나지 않게, 연출만 본다).
	session().start()
	session().frozen_clocks.append(TimedSystem.Clock.PLAY)
	session().frozen_clocks.append(TimedSystem.Clock.REFILL)
	if mode == "match" or mode == "reduce":
		prepare_match_above(1)
		var coin_cell: Vector2i = session().board.player_pos + Vector2i(-1, -1)
		session().board.get_cell(coin_cell).attach_coin(1000.0)
		_points = prime_recipe(0, 1)
		session().recipes.set_recipe_colors(1, PackedInt32Array([1, 0, 2]))
		controller.hud_channel.recipes_updated.emit(session().recipes, RecipeSet.ClearOutcome.new())
		redraw_board()


func _trigger() -> void:
	var board: Board = session().board
	var me: Vector2i = board.player_pos
	match mode:
		"match", "reduce":
			flow().request_move(Vector2i.UP)
		"pop":
			var cells: Array[Vector2i] = []
			for k: int in range(1, 4):
				if board.is_inside(me + Vector2i(k, 0)):
					cells.append(me + Vector2i(k, 0))
			controller.board_channel.cells_changed.emit(cells)
		"stamp":
			var cells: Array[Vector2i] = []
			for y: int in range(-2, 3):
				for x: int in range(-2, 3):
					var cell: Vector2i = me + Vector2i(x, y)
					if cell != me and board.is_inside(cell):
						cells.append(cell)
			controller.board_channel.cells_stamped.emit(cells, me)
		"wall":
			var blocked: Board.MoveResult = Board.MoveResult.new(Board.MoveOutcome.BLOCKED_BY_WALL, me, me + Vector2i.LEFT)
			controller.board_channel.move_blocked.emit(blocked)


func _floating_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in node("Hud/%Floats").get_children():
		if child is FloatingText and not child.is_queued_for_deletion():
			texts.append((child as FloatingText).text)
	return texts


func _count_in_cells(type: Variant) -> int:
	var count: int = 0
	for child: Node in _board_view().get_node("Cells").get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			count += 1
	return count


## 칸 그림(CellView) 중 판 칸이 아닌 것 = 깨진 블록 그림자.
func _ghosts() -> int:
	var views: Dictionary = _board_view().get("_views")
	var count: int = 0
	for child: Node in _board_view().get_node("Cells").get_children():
		if child is CellView and not views.values().has(child) and not child.is_queued_for_deletion():
			count += 1
	return count


func _view(cell: Vector2i) -> CellView:
	return (_board_view().get("_views") as Dictionary)[cell]


func _check(ms: int) -> void:
	var me: Vector2i = session().board.player_pos
	match mode:
		"match":
			if ms == 30:
				expect(_ghosts() == 4, "4 cleared-block ghosts (%d)" % _ghosts())
				expect(_count_in_cells(BurstEffect) == 4, "a burst per cell")
				expect(_floating_texts().has("+%d" % _points), "+%d flies (%s)" % [_points, _floating_texts()])
				expect(_floating_texts().has("+10"), "coin +10 flies")
				expect((node("Hud/%Recipe0") as RecipeView).is_breaking(), "completed card is breaking")
				expect(not _board_view().get_node("Cells").position.is_equal_approx(_home()), "board is shaking")
				expect((node("Hud") as Hud).shown_score() == 0, "score waits for the flying points")
		"pop":
			if ms == 0:
				var view: CellView = _view(me + Vector2i.RIGHT)
				expect(view.modulate.r > 1.05 or view.modulate.g > 1.05 or view.modulate.b > 1.05, "pop starts brighter (%s)" % view.modulate)
		"stamp":
			if ms == 160:  # 거리 1칸은 0.055초, 거리 4칸은 0.22초 뒤 시작
				var near: CellView = _view(me + Vector2i.RIGHT)
				var far: CellView = _view(me + Vector2i(2, 2))
				expect(near.scale.x > far.scale.x, "near cells pop out first (%.2f > %.2f)" % [near.scale.x, far.scale.x])
				expect(far.modulate.a < 0.05, "far cells still hidden")
		"wall":
			if ms == 90:
				var view: CellView = _view(me)
				expect(view.position.x < (_board_view().call("_to_pixel", me) as Vector2).x - 1.0, "player nudged toward the wall")
		"reduce":
			if ms == 30:
				expect(_ghosts() == 0, "no ghosts")
				expect(_count_in_cells(BurstEffect) == 0, "no bursts")
				expect(_floating_texts().is_empty(), "no floating text")
				expect(not (node("Hud/%Recipe0") as RecipeView).is_breaking(), "card replaced at once")
				expect(_board_view().get_node("Cells").position.is_equal_approx(_home()), "board does not shake")


func _home() -> Vector2:
	return -Vector2.ONE * _board_view().board_extent() / 2.0


func _final_checks() -> void:
	match mode:
		"match":
			expect((node("Hud/%CoinLabel") as Label).text.ends_with("10"), "coins arrive (%s)" % (node("Hud/%CoinLabel") as Label).text)
			expect(not (node("Hud/%Recipe0") as RecipeView).is_breaking(), "new card in place")
			expect(_ghosts() == 0, "ghosts gone")
		"stamp":
			expect(is_equal_approx(_view(session().board.player_pos + Vector2i(2, 2)).scale.x, 1.0), "every stamped cell settles")
		"wall":
			var me: Vector2i = session().board.player_pos
			expect(_view(me).position.is_equal_approx(_board_view().call("_to_pixel", me) as Vector2), "player back home")
		"reduce":
			expect((node("Hud/%CoinLabel") as Label).text.ends_with("10"), "coins shown at once")
	if mode == "match" or mode == "reduce":
		expect((node("Hud") as Hud).shown_score() > 0, "points reached the score (%d)" % (node("Hud") as Hud).shown_score())

