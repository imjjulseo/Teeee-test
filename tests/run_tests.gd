extends SceneTree
## 헤드리스 테스트 러너.
## 실행: godot --headless --path . -s tests/run_tests.gd
## tests/ 바로 아래의 test_*.gd를 찾아 test_로 시작하는 메서드를 모두 실행한다. 실패가 있으면 exit code 1.
## 테스트마다: before_each → 테스트 → after_each → 전역 상태 확인·초기화.
## 실패로 세는 것: assert_* 실패 / 테스트 도중 스크립트 오류 / 만들고 해제하지 않은 노드 / 전역 상태(SaveData.path_override,
## PlaytestLog.path_override, SafeArea.debug_insets, TrialRequest.character_id, Master 버스 볼륨·음소거)를 바꿔 놓고 되돌리지 않음.
## 전역 상태는 다음 테스트를 위해 항상 초기화한다.

const TESTS_DIR: String = "res://tests"
const ErrorCounter = preload("res://tests/framework/error_counter.gd")

var _errors: ErrorCounter = ErrorCounter.new()


func _initialize() -> void:
	OS.add_logger(_errors)
	var total: int = 0
	var failed: int = 0
	for file_name: String in _find_test_files():
		var script: GDScript = load("%s/%s" % [TESTS_DIR, file_name]) as GDScript
		if script == null or not script.can_instantiate():
			printerr("  FAIL %s: could not load script (parse error?)" % file_name)
			total += 1
			failed += 1
			continue
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			total += 1
			var failures: PackedStringArray = _run_one(script, method_name)
			if failures.is_empty():
				print("  ok   %s::%s" % [file_name, method_name])
			else:
				failed += 1
				for failure: String in failures:
					printerr("  FAIL %s::%s — %s" % [file_name, method_name, failure])
	OS.remove_logger(_errors)
	print("\n%d tests, %d passed, %d failed" % [total, total - failed, failed])
	quit(1 if failed > 0 else 0)


func _run_one(script: GDScript, method_name: String) -> PackedStringArray:
	var instance: Object = script.new()
	_errors.reset()
	var nodes_before: int = _node_count()
	instance.call("before_each")
	instance.call(method_name)  # 스크립트 오류가 나면 이 테스트 함수만 중단되고 여기로 돌아온다
	instance.call("after_each")
	var failures: PackedStringArray = instance.get("failures")
	if _errors.script_errors > 0:
		failures.append("script error during test (%d): %s" % [_errors.script_errors, _errors.last_error])
	var leaked_nodes: int = _node_count() - nodes_before
	if leaked_nodes > 0:
		failures.append("%d node(s) not freed (call free() on nodes the test created)" % leaked_nodes)
	failures.append_array(_reset_global_state())
	return failures


## 살아 있는 노드 수 (트리 안 + 트리 밖). 테스트는 트리 밖에서 돌므로 만든 노드는 직접 free()해야 한다.
func _node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		+ Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


## 테스트가 바꿔 놓고 되돌리지 않은 전역 상태를 찾아 실패로 알리고 초기화한다.
func _reset_global_state() -> PackedStringArray:
	var leaks: PackedStringArray = PackedStringArray()
	if not SaveData.path_override.is_empty():
		leaks.append("leaked global state: SaveData.path_override = \"%s\" (reset)" % SaveData.path_override)
		SaveData.path_override = ""
	if not PlaytestLog.path_override.is_empty():
		leaks.append("leaked global state: PlaytestLog.path_override = \"%s\" (reset)" % PlaytestLog.path_override)
		PlaytestLog.path_override = ""
	if SafeArea.debug_insets != Vector4.ZERO:
		leaks.append("leaked global state: SafeArea.debug_insets = %s (reset)" % SafeArea.debug_insets)
		SafeArea.debug_insets = Vector4.ZERO
	if TrialRequest.character_id != &"":
		leaks.append("leaked global state: TrialRequest.character_id = \"%s\" (reset)" % TrialRequest.character_id)
		TrialRequest.character_id = &""
	if TrialRequest.with_lesson:
		leaks.append("leaked global state: TrialRequest.with_lesson (reset)")
		TrialRequest.with_lesson = false
	if PuzzleRequest.is_pending():
		leaks.append("leaked global state: PuzzleRequest (reset)")
		PuzzleRequest.take()
	var master: int = AudioServer.get_bus_index(OptionsStore.MASTER_BUS)
	if master >= 0 and (AudioServer.get_bus_volume_db(master) != 0.0 or AudioServer.is_bus_mute(master)):
		leaks.append("leaked global state: Master bus volume %.1f dB, mute %s (reset)" % [
			AudioServer.get_bus_volume_db(master), AudioServer.is_bus_mute(master)])
		AudioServer.set_bus_volume_db(master, 0.0)
		AudioServer.set_bus_mute(master, false)
	return leaks


func _find_test_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(TESTS_DIR):
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			result.append(file_name)
	result.sort()
	return result
