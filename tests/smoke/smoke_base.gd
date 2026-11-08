extends SceneTree
## 실제 창(렌더링)에서 게임을 띄워 확인하는 스모크 테스트의 공통 기반.
## - 게임 전체가 스모크 전용 저장 파일(SaveData.path_override)을 쓰게 하고, 끝나면 지운다.
##   사용자 저장 파일(user://save.cfg)은 시작·끝의 내용을 비교해 한 바이트라도 바뀌면 실패로 처리한다.
## - 하위 스크립트는 _setup()과 _tick()을 구현하고, 끝나면 finish()를 부른다.
## - 실패가 있으면 exit code 1. 스크린샷은 user://smoke_shots/에 저장.
## 실행: godot --path . -s tests/smoke/<파일>.gd -- <모드> [인자...]

const SMOKE_SAVE_PATH: String = "user://smoke_save.cfg"
const SMOKE_LOG_PATH: String = "user://smoke_playtest_log.csv"
## 예전 백업 방식이 남긴 파일 (있으면 한 번 복원한다).
const LEGACY_BACKUP_PATH: String = "user://save.cfg.smokebak"
const SHOT_DIR: String = "user://smoke_shots"
const TIMEOUT: float = 20.0
const S = GameFlow.GameState

var args: PackedStringArray = PackedStringArray()
var mode: String = ""
var step: int = 0
var step_time: float = 0.0
var errors: int = 0
var controller: Node
## 게임 설정 리소스. 스크립트가 참조를 계속 쥐고 있어야 게임 씬이 같은 인스턴스(메모리에서 바꾼 값)를 쓴다.
## (참조가 없으면 해제되어 게임 씬이 디스크에서 원래 값을 다시 불러온다.)
var config: GameConfig = load("res://resources/game_config.tres")
## 진행 설정 (같은 이유로 참조를 쥔다). 기본은 보드 단계 표를 비워 모든 판이 본 게임 보드·위 config 그대로다
## (스모크 저장 파일은 Lv1이라 단계가 적용되면 3색·40초가 된다). 단계를 검사하는 스모크는 keep_stages = true.
var progression: ProgressionConfig = load("res://resources/progression.tres")
var keep_stages: bool = false
## 스모크 창이 포커스를 잃어 자동 일시정지되면 바로 재개한다. 일시정지 자체를 검사하는 동안은 false로 둔다.
var auto_resume: bool = true

var _user_save_before: PackedByteArray = PackedByteArray()
var _user_log_before: PackedByteArray = PackedByteArray()
var _finished: bool = false
var _held_mouse: Vector2 = Vector2.ZERO


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	mode = args[0] if not args.is_empty() else ""
	_isolate_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	# 기본은 튜토리얼을 끝낸 저장으로 시작한다 (튜토리얼·흐름 스모크는 _setup에서 TutorialStore를 다시 정한다).
	TutorialStore.new().finish_all()
	_setup()
	if not keep_stages:
		progression.stages = []


func _process(delta: float) -> bool:
	if _finished:
		return false
	step_time += delta
	if step_time > TIMEOUT:
		fail("timeout at step %d" % step)
		finish()
		return false
	if current_scene == null:
		return false
	if controller == null and current_scene.name == "Main":
		controller = current_scene.get_node("GameController")
	if auto_resume and flow() != null and flow().state == S.PAUSED:
		flow().resume()
	_tick()
	return false


# --- 하위 스크립트가 구현 -----------------------------------------------------

func _setup() -> void:
	pass


func _tick() -> void:
	pass


# --- 판정 -------------------------------------------------------------------

func expect(cond: bool, what: String) -> void:
	if cond:
		print("  ok   " + what)
	else:
		fail(what)


func fail(what: String) -> void:
	errors += 1
	printerr("  FAIL " + what)


func finish() -> void:
	if _finished:
		return
	_finished = true
	_release_save()
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	print("SMOKE[%s %s] %s (%d errors)" % [script_name, mode, "PASS" if errors == 0 else "FAIL", errors])
	quit(1 if errors > 0 else 0)


func next_step() -> void:
	step += 1
	step_time = 0.0


# --- 조작 흉내 -----------------------------------------------------------------

## 실제 마우스 클릭. 누름과 뗌을 같은 프레임에 넣는다 — 누른 채로 프레임이 지나면, 실행 중 사용자가 움직인 진짜 마우스 이동이
## 끼어들어 버튼이 눌림을 취소하거나 슬라이더가 끌려간다. 좌표는 뷰포트(1080×1920 기준) 좌표.
func click_control(control: Control) -> void:
	var center: Vector2 = control.get_global_rect().get_center()
	_click(center, true)
	_click(center, false)


## 마우스 버튼을 control 가운데에서 누른 채로 둔다 (release_mouse로 뗀다). 패드 누르고 있기 등.
func press_control(control: Control) -> void:
	_held_mouse = control.get_global_rect().get_center()
	_click(_held_mouse, true)


func release_mouse() -> void:
	_click(_held_mouse, false)


## 손가락을 pos(뷰포트 좌표)로 끈다 (닿아 있는 동안). 스와이프는 touch(시작, true) → drag(끝) → touch(끝, false).
func drag(pos: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.position = root.get_final_transform() * pos
	Input.parse_input_event(event)


## 손가락을 pos(뷰포트 좌표)에 대거나 뗀다.
func touch(pos: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = root.get_final_transform() * pos
	event.pressed = pressed
	Input.parse_input_event(event)


func press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _click(viewport_pos: Vector2, pressed: bool) -> void:
	if pressed:  # 먼저 커서를 그 자리로 옮긴다 (GUI가 마지막 마우스 위치·호버를 기준으로 판단하는 경우 대비)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = root.get_final_transform() * viewport_pos
		motion.global_position = motion.position
		Input.parse_input_event(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform() * viewport_pos
	event.global_position = event.position
	event.pressed = pressed
	Input.parse_input_event(event)


# --- 조회 ------------------------------------------------------------------

func node(path: String) -> Node:
	return current_scene.get_node(path)


func flow() -> GameFlow:
	return controller.get("_flow") if controller != null else null


func session() -> GameSession:
	var f: GameFlow = flow()
	return f.session if f != null else null


func in_scene(scene_name: String, min_time: float = 0.3) -> bool:
	return current_scene != null and current_scene.name == scene_name and step_time > min_time


## 판이 깔려 이동을 받을 수 있는 상태 (첫 이동 전 WAITING 포함).
func playing(min_time: float = 0.3) -> bool:
	var f: GameFlow = flow()
	return f != null and (f.state == S.WAITING or f.state == S.PLAYING) and step_time > min_time


func shot(shot_name: String) -> void:
	var script_name: String = (get_script() as Script).resource_path.get_file().get_basename()
	root.get_texture().get_image().save_png("%s/%s_%s.png" % [SHOT_DIR, script_name, shot_name])


## 스모크 전용: 플레이어 바로 위 칸을 중심으로 한 십자(중심 + 위·왼쪽·오른쪽)를 color로 만든다 → UP 이동 시 매치.
## 화면도 다시 그린다.
func prepare_match_above(color: int) -> void:
	_paint_cross_toward(Vector2i.UP, color)


## 스모크 전용: 플레이어 바로 아래 칸을 중심으로 한 십자를 color로 만든다 → DOWN 이동 시 매치.
func prepare_match_below(color: int) -> void:
	_paint_cross_toward(Vector2i.DOWN, color)


## 스모크 전용: slot 족보를 color를 한 번 더 깨면 완성되게 만든다 ([color, color], 진행 1). 완성 점수를 반환한다.
func prime_recipe(slot: int, color: int) -> int:
	session().recipes.set_recipe_colors(slot, PackedInt32Array([color, color]))
	session().recipes.recipes[slot].progress = 1
	controller.hud_channel.recipes_updated.emit(session().recipes, RecipeSet.ClearOutcome.new())
	return session().recipes.recipes[slot].points


func _paint_cross_toward(dir: Vector2i, color: int) -> void:
	var center: Vector2i = session().board.player_pos + dir
	var cells: Array[Vector2i] = [center]
	for side: Vector2i in Board.DIRECTIONS:
		if side != -dir:
			cells.append(center + side)
	_paint(cells, color)


func _paint(cells: Array[Vector2i], color: int) -> void:
	var board: Board = session().board
	for pos: Vector2i in cells:
		board.set_color_block(pos, color)
	redraw_board()


func redraw_board() -> void:
	controller.board_channel.board_created.emit(session().board)


# --- 저장 파일 격리 -------------------------------------------------------------

func _isolate_save() -> void:
	if FileAccess.file_exists(LEGACY_BACKUP_PATH):  # 예전 방식 실행이 도중에 죽어 남은 백업 → 원본 복원
		_copy(LEGACY_BACKUP_PATH, SaveData.DEFAULT_PATH)
		_remove(LEGACY_BACKUP_PATH)
	_user_save_before = _read_bytes(SaveData.DEFAULT_PATH)
	_user_log_before = _read_bytes(PlaytestLog.DEFAULT_PATH)
	SaveData.path_override = SMOKE_SAVE_PATH
	PlaytestLog.path_override = SMOKE_LOG_PATH
	_remove(SMOKE_SAVE_PATH)
	_remove(SMOKE_LOG_PATH)


func _release_save() -> void:
	_remove(SMOKE_SAVE_PATH)
	_remove(SMOKE_LOG_PATH)
	SaveData.path_override = ""
	PlaytestLog.path_override = ""
	if _read_bytes(SaveData.DEFAULT_PATH) != _user_save_before:
		fail("user save file was modified (save isolation broken)")
	if _read_bytes(PlaytestLog.DEFAULT_PATH) != _user_log_before:
		fail("user playtest log was modified (log isolation broken)")


## 스모크 전용 플레이 기록 파일의 데이터 행들 (헤더 제외).
func smoke_log_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if not FileAccess.file_exists(SMOKE_LOG_PATH):
		return rows
	var lines: PackedStringArray = FileAccess.get_file_as_string(SMOKE_LOG_PATH).strip_edges().split("\n")
	for i: int in range(1, lines.size()):
		rows.append(lines[i].split(","))
	return rows


func _read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


func _copy(from: String, to: String) -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(to))


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
