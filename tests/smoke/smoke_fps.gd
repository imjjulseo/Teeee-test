extends "res://tests/smoke/smoke_base.gd"
## QA 9·13: 실제 엔진에서 매 프레임 방향키/WASD 연타(동시 입력 포함) 후 View와 Grid 일치.
## --max-fps로 fps를 바꿔 실행한다. 예: godot --path . --max-fps 30 -s tests/smoke/smoke_fps.gd -- run

const KEYS: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _frames: int = 0


func _setup() -> void:
	config.game_duration = 1000.0
	_rng.seed = 11
	change_scene_to_file("res://scenes/main.tscn")


var _elapsed_before: float = 0.0


func _tick() -> void:
	if mode == "hitch":
		_tick_hitch()
		return
	match step:
		0:
			if playing(0.0):
				next_step()
		1:
			if step_time < 4.0:
				_frames += 1
				for _i: int in _rng.randi_range(1, 2):
					press_key(KEYS[_rng.randi_range(0, KEYS.size() - 1)])
			elif step_time > 4.5:  # 입력을 멈추고 이동·트윈 정리 대기
				var board: Board = session().board
				var view: BoardView = node("BoardView")
				var views: Dictionary = view.get("_views")
				var mismatch: int = 0
				for pos: Vector2i in views:
					var cell: CellView = views[pos]
					if not cell.position.is_equal_approx(Vector2(pos) * (view.theme_data.cell_size + view.theme_data.cell_gap)):
						mismatch += 1
					if cell.get_node("Border").visible != (board.get_cell_type(pos) == Board.CellType.PLAYER):
						mismatch += 1
				print("  fps~%.0f input frames %d" % [_frames / 4.0, _frames])
				expect(mismatch == 0, "all %d views match the grid (%d mismatches)" % [views.size(), mismatch])
				expect(board.count_type(Board.CellType.PLAYER) == 1, "exactly one player")
				finish()


## 모드 hitch: 플레이 중 프로세스를 1초 멈춰(로딩·GC 흉내) 한 프레임에 흘러간 게임 시간이 max_frame_delta로 제한되는지.
func _tick_hitch() -> void:
	match step:
		0:
			if playing(0.5):
				flow().request_move(Vector2i.ZERO)  # 시계 시작 (판은 그대로)
				_elapsed_before = session().elapsed
				OS.delay_msec(1000)
				next_step()
		1:
			if step_time > 0.0:
				# 멈춘 1초 + 이후 몇 프레임. 제한이 없으면 1초 이상 흐른다.
				var passed: float = session().elapsed - _elapsed_before
				print("  game time passed over the 1s hitch frame: %.3f s (limit %.2f)" % [passed, config.max_frame_delta])
				expect(passed <= config.max_frame_delta + 0.1, "hitch clamped (%.3f s)" % passed)
				expect(passed >= config.max_frame_delta - 0.001, "clamped frame still advanced by max_frame_delta")
				finish()